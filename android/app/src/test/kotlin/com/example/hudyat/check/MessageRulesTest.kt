package com.example.hudyat.check

import java.io.File
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test

/**
 * Holds the Kotlin rules to the Dart rules. The case files are written by
 * test/features/check/checker_cases_test.dart: each message with the Dart
 * checker's verdict, reason ids and facts. This copy must give the same.
 */
class MessageRulesTest {
    private fun replay(file: File): Int {
        val json = JSONObject(file.readText())
        val rules = MessageRules(RuleData.fromJson(json.getJSONObject("rules")))
        val cases = json.getJSONArray("cases")
        val wrong = mutableListOf<String>()
        for (index in 0 until cases.length()) {
            val case = cases.getJSONObject(index)
            val text = case.getString("text")
            val sender = if (case.isNull("sender")) null else case.getString("sender")
            val got = rules.check(text, sender)
            val expected = case.getJSONArray("reasons")
            val want = List(expected.length()) {
                val reason = expected.getJSONObject(it)
                val facts = reason.getJSONObject("facts")
                reason.getString("id") + facts.keys().asSequence().sorted()
                    .map { key -> "$key=${facts.getString(key)}" }.toList()
            }
            val have = got.reasons.map { reason ->
                reason.id + reason.facts.keys.sorted().map { key -> "$key=${reason.facts[key]}" }
            }
            if (got.name != case.getString("verdict") || have != want) {
                // The index, not the text: an inbox case is private.
                wrong.add("case $index: Dart ${case.getString("verdict")} $want, Kotlin ${got.name} $have")
            }
        }
        assertEquals(wrong.joinToString("\n"), 0, wrong.size)
        return cases.length()
    }

    @Test
    fun matchesDartOnTheCheckedInCases() {
        val file = File("../../test/fixtures/checker_cases.json")
        assertTrue("missing ${file.absolutePath}", file.exists())
        assertTrue(replay(file) > 100)
    }

    @Test
    fun matchesDartOnASavedInbox() {
        val file = File("../../pack/raw/checker_cases_inbox.json")
        assumeTrue("no saved inbox cases", file.exists())
        replay(file)
    }
}
