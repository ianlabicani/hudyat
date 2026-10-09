package com.example.hudyat.check

import org.json.JSONArray
import org.json.JSONObject

// A Kotlin copy of the rules-only path of
// lib/features/check/services/message_checker.dart and gambling.dart. The
// Dart files are the source of truth; MessageRulesTest replays the Dart
// checker's own answers against this copy. The wording check needs the model
// and is not here.

class Sender(
    val short: String,
    val aliases: List<String>,
    val strictAliases: List<String>,
    val domains: List<String>,
)

class GamblingBrand(val name: String, val aliases: List<String>, val domains: List<String>)

class RuleData(
    val senders: List<Sender>,
    val shorteners: Set<String>,
    val neutralHosts: Set<String>,
    val brands: List<GamblingBrand>,
    val hostWords: List<String>,
    val terms: List<String>,
    /** Sender names by bank or e-wallet short name; empty in an older pack. */
    val bankSenders: Map<String, List<String>> = emptyMap(),
) {
    companion object {
        private fun strings(array: JSONArray?): List<String> =
            if (array == null) emptyList() else List(array.length()) { array.getString(it) }

        fun senderFrom(json: JSONObject) = Sender(
            short = json.getString("short"),
            aliases = strings(json.optJSONArray("aliases")),
            strictAliases = strings(json.optJSONArray("strict_aliases")),
            domains = strings(json.optJSONArray("domains")),
        )

        /** [gambling] is the pack's `gambling` meta value, or null in an older pack. */
        fun from(
            senders: List<Sender>,
            shorteners: List<String>,
            neutralHosts: List<String>,
            gambling: JSONObject?,
            bankSenders: JSONObject? = null,
        ): RuleData {
            val brands = gambling?.optJSONArray("brands")
            return RuleData(
                senders = senders,
                shorteners = shorteners.toSet(),
                neutralHosts = neutralHosts.toSet(),
                brands = if (brands == null) emptyList() else List(brands.length()) {
                    val brand = brands.getJSONObject(it)
                    GamblingBrand(
                        brand.getString("name"),
                        strings(brand.optJSONArray("aliases")),
                        strings(brand.optJSONArray("domains")),
                    )
                },
                hostWords = strings(gambling?.optJSONArray("host_words")),
                terms = strings(gambling?.optJSONArray("terms")),
                bankSenders = bankSenders?.keys()?.asSequence()
                    ?.associateWith { strings(bankSenders.optJSONArray(it)) }
                    ?: emptyMap(),
            )
        }

        fun fromJson(json: JSONObject): RuleData {
            val senders = json.getJSONArray("senders")
            return from(
                List(senders.length()) { senderFrom(senders.getJSONObject(it)) },
                strings(json.optJSONArray("shorteners")),
                strings(json.optJSONArray("neutral_hosts")),
                json.optJSONObject("gambling"),
                json.optJSONObject("bank_senders"),
            )
        }
    }
}

class Reason(val id: String, val facts: Map<String, String>)

class Verdict(val name: String, val reasons: List<Reason>) {
    val isScam get() = name == SCAM

    companion object {
        const val SCAM = "scam"
        const val CAUTION = "caution"
        const val CLEAR = "clear"
    }
}

class MessageRules(private val data: RuleData) {
    private val terms = data.terms.map { Regex("(?<![a-z0-9])" + Regex.escape(it.lowercase())) }

    // The bank a sender name belongs to, by the name in lower case.
    private val bankBySender = buildMap {
        for (bank in data.senders) {
            for (name in data.bankSenders[bank.short] ?: emptyList()) put(name.lowercase(), bank)
        }
    }

