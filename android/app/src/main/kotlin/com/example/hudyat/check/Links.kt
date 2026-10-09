package com.example.hudyat.check

// A Kotlin copy of lib/features/check/services/links.dart, for the timed
// check that runs without Flutter. The Dart file is the source of truth:
// change it first, then this, and MessageRulesTest holds the two together.
//
// Patterns spell out their character classes. Android and the laptop's JVM
// disagree about what \w, \s and \b cover, and Dart agrees with neither.

/** Dart's `\w`, for use inside a character class. */
internal const val W = "A-Za-z0-9_"

/** Dart's `\s`, for use inside a character class. */
internal const val S =
    " \\t\\n\\u000B\\f\\r\\u00A0\\u1680\\u2000-\\u200A\\u2028\\u2029\\u202F\\u205F\\u3000\\uFEFF"

/** `\b` where a word starts. */
internal const val START = "(?<![$W])"

/** `\b` where a word ends. */
internal const val END = "(?![$W])"

object Links {
    private val bareTlds = setOf(
        "com", "ph", "net", "org", "info", "xyz", "top", "site", "online", "cc", "co", "io",
        "me", "ly", "gd", "gy", "app", "link", "shop", "club", "vip", "live", "click", "biz",
        "gov", "id", "to", "be", "at", "ee", "bio", "store", "icu", "cn", "ru", "tk", "ml",
        "ga", "cf", "win", "work", "life", "pro",
    )

    private val withScheme = Regex("https?://([^/?#$S]+)", RegexOption.IGNORE_CASE)
    private val bare = Regex(
        "(?<![$W@.])((?:[a-z0-9-]+\\.)+([a-z]{2,6}))(?![$W-])",
        RegexOption.IGNORE_CASE,
    )

    private fun clean(host: String): String {
        var value = host.lowercase()
        val at = value.lastIndexOf('@')
        if (at >= 0) value = value.substring(at + 1)
        value = value.split(":").first()
        while (value.endsWith(".")) value = value.dropLast(1)
        return if (value.startsWith("www.")) value.substring(4) else value
    }

    /** The host of every link in [text], lower-cased, in order, without repeats. */
    fun linkHosts(text: String): List<String> {
        val found = sortedMapOf<Int, String>()
        val taken = mutableListOf<IntRange>()
        for (match in withScheme.findAll(text)) {
            found[match.range.first] = clean(match.groupValues[1])
            taken.add(match.range)
        }
        for (match in bare.findAll(text)) {
            val inside = taken.any { match.range.first in it }
            if (inside || match.groupValues[2].lowercase() !in bareTlds) continue
            found[match.range.first] = clean(match.groupValues[1])
        }
        val hosts = mutableListOf<String>()
        for (host in found.values) {
            if (host.contains('.') && host !in hosts) hosts.add(host)
        }
        return hosts
    }

    fun isOnDomain(host: String, domain: String): Boolean =
        host == domain || host.endsWith(".$domain")

    fun isGovernmentHost(host: String): Boolean = host == "gov.ph" || host.endsWith(".gov.ph")

    private val senderNoise = Regex("[$S().-]")
    private val mobile = Regex("\\A(?:\\+?63|0)9[0-9]{9}\\z")

    fun isMobileNumber(sender: String): Boolean =
        mobile.containsMatchIn(sender.replace(senderNoise, ""))

    private const val ENDINGS = "(com|ph|net|org|info|xyz|top|cc|site|online|shop)(?![A-Za-z0-9-])"
    private val brokenAfterDot = Regex(
        "(?<![$W.@])([A-Za-z][A-Za-z0-9-]{4,})" +
            "(?:\\.[ \\t]+|[ \\t]*[(\\[]dot[)\\]][ \\t]*|[ \\t]+dot[ \\t]+)" + ENDINGS,
    )
    private val brokenBeforeDot = Regex(
        "(?<![$W.@])([A-Za-z][A-Za-z0-9-]{4,})[ \\t]+\\.[ \\t]*$ENDINGS",
    )
    private val saysRemoveSpace = Regex("$START(space|puwang|espasyo)$END", RegexOption.IGNORE_CASE)

    /** Hosts written broken up so a network's filter does not see a link. */
    fun brokenLinkHosts(text: String): List<String> {
        val hosts = mutableListOf<String>()
        fun take(pattern: Regex) {
            for (match in pattern.findAll(text)) {
                val host = "${match.groupValues[1].lowercase()}.${match.groupValues[2]}"
                if (host !in hosts) hosts.add(host)
            }
        }
        take(brokenAfterDot)
        if (saysRemoveSpace.containsMatchIn(text)) take(brokenBeforeDot)
        return hosts
    }
}
