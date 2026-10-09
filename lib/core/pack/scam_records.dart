import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'pack_record.dart';

List<String> _strings(String json) => (jsonDecode(json) as List).cast<String>();

/// One row of the pack's `official_senders` table: an organisation scammers
/// imitate, with the names it goes by and where it really lives.
class OfficialSender {
  const OfficialSender({
    required this.name,
    required this.short,
    required this.aliases,
    required this.domains,
    this.strictAliases = const [],
    this.phones = const [],
  });

  factory OfficialSender.fromRow(Row row) => OfficialSender(
    name: row['name'] as String,
    short: row['short'] as String,
    aliases: _strings(row['aliases'] as String),
    strictAliases: _strings(row['strict_aliases'] as String),
    domains: _strings(row['domains'] as String),
    phones: Phone.listFromJson(row['phones'] as String),
  );

  final String name;

  /// The form used in reason text, e.g. "DSWD".
  final String short;

  /// Names matched as whole words.
  final List<String> aliases;

  /// Names that are also ordinary words ("Smart", "Maya"). They count only
  /// with their capital letter and a telltale word nearby.
  final List<String> strictAliases;
  final List<String> domains;
  final List<Phone> phones;

  List<Phone> get dialable => [
    for (final phone in phones)
      if (phone.dial != null) phone,
  ];
}

/// One online gambling operator that advertises by text.
class GamblingBrand {
  const GamblingBrand({
    required this.name,
    required this.aliases,
    this.domains = const [],
  });

  factory GamblingBrand.fromJson(Map<String, dynamic> json) => GamblingBrand(
    name: json['name'] as String,
    aliases: (json['aliases'] as List).cast<String>(),
    domains: (json['domains'] as List? ?? const []).cast<String>(),
  );

  final String name;

  /// Names matched in the sender, the text and link hosts.
  final List<String> aliases;

  /// Domains seen in its messages. Often empty: aliases match hosts too.
  final List<String> domains;
}

/// The pack's `gambling` meta value: what marks a gambling promo.
class GamblingRules {
  const GamblingRules({
    this.brands = const [],
    this.hostWords = const [],
    this.terms = const [],
  });

  factory GamblingRules.fromJson(Map<String, dynamic> json) => GamblingRules(
    brands: [
      for (final brand in json['brands'] as List)
        GamblingBrand.fromJson((brand as Map).cast<String, dynamic>()),
    ],
    hostWords: (json['host_words'] as List).cast<String>(),
    terms: (json['terms'] as List).cast<String>(),
  );

  /// For a pack built before the list existed: nothing is flagged.
  static const none = GamblingRules();

  final List<GamblingBrand> brands;

  /// Words that mark a link host as a gambling site on their own.
  final List<String> hostWords;

  /// Promo wording. Two different ones plus a link mark a message.
  final List<String> terms;
}

/// One row of `scam_examples`.
class ScamExample {
  const ScamExample({required this.text, required this.typeLabel});

  factory ScamExample.fromRow(Row row) => ScamExample(
    text: row['text'] as String,
    typeLabel: row['type_label'] as String,
  );

  final String text;

  /// The kind of scam in Tagalog, shown as the fact under the reason.
  final String typeLabel;
}

/// One row of `scam_reasons`: the fixed wording for a reason id. `{org}`
/// and similar placeholders are filled from the check's own facts.
class ScamReasonText {
  const ScamReasonText({
    required this.tl,
    required this.en,
    required this.fact,
  });

  factory ScamReasonText.fromRow(Row row) => ScamReasonText(
    tl: row['tl'] as String,
    en: row['en'] as String,
    fact: row['fact'] as String,
  );

  final String tl;
  final String en;
  final String fact;
}
