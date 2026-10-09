package com.example.hudyat

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.util.Log

/**
 * The timed wake-up for [InboxCheck]. Android may delay delivery, including
 * while the phone holds the app frozen. Each alarm sets the next one.
 */
object InboxAlarm {
    const val TAG = "HudyatAlarm"
    private const val REQUEST_CODE = 4301

    /**
     * Every 12 hours. Every 2 minutes in a debug build, so a wake-up can be
     * watched; Android adds a window, so it fires about 3½ minutes apart.
     */
    fun intervalMinutes(context: Context): Int =
        if (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) 2 else 12 * 60

    /** Sets the next alarm while the check is on, and clears it when off. */
    fun sync(context: Context) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (!InboxCheck.isOn(context)) {
            alarms.cancel(pendingIntent(context))
            return
        }
        alarms.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis() + intervalMinutes(context) * 60_000L,
            pendingIntent(context),
        )
    }

    private fun pendingIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        REQUEST_CODE,
        Intent(context, InboxAlarmReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}

/** Runs on each alarm, and after a restart or an update to set the alarm again. */
class InboxAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        InboxAlarm.sync(app)
        if (intent.action != null || !InboxCheck.isOn(app)) return
        Log.i(InboxAlarm.TAG, "alarm fired")
        val pending = goAsync()
        Thread {
            try {
                InboxCheck.run(app, alert = true)
            } finally {
                pending.finish()
            }
        }.start()
    }
}
