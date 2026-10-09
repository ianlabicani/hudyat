package com.example.hudyat

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

/**
 * SMS recovery status and the seven-day widget counts. The serial protection
 * pipeline performs the work without starting Flutter.
 */
object InboxCheck {
    private const val PREFS = "hudyat_timed"

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

    fun saveCounts(
        context: Context,
        scam: Int,
        caution: Int,
        gambling: Int,
        total: Int,
        checkedAt: Long,
    ) {
        prefs(context).edit()
            .putInt("scam", scam)
            .putInt("caution", caution)
            .putInt("gambling", gambling)
            .putInt("total", total)
            .putLong("checked_at", checkedAt)
            .apply()
        ScamWidget.redraw(context)
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

    fun run(context: Context, alert: Boolean) = ProtectionEngine.scanInbox(context, alert)

    fun openFlagged(context: Context, requestCode: Int): PendingIntent = PendingIntent.getActivity(
        context,
        requestCode,
        Intent(context, MainActivity::class.java)
            .setAction(MainActivity.ACTION_FLAGGED)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

}
