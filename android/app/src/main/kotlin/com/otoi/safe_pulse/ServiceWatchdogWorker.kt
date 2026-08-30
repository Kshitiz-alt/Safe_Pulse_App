package com.otoi.safe_pulse

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters

import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit
import android.os.Build


class ServiceWatchdogWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    override fun doWork(): Result {

        Log.e("SAFE_PULSE_WATCHDOG", "Checking service...")

        val prefs = applicationContext.getSharedPreferences(
            LocationForegroundService.WATCHDOG_PREFS,
            Context.MODE_PRIVATE
        )

        val lastAlive = prefs.getLong(
            LocationForegroundService.KEY_LAST_ALIVE_TS,
            0L
        )

        val now = System.currentTimeMillis()
        val isDead = now - lastAlive > 5 * 60 * 1000L

        if (isDead) {
            Log.e("SAFE_PULSE_WATCHDOG", "Service frozen → restarting")

            try {
                val intent = Intent(applicationContext, LocationForegroundService::class.java)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    applicationContext.startForegroundService(intent)
                } else {
                    applicationContext.startService(intent)
                }

            } catch (e: Exception) {
                Log.e("SAFE_PULSE_WATCHDOG", "Restart failed", e)
            }

        } else {
            Log.d("SAFE_PULSE_WATCHDOG", "Service alive")
        }

        return Result.success()
    }
}