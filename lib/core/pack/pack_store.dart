import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../geo.dart';
import 'pack_record.dart';
import 'scam_records.dart';

/// Which level a set of hotlines belongs to. Cards always label it.
enum HotlineLevel { city, province, national }

/// Read-only access to one pack. All SQL lives here.
class PackStore {
  PackStore(this._db);

  factory PackStore.open(String path) =>
      PackStore(sqlite3.open(path, mode: OpenMode.readOnly));

  final Database _db;

  late final PackMeta meta = _readMeta();

  PackMeta _readMeta() {
    final values = {
      for (final row in _db.select('SELECT key, value FROM meta'))
        row['key'] as String: row['value'] as String,
    };
    final bbox = [
      for (final part in (values['bbox'] ?? '0,0,0,0').split(','))
        double.parse(part),
    ];
    return PackMeta(
      name: values['name'] ?? 'Pack',
      buildDate: values['build_date'] ?? 'unknown',
      west: bbox[0],
      south: bbox[1],
      east: bbox[2],
      north: bbox[3],
    );
  }

  List<IntentDef> intents() => [
    for (final row in _db.select('SELECT * FROM intents'))
      IntentDef.fromRow(row),
  ];

  /// Organisations the message check knows, companies first.
  List<OfficialSender> officialSenders() => [
    for (final row in _db.select('SELECT * FROM official_senders ORDER BY id'))
      OfficialSender.fromRow(row),
  ];

  List<ScamExample> scamExamples() => [
    for (final row in _db.select('SELECT * FROM scam_examples ORDER BY id'))
      ScamExample.fromRow(row),
  ];

  /// Fixed reason wording by reason id.
  Map<String, ScamReasonText> scamReasons() => {
    for (final row in _db.select('SELECT * FROM scam_reasons'))
      row['id'] as String: ScamReasonText.fromRow(row),
  };

  /// Link-shortening services, whose links hide where they lead.
  List<String> linkShorteners() {
    final rows = _db.select(
      "SELECT value FROM meta WHERE key = 'link_shorteners'",
    );
    if (rows.isEmpty) return const [];
    return (jsonDecode(rows.first['value'] as String) as List).cast<String>();
  }

  /// Hosts anyone links to, such as facebook.com. A link there is never
  /// "not their website".
  List<String> neutralHosts() => _metaList('neutral_hosts');

  /// Sender names real organisations text from. Shown on a result, never
  /// trusted, since a sender name can be faked.
  List<String> knownSenderIds() => _metaList('sender_ids');

  /// Identifies the message-check lists in this pack. Falls back to the
  /// build date for a pack made before it was recorded.
  String rulesVersion() {
    final rows = _db.select(
      "SELECT value FROM meta WHERE key = 'rules_version'",
    );
    return rows.isEmpty ? meta.buildDate : rows.first['value'] as String;
  }

  List<String> _metaList(String key) {
    final rows = _db.select('SELECT value FROM meta WHERE key = ?', [key]);
    if (rows.isEmpty) return const [];
    return (jsonDecode(rows.first['value'] as String) as List).cast<String>();
  }

  /// Online gambling brands and wording, or nothing in an older pack.
  GamblingRules gamblingRules() {
    final rows = _db.select("SELECT value FROM meta WHERE key = 'gambling'");
    if (rows.isEmpty) return GamblingRules.none;
    return GamblingRules.fromJson(
      (jsonDecode(rows.first['value'] as String) as Map)
          .cast<String, dynamic>(),
    );
  }

  IntentDef? intent(String id) {
    final rows = _db.select('SELECT * FROM intents WHERE id = ?', [id]);
    return rows.isEmpty ? null : IntentDef.fromRow(rows.first);
  }

  /// Cities the pack has places for, in alphabetical order.
  List<String> cities() => [
    for (final row in _db.select(
      "SELECT DISTINCT city FROM records WHERE kind = 'place' "
      'AND city IS NOT NULL ORDER BY city',
    ))
      row['city'] as String,
  ];

  String? provinceOf(String city) {
    final rows = _db.select(
      'SELECT province FROM records WHERE city = ? AND province IS NOT NULL '
      'LIMIT 1',
      [city],
    );
    return rows.isEmpty ? null : rows.first['province'] as String;
  }

