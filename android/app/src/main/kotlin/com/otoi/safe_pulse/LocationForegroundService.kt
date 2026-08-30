package com.otoi.safe_pulse
import android.util.Log

import android.os.HandlerThread
import android.os.Handler

import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import android.os.PowerManager
import android.os.SystemClock
import android.os.Looper
import android.content.Context
// import android.os.Handler

import android.provider.Settings

import android.content.pm.ServiceInfo

import okhttp3.Request
import okhttp3.Response

import android.app.PendingIntent

import android.Manifest
import android.app.*
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import android.location.Location
import java.util.concurrent.TimeUnit

class LocationForegroundService : Service() {

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    // private lateinit var locationCallback: LocationCallback
    private var jwt: String? = null
    private var userId: String? = null
    private var username: String? = null
    private var serverUrl: String? = null
    private var isTracking = false
    private var prefsRetryCount = 0
    private var permissionRetryCount = 0
    private val locationBuffer = ArrayDeque<Location>()
    // private lateinit var handler: Handler
    @Volatile private var isBatchRunning = false
    private var isAppForeground = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var isHeartbeatRunning = false
    @Volatile private var isLocationRegistered = false

    // private var heartbeatStarted = false

    // private var startInProgress = false

    // private lateinit var locationCallback: LocationCallback
    private var locationCallback: LocationCallback? = null


    private var recoveryAttempts = 0
    private val MAX_SOFT_RECOVERY = 5

    private var prevLocation: Location? = null

    private var lastLocationTime = 0L

    private var lastMovementTime = System.currentTimeMillis()
    private var isCurrentlyStationary = false


    private var lastBatchStartTime = 0L
    private val batchTimeoutMs = 2 * 60_000L

    private var lastRecoveryTime = 0L
    private val RECOVERY_COOLDOWN = 5 * 60 * 1000L

    private val lifecycleLock = Any()

    private val watchdogIntervalMs = 30_000L
    private val maxNoLocationMs = 5 * 60_000L
    private var lastHeartbeatTs = System.currentTimeMillis()
    @Volatile private var watchdogStarted = false
    
    // Notification watchdog: restore foreground notification every 10s to catch OEM swipe clearing
    private val notificationWatchdogIntervalMs = 10_000L
    @Volatile private var notificationWatchdogStarted = false

    @Volatile private var startInProgress = false
    @Volatile private var restartInProgress = false

private fun acquireStartLock(): Boolean {
    synchronized(lifecycleLock) {
        if (startInProgress) return false
        startInProgress = true
        return true
    }
}

private fun releaseStartLock() {
    startInProgress = false
}

    @Volatile private var recoveryInProgress = false

    private fun recover(reason: String) {
        val now = System.currentTimeMillis()
        synchronized(lifecycleLock) {
            if (recoveryInProgress) return
            if (now - lastRecoveryTime < RECOVERY_COOLDOWN) {
                Log.d("SAFE_PULSE_RECOVERY", "Skipped recovery (cooldown): $reason")
                return
            }
            recoveryInProgress = true
            lastRecoveryTime = now
        }

        recoveryAttempts++
        Log.e("SAFE_PULSE_RECOVERY", "Recovering: $reason (attempt=$recoveryAttempts)")

        try {
            isTracking = false
            isLocationRegistered = false
            if (::fusedLocationClient.isInitialized) {
                locationCallback?.let { fusedLocationClient.removeLocationUpdates(it) }
            }
            handler.removeCallbacks(heartbeatRunnable)
            handler.removeCallbacks(watchdogRunnable)
            watchdogStarted = false
            isHeartbeatRunning = false
            scheduleServiceRestart(reason)
            retryLoadPrefs(null, 0, 0)
        } catch (e: Exception) {
            Log.e("SAFE_PULSE_RECOVERY", "Recovery failed", e)
        } finally {
            recoveryInProgress = false
        }
    }

    private var consecutiveFailures = 0
    private val maxLiveAttemptsBeforeBufferOnly = 3


    private lateinit var serviceThread: HandlerThread
    private lateinit var handler: Handler

    private val normalRequest = LocationRequest.Builder(
        Priority.PRIORITY_HIGH_ACCURACY,
        15000L
    )
    .setMinUpdateIntervalMillis(12000L)
    .setMinUpdateDistanceMeters(15f)
    .build()