    fun check(text: String, sender: String?): Verdict {
        val from = sender?.trim()
        val broken = Links.brokenLinkHosts(text)
        val plain = Links.linkHosts(text)
        val hosts = plain + broken.filter { it !in plain }
        val named = from?.let { bankBySender[it.lowercase()] }
        val claimed = listOfNotNull(named) + claimedSenders(text).filter { it !== named }
        val reasons = mutableListOf<Reason>()

        fun add(id: String, vararg facts: Pair<String, String>) {
            if (reasons.none { it.id == id }) reasons.add(Reason(id, mapOf(*facts)))
        }

        for (host in hosts) {
            if (isOfficial(host)) continue
            if (host in broken) add(LINK_HIDDEN, "domain" to host)
            val copied = imitatedBy(host, text)
            if (copied != null) {
                add(
                    LINK_LOOKALIKE,
                    "org" to copied.short,
                    "domain" to host,
                    "official" to copied.domains.first(),
                )
            } else if (data.shorteners.any { Links.isOnDomain(host, it) }) {
                add(LINK_SHORTENER, "domain" to host)
            } else if (claimed.isNotEmpty() &&
                data.neutralHosts.none { Links.isOnDomain(host, it) }
            ) {
                val org = claimed.first()
                add(
                    LINK_NOT_OFFICIAL,
                    "org" to org.short,
                    "domain" to host,
                    "official" to org.domains.first(),
                )
            }
            if (claimed.isNotEmpty() && claimed.first().short in data.bankSenders &&
                data.neutralHosts.none { Links.isOnDomain(host, it) }
            ) {
                add(BANK_LINK, "org" to claimed.first().short)
            }
        }
        // A look-alike already says the link is not theirs.
        if (reasons.any { it.id == LINK_LOOKALIKE }) {
            reasons.removeAll { it.id == LINK_NOT_OFFICIAL }
        }

        // An offer in a bank's or e-wallet's name, sent from an ordinary number,
        // speaks for it without a "GCash:" in front.
        val speaker = claimed.firstOrNull()
            ?: if (from != null && Links.isMobileNumber(from) && isOffer(text)) {
                firstMentionedBank(text)
            } else {
                null
            }
        if (from != null && speaker != null && Links.isMobileNumber(from)) {
            add(SENDER_MOBILE, "org" to speaker.short, "sender" to from)
        }

        val promo = gamblingSource(text, hosts, from)
        if (promo != null) add(GAMBLING_PROMO, "source" to promo)

        return Verdict(verdictFor(reasons), reasons)
    }

    private fun verdictFor(reasons: List<Reason>): String {
        val ids = reasons.map { it.id }.toSet()
        if (ids.isEmpty()) return Verdict.CLEAR
        if (LINK_LOOKALIKE in ids || LINK_HIDDEN in ids || LINK_NOT_OFFICIAL in ids ||
            ids.size >= 2
        ) {
            return Verdict.SCAM
        }
        return Verdict.CAUTION
    }

    /** Two different offer words, so one "claim" in a chat is not enough. */
    private fun isOffer(text: String): Boolean =
        offer.findAll(text).map { it.value.lowercase() }.toSet().size >= 2

    /** The bank or e-wallet named earliest in [text], claimed or not. */
    private fun firstMentionedBank(text: String): Sender? {
        var first: Sender? = null
        var at = text.length
        for (sender in data.senders) {
            if (sender.short !in data.bankSenders) continue
            for (match in mentions(sender, text)) {
                if (match.first < at) {
                    at = match.first
                    first = sender
                }
            }
        }
        return first
    }

    /** Organisations [text] claims to come from, in the order they appear. */
    private fun claimedSenders(text: String): List<Sender> {
        val found = mutableListOf<Pair<Int, Sender>>()
        for (sender in data.senders) {
            var best: Int? = null
            for (match in mentions(sender, text)) {
                val start = match.first
                if (isClaim(text, start, match.last + 1) && (best == null || start < best)) {
                    best = start
                }
            }
            if (best != null) found.add(best to sender)
        }
        // Stable, as Dart's sort is for a list this size.
        return found.sortedBy { it.first }.map { it.second }
    }

    /** Every place [sender] is named in [text]. */
    private fun mentions(sender: Sender, text: String): List<IntRange> {
        val found = mutableListOf<IntRange>()
        for (alias in sender.aliases) {
            // A three-letter acronym in lower case is usually just a word.
            val exact = alias.length <= 3 && alias == alias.uppercase()
            word(alias, exact).findAll(text).mapTo(found) { it.range }
        }
        if (sender.strictAliases.isEmpty() || !telltale.containsMatchIn(text)) return found
        for (alias in sender.strictAliases) {
            word(alias, true).findAll(text).mapTo(found) { it.range }
            if (alias != alias.uppercase()) {
                word(alias.uppercase(), true).findAll(text).mapTo(found) { it.range }
            }
        }
        return found
    }

    private fun isClaim(text: String, start: Int, end: Int): Boolean {
        val before = text.substring(0, start)
        val after = text.substring(end)
        if (lead.containsMatchIn(before) && label.containsMatchIn(after)) return true
        if (beforeClaim.containsMatchIn(before)) return true
        return afterClaim.containsMatchIn(after)
    }

    private fun isOfficial(host: String): Boolean =
        Links.isGovernmentHost(host) ||
            data.senders.any { s -> s.domains.any { Links.isOnDomain(host, it) } }

