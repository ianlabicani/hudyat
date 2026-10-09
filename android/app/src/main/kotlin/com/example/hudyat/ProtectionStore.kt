package com.example.hudyat

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import com.example.hudyat.check.Reason
import com.example.hudyat.check.Verdict
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** The same flagged.sqlite file Dart opens. Only flagged bodies enter this file. */
internal object ProtectionStore {
    data class Incoming(
        val key: String,
        val type: String,
        val sourcePackage: String?,
        val app: String,
        val sender: String?,
        val text: String,
        val arrivedAt: Long,
        val truncated: Boolean,
        val fingerprint: String,
    )

    data class Saved(val resultId: Long?, val alert: Boolean, val changed: Boolean)

    private var opened: SQLiteDatabase? = null

    private fun database(context: Context): SQLiteDatabase {
        opened?.let { if (it.isOpen) return it }
        val file = File(context.filesDir, "flagged.sqlite")
        val db = SQLiteDatabase.openDatabase(
            file.path,
            null,
            SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.CREATE_IF_NECESSARY,
        )
        db.execSQL("PRAGMA busy_timeout = 3000")
        db.enableWriteAheadLogging()
        db.execSQL(
            """CREATE TABLE IF NOT EXISTS flagged (
                id INTEGER PRIMARY KEY, text TEXT NOT NULL, sender TEXT, app TEXT,
                verdict TEXT NOT NULL, reasons TEXT NOT NULL, claimed TEXT,
                truncated INTEGER NOT NULL, checked_at INTEGER NOT NULL,
                phrasing TEXT NOT NULL DEFAULT 'unknown',
                link_count INTEGER NOT NULL DEFAULT 0,
                source_key TEXT, source_type TEXT, source_package TEXT,
                arrived_at INTEGER, rules_version TEXT, ai_version TEXT
            )""",
        )
        val columns = mutableSetOf<String>()
        db.rawQuery("PRAGMA table_info(flagged)", null).use { rows ->
            while (rows.moveToNext()) columns.add(rows.getString(1))
        }
        for ((name, type) in listOf(
            "phrasing" to "TEXT NOT NULL DEFAULT 'unknown'",
            "link_count" to "INTEGER NOT NULL DEFAULT 0",
            "source_key" to "TEXT",
            "source_type" to "TEXT",
            "source_package" to "TEXT",
            "arrived_at" to "INTEGER",
            "rules_version" to "TEXT",
            "ai_version" to "TEXT",
        )) {
            if (name !in columns) db.execSQL("ALTER TABLE flagged ADD COLUMN $name $type")
        }
        db.execSQL(
            "CREATE UNIQUE INDEX IF NOT EXISTS flagged_source_key " +
                "ON flagged(source_key) WHERE source_key IS NOT NULL",
        )
        db.execSQL(
            """CREATE TABLE IF NOT EXISTS protection_events (
                source_key TEXT PRIMARY KEY, fingerprint TEXT NOT NULL,
                source_type TEXT NOT NULL, arrived_at INTEGER NOT NULL,
                seen_at INTEGER NOT NULL, rules_version TEXT NOT NULL,
                result_id INTEGER, consumed INTEGER NOT NULL DEFAULT 1
            )""",
        )
        db.execSQL(
            "CREATE INDEX IF NOT EXISTS protection_events_match " +
                "ON protection_events(fingerprint, arrived_at)",
        )
        db.execSQL(
            """CREATE TABLE IF NOT EXISTS protection_sms (
                sms_id INTEGER PRIMARY KEY, fingerprint TEXT NOT NULL,
                sent_at INTEGER NOT NULL, rules_version TEXT NOT NULL,
                verdict TEXT NOT NULL, gambling INTEGER NOT NULL,
                scan_at INTEGER NOT NULL
            )""",
        )
        opened = db
        return db
    }

    fun smsUnchanged(context: Context, id: Long, fingerprint: String, rules: String): Boolean {
        database(context).rawQuery(
            "SELECT 1 FROM protection_sms WHERE sms_id=? AND fingerprint=? " +
                "AND rules_version=?",
            arrayOf(id.toString(), fingerprint, rules),
        ).use { return it.moveToFirst() }
    }

    fun markSmsSeen(context: Context, id: Long, scanAt: Long) {
        database(context).execSQL(
            "UPDATE protection_sms SET scan_at=? WHERE sms_id=?",
            arrayOf(scanAt, id),
        )
    }

    fun saveSmsState(
        context: Context,
        id: Long,
        fingerprint: String,
        sentAt: Long,
        rules: String,
        verdict: Verdict,
        scanAt: Long,
    ) {
        val values = ContentValues().apply {
            put("sms_id", id)
            put("fingerprint", fingerprint)
            put("sent_at", sentAt)
            put("rules_version", rules)
            put("verdict", verdict.name)
            put("gambling", if (verdict.reasons.any { it.id == "gambling_promo" }) 1 else 0)
            put("scan_at", scanAt)
        }
        database(context).insertWithOnConflict(
            "protection_sms", null, values, SQLiteDatabase.CONFLICT_REPLACE,
        )
    }

    fun finishSmsScan(context: Context, scanAt: Long): IntArray {
        val db = database(context)
        db.delete("protection_sms", "scan_at != ?", arrayOf(scanAt.toString()))
        db.rawQuery(
            "SELECT COUNT(*), SUM(verdict='scam'), SUM(verdict='caution'), " +
                "SUM(gambling) FROM protection_sms",
            null,
        ).use {
            it.moveToFirst()
            return intArrayOf(it.getInt(0), it.getInt(1), it.getInt(2), it.getInt(3))
        }
    }