    private val stationaryRequest = LocationRequest.Builder(
        Priority.PRIORITY_LOW_POWER,   // 🔋 BEST FOR BATTERY
        120000L
    )
    .setMinUpdateIntervalMillis(120000L)
    .setMinUpdateDistanceMeters(25f)
    .setWaitForAccurateLocation(false)
    .build()

    companion object {
        const val CHANNEL_ID = "safe_pulse_tracking_v2"
        const val NOTIFICATION_ID = 1001

        const val WATCHDOG_PREFS = "safe_pulse_watchdog"      // ← added
        const val KEY_LAST_ALIVE_TS = "last_alive_ts"          // ← added

        fun persistHeartbeat(context: Context) {                // ← added
            context.getSharedPreferences(WATCHDOG_PREFS, MODE_PRIVATE)
                .edit()
                .putLong(KEY_LAST_ALIVE_TS, System.currentTimeMillis())
                .apply()
        }
    }



    private fun buildTrackingNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Safe Pulse")
            .setContentText("Tracking location")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setSilent(false)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()

        notification.flags = notification.flags or Notification.FLAG_ONGOING_EVENT or Notification.FLAG_NO_CLEAR
        return notification
    }

    private fun refreshTrackingNotification(useLocationServiceType: Boolean = true) {
        try {
            val notification = buildTrackingNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && useLocationServiceType) {
                try {
                    // Try to start with location type (requires app to be in foreground on Android 15+)
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                    )
                } catch (e: SecurityException) {
                    // If location type fails (app not in foreground), start without type
                    Log.w("SAFE_PULSE_SERVICE", "Cannot start with location type, falling back to generic FGS", e)
                    startForeground(
                        NOTIFICATION_ID,
                        notification
                    )
                }
            } else {
                startForeground(
                    NOTIFICATION_ID,
                    notification
                )
            }
            Log.d("SAFE_PULSE_SERVICE", "Foreground notification refreshed")
        } catch (e: Exception) {
            Log.e("SAFE_PULSE_SERVICE", "Failed to refresh foreground notification", e)
        }
    }

    override fun onCreate() {
        super.onCreate()

        isTracking = false

        serviceThread = HandlerThread("safe-pulse-thread")
        serviceThread.start()

        handler = Handler(serviceThread.looper)

//         if (!heartbeatStarted) {
//     heartbeatStarted = true
//     handler.post(heartbeatRunnable)
// }

        createNotificationChannel()

        // Never use location service type in onCreate (app likely in background)
        // Only use it in heartbeat/watchdog when app is confirmed active
        refreshTrackingNotification(useLocationServiceType = false)

        Log.e("SAFE_PULSE", "Notification should be visible now")

        Log.e("SAFE_PULSE_SERVICE", "ABOUT TO START FOREGROUND")

        Log.e("SAFE_PULSE_SERVICE", "STARTED FOREGROUND CALL DONE")

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        Log.d("SAFE_PULSE_SERVICE", "Location client initialized")

        lastLocationTime = 0L
        Log.d("SAFE_PULSE_HEARTBEAT", "alive")
        persistHeartbeat(this@LocationForegroundService)

        // Permission check will happen in startLocationUpdates() when actually registering for location updates
        // For now, just proceed with loading preferences to initiate tracking flow

        // if (!isHeartbeatRunning) {
        //     isHeartbeatRunning = true
        //     handler.post(heartbeatRunnable)
        // }


        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SafePulse::LocationWakeLock"
        )
        if (wakeLock?.isHeld != true) {
            wakeLock?.acquire(10 * 60 * 1000L) // 10 min
        }
    }

    // private val handler = Handler(mainLooper)

    private var batchBackoffMs = 30_000L
    private val maxBackoffMs = 10 * 60_000L

    @Volatile
    private var batchInFlight = false

    private val batchRunnable = object : Runnable {
        override fun run() {

            val now = System.currentTimeMillis()

            // 🔥 safety reset if stuck
            if (batchInFlight && now - lastBatchStartTime > batchTimeoutMs) {
                Log.e("SAFE_PULSE_BATCH", "RESETTING STUCK batchInFlight")
                batchInFlight = false
            }

            if (batchInFlight) {
                handler.postDelayed(this, 5000)
                return
            }

            if (locationBuffer.isNotEmpty()) {

                batchInFlight = true
                lastBatchStartTime = now   // 🔥 IMPORTANT

                sendBatchToServer()

                handler.postDelayed(this, batchBackoffMs)
                batchBackoffMs = (batchBackoffMs * 2).coerceAtMost(maxBackoffMs)

            } else {
                isBatchRunning = false
                batchBackoffMs = 30_000L
                consecutiveFailures = 0
            }
        }
    }

    private fun scheduleServiceRestart(reason: String) {
        try {
            val restartIntent = Intent(applicationContext, LocationForegroundService::class.java)
            val pendingIntent = PendingIntent.getService(
                applicationContext,
                999,
                restartIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerAt = SystemClock.elapsedRealtime() + 2_000L
            val canScheduleExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                alarmManager.canScheduleExactAlarms()

            if (canScheduleExact) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    pendingIntent
                )
            } else {
                alarmManager.set(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    pendingIntent
                )
            }

            Log.d("SAFE_PULSE_RECOVERY", "Scheduled service restart after: $reason")
        } catch (e: Exception) {
            Log.e("SAFE_PULSE_RECOVERY", "Failed to schedule restart", e)
        }
    }

    private fun startWatchdogIfNeeded() {
        if (watchdogStarted) return
        watchdogStarted = true
        handler.post(watchdogRunnable)
    }

    private fun stopWatchdog() {
        watchdogStarted = false
        handler.removeCallbacks(watchdogRunnable)
    }
    
    private fun startNotificationWatchdogIfNeeded() {
        if (notificationWatchdogStarted) return
        notificationWatchdogStarted = true
        handler.post(notificationWatchdogRunnable)
    }

    private fun stopNotificationWatchdog() {
        notificationWatchdogStarted = false
        handler.removeCallbacks(notificationWatchdogRunnable)
    }

    private val notificationWatchdogRunnable = object : Runnable {
        override fun run() {
            // Re-apply foreground notification every 10s to defend against OEM clearing
            if (isTracking && isLocationRegistered) {
                refreshTrackingNotification()
            }

            if (notificationWatchdogStarted) {
                handler.postDelayed(this, notificationWatchdogIntervalMs)
            }
        }
    }

    private val watchdogRunnable = object : Runnable {
        override fun run() {
            val now = System.currentTimeMillis()
            val lastKnownLocationAge = if (lastLocationTime > 0L) now - lastLocationTime else Long.MAX_VALUE

            if (isLocationRegistered && lastLocationTime > 0L && lastKnownLocationAge > maxNoLocationMs) {
                Log.e("SAFE_PULSE_RECOVERY", "Watchdog: no location updates for ${lastKnownLocationAge}ms")
                recover("watchdog stale location")
                return
            }

            if (isLocationRegistered && now - lastHeartbeatTs > 2 * 60_000L) {
                Log.e("SAFE_PULSE_RECOVERY", "Watchdog: heartbeat stale for ${now - lastHeartbeatTs}ms")
                recover("watchdog stale heartbeat")
                return
            }

            if (watchdogStarted) {
                handler.postDelayed(this, watchdogIntervalMs)
            }
        }
    }

    // Fires every 60s regardless of whether a location fix arrives. If this
    // stops appearing in logcat but the notification is still showing, the
    // process has been frozen by the OS (not killed) -- distinguishes that
    // from "fixes are arriving but failing the accuracy filter."

    private val heartbeatRunnable = object : Runnable {
        override fun run() {
            val now = System.currentTimeMillis()
            lastHeartbeatTs = now
            persistHeartbeat(this@LocationForegroundService)

            if (isLocationRegistered &&
                lastLocationTime > 0L &&
                now - lastLocationTime > 5 * 60 * 1000
            ) {
                recover("heartbeat timeout")
            }

            if (!isHeartbeatRunning) return

            wakeLock?.let {
                if (!it.isHeld) it.acquire(10 * 60 * 1000L)
            }

            Log.d("SAFE_PULSE_HEARTBEAT", "alive")
            refreshTrackingNotification()

            sendHeartbeat()

            handler.postDelayed(this, 60000)
        }
    }


    private fun sendHeartbeat() {

    if (userId.isNullOrEmpty() || jwt.isNullOrEmpty() || serverUrl.isNullOrEmpty()) {
        Log.e("HB", "Missing credentials, skipping heartbeat")
        return
    }

    val deviceId = Settings.Secure.getString(
        contentResolver,
        Settings.Secure.ANDROID_ID
    )

    val json = JSONObject().apply {
        put("userId", userId)
        put("deviceId", deviceId)
        put("battery", getBatteryLevel())
        put("appState", "FOREGROUND")
        put("locationActive", isTracking)
        put("lastLocationTime", lastLocationTime)
        put("appVersion", "1.0")
    }

    val body = json.toString()
        .toRequestBody("application/json".toMediaType())

    val request = Request.Builder()
        .url("${serverUrl}/api/device/heartbeat")
        .addHeader("Authorization", "Bearer $jwt")
        .post(body)
        .build()

    client.newCall(request).enqueue(object : Callback {

        override fun onFailure(call: Call, e: IOException) {
            Log.e("HB", "failed", e)

            consecutiveFailures++
        }

        override fun onResponse(call: Call, response: Response) {
            Log.d("HB", "heartbeat sent: ${response.code}")
            response.close()
        }
    })
}


