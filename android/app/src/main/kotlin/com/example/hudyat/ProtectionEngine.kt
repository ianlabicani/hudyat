package com.example.hudyat

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.provider.Telephony
import android.util.Log
import com.example.hudyat.check.Links
import com.example.hudyat.check.MessageRules
import com.example.hudyat.check.PackRules
import com.example.hudyat.check.Verdict
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

/** One serial worker for SMS, app notifications, and the recovery alarm. */
internal object ProtectionEngine {
    private const val PREFS = "hudyat_protection"
    private const val CHANNEL_ID = "scam_alerts"
    private const val SEVEN_DAYS = 7L * 24 * 60 * 60 * 1000
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var cachedPack: PackRules? = null
    private var cachedChecker: MessageRules? = null
    private var packStamp: Pair<Long, Long>? = null

    @Volatile var listenerConnected = false
    @Volatile var resultsChanged: (() -> Unit)? = null

    private val knownApps = linkedMapOf(
        "com.google.android.apps.messaging" to "Messages",
        "com.android.mms" to "Messages",
        "com.samsung.android.messaging" to "Messages",
        "com.facebook.orca" to "Messenger",
        "com.whatsapp" to "WhatsApp",
        "com.viber.voip" to "Viber",
        "org.telegram.messenger" to "Telegram",
        "org.telegram.messenger.web" to "Telegram",
    )

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun execute(context: Context, task: () -> Unit) {
        val app = context.applicationContext
        worker.execute {
            try {
                task()
            } catch (error: Exception) {
                // No message bodies, sender names, or notification extras in logs.
                prefs(app).edit().putString("failure", error.javaClass.simpleName).apply()
            }
        }
    }

    fun appsOn(context: Context) = prefs(context).getBoolean("apps_on", false)

    fun setAppsOn(context: Context, value: Boolean) {
        prefs(context).edit().putBoolean("apps_on", value).apply()
    }

    fun stopAll(context: Context) {
        InboxCheck.setOn(context, false)
        setAppsOn(context, false)
        InboxAlarm.sync(context)
    }

    private fun enabledPackages(context: Context): Set<String> =
        prefs(context).getStringSet("packages", null)?.toSet() ?: supported(context).keys

    fun sourceEnabled(context: Context, pkg: String): Boolean = pkg in enabledPackages(context)

    fun setSourceEnabled(context: Context, pkg: String, enabled: Boolean) {
        if (pkg !in supported(context)) return
        val updated = enabledPackages(context).toMutableSet()
        if (enabled) updated.add(pkg) else updated.remove(pkg)
        prefs(context).edit().putStringSet("packages", updated).apply()
    }

    private fun supported(context: Context): Map<String, String> = knownApps.toMutableMap().apply {
        Telephony.Sms.getDefaultSmsPackage(context)?.let { putIfAbsent(it, "Messages") }
    }

    fun sourceName(context: Context, pkg: String): String? = supported(context)[pkg]

    fun isSmsApp(context: Context, pkg: String): Boolean =
        pkg == Telephony.Sms.getDefaultSmsPackage(context) ||
            (knownApps[pkg] == "Messages")