    /** Records the event and its finding in one transaction, before any alert. */
    fun record(
        context: Context,
        incoming: Incoming,
        verdict: Verdict,
        rulesVersion: String,
        linkCount: Int,
        canAlert: Boolean,
    ): Saved {
        val db = database(context)
        db.beginTransaction()
        try {
            var previousVersion: String? = null
            var previousId: Long? = null
            db.rawQuery(
                "SELECT rules_version, result_id FROM protection_events WHERE source_key=?",
                arrayOf(incoming.key),
            ).use { rows ->
                if (rows.moveToFirst()) {
                    previousVersion = rows.getString(0)
                    if (!rows.isNull(1)) previousId = rows.getLong(1)
                }
            }
            if (previousVersion == rulesVersion) {
                db.setTransactionSuccessful()
                return Saved(previousId, false, false)
            }

            var reconciled = false
            if (incoming.type == "sms" && previousVersion == null) {
                db.rawQuery(
                    "SELECT 1 FROM protection_events WHERE fingerprint=? " +
                        "AND source_type IN ('sms_broadcast','notification') " +
                        "AND ABS(arrived_at - ?) <= 300000 LIMIT 1",
                    arrayOf(incoming.fingerprint, incoming.arrivedAt.toString()),
                ).use { reconciled = it.moveToFirst() }
            }

            val id = if (verdict.name == Verdict.CLEAR) {
                if (previousId != null) {
                    db.delete("flagged", "id=?", arrayOf(previousId.toString()))
                }
                null
            } else {
                upsertFinding(db, incoming, verdict, rulesVersion, linkCount, previousId)
            }
            val values = ContentValues().apply {
                put("source_key", incoming.key)
                put("fingerprint", incoming.fingerprint)
                put("source_type", incoming.type)
                put("arrived_at", incoming.arrivedAt)
                put("seen_at", System.currentTimeMillis())
                put("rules_version", rulesVersion)
                if (id == null) putNull("result_id") else put("result_id", id)
            }
            db.insertWithOnConflict(
                "protection_events", null, values, SQLiteDatabase.CONFLICT_REPLACE,
            )
            db.delete(
                "protection_events", "seen_at < ?",
                arrayOf((System.currentTimeMillis() - SEVEN_DAYS).toString()),
            )
            db.setTransactionSuccessful()
            return Saved(
                id,
                previousVersion == null && !reconciled && canAlert && verdict.isScam && id != null,
                id != null || previousId != null,
            )
        } finally {
            db.endTransaction()
        }
    }

    private fun upsertFinding(
        db: SQLiteDatabase,
        incoming: Incoming,
        verdict: Verdict,
        rulesVersion: String,
        linkCount: Int,
        previousId: Long?,
    ): Long {
        var id = previousId
        if (id == null) {
            db.rawQuery("SELECT id FROM flagged WHERE source_key=?", arrayOf(incoming.key)).use {
                if (it.moveToFirst()) id = it.getLong(0)
            }
        }
        if (id == null && incoming.type == "sms") {
            // An SMS broadcast precedes the inbox provider's row. Reconcile
            // them by sender/body fingerprint and arrival time, retaining id.
            db.rawQuery(
                "SELECT result_id FROM protection_events WHERE fingerprint=? " +
                    "AND source_type IN ('sms_broadcast','notification') " +
                    "AND result_id IS NOT NULL AND ABS(arrived_at - ?) <= 300000 " +
                    "ORDER BY ABS(arrived_at - ?) LIMIT 1",
                arrayOf(incoming.fingerprint, incoming.arrivedAt.toString(),
                    incoming.arrivedAt.toString()),
            ).use { if (it.moveToFirst()) id = it.getLong(0) }
        }
        if (id == null) {
            db.rawQuery(
                "SELECT id FROM flagged WHERE source_key IS NULL AND text=? " +
                    "AND sender IS ? ORDER BY id DESC LIMIT 1",
                arrayOf(incoming.text, incoming.sender),
            ).use { if (it.moveToFirst()) id = it.getLong(0) }
        }

        val reasons = JSONArray().apply {
            for (reason: Reason in verdict.reasons) {
                put(JSONObject().put("id", reason.id).put("facts", JSONObject(reason.facts)))
            }
        }.toString()
        val values = ContentValues().apply {
            put("text", incoming.text)
            put("sender", incoming.sender)
            put("app", incoming.app)
            put("verdict", verdict.name)
            put("reasons", reasons)
            putNull("claimed")
            put("truncated", if (incoming.truncated) 1 else 0)
            put("checked_at", incoming.arrivedAt)
            put("phrasing", "skipped")
            put("link_count", linkCount)
            put("source_key", incoming.key)
            put("source_type", incoming.type)
            put("source_package", incoming.sourcePackage)
            put("arrived_at", incoming.arrivedAt)
            put("rules_version", rulesVersion)
            putNull("ai_version")
        }
        if (id != null) {
            // A foreground AI pass may have enriched the same rules finding.
            // Reconciliation must preserve that result and its row identity.
            db.rawQuery(
                "SELECT rules_version, phrasing FROM flagged WHERE id=?",
                arrayOf(id.toString()),
            ).use { rows ->
                if (rows.moveToFirst() && rows.getString(0) == rulesVersion &&
                    rows.getString(1) == "checked"
                ) {
                    for (name in listOf("verdict", "reasons", "phrasing", "ai_version")) {
                        values.remove(name)
                    }
                }
            }
            db.update("flagged", values, "id=?", arrayOf(id.toString()))
            return id!!
        }
        return db.insertOrThrow("flagged", null, values)
    }

    private const val SEVEN_DAYS = 7L * 24 * 60 * 60 * 1000
}
