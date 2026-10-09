package com.example.hudyat.check

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import org.json.JSONArray
import org.json.JSONObject

/** The message-check lists and reason wording, read from the pack in app storage. */
class PackRules(
    val data: RuleData,
    private val wording: Map<String, String>,
    val version: String,
) {
    /** The fixed Tagalog wording for [reason], with its facts filled in. */
    fun describe(reason: Reason): String {
        val template = wording[reason.id] ?: return "Mukhang scam"
        return placeholder.replace(template) { reason.facts[it.groupValues[1]] ?: "" }
    }

    companion object {
        private val placeholder = Regex("\\{([A-Za-z0-9_]+)\\}")

        // Flutter copies the pack here on every launch (pack_installer.dart).
        private fun file(context: Context) = File(context.filesDir, "metro-manila.sqlite")

        private fun strings(json: String): List<String> {
            val array = JSONArray(json)
            return List(array.length()) { array.getString(it) }
        }

        /** Null when the pack is not there yet or is being rewritten. */
        fun load(context: Context): PackRules? {
            val file = file(context)
            if (!file.exists()) return null
            return try {
                SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                    val senders = ArrayList<Sender>()
                    db.rawQuery(
                        "SELECT short, aliases, strict_aliases, domains FROM official_senders ORDER BY id",
                        null,
                    ).use { rows ->
                        while (rows.moveToNext()) {
                            senders.add(
                                Sender(
                                    rows.getString(0),
                                    strings(rows.getString(1)),
                                    strings(rows.getString(2)),
                                    strings(rows.getString(3)),
                                ),
                            )
                        }
                    }
                    val meta = HashMap<String, String>()
                    db.rawQuery(
                        "SELECT key, value FROM meta WHERE key IN " +
                            "('link_shorteners', 'neutral_hosts', 'gambling', 'bank_senders', 'rules_version')",
                        null,
                    ).use { rows ->
                        while (rows.moveToNext()) meta[rows.getString(0)] = rows.getString(1)
                    }
                    val wording = HashMap<String, String>()
                    db.rawQuery("SELECT id, tl FROM scam_reasons", null).use { rows ->
                        while (rows.moveToNext()) wording[rows.getString(0)] = rows.getString(1)
                    }
                    PackRules(
                        RuleData.from(
                            senders,
                            meta["link_shorteners"]?.let(::strings) ?: emptyList(),
                            meta["neutral_hosts"]?.let(::strings) ?: emptyList(),
                            meta["gambling"]?.let(::JSONObject),
                            meta["bank_senders"]?.let(::JSONObject),
                        ),
                        wording,
                        "${meta["rules_version"] ?: "unknown"}-4",
                    )
                }
            } catch (error: Exception) {
                null
            }
        }
    }
}