    /** The organisation whose name [host] carries without being its site. */
    private fun imitatedBy(host: String, text: String): Sender? {
        val parts = host.split(Regex("[.\\-_]"))
        val squashed = squash(host)
        for (sender in data.senders) {
            for (alias in sender.aliases) {
                val token = squash(alias)
                if (token.length < 3) continue
                if (if (token.length >= 5) squashed.contains(token) else token in parts) {
                    return sender
                }
            }
            if (mentions(sender, text).isEmpty()) continue
            for (alias in sender.strictAliases) {
                if (alias.lowercase() in parts) return sender
            }
        }
        return null
    }

    /** Who a gambling promo is from, or null when this is not one. */
    private fun gamblingSource(text: String, hosts: List<String>, sender: String?): String? {
        val from = squash(sender ?: "")
        val plain = text.lowercase().replace(dashesAndSpaces, " ")
        val wording = terms.count { it.containsMatchIn(plain) }

        for (brand in data.brands) {
            if (hosts.any { host -> brand.domains.any { Links.isOnDomain(host, it) } }) {
                return brand.name
            }
            for (alias in brand.aliases) {
                // A short name could sit inside an ordinary word.
                val token = squash(alias)
                if (token.length >= 5 &&
                    (from.startsWith(token) || hosts.any { squash(it).contains(token) })
                ) {
                    return brand.name
                }
                if (hosts.isNotEmpty() && wording > 0 &&
                    word(alias, false).containsMatchIn(text)
                ) {
                    return brand.name
                }
            }
        }
        for (host in hosts) {
            val squashed = squash(host)
            if (data.hostWords.any { squashed.contains(it) }) return host
        }
        if (wording < 2) return null
        return hosts.firstOrNull { !isOfficial(it) }
    }

    companion object {
        const val LINK_LOOKALIKE = "link_lookalike"
        const val LINK_NOT_OFFICIAL = "link_not_official"
        const val SENDER_MOBILE = "sender_mobile"
        const val LINK_SHORTENER = "link_shortener"
        const val LINK_HIDDEN = "link_hidden"
        const val GAMBLING_PROMO = "gambling_promo"
        const val BANK_LINK = "bank_link"

        private val notPlain = Regex("[^a-z0-9]")
        private val dashesAndSpaces = Regex("[-$S]+")

        private fun squash(value: String) = value.lowercase().replace(notPlain, "")

        private fun word(alias: String, caseSensitive: Boolean): Regex {
            val pattern = "(?<![A-Za-z0-9])" + Regex.escape(alias) + "(?![A-Za-z0-9])"
            return if (caseSensitive) Regex(pattern) else Regex(pattern, RegexOption.IGNORE_CASE)
        }

        /** Words that turn "Smart" or "Maya" from an ordinary word into a company. */
        private val telltale = Regex(
            "$START(account|wallet|load|sim|promo|postpaid|prepaid|subscriber|bill|" +
                "data|points|rewards|app|verify|otp)$END",
            RegexOption.IGNORE_CASE,
        )
        /** Wording of an offer made in an organisation's name. */
        private val offer = Regex(
            "$START(rewards?|promo|claim|cashback|voucher|prize|premyo|" +
                "t&cs?\\s+apply|permit\\s+no)$END",
            RegexOption.IGNORE_CASE,
        )
        private val lead = Regex(
            "(\\A|[\\n.!?][$S]*)(from[$S]+|dear[$S]+|mula[$S]+sa[$S]+|galing[$S]+sa[$S]+)?\\z",
            RegexOption.IGNORE_CASE,
        )
        private val label = Regex(
            "\\A[$S]*([:\\-–|]|advisory|alert|notice|update|reminder|ph$END|customer|" +
                "support|security|team|cash assistance)",
            RegexOption.IGNORE_CASE,
        )
        private val beforeClaim = Regex(
            "(${START}from[$S]+(the[$S]+)?|${START}mula[$S]+sa[$S]+|${START}galing[$S]+sa[$S]+|" +
                "${START}taga[- ]|$START(your|iyong|inyong)[$S]+|" +
                "$START(agent|service|support|staff|team|representative|opisina|tanggapan)" +
                "$END[^.!?\\n]{0,20}$START(ng|of)[$S]+)\\z",
            RegexOption.IGNORE_CASE,
        )
        private val afterClaim = Regex(
            "\\A[$S]+(account|wallet|sim|card|number|loan)[$S]+(mo|ninyo|niyo|nyo|ay)$END",
            RegexOption.IGNORE_CASE,
        )
    }
}
