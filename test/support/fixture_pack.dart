import 'dart:async';
import 'dart:convert';

import 'package:hudyat/core/geo.dart';
import 'package:hudyat/core/models/model_runtime.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/features/check/services/message_watcher.dart';
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
    'na-lock',
    'i-verify',
    'ayuda',
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
PackStore fixtureStore({bool gambling = true}) {
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
CREATE TABLE official_senders (
  id INTEGER PRIMARY KEY, name TEXT NOT NULL, short TEXT NOT NULL,
  kind TEXT NOT NULL, aliases TEXT NOT NULL, strict_aliases TEXT NOT NULL,
  domains TEXT NOT NULL, phones TEXT NOT NULL, source_url TEXT
);
CREATE TABLE scam_examples (
  id INTEGER PRIMARY KEY, text TEXT NOT NULL, type TEXT NOT NULL,
  type_label TEXT NOT NULL
);
CREATE TABLE scam_reasons (
  id TEXT PRIMARY KEY, tl TEXT NOT NULL, en TEXT NOT NULL, fact TEXT NOT NULL
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

  meta('link_shorteners', jsonEncode(['bit.ly', 'tinyurl.com']));
  meta('neutral_hosts', jsonEncode(['facebook.com']));
  meta('sender_ids', jsonEncode(['GCash', 'BDO Alert']));
  if (gambling) {
    meta(
      'gambling',
      jsonEncode({
        'brands': [
          {
            'name': 'BingoPlus',
            'aliases': ['BingoPlus'],
            'domains': ['bingoplus.com'],
          },
          {
            'name': '789Bingo',
            'aliases': ['789Bingo'],
            'domains': ['789bingo.com'],
          },
          {
            'name': 'ArenaPlus',
            'aliases': ['ArenaPlus'],
            'domains': <String>[],
          },
          {
            'name': 'Lucky Cola',
            'aliases': ['LuckyCola', 'Lucky Cola'],
            'domains': <String>[],
          },
        ],
        'host_words': ['casino', 'bingo'],
        'terms': ['rebate', 'cashback', 'jackpot', 'top up', 'casino', 'slot'],
      }),
    );
  }
  void sender(
    String name,
    String kind,
    List<String> aliases,
    List<String> domains, {
    String? short,
    List<String> strict = const [],
    List<(String, String?)> phones = const [],
  }) => db.execute(
    'INSERT INTO official_senders (name, short, kind, aliases, '
    'strict_aliases, domains, phones) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [
      name,
      short ?? name,
      kind,
      jsonEncode(aliases),
      jsonEncode(strict),
      jsonEncode(domains),
      jsonEncode([
        for (final (display, dial) in phones)
          {'display': display, 'dial': dial},
      ]),
    ],
  );
  sender(
    'GCash',
    'company',
    ['GCash'],
    ['gcash.com'],
    phones: [('(02) 7213-9999', '0272139999'), ('2882', '2882')],
  );
  sender('BDO', 'company', ['BDO', 'Banco de Oro'], ['bdo.com.ph']);
  sender(
    'Smart',
    'company',
    ['Smart Communications'],
    ['smart.com.ph'],
    strict: ['Smart'],
  );
  sender('Maya', 'company', ['PayMaya'], ['maya.ph'], strict: ['Maya']);
  sender(
    'Department of Social Welfare and Development',
    'agency',
    ['Department of Social Welfare and Development', 'DSWD'],
    ['dswd.gov.ph'],
    short: 'DSWD',
  );
  sender(
    'Social Security System',
    'agency',
    ['Social Security System', 'SSS'],
    ['sss.gov.ph'],
    short: 'SSS',
  );

  void example(String text, String label) => db.execute(
    'INSERT INTO scam_examples (text, type, type_label) VALUES (?, ?, ?)',
    [text, 'test', label],
  );
  example('Na-lock ang account mo, i-verify agad', 'Na-lock na account');
  example('Kwalipikado ka sa ayuda, i-claim na', 'Pekeng ayuda');

  void reason(String id, String tl, String en, String fact) => db.execute(
    'INSERT INTO scam_reasons VALUES (?, ?, ?, ?)',
    [id, tl, en, fact],
  );
  reason(
    'link_lookalike',
    'Ginagaya ng link na {domain} ang {org}.',
    'The link {domain} imitates {org}.',
    'Opisyal: {official}',
  );
  reason(
    'link_not_official',
    'Hindi opisyal na website ng {org} ang {domain}.',
    'The link {domain} is not the official {org} website.',
    'Opisyal: {official}',
  );
  reason(
    'sender_mobile',
    'Nagpapakilalang {org} pero galing sa mobile number.',
    'Claims to be {org} but comes from a mobile number.',
    'Galing sa: {sender}',
  );
  reason(
    'link_shortener',
    'Pinaikli ang link.',
    'The link is shortened.',
    'Link: {domain}',
  );
  reason(
    'phrasing',
    'Kahawig ito ng mga kilalang scam.',
    'Close to known scam messages.',
    'Uri: {type}',
  );
  reason(
    'link_hidden',
    'Sinadyang putulin ang link.',
    'The link is deliberately broken up.',
    'Link: {domain}',
  );
  reason(
    'gambling_promo',
    'Promo ito ng online na sugal.',
    'This is an online gambling promo.',
    'Mula sa: {source}',
  );
  return PackStore(db);
}

/// Notification access that is granted or refused as the test says, with a
/// stream the test feeds.
class FakeNotificationSource implements NotificationSource {
  FakeNotificationSource({this.granted = false, this.grantsOnRequest = true});

  bool granted;
  bool grantsOnRequest;
  int requests = 0;
  final controller = StreamController<IncomingNotification>.broadcast();

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> requestAccess() async {
    requests++;
    return granted = grantsOnRequest;
  }

  @override
  Stream<IncomingNotification> get notifications => controller.stream;
}

/// Records the alerts that would have been posted.
class FakeAlerter implements Alerter {
  final alerts = <({int id, String title, String body})>[];
  void Function(int flaggedId)? onOpen;

  @override
  Future<void> start(void Function(int flaggedId) onOpen) async =>
      this.onOpen = onOpen;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> alert({
    required int flaggedId,
    required String title,
    required String body,
  }) async => alerts.add((id: flaggedId, title: title, body: body));
}
