import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

import com.otoi.safe_pulse.ServiceWatchdogWorker
class SafePulseWatchdogScheduler {

    companion object {

        fun start(context: Context) {

            val request =
                PeriodicWorkRequestBuilder<ServiceWatchdogWorker>(
                    15, TimeUnit.MINUTES
                ).build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "safe_pulse_watchdog",
                ExistingPeriodicWorkPolicy.UPDATE,
                request
            )
        }
    }
}