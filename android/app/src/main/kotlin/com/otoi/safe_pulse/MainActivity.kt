package com.otoi.safe_pulse
import androidx.work.*
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.os.PowerManager
import android.provider.Settings
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    private val CHANNEL = "safe_pulse/location"
    private val notificationPermissionRequestCode = 2001

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestNotificationPermission()
        startWatchdog(this)
        createNotificationChannel(this)
        SafePulseWatchdogScheduler.start(applicationContext)
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                notificationPermissionRequestCode
            )
        }
    }


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
    flutterEngine.dartExecutor.binaryMessenger,
    CHANNEL
).setMethodCallHandler { call, result ->

    Log.d("METHOD_CHANNEL", "Method called: ${call.method}")

    when (call.method) {

         "setForeground" -> {
                        val intent = Intent(this, LocationForegroundService::class.java)

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }

                        result.success("Service started")
                    }

                    "setBackground" -> {
                        val intent = Intent(this, LocationForegroundService::class.java)
                        stopService(intent)
                        result.success("Service stopped")
                    }

                    "isForeground" -> {
    result.success(true) // or track actual state if needed
}


         "startLocationService" -> {
        val intent = Intent(this, LocationForegroundService::class.java)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }

        result.success(true)
    }

    "setAppState" -> {
        val isForeground = call.argument<Boolean>("isForeground") ?: false

        val intent = Intent(this, LocationForegroundService::class.java)
        intent.putExtra("isForeground", isForeground)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }

        result.success(true)
    }

    "requestExactAlarmPermission" -> {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        if (!alarmManager.canScheduleExactAlarms()) {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        }
    }
    result.success(true)
}
        "requestBatteryOptimizationExemption" -> {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
            result.success(true)
        }

        "getManufacturer" -> {
    result.success(Build.MANUFACTURER)
}

"openAutostartSettings" -> {
    val opened = openManufacturerAutostartSettings()
    result.success(opened)
}

        else -> result.notImplemented()
    }
}
    }


//     private fun startWatchdog(context: Context) {

//     val request = PeriodicWorkRequestBuilder<ServiceWatchdogWorker>(
//         15, java.util.concurrent.TimeUnit.MINUTES
//     ).build()

//     WorkManager.getInstance(context).enqueueUniquePeriodicWork(
//         "safe_pulse_watchdog",
//         ExistingPeriodicWorkPolicy.UPDATE,
//         request
//     )
// }

    private fun startWatchdog(context: Context){
           val request = OneTimeWorkRequestBuilder<ServiceWatchdogWorker>()
            .setInitialDelay(1, TimeUnit.MINUTES) // 👈 change to 1–2 min
            .build()

            WorkManager.getInstance(context).enqueue(request)
    }


    private fun createNotificationChannel(context: Context) {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            val channel = NotificationChannel(
                "safe_pulse_tracking_v2",
                "Safe Pulse Tracking",
                NotificationManager.IMPORTANCE_HIGH
            )

            channel.description =
                "Used for background location tracking"

            val manager =
                context.getSystemService(NotificationManager::class.java)

            manager.createNotificationChannel(channel)
        }
    }

    private fun openManufacturerAutostartSettings(): Boolean {
    val manufacturer = Build.MANUFACTURER.lowercase()

    val intents = when {
        manufacturer.contains("xiaomi") -> listOf(
            Intent().apply {
                component = android.content.ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
                )
            }
        )
        manufacturer.contains("oppo") -> listOf(
            Intent().apply {
                component = android.content.ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                )
            },
            Intent().apply {
                component = android.content.ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.startupapp.StartupAppListActivity"
                )
            }
        )
        manufacturer.contains("vivo") -> listOf(
            Intent().apply {
                component = android.content.ComponentName(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                )
            }
        )
        manufacturer.contains("oneplus") -> listOf(
            Intent().apply {
                component = android.content.ComponentName(
                    "com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
                )
            }
        )
        manufacturer.contains("huawei") || manufacturer.contains("honor") -> listOf(
            Intent().apply {
                component = android.content.ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                )
            }
        )
        manufacturer.contains("asus") -> listOf(
            Intent().apply {
                component = android.content.ComponentName(
                    "com.asus.mobilemanager",
                    "com.asus.mobilemanager.autostart.AutoStartActivity"
                )
            }
        )
        else -> emptyList()
    }

    for (intent in intents) {
        try {
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            return true
        } catch (e: Exception) {
            // Try next intent, or fall through
        }
    }

    // Fallback: open the app's own settings page so the user can at least
    // find battery/permission options manually
    return try {
        val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        fallback.data = Uri.parse("package:$packageName")
        fallback.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(fallback)
        false // signal "used fallback, not the real autostart screen"
    } catch (e: Exception) {
        false
    }
}
}