package com.example.hudyat

import android.content.Context
import android.net.Uri

/**
 * Reads the SMS inbox for "Scan my messages". Read-only: nothing is changed,
 * moved or deleted, and the texts go no further than the app's own checker.
 */
object SmsReader {
    private val INBOX: Uri = Uri.parse("content://sms/inbox")

    /** Texts received at or after [since], with an id above [afterId], lowest id first. */
    fun read(context: Context, since: Long, afterId: Long, limit: Int): List<Map<String, Any?>> {
        val rows = ArrayList<Map<String, Any?>>()
        context.contentResolver.query(
            INBOX,
            arrayOf("_id", "address", "date", "body"),
            "date >= ? AND _id > ?",
            arrayOf(since.toString(), afterId.toString()),
            "_id ASC",
        )?.use { cursor ->
            while (rows.size < limit && cursor.moveToNext()) {
                rows.add(
                    mapOf(
                        "id" to cursor.getLong(0),
                        "sender" to (cursor.getString(1) ?: ""),
                        "date" to cursor.getLong(2),
                        "body" to (cursor.getString(3) ?: ""),
                    ),
                )
            }
        }
        return rows
    }
}
