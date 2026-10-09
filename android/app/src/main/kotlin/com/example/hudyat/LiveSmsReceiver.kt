package com.example.hudyat

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/** Receives SMS when Android delivers it, including multipart messages. */
class LiveSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION ||
            !InboxCheck.isOn(context) || !ProtectionEngine.canCaptureSms(context)
        ) return
        val pending = goAsync()
        ProtectionEngine.execute(context) {
            try {
                val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                if (parts.isEmpty()) return@execute
                val text = parts.joinToString("") { it.messageBody ?: "" }
                if (text.isBlank()) return@execute
                val sender = parts.first().displayOriginatingAddress ?: ""
                val arrivedAt = System.currentTimeMillis()
                val pdus = intent.extras?.get("pdus") as? Array<*>
                val pduIdentity = pdus?.joinToString("") {
                    (it as? ByteArray)?.joinToString("") { byte -> "%02x".format(byte) } ?: ""
                } ?: ""
                val key = "sms_broadcast:${ProtectionEngine.digest(pduIdentity.ifEmpty {
                    "$sender\u0000${parts.first().timestampMillis}\u0000$text"
                })}"
                ProtectionEngine.process(
                    context.applicationContext,
                    ProtectionStore.Incoming(
                        key, "sms_broadcast", null, "Messages", sender, text,
                        arrivedAt, false, ProtectionEngine.fingerprint(sender, text),
                    ),
                    alert = true,
                )
            } finally {
                pending.finish()
            }
        }
    }
}