private fun getBatteryLevel(): Int {
    val bm = getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
    return bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
}

private fun tryStartLocationUpdates(): Boolean {
    synchronized(lifecycleLock) {
        if (startInProgress) return false
        startInProgress = true
        return true
    }
}

    // FIX: a single reusable main-thread handler + tracked runnable so that if
    // retryLoadPrefs() is triggered from two places close together (e.g.
    // onStartCommand() and hardRecover()'s restart chain), the second call
    // cancels the first pending attempt instead of letting both chains run
    // concurrently and each independently retry/schedule.
    private val mainHandler = Handler(Looper.getMainLooper())
    private var prefsRetryRunnable: Runnable? = null
    private var permissionRetryRunnable: Runnable? = null

private fun retryLoadPrefs(intent: Intent?, flags: Int, startId: Int) {
    Log.e("SAFE_PULSE_DEBUG", "retryLoadPrefs called")

    prefsRetryRunnable?.let { mainHandler.removeCallbacks(it) }

    val runnable = Runnable {

        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)

        jwt = prefs.getString("flutter.jwtToken", null)
        userId = prefs.getString("flutter.userId", null)
        serverUrl = prefs.getString("flutter.serverUrl", null)

        Log.d("SAFE_PULSE_DEBUG", "Preferences loaded: jwt=${!jwt.isNullOrEmpty()}, userId=${!userId.isNullOrEmpty()}, server=${!serverUrl.isNullOrEmpty()}")

        Log.d(
    "SAFE_PULSE_PREFS",
    "jwt=${!jwt.isNullOrEmpty()}, userId=$userId, server=$serverUrl"
)

        if (!userId.isNullOrEmpty() &&
    !jwt.isNullOrEmpty() &&
    !serverUrl.isNullOrEmpty()
) {
    Log.d("SAFE_PULSE_SERVICE", "Prefs loaded, starting tracking")

    // FIX: isTracking was being set true here, right before
    // startTrackingIfNeeded()'s own `if (isTracking) return` guard --
    // which made that guard fire immediately and skip
    // startLocationUpdates() entirely. isTracking is now only set true
    // once startLocationUpdates() actually registers for updates.
    // startTrackingIfNeeded()
    startTracking()

} else {

    // if (prefsRetryCount < 10) {
    //     prefsRetryCount++
    //     Log.d("SAFE_PULSE_SERVICE", "Retrying prefs ($prefsRetryCount)")
    //     retryLoadPrefs(intent, flags, startId)
    // } else {
    //     Log.e("SAFE_PULSE_SERVICE", "Prefs failed, retrying forever")

    //     mainHandler.postDelayed({
    //         retryLoadPrefs(intent, flags, startId)
    //     }, 10000)
    // }
    val delay = (3000L * (prefsRetryCount + 1)).coerceAtMost(30000L)

mainHandler.postDelayed({
    retryLoadPrefs(intent, flags, startId)
}, delay)

prefsRetryCount++
}

    }
    prefsRetryRunnable = runnable
    mainHandler.postDelayed(runnable, 3000)
}




    // @Synchronized
    // private fun startTrackingIfNeeded() {
    //     if (isTracking) return
    //     // isTracking = true
    //     startLocationUpdates()
    // }

    private fun startTracking() {
    if (!acquireStartLock()) return

    try {
        if (isTracking && isLocationRegistered && locationCallback != null) return

        if (startLocationUpdates()) {
            startHeartbeatIfNeeded()
        }

    } finally {
        releaseStartLock()
    }
}

