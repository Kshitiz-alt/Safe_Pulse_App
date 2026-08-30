package com.otoi.safe_pulse

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class SafePulseBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (
    intent.action == Intent.ACTION_BOOT_COMPLETED ||
    intent.action == Intent.ACTION_REBOOT ||
    intent.action == "android.intent.action.QUICKBOOT_POWERON"
) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val userId = prefs.getString("flutter.userId", null)
            val jwt = prefs.getString("flutter.jwtToken", null)

            if (!userId.isNullOrEmpty() && !jwt.isNullOrEmpty()) {
                val serviceIntent = Intent(context, LocationForegroundService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
        }
    }
}