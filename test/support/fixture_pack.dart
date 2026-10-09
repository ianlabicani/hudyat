import 'dart:convert';

import 'package:hudyat/core/geo.dart';
import 'package:hudyat/core/models/model_runtime.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/features/location/services/location_service.dart';
import 'package:sqlite3/sqlite3.dart';

/// A position in Pasig, inside the fixture pack's area.
const pasigPosition = LatLon(14.57, 121.07);

/// A GPS that returns whatever the test sets, or nothing.
class FakeLocationService implements LocationService {
  FakeLocationService([this.fix]);

  LatLon? fix;

  @override
  Future<LatLon?> currentPosition() async => fix;
}

/// Embeds text as counts of a few known words, so tests can predict which
/// phrases are close. Counts every call to check caching.
class FakeEmbedder implements TextEmbedder {
  static const words = [
    'ospital',
    'hinga',
    'malay',
    'botika',
    'gamot',
    'sugat',
    'dugo',
    'trapik',
    'passport',
    'klinika',
    'ubo',
  ];

  int calls = 0;

  /// How many texts have been embedded, however they were batched.
  int embedded = 0;
  Object? failure;

  @override
  Future<List<List<double>>> embed(
    List<String> texts, {
    required bool asQuery,
  }) async {
    calls++;
    embedded += texts.length;
    if (failure case final failure?) throw failure;
    return [
      for (final text in texts)
        [
          for (final word in words)
            text.toLowerCase().contains(word) ? 1.0 : 0.0,
        ],
    ];
  }
}

/// Emits the given pieces of text, or fails.
class FakeGenerator implements TextGenerator {
  FakeGenerator(this.pieces, {this.failure});

  final List<String> pieces;
  final Object? failure;
  String? lastPrompt;

  @override
  Stream<String> generate(String prompt, {int maxOutputTokens = 80}) async* {
    lastPrompt = prompt;
    if (failure case final failure?) throw failure;
    yield* Stream.fromIterable(pieces);
  }
}

/// A model layer with whatever the test puts on the "phone".
class FakeRuntime implements ModelRuntime {
  FakeRuntime({this.embedder, this.generator, this.canDownload = false});

  TextEmbedder? embedder;
  TextGenerator? generator;
  Object? loadFailure;

  @override
  final bool canDownload;

  @override
  Future<String?> sideloadFolder() async => '/phone/models';

  @override
  Future<TextEmbedder?> loadEmbedder() async {
    if (loadFailure case final failure?) throw failure;
    return embedder;
  }

  @override
  Future<TextGenerator?> loadGenerator() async => generator;

  @override
  Future<TextEmbedder?> downloadEmbedder(
    void Function(int percent) onProgress,
  ) async {
    onProgress(50);
    onProgress(100);
    return embedder ??= FakeEmbedder();
  }

  @override
  Future<TextGenerator?> downloadGenerator(
    void Function(int percent) onProgress,
  ) async {
    onProgress(100);
    return generator ??= FakeGenerator(const ['Tawagan ang hotline.']);
  }
}