    fun notificationAccess(context: Context): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver, "enabled_notification_listeners",
        ) ?: return false
        val target = ComponentName(context, ScamNotificationListener::class.java)
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == target }
    }

    fun canCaptureSms(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED

    private fun manager(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun ensureChannel(context: Context) {
        manager(context).createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Scam alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Warnings for messages checked as Mukhang scam"
            },
        )
    }

    fun canAlert(context: Context): Boolean {
        ensureChannel(context)
        val permission = Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        return permission && manager(context).areNotificationsEnabled() &&
            manager(context).getNotificationChannel(CHANNEL_ID)?.importance !=
            NotificationManager.IMPORTANCE_NONE
    }

    fun status(context: Context): Map<String, Any> {
        val packages = enabledPackages(context)
        val sources = supported(context).map { (pkg, name) ->
            val installed = try {
                context.packageManager.getPackageInfo(pkg, 0)
                true
            } catch (_: PackageManager.NameNotFoundException) {
                false
            }
            mapOf("package" to pkg, "name" to name, "installed" to installed,
                "enabled" to (pkg in packages))
        }
        val saved = prefs(context)
        return mapOf(
            "smsOn" to InboxCheck.isOn(context),
            "smsRead" to InboxCheck.canReadSms(context),
            "smsCapture" to canCaptureSms(context),
            "appsOn" to appsOn(context),
            "notificationAccess" to notificationAccess(context),
            "listenerConnected" to listenerConnected,
            "canAlert" to canAlert(context),
            "lastProcessed" to saved.getLong("last_processed", 0),
            "failure" to (saved.getString("failure", "") ?: ""),
            "sources" to sources,
        )
    }

    private fun rules(context: Context): PackRules? {
        val file = File(context.filesDir, "metro-manila.sqlite")
        val stamp = file.lastModified() to file.length()
        if (cachedPack != null && stamp == packStamp) return cachedPack
        val pack = PackRules.load(context) ?: return null
        cachedPack = pack
        // Built once per pack: it compiles a pattern for every promo term.
        cachedChecker = MessageRules(pack.data)
        packStamp = stamp
        return pack
    }

    /** The rules for [pack], compiled once and kept beside it. */
    private fun checker(pack: PackRules): MessageRules =
        cachedChecker?.takeIf { cachedPack === pack } ?: MessageRules(pack.data)

    fun fingerprint(sender: String?, text: String): String = digest(
        "${sender?.trim()?.lowercase() ?: ""}\u0000$text",
    )

    fun digest(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it) }

    /**
     * Caller is on [worker]. An inbox scan hands in the [verdict] it has
     * already worked out and marks the run itself, so a message is checked
     * once and the settings are written once.
     */
    fun process(
        context: Context,
        incoming: ProtectionStore.Incoming,
        alert: Boolean,
        verdict: Verdict? = null,
    ) {
        if (incoming.text.isBlank()) return
        val pack = rules(context) ?: run {
            prefs(context).edit().putString("failure", "pack_unavailable").apply()
            return
        }
        val inScan = verdict != null
        val verdict = verdict ?: checker(pack).check(incoming.text, incoming.sender)
        val linkCount = (Links.linkHosts(incoming.text) +
            Links.brokenLinkHosts(incoming.text)).distinct().size
        val saved = ProtectionStore.record(
            context, incoming, verdict, pack.version, linkCount, alert,
        )
        if (!inScan) markProcessed(context)
        if (saved.changed) main.post { resultsChanged?.invoke() }
        if (saved.alert && saved.resultId != null && canAlert(context)) {
            notify(context, saved.resultId, incoming.sender, pack.describe(verdict.reasons.first()))
        }
    }

    private fun markProcessed(context: Context) {
        prefs(context).edit()
            .putLong("last_processed", System.currentTimeMillis())
            .remove("failure")
            .apply()
    }

    /** Incremental SMS recovery and a full seven-day recount on rule changes. */
    fun scanInbox(context: Context, alert: Boolean) {
        if (!InboxCheck.canReadSms(context)) return
        val pack = rules(context) ?: return
        val checker = checker(pack)
        val saved = prefs(context)
        // The first scan into an empty store only takes stock: every text
        // already in the inbox would otherwise raise an alert at once.
        val mayAlert = alert && saved.getBoolean("sms_recovery_initialized", false) &&
            !ProtectionStore.smsStateEmpty(context)
        val scanAt = System.nanoTime()
        val started = System.currentTimeMillis()
        val alertNow = mayAlert && InboxCheck.isOn(context)
        // What earlier scans already judged, read once for the whole inbox.
        val known = ProtectionStore.smsStates(context)
        var read = 0
        var checked = 0
        // One transaction for the scan: hundreds of texts are one write to
        // disk, not one each.
        val counts = ProtectionStore.inTransaction(context) {
            var afterId = 0L
            do {
                val page = SmsReader.read(context, started - SEVEN_DAYS, afterId, 200)
                for (sms in page) {
                    val id = sms["id"] as Long
                    val sender = sms["sender"] as String
                    val text = sms["body"] as String
                    val arrivedAt = sms["date"] as Long
                    val hash = fingerprint(sender, text)
                    read++
                    if (known[id] == hash to pack.version) {
                        ProtectionStore.markSmsSeen(context, id, scanAt)
                    } else if (text.isNotBlank()) {
                        val incoming = ProtectionStore.Incoming(
                            "sms:$id", "sms", null, "Messages", sender, text,
                            arrivedAt, false, hash,
                        )
                        val verdict = checker.check(text, sender)
                        process(context, incoming, alertNow, verdict)
                        ProtectionStore.saveSmsState(
                            context, id, hash, arrivedAt, pack.version, verdict, scanAt,
                        )
                        checked++
                    }
                }
                if (page.isEmpty()) break
                afterId = page.last()["id"] as Long
                if (page.size < 200) break
            } while (true)
            ProtectionStore.finishSmsScan(context, scanAt)
        }
        markProcessed(context)
        // Counts and timing only: never a message or a sender.
        Log.i(
            "Hudyat",
            "inbox scan: $read texts read, $checked checked, " +
                "${System.currentTimeMillis() - started} ms",
        )
        InboxCheck.saveCounts(context, counts[1], counts[2], counts[3], counts[0], started)
        saved.edit().putBoolean("sms_recovery_initialized", true).apply()
    }

    private fun notify(context: Context, id: Long, sender: String?, reason: String) {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(MainActivity.ACTION_RESULT)
            .setData(Uri.parse("hudyat://result/$id"))
            .putExtra(MainActivity.EXTRA_RESULT_ID, id)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val open = PendingIntent.getActivity(
            context, id.toInt(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val from = sender?.takeIf { it.isNotBlank() } ?: "hindi kilalang sender"
        val notification = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_hudyat)
            .setContentTitle("Mukhang scam ang mensahe mula kay $from")
            .setContentText(reason)
            .setStyle(Notification.BigTextStyle().bigText(reason))
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, "Tingnan", open).build())
            .setAutoCancel(true)
            .build()
        manager(context).notify(id.toInt(), notification)
    }
}
