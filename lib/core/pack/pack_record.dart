import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

/// A phone number as written in the source, with a dialable form when the
/// pack builder could be sure of one.
class Phone {
  const Phone({required this.display, this.dial});

  final String display;
  final String? dial;

  static List<Phone> listFromJson(String json) => [
    for (final item in jsonDecode(json) as List)
      Phone(
        display: (item as Map)['display'] as String,
        dial: item['dial'] as String?,
      ),
  ];
}

/// One row of the pack's `records` table.
class PackRecord {
  const PackRecord({
    required this.id,
    required this.kind,
    required this.name,
    required this.category,
    required this.phones,
    required this.source,
    this.region,
    this.province,
    this.city,
    this.address,
    this.lat,
    this.lon,
    this.url,
    this.parent,
  });

  factory PackRecord.fromRow(Row row) => PackRecord(
    id: row['id'] as int,
    kind: row['kind'] as String,
    name: row['name'] as String,
    category: row['category'] as String,
    region: row['region'] as String?,
    province: row['province'] as String?,
    city: row['city'] as String?,
    phones: Phone.listFromJson(row['phones'] as String),
    address: row['address'] as String?,
    lat: (row['lat'] as num?)?.toDouble(),
    lon: (row['lon'] as num?)?.toDouble(),
    url: row['url'] as String?,
    parent: row['parent'] as String?,
    source: row['source'] as String,
  );

  final int id;

  /// `hotline`, `agency`, `official`, `service` or `place`.
  final String kind;
  final String name;
  final String category;
  final String? region;
  final String? province;
  final String? city;
  final List<Phone> phones;
  final String? address;
  final double? lat;
  final double? lon;
  final String? url;

  /// The agency a service belongs to.
  final String? parent;
  final String source;

  List<Phone> get dialable => [
    for (final phone in phones)
      if (phone.dial != null) phone,
  ];

  bool get canCall => phones.any((phone) => phone.dial != null);
}

/// One row of the pack's `intents` table.
class IntentDef {
  const IntentDef({
    required this.id,
    required this.label,
    required this.hotlineCategories,
    required this.placeKinds,
    required this.examples,
  });

  factory IntentDef.fromRow(Row row) => IntentDef(
    id: row['id'] as String,
    label: row['label'] as String,
    hotlineCategories: _strings(row['hotline_categories'] as String),
    placeKinds: _strings(row['place_kinds'] as String),
    examples: _strings(row['examples'] as String),
  );

  final String id;
  final String label;
  final List<String> hotlineCategories;
  final List<String> placeKinds;
  final List<String> examples;

  static List<String> _strings(String json) =>
      (jsonDecode(json) as List).cast<String>();
}

class PackMeta {
  const PackMeta({
    required this.name,
    required this.buildDate,
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final String name;

  /// ISO date. Shown on every card, since numbers go out of date.
  final String buildDate;
  final double west;
  final double south;
  final double east;
  final double north;

  /// Whether a position is inside the area the places and map cover.
  bool covers(double lat, double lon) =>
      lat >= south && lat <= north && lon >= west && lon <= east;
}