/// A small in-memory pack with the same tables as the real one. Tests never
/// open the real pack.
PackStore fixtureStore() {
  final db = sqlite3.openInMemory()
    ..execute('''
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE records (
  id INTEGER PRIMARY KEY, kind TEXT NOT NULL, name TEXT NOT NULL,
  category TEXT NOT NULL, region TEXT, province TEXT, city TEXT,
  phones TEXT NOT NULL, address TEXT, lat REAL, lon REAL, url TEXT,
  parent TEXT, source TEXT NOT NULL
);
CREATE VIRTUAL TABLE records_fts USING fts5 (
  name, category, city, parent, content = 'records', content_rowid = 'id',
  tokenize = 'unicode61 remove_diacritics 2'
);
CREATE TABLE intents (
  id TEXT PRIMARY KEY, label TEXT NOT NULL, examples TEXT NOT NULL,
  hotline_categories TEXT NOT NULL, place_kinds TEXT NOT NULL
);
''');

  void meta(String key, String value) =>
      db.execute('INSERT INTO meta VALUES (?, ?)', [key, value]);
  meta('name', 'Test pack');
  meta('build_date', '2026-10-09');
  meta('bbox', '120.9,14.34,121.16,14.8');

  void intent(
    String id,
    String label,
    List<String> cats,
    List<String> kinds,
    List<String> examples,
  ) => db.execute('INSERT INTO intents VALUES (?, ?, ?, ?, ?)', [
    id,
    label,
    jsonEncode(examples),
    jsonEncode(cats),
    jsonEncode(kinds),
  ]);
  const urgent = ['medical', 'disaster', 'emergency'];
  intent(
    'medical_emergency',
    'Medical emergency',
    urgent,
    ['hospital'],
    ['hindi makahinga, kailangan ng ospital', 'nawalan ng malay'],
  );
  intent(
    'need_medicine',
    'Medicine',
    [],
    ['pharmacy'],
    ['saan may botika', 'kailangan ng gamot'],
  );
  intent('traffic', 'Traffic', ['transport'], [], ['sobrang trapik']);
  intent('injury', 'Injury', urgent, ['hospital'], ['nasugatan, may dugo']);
  intent('general_lookup', 'Look up', [], [], ['paano kumuha ng passport']);
  intent('need_clinic', 'Clinic', [], ['clinic'], ['magpa-checkup sa klinika']);

  void record(
    String kind,
    String name,
    String category, {
    String? city,
    String? province,
    List<(String display, String? dial)> phones = const [],
    double? lat,
    double? lon,
    String? address,
    String? url,
    String? parent,
  }) => db.execute(
    'INSERT INTO records (kind, name, category, province, city, phones, '
    'address, lat, lon, url, parent, source) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      kind,
      name,
      category,
      province,
      city,
      jsonEncode([
        for (final (display, dial) in phones)
          {'display': display, 'dial': dial},
      ]),
      address,
      lat,
      lon,
      url,
      parent,
      'test-source',
    ],
  );

  const mm = 'Metro Manila';
  // Hotlines: Pasig has city numbers, Marikina has none.
  record(
    'hotline',
    'Pasig City General Hospital',
    'medical',
    city: 'Pasig',
    province: mm,
    phones: [('86427379', '0286427379'), ('86427381', '0286427381')],
  );
  record(
    'hotline',
    'Pasig City DRRMO Emergency Hotline',
    'disaster',
    city: 'Pasig',
    province: mm,
    phones: [('86430000', '0286430000')],
  );
  record(
    'hotline',
    'Pasig Health Laboratory',
    'medical',
    city: 'Pasig',
    province: mm,
    phones: [('6431234', null)],
  );
  record(
    'hotline',
    'Metro Manila Development Authority (MMDA)',
    'transport',
    province: mm,
    phones: [('136 (Hotline)', '136')],
  );
  record(
    'hotline',
    'Red Cross',
    'disaster',
    phones: [('143 (Hotline)', '143')],
  );
  record(
    'hotline',
    'National Emergency Hotline',
    'emergency',
    phones: [('911', '911')],
  );

  // Places.
  record(
    'place',
    'Pasig Hospital East',
    'hospital',
    city: 'Pasig',
    province: mm,
    lat: 14.56,
    lon: 121.08,
    address: '1 East Road, Pasig',
    phones: [('+63 2 8111 2222', '0281112222')],
  );
  record(
    'place',
    'Marikina Valley Hospital',
    'hospital',
    city: 'Marikina',
    province: mm,
    lat: 14.65,
    lon: 121.10,
  );
  record(
    'place',
    'Pasig Hospital West',
    'hospital',
    city: 'Pasig',
    province: mm,
    lat: 14.575,
    lon: 121.068,
  );
  record(
    'place',
    'Botika ng Marikina',
    'pharmacy',
    city: 'Marikina',
    province: mm,
    lat: 14.64,
    lon: 121.1,
  );
  record(
    'place',
    'Pasig Clinic',
    'clinic',
    city: 'Pasig',
    lat: 14.571,
    lon: 121.071,
  );
  record(
    'place',
    'Pasig Police',
    'police',
    city: 'Pasig',
    lat: 14.569,
    lon: 121.069,
  );

  // Everyday lookup.
  record(
    'agency',
    'DEPARTMENT OF FOREIGN AFFAIRS',
    'Department',
    phones: [('(632) 8834-4000', '0288344000')],
    url: 'https://www.dfa.gov.ph',
  );
  record(
    'service',
    'Schedule Passport Application Appointment',
    'Passport and Travel',
    url: 'https://passport.gov.ph/appointment',
    parent: 'DEPARTMENT OF FOREIGN AFFAIRS',
    phones: [('(632) 8834-4000', '0288344000')],
  );
  record(
    'service',
    'Renew NBI Clearance',
    'Certificates and IDs',
    url: 'https://nbi.gov.ph',
  );
  record(
    'official',
    'JUAN DELA CRUZ',
    'Mayor',
    city: 'Parañaque',
    province: mm,
    phones: [('8805-7963', '0288057963')],
  );

  db.execute("INSERT INTO records_fts (records_fts) VALUES ('rebuild')");
  return PackStore(db);
}