private fun startHeartbeatIfNeeded() {
    if (isHeartbeatRunning) return

    isHeartbeatRunning = true
    lastHeartbeatTs = System.currentTimeMillis()
    startWatchdogIfNeeded()
    startNotificationWatchdogIfNeeded()

    handler.post(heartbeatRunnable)
    Log.d("SAFE_PULSE_HEARTBEAT", "Heartbeat started")
}


    private fun startLocationUpdates(): Boolean {

        if (isLocationRegistered && locationCallback != null) return true

        if (!::fusedLocationClient.isInitialized) {
            fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
            Log.d("SAFE_PULSE_SERVICE", "Location client initialized lazily")
        }


        // if (!tryStartLocationUpdates()) return

        try {

        // if (!acquireStartLock()) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val backgroundGranted =
                ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.ACCESS_BACKGROUND_LOCATION
                ) == PackageManager.PERMISSION_GRANTED

                Log.d(
                    "SAFE_PULSE_SERVICE",
                    "Background location granted: $backgroundGranted"
                )



                if (!backgroundGranted) {
                    // FIX: don't claim we're tracking when we haven't actually
                    // registered for location updates yet.
                    isTracking = false

                    if (permissionRetryCount < 5) {
                        permissionRetryCount++
                        Log.e("SAFE_PULSE_SERVICE", "No background permission, retrying...")
                        permissionRetryRunnable?.let { mainHandler.removeCallbacks(it) }
                        val retry = Runnable { startTracking() }
                        permissionRetryRunnable = retry
                        mainHandler.postDelayed(retry, 10000)
                    } else {
                        Log.e("SAFE_PULSE_SERVICE", "Permission missing permanently")
                    }
                    return false
                }
            }


            // FIX: startLocationUpdates() can be re-entered from recovery/retry
            // paths and always creates a brand-new locationCallback instance.
            // Without removing the *old* instance's registration first, a stale
            // listener can keep running alongside the new one on some OEMs
            // (duplicate callbacks, extra battery drain, inconsistent accuracy).
        if (::fusedLocationClient.isInitialized) {
    locationCallback?.let { 
        fusedLocationClient.removeLocationUpdates(it)
     }
     locationCallback = null
}

            locationCallback = object : LocationCallback() {
            
                override fun onLocationResult(result: LocationResult) {

                    Log.d(
                        "SAFE_PULSE_SERVICE",
                        "Location callback fired. Count = ${result.locations.size}"
                    )

                    // wakeLock?.let {
                    //     if (!it.isHeld) it.acquire(60 * 60 * 1000L)
                    // }
        


                    synchronized(locationBuffer) {
                        for (location in result.locations) {

                            val previous = prevLocation  // 🔥 snapshot FIRST

                            val distance = if (previous != null)
                                location.distanceTo(previous)
                            else Float.MAX_VALUE

                            val isNoise =
                                previous != null &&
                                distance < 5f &&
                                location.accuracy > 25f

                                // ✅ only update prevLocation ONCE (clean rule)
                            if (!isNoise) {
                                prevLocation = location
                            }

                            if (lastLocationTime == 0L) {
    Log.d("SAFE_PULSE", "FIRST GPS FIX RECEIVED")
}

                            lastLocationTime = System.currentTimeMillis()
                            isTracking = true
                            persistHeartbeat(this@LocationForegroundService)

                            Log.d(
                                "SAFE_PULSE_LOCATION",
                                "Lat=${location.latitude}, Lng=${location.longitude}, Acc=${location.accuracy}, Speed=${location.speed}"
                            )

                            val shouldBufferOnly =
                                consecutiveFailures >= maxLiveAttemptsBeforeBufferOnly

                            if (shouldBufferOnly) {
                                bufferLocation(location)
                            } else {
                                sendLocationToServer(location, location.accuracy > 80)
                            }

                            // 🔥 movement detection (use snapshot, NOT prevLocation)
                            val moved =
                                location.speed > 0.3f ||
                                distance > 5f

                            if (moved) {
                                lastMovementTime = System.currentTimeMillis()

                                if (isCurrentlyStationary) {
                                    switchLocationMode(false)
                                }

                            } else {
                                val timeSinceMove = System.currentTimeMillis() - lastMovementTime

                                if (timeSinceMove > 5 * 60 * 1000L && !isCurrentlyStationary) {
                                    switchLocationMode(true)
                                }
                            }
                        }
                    }
                }
            }
            if (
                ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.ACCESS_FINE_LOCATION
                ) != PackageManager.PERMISSION_GRANTED &&
                ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                Log.e("SAFE_PULSE_SERVICE", "Location permission missing")
                isTracking = false
                stopSelf()
                return false
            }

            Log.d("SAFE_PULSE_SERVICE", "Requesting location updates")

            val callback = locationCallback ?: return false
            fusedLocationClient.requestLocationUpdates(
                normalRequest,
                callback,
                handler.looper
            )

            isLocationRegistered = true
            isTracking = true
            permissionRetryCount = 0
            permissionRetryRunnable?.let { mainHandler.removeCallbacks(it) }
            permissionRetryRunnable = null

            // batchRunnable is now started lazily, only when a send actually
            // fails (see sendLocationToServer's onFailure) -- it's a retry queue
            // for offline stretches, not a second delivery path for every point.

            Log.d("SAFE_PULSE_SERVICE", "Location updates started")
            return true

        } catch (e: Exception) {

            Log.e("SAFE_PULSE_CRASH", "CRASH INSIDE LOCATION", e)

            isTracking = false
                isLocationRegistered = false
                return false
        } finally {
                releaseStartLock()
        }
    }

    private fun createNotificationChannel() {
        Log.d("SAFE_PULSE_DEBUG", "Creating notification channel")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            // Persistent tracking notification: LOW importance means no sound,
            // no heads-up popup, no vibration. Matches setPriority(PRIORITY_LOW)
            // above -- channel importance is what Android actually honors on O+.
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Safe Pulse Tracking",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Foreground location tracking"
            
            Log.d("SAFE_PULSE_DEBUG", "Channel importance set to LOW")


            val manager =
                getSystemService(NotificationManager::class.java)

            manager.createNotificationChannel(channel)
        }
    }

    private fun sendBatchToServer() {

        if (locationBuffer.isEmpty()) return

        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
        val network = cm.activeNetwork
        val caps = cm.getNetworkCapabilities(network)

        val isConnected = caps?.hasCapability(
            android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET
        ) == true

        if (!isConnected) {
            Log.d("SAFE_PULSE_BATCH", "No internet")
            return
        }

        val locationsToSend = synchronized(locationBuffer) {
            val copy = ArrayList<Location>(locationBuffer)
            locationBuffer.clear()
            copy
        }

        val jsonArray = org.json.JSONArray()

        for (loc in locationsToSend) {

            val isoTimestamp = java.text.SimpleDateFormat(
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
                java.util.Locale.US
            ).apply {
                timeZone = java.util.TimeZone.getTimeZone("UTC")
            }.format(java.util.Date(loc.time))

            val obj = JSONObject().apply {
                put("userId", userId)
                put("latitude", loc.latitude)
                put("longitude", loc.longitude)
                put("timestamp", isoTimestamp)
            }

            jsonArray.put(obj)
        }

        val body = JSONObject().apply {
            put("locations", jsonArray)
        }.toString().toRequestBody("application/json".toMediaType())

        val request = Request.Builder()
            .url("${serverUrl}/api/location/batch")
            .addHeader("Authorization", "Bearer $jwt")
            .post(body)
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("SAFE_PULSE_BATCH", "Failed", e)

                synchronized(locationBuffer) {
                    locationBuffer.addAll(locationsToSend)
                }
                batchInFlight = false
            }

            override fun onResponse(call: Call, response: Response) {
                Log.d("SAFE_PULSE_BATCH", "Sent batch: ${response.code}")
                response.close()

                batchInFlight = false        // 🔥 CRITICAL
                batchBackoffMs = 30_000L     // reset retry delay
            }
        })
    }

    private val client = OkHttpClient.Builder()
    .connectTimeout(10, TimeUnit.SECONDS)
    .readTimeout(10, TimeUnit.SECONDS)
    .writeTimeout(10, TimeUnit.SECONDS)
    .callTimeout(15, TimeUnit.SECONDS)
    .retryOnConnectionFailure(true)
    .build()

  

    private fun sendLocationToServer(location: android.location.Location, lowAccuracy: Boolean = false) {

        Log.d("SAFE_PULSE_HTTP", "userId = $userId")
        Log.d("SAFE_PULSE_HTTP", "jwt = ${!jwt.isNullOrEmpty()}")
        Log.d("SAFE_PULSE_HTTP", "serverUrl = $serverUrl")

        if (userId.isNullOrEmpty() ||
            jwt.isNullOrEmpty() ||
            serverUrl.isNullOrEmpty()) {

            Log.e("SAFE_PULSE_HTTP", "Missing credentials")
            return
        }

        // location.time is the actual GPS fix capture time (epoch millis),
        // not the time the HTTP request happens to arrive at the server.
        val isoTimestamp = java.text.SimpleDateFormat(
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            java.util.Locale.US
        ).apply {
            timeZone = java.util.TimeZone.getTimeZone("UTC")
        }.format(java.util.Date(location.time))

        val json = JSONObject().apply {
            put("userId", userId)
            put("latitude", location.latitude)
            put("longitude", location.longitude)
            put("timestamp", isoTimestamp)
            put("lowAccuracy", lowAccuracy)
        }

        val token = jwt ?: run {
        Log.e("SAFE_PULSE_HTTP", "JWT null, skipping")
        return
        }

        val body = json.toString()
            .toRequestBody("application/json".toMediaType())

        val baseUrl = serverUrl?.trimEnd('/') ?: run {
            Log.e("SAFE_PULSE_HTTP", "serverUrl null, skipping")
            return
        }

        val url = "$baseUrl/api/location/update"

        if (!url.startsWith("http")) {
            Log.e("SAFE_PULSE_HTTP", "Invalid URL: $url")
            return
        }

        val request = Request.Builder()
            .url(url)
            .addHeader("Authorization", "Bearer $token")
            .post(body)
            .build()
            Log.d("SAFE_PULSE_HTTP", json.toString())

            client.newCall(request).enqueue(object : Callback {

                override fun onFailure(call: Call, e: IOException) {
                    Log.e("SAFE_PULSE_HTTP", "Failed (${consecutiveFailures})", e)

                    consecutiveFailures++

                    // 🔥 ALWAYS unlock batch system on failure
                    batchInFlight = false

                    synchronized(locationBuffer) {
                        locationBuffer.add(location)
                        if (locationBuffer.size > 100) {
                            locationBuffer.removeFirst()
                        }
                    }

                    // 🔥 ensure batch runner is active (single source of truth)
                    startBatchLoopIfNeeded()
                }

                override fun onResponse(call: Call, response: Response) {
                    consecutiveFailures = 0 
                    val body = response.body?.string()

                    Log.d("SAFE_PULSE_HTTP", "Code = ${response.code}")
                    Log.d("SAFE_PULSE_HTTP", "Body = $body")

                    response.close()
                    consecutiveFailures = 0
                    batchBackoffMs = 30_000L
                    batchInFlight = false
                }
            })
    }

   

    override fun onDestroy() {
        Log.e("SAFE_PULSE_SERVICE", "onDestroy called - cleaning up")

        isTracking = false
        handler.removeCallbacks(heartbeatRunnable)
        stopWatchdog()
        stopNotificationWatchdog()
        isHeartbeatRunning = false
        isBatchRunning = false
        handler.removeCallbacks(batchRunnable)
        recoveryInProgress = false
        batchInFlight = false

        try {
            // 1. Stop location updates safely
           if (::fusedLocationClient.isInitialized) {
                locationCallback?.let { fusedLocationClient.removeLocationUpdates(it) }
            }
            isLocationRegistered = false
            // locationCallback = null
        } catch (e: Exception) {
            Log.e("SAFE_PULSE_SERVICE", "Error stopping location updates", e)
        }

        try {
            // 2. Stop handler tasks (IMPORTANT)
            if (::handler.isInitialized) {
                handler.removeCallbacksAndMessages(null)
            }
        } catch (e: Exception) {
            Log.e("SAFE_PULSE_SERVICE", "Handler cleanup failed", e)
        }

        try {
            // 3. Stop thread safely
            if (::serviceThread.isInitialized) {
                serviceThread.quitSafely()
            }
        } catch (e: Exception) {
            Log.e("SAFE_PULSE_SERVICE", "Thread shutdown failed", e)
        }

        try {
            // 4. Release WakeLock
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.e("SAFE_PULSE_SERVICE", "WakeLock release failed", e)
        }

        try {
            // 5. Clear buffers
            synchronized(locationBuffer) {
                locationBuffer.clear()
            }
        } catch (e: Exception) {
            Log.e("SAFE_PULSE_SERVICE", "Buffer clear failed", e)
        }

        super.onDestroy()

        Log.e("SAFE_PULSE_SERVICE", "Service fully destroyed")
    }


    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)


        Log.d("SAFE_PULSE_SERVICE", "Task removed, scheduling restart")
        startBatchLoopIfNeeded()

        val restartIntent = Intent(applicationContext, LocationForegroundService::class.java)
        val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.PendingIntent.getForegroundService(
                applicationContext,
                1,
                restartIntent,
                android.app.PendingIntent.FLAG_ONE_SHOT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            android.app.PendingIntent.getService(
                applicationContext,
                1,
                restartIntent,
                android.app.PendingIntent.FLAG_ONE_SHOT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
        }

        // NOTE: setExactAndAllowWhileIdle silently degrades to an inexact alarm
        // (or is dropped) on API 31+ unless SCHEDULE_EXACT_ALARM is granted.
        // canScheduleExactAlarms() doesn't exist pre-S, so short-circuit past it there.
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val canScheduleExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()

        if (canScheduleExact) {
            alarmManager.setExactAndAllowWhileIdle(
                android.app.AlarmManager.ELAPSED_REALTIME_WAKEUP,
                android.os.SystemClock.elapsedRealtime() + 1000,
                pendingIntent
            )
        } else {
            Log.e("SAFE_PULSE_SERVICE", "No exact alarm permission -- falling back to inexact restart")
            alarmManager.set(
                android.app.AlarmManager.ELAPSED_REALTIME_WAKEUP,
                android.os.SystemClock.elapsedRealtime() + 1000,
                pendingIntent
            )
        }
    }
   
   
    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {
        Log.d("SAFE_PULSE_SERVICE", "Service started")
        
        // Never use location service type on initial start (app may be in background)
        // Periodic updates from heartbeat/watchdog will upgrade it when appropriate
        refreshTrackingNotification(useLocationServiceType = false)
        // handler.post(batchRunnable)

        // wakeLock?.let { if (!it.isHeld) it.acquire(60 * 60 * 1000L) } // 1 hour
        retryLoadPrefs(intent, flags, startId)
        

        // return START_NOT_STICKY
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
    private fun switchLocationMode(stationary: Boolean) {
        if (isCurrentlyStationary == stationary) return
        isCurrentlyStationary = stationary

        Log.d("SAFE_PULSE_SERVICE", "Switching to ${if (stationary) "STATIONARY" else "NORMAL"} mode")

        val callback = locationCallback ?: return
        fusedLocationClient.removeLocationUpdates(callback)
        isLocationRegistered = false
        fusedLocationClient.requestLocationUpdates(
            if (stationary) stationaryRequest else normalRequest,
            callback,
            handler.looper
        )
        isLocationRegistered = true
    }
    

    private fun bufferLocation(location: Location) {
        synchronized(locationBuffer) {
            locationBuffer.add(location)
            if (locationBuffer.size > 100) locationBuffer.removeFirst()
        }

        startBatchLoopIfNeeded()
    }

    private fun startBatchLoopIfNeeded() {
        if (isBatchRunning) return
        isBatchRunning = true
        handler.post(batchRunnable)
    }
}