  /// Hotlines in [categories] at exactly one level: pass [city] for city
  /// numbers, [province] for province-wide numbers, neither for national.
  List<PackRecord> hotlines({
    required List<String> categories,
    String? city,
    String? province,
  }) {
    if (categories.isEmpty) return const [];
    final marks = List.filled(categories.length, '?').join(', ');
    final String scope;
    final List<Object?> args;
    if (city != null) {
      scope = 'city = ?';
      args = [city];
    } else if (province != null) {
      scope = 'city IS NULL AND province = ?';
      args = [province];
    } else {
      scope = 'city IS NULL AND province IS NULL';
      args = [];
    }
    return [
      for (final row in _db.select(
        "SELECT * FROM records WHERE kind = 'hotline' AND $scope "
        'AND category IN ($marks) ORDER BY id',
        [...args, ...categories],
      ))
        PackRecord.fromRow(row),
    ];
  }

  /// The single national emergency number, for Home and the no-match screen.
  PackRecord? nationalEmergency() {
    final rows = hotlines(categories: const ['emergency']);
    for (final row in rows) {
      if (row.canCall) return row;
    }
    return null;
  }

  /// Places whose category is in [kinds], optionally limited to one city.
  List<PackRecord> places({required List<String> kinds, String? city}) {
    if (kinds.isEmpty) return const [];
    final marks = List.filled(kinds.length, '?').join(', ');
    final cityClause = city == null ? '' : 'AND city = ?';
    return [
      for (final row in _db.select(
        "SELECT * FROM records WHERE kind = 'place' "
        'AND category IN ($marks) $cityClause ORDER BY name',
        [...kinds, ?city],
      ))
        PackRecord.fromRow(row),
    ];
  }

  /// The city the five nearest places point to. The pack has no city
  /// boundaries, so this stands in for one.
  String? nearestCity(double lat, double lon) {
    // A degree of longitude is shorter than a degree of latitude here; the
    // factor keeps the squared-degree ordering close to true distance.
    final rows = _db.select(
      "SELECT city FROM records WHERE kind = 'place' AND city IS NOT NULL "
      'ORDER BY (lat - ?1) * (lat - ?1) + (lon - ?2) * (lon - ?2) * 0.94 '
      'LIMIT 5',
      [lat, lon],
    );
    if (rows.isEmpty) return null;
    // Closer places count for more, so one stray neighbour cannot outvote
    // the places right next to the user.
    final votes = <String, int>{};
    for (final (rank, row) in rows.indexed) {
      final city = row['city'] as String;
      votes[city] = (votes[city] ?? 0) + rows.length - rank;
    }
    return votes.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  /// Keyword search over names, categories, cities and parent agencies.
  /// Every word must match first; if nothing does, any word may.
  List<PackRecord> search(String query, {String? kind, int limit = 40}) {
    final words = RegExp(r'[\p{L}\p{N}]+', unicode: true)
        .allMatches(query.toLowerCase())
        .map((match) => match.group(0)!)
        .where((word) => word.length > 1)
        .toList();
    if (words.isEmpty) return const [];
    final terms = [for (final word in words) '"$word"*'];
    for (final joiner in const [' AND ', ' OR ']) {
      final rows = _db.select(
        'SELECT r.* FROM records_fts f JOIN records r ON r.id = f.rowid '
        'WHERE records_fts MATCH ? ${kind == null ? '' : 'AND r.kind = ?'} '
        'ORDER BY rank LIMIT ?',
        [terms.join(joiner), ?kind, limit],
      );
      if (rows.isNotEmpty) {
        return [for (final row in rows) PackRecord.fromRow(row)];
      }
      if (words.length == 1) break;
    }
    return const [];
  }

  /// Straight-line distance from [from] to a place, or null without both.
  static double? distanceTo(PackRecord place, LatLon? from) {
    final lat = place.lat;
    final lon = place.lon;
    if (from == null || lat == null || lon == null) return null;
    return distanceKm(from.lat, from.lon, lat, lon);
  }

  void close() => _db.close();
}
