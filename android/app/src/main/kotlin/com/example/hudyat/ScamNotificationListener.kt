package com.example.hudyat

import android.app.Notification
import android.app.Person
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/** Reads only visible previews from user-selected messaging apps. */
class ScamNotificationListener : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        ProtectionEngine.listenerConnected = true
        baselineActive()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        instance = null
        ProtectionEngine.listenerConnected = false
    }

    fun baselineActive() {
        activeNotifications?.forEach { submit(it, alert = false) }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        submit(sbn, alert = true)
    }

    private fun submit(sbn: StatusBarNotification, alert: Boolean) {
        val pkg = sbn.packageName
        if (pkg == packageName || !ProtectionEngine.appsOn(this) ||
            !ProtectionEngine.sourceEnabled(this, pkg)
        ) return
        val name = ProtectionEngine.sourceName(this, pkg) ?: return
        if (ProtectionEngine.isSmsApp(this, pkg) && ProtectionEngine.canCaptureSms(this) &&
            InboxCheck.isOn(this)
        ) return
        val visible = NotificationMessages.extract(sbn)
        if (visible.isEmpty()) return
        ProtectionEngine.execute(this) {
            for (message in visible) {
                val hash = ProtectionEngine.fingerprint(message.sender, message.text)
                val key = "notification:$pkg:${sbn.key}:" +
                    if (message.truncated) hash else "${message.arrivedAt}:$hash"
                ProtectionEngine.process(
                    applicationContext,
                    ProtectionStore.Incoming(
                        key, "notification", pkg, name, message.sender,
                        message.text, message.arrivedAt, message.truncated, hash,
                    ),
                    alert,
                )
            }
        }
    }

    companion object {
        @Volatile var instance: ScamNotificationListener? = null
            private set
    }
}

internal data class VisibleMessage(
    val sender: String?,
    val text: String,
    val arrivedAt: Long,
    val truncated: Boolean,
)

internal object NotificationMessages {
    /** Package and conversation titles are never prepended to message text. */
    fun extract(sbn: StatusBarNotification): List<VisibleMessage> {
        val notification = sbn.notification
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return emptyList()
        val extras = notification.extras ?: return emptyList()
        val self = extras.getCharSequence(Notification.EXTRA_SELF_DISPLAY_NAME)?.toString()
        val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
        if (messages != null) {
            return messages.mapNotNull { item ->
                val bundle = item as? Bundle ?: return@mapNotNull null
                val text = bundle.getCharSequence("text")?.toString()?.trim()
                    ?: return@mapNotNull null
                val person = bundle.getParcelable("sender_person") as? Person
                val sender = person?.name?.toString()
                    ?: bundle.getCharSequence("sender")?.toString()
                if (sender.isNullOrBlank() || sender == self ||
                    !isIncomingText(text)
                ) return@mapNotNull null
                VisibleMessage(
                    sender, text, bundle.getLong("time").takeIf { it > 0 } ?: sbn.postTime,
                    false,
                )
            }
        }
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString()?.trim()
            ?: return emptyList()
        if (!isIncomingText(text)) return emptyList()
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        if (title.isNullOrBlank() || title.equals("You", true)) return emptyList()
        return listOf(VisibleMessage(title, text, sbn.postTime, true))
    }

    internal fun isIncomingText(text: String): Boolean = text.isNotBlank() &&
        !text.startsWith("You: ", true) && !text.startsWith("Me: ", true) &&
        !text.startsWith("You sent ", true)
}
