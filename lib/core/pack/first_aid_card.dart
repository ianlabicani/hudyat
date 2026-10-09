import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

/// One row of the pack's `first_aid_cards` table. Every word is fixed text
/// from the pack, checked by hand against [sourceUrl].
class FirstAidCard {
  const FirstAidCard({
    required this.id,
    required this.title,
    required this.titleTl,
    required this.steps,
    required this.sourceName,
    required this.sourceUrl,
    required this.examples,
  });

  factory FirstAidCard.fromRow(Row row) => FirstAidCard(
    id: row['id'] as String,
    title: row['title'] as String,
    titleTl: row['title_tl'] as String,
    steps: _strings(row['steps'] as String),
    sourceName: row['source_name'] as String,
    sourceUrl: row['source_url'] as String,
    examples: _strings(row['examples'] as String),
  );

  final String id;
  final String title;

  /// The title in Filipino, shown as the gloss under it.
  final String titleTl;

  /// Plain Tagalog, one action per step, in order.
  final List<String> steps;
  final String sourceName;
  final String sourceUrl;

  /// Taglish messages this card should match.
  final List<String> examples;

  static List<String> _strings(String json) =>
      (jsonDecode(json) as List).cast<String>();
}
