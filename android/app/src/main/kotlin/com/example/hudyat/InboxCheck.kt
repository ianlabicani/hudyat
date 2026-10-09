package com.example.hudyat

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import com.example.hudyat.check.MessageRules
import com.example.hudyat.check.PackRules

/**
 * The timed check: reads the last 7 days of the SMS inbox, runs the rules,
 * alerts once for each new "Mukhang scam" text and saves the counts the
 * widget shows. All in Kotlin, so it runs when Android wakes the app by
 * alarm with no Flutter engine behind it. It keeps counts and ids only,
 * never a message's text.
 */
object InboxCheck {
    private const val TAG = "HudyatCheck"
    private const val PREFS = "hudyat_timed"
    private const val WINDOW_MS = 7L * 24 * 60 * 60 * 1000
    private const val CHANNEL_ID = "scam_alerts"

    const val NO_ACCESS = "no_access"
    const val NOT_CHECKED = "not_checked"
    const val CHECKED = "checked"

    class Counts(
        val state: String,
        val scam: Int,
        val caution: Int,
        val gambling: Int,
        val total: Int,
        val checkedAt: Long,
    )

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isOn(context: Context): Boolean = prefs(context).getBoolean("on", false)

    fun setOn(context: Context, on: Boolean) {
        prefs(context).edit().putBoolean("on", on).apply()
    }

    fun canReadSms(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED

    fun canNotify(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    fun counts(context: Context): Counts {
        val saved = prefs(context)
        val state = when {
            !canReadSms(context) -> NO_ACCESS
            saved.getLong("checked_at", 0) == 0L -> NOT_CHECKED
            else -> CHECKED
        }
        return Counts(
            state,
            saved.getInt("scam", 0),
            saved.getInt("caution", 0),
            saved.getInt("gambling", 0),
            saved.getInt("total", 0),
            saved.getLong("checked_at", 0),
        )
    }

    /**
     * Checks the inbox and redraws the widget. With [alert] false, texts
     * already there are marked as seen without a notification: turning the
     * check on must not alert for last week's messages.
     */
    @Synchronized
    fun run(context: Context, alert: Boolean) {
        val started = System.currentTimeMillis()
        try {
            if (!canReadSms(context)) {
                Log.i(TAG, "skipped: no SMS access")
                return
            }
            val pack = PackRules.load(context)
            if (pack == null) {
                Log.i(TAG, "skipped: pack not readable")
                return
            }
            val rules = MessageRules(pack.data)
            val saved = prefs(context)
            val alerted = saved.getStringSet("alerted", emptySet())!!
            val stillThere = HashSet<String>()
            var scam = 0
            var caution = 0
            var gambling = 0
            var raised = 0
            val texts = SmsReader.read(context, started - WINDOW_MS, 0, 5000)
            for (text in texts) {
                val id = text["id"].toString()
                val sender = text["sender"] as String
                val verdict = rules.check(text["body"] as String, sender)
                if (verdict.reasons.any { it.id == MessageRules.GAMBLING_PROMO }) gambling++
                if (verdict.name == com.example.hudyat.check.Verdict.CAUTION) caution++
                if (!verdict.isScam) continue
                scam++
                stillThere.add(id)
                if (alert && id !in alerted && canNotify(context)) {
                    notify(context, id, sender, pack.describe(verdict.reasons.first()))
                    raised++
                }
            }
            saved.edit()
                .putStringSet("alerted", stillThere)
                .putInt("scam", scam)
                .putInt("caution", caution)
                .putInt("gambling", gambling)
                .putInt("total", texts.size)
                .putLong("checked_at", started)
                .apply()
            Log.i(
                TAG,
                "checked ${texts.size} texts in ${System.currentTimeMillis() - started} ms: " +
                    "$scam scam, $caution caution, $gambling gambling, $raised alerts",
            )
        } catch (error: Exception) {
            Log.w(TAG, "failed: ${error.javaClass.simpleName}")
        } finally {
            ScamWidget.redraw(context)
        }
    }

    fun openFlagged(context: Context, requestCode: Int): PendingIntent = PendingIntent.getActivity(
        context,
        requestCode,
        Intent(context, MainActivity::class.java)
            .setAction(MainActivity.ACTION_FLAGGED)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun notify(context: Context, smsId: String, sender: String, reason: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Scam alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Text messages checked as \"Mukhang scam\""
            },
        )
        val from = sender.ifBlank { "hindi kilalang sender" }
        val notification = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_hudyat)
            .setContentTitle("Mukhang scam ang mensahe mula kay $from")
            .setContentText(reason)
            .setStyle(Notification.BigTextStyle().bigText(reason))
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setContentIntent(openFlagged(context, 4400))
            .addAction(
                Notification.Action.Builder(null, "Tingnan", openFlagged(context, 4400)).build(),
            )
            .setAutoCancel(true)
            .build()
        manager.notify(smsId.hashCode(), notification)
    }
}
