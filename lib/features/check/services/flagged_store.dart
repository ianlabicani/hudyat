import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/pack/scam_records.dart';
import '../models/check_result.dart';

/// Opens the flagged-messages file at [path]. A file that cannot be read is
/// moved aside, not deleted, and a new one started: the list can be rebuilt
/// by a scan, and the app must still open.
Database openFlaggedDatabase(String path) {
  Database? db;
  try {
    db = sqlite3.open(path);
    final check = db.select('PRAGMA quick_check');
    if (check.isEmpty || check.first.values.first != 'ok') {
      throw const FormatException('flagged file failed its check');
    }
    return db;
  } on Object catch (error) {
    debugPrint('Flagged file unreadable, starting a new one: $error');
    db?.close();
    // One set-aside copy is enough to look into; more would only fill the
    // phone if the file kept failing.
    final folder = File(path).parent;
    if (folder.existsSync()) {
      for (final old in folder.listSync().whereType<File>()) {
        if (old.path.startsWith('$path.damaged-')) old.deleteSync();
      }
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (final suffix in const ['', '-wal', '-shm']) {
      final file = File('$path$suffix');
      if (file.existsSync()) file.renameSync('$path.damaged-$stamp$suffix');
    }
    return sqlite3.open(path);
  }
}

/// A kept message with the result it was given.
class FlaggedMessage {
  const FlaggedMessage({
    required this.id,
    required this.result,
    required this.checkedAt,
    this.sourceKey,
    this.sourceType,
    this.sourcePackage,
    this.arrivedAt,
    this.rulesVersion,
    this.aiVersion,
  });

  final int id;
  final CheckResult result;
  final DateTime checkedAt;
  final String? sourceKey;
  final String? sourceType;
  final String? sourcePackage;
  final DateTime? arrivedAt;
  final String? rulesVersion;
  final String? aiVersion;
}

/// The only place message text is stored: "Mukhang scam" and "Mag-ingat"
/// messages, in their own file on the phone, until the user clears them.
/// Everything else is discarded after the check.
class FlaggedStore extends ChangeNotifier {
  FlaggedStore(this._db, {List<OfficialSender> senders = const []})
    : _senders = {for (final sender in senders) sender.name: sender} {
    _db.execute('''
CREATE TABLE IF NOT EXISTS flagged (
  id INTEGER PRIMARY KEY,
  text TEXT NOT NULL,
  sender TEXT,
  app TEXT,
  verdict TEXT NOT NULL,
  reasons TEXT NOT NULL,
  claimed TEXT,
  truncated INTEGER NOT NULL,
  checked_at INTEGER NOT NULL,
  phrasing TEXT NOT NULL DEFAULT 'unknown',
  link_count INTEGER NOT NULL DEFAULT 0,
  source_key TEXT,
  source_type TEXT,
  source_package TEXT,
  arrived_at INTEGER,
  rules_version TEXT,
  ai_version TEXT
)''');
    final columns = {
      for (final row in _db.select('PRAGMA table_info(flagged)')) row['name'],
    };
    _db.execute('BEGIN');
    try {
      if (!columns.contains('phrasing')) {
        _db.execute(
          "ALTER TABLE flagged ADD COLUMN phrasing TEXT NOT NULL DEFAULT 'unknown'",
        );
      }
      if (!columns.contains('link_count')) {
        _db.execute(
          'ALTER TABLE flagged ADD COLUMN link_count INTEGER NOT NULL DEFAULT 0',
        );
      }
      for (final name in [
        'source_key',
        'source_type',
        'source_package',
        'arrived_at',
        'rules_version',
        'ai_version',
      ]) {
        if (!columns.contains(name)) {
          _db.execute(
            'ALTER TABLE flagged ADD COLUMN $name '
            '${name == 'arrived_at' ? 'INTEGER' : 'TEXT'}',
          );
        }
      }
      _db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS flagged_source_key '
        'ON flagged(source_key) WHERE source_key IS NOT NULL',
      );
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
    _db.execute('PRAGMA busy_timeout = 3000');
    _db.execute('PRAGMA journal_mode = WAL');
    // With the write-ahead log this is safe, and a commit no longer waits
    // for the disk: an inbox scan commits once per text.
    _db.execute('PRAGMA synchronous = NORMAL');
    // What has been copied in from the Android side, by its source key. The
    // tag says which version of a finding was copied, so one the user removed
    // here is not brought back unless Android judged it anew.
    _db.execute('''
CREATE TABLE IF NOT EXISTS native_findings (
  source_key TEXT PRIMARY KEY,
  native_id INTEGER NOT NULL,
  tag TEXT NOT NULL
)''');
  }

  factory FlaggedStore.open(
    String path, {
    List<OfficialSender> senders = const [],
  }) => FlaggedStore(sqlite3.open(path), senders: senders);

  final Database _db;

  /// The contact is looked up again on reading, so it is always the pack's
  /// current one.
  final Map<String, OfficialSender> _senders;

  /// Whether the last [_keepInTransaction] changed a row. A clear text that
  /// was never kept changes nothing, and nobody needs telling.
  bool _wrote = false;

  int get count =>
      _db.select('SELECT count(*) AS n FROM flagged').first['n'] as int;

  /// How many kept messages from [sender] are gambling promos. Counted in
  /// the database, so a result screen does not load every kept message.
  int promosFrom(String sender) =>
      _db.select(
            'SELECT count(*) AS n FROM flagged WHERE sender = ? '
            'AND reasons LIKE ?',
            [sender, '%"id":"${ReasonId.gamblingPromo}"%'],
          ).first['n']
          as int;

  /// Whether this text from this sender is already kept.
  bool has(CheckResult result) => _db.select(
    'SELECT 1 FROM flagged WHERE text = ? AND sender IS ? LIMIT 1',
    [result.text, result.sender],
  ).isNotEmpty;

  /// Saves a flagged result atomically. A source identity keeps the same row
  /// when an alert, inbox scan, and foreground AI pass see the same message.
  int? keep(
    CheckResult result, {
    DateTime? at,
    String? sourceKey,
    String? sourceType,
    String? sourcePackage,
    DateTime? arrivedAt,
    String? rulesVersion,
    String? aiVersion,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final id = _keepInTransaction(
        result,
        at: at,
        sourceKey: sourceKey,
        sourceType: sourceType,
        sourcePackage: sourcePackage,
        arrivedAt: arrivedAt,
        rulesVersion: rulesVersion,
        aiVersion: aiVersion,
      );
      _db.execute('COMMIT');
      if (_wrote) notifyListeners();
      return id;
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  int? _keepInTransaction(
    CheckResult result, {
    DateTime? at,
    String? sourceKey,
    String? sourceType,
    String? sourcePackage,
    DateTime? arrivedAt,
    String? rulesVersion,
    String? aiVersion,
  }) {
    _wrote = false;
    final bySource = sourceKey == null
        ? const <Row>[]
        : _db.select('SELECT id FROM flagged WHERE source_key = ?', [
            sourceKey,
          ]);
    final legacy = bySource.isNotEmpty
        ? const <Row>[]
        : _db.select(
            'SELECT id FROM flagged WHERE source_key IS NULL '
            'AND text = ? AND sender IS ? ORDER BY id DESC LIMIT 1',
            [result.text, result.sender],
          );
    final id =
        (bySource.isNotEmpty
                ? bySource.first['id']
                : legacy.isNotEmpty
                ? legacy.first['id']
                : null)
            as int?;
    if (!result.isFlagged) {
      if (id != null) {
        _db.execute('DELETE FROM flagged WHERE id = ?', [id]);
        _wrote = true;
      }
      return null;
    }
    _wrote = true;
    final values = [
      result.text,
      result.sender,
      result.app,
      result.verdict.name,
      jsonEncode([
        for (final reason in result.reasons)
          {'id': reason.id, 'facts': reason.facts},
      ]),
      result.claimed?.name,
      result.truncated ? 1 : 0,
      (at ?? DateTime.now()).millisecondsSinceEpoch,
      result.phrasing.name,
      result.linkCount,
      sourceKey,
      sourceType,
      sourcePackage,
      arrivedAt?.millisecondsSinceEpoch,
      rulesVersion,
      aiVersion,
    ];
    if (id == null) {
      _db.execute(
        'INSERT INTO flagged (text, sender, app, verdict, reasons, claimed, '
        'truncated, checked_at, phrasing, link_count, source_key, '
        'source_type, source_package, arrived_at, rules_version, ai_version) '
        'VALUES (${List.filled(16, '?').join(', ')})',
        values,
      );
      return _db.lastInsertRowId;
    }
    _db.execute(
      'UPDATE flagged SET text=?, sender=?, app=?, verdict=?, reasons=?, '
      'claimed=?, truncated=?, checked_at=?, phrasing=?, link_count=?, '
      'source_key=COALESCE(?, source_key), source_type=COALESCE(?, source_type), '
      'source_package=COALESCE(?, source_package), '
      'arrived_at=COALESCE(?, arrived_at), '
      'rules_version=COALESCE(?, rules_version), '
      'ai_version=COALESCE(?, ai_version) WHERE id=?',
      [...values, id],
    );
    return id;
  }

  /// The kept message with [id], if it has not been cleared.
  FlaggedMessage? byId(int id) {
    final rows = _db.select('SELECT * FROM flagged WHERE id = ?', [id]);
    return rows.isEmpty ? null : _message(rows.single);
  }

  /// Newest first.
  List<FlaggedMessage> all() => [
    for (final row in _db.select(
      'SELECT * FROM flagged ORDER BY checked_at DESC, id DESC',
    ))
      _message(row),
  ];

  FlaggedMessage _message(Row row) => FlaggedMessage(
    id: row['id'] as int,
    checkedAt: DateTime.fromMillisecondsSinceEpoch(row['checked_at'] as int),
    sourceKey: row['source_key'] as String?,
    sourceType: row['source_type'] as String?,
    sourcePackage: row['source_package'] as String?,
    arrivedAt: row['arrived_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['arrived_at'] as int),
    rulesVersion: row['rules_version'] as String?,
    aiVersion: row['ai_version'] as String?,
    result: CheckResult(
      text: row['text'] as String,
      verdict: Verdict.values.byName(row['verdict'] as String),
      reasons: [
        for (final item in jsonDecode(row['reasons'] as String) as List)
          CheckReason(
            (item as Map)['id'] as String,
            (item['facts'] as Map).cast<String, String>(),
          ),
      ],
      phrasing: PhrasingState.values.firstWhere(
        (state) => state.name == row['phrasing'],
        orElse: () => PhrasingState.unknown,
      ),
      linkCount: row['link_count'] as int,
      sender: row['sender'] as String?,
      app: row['app'] as String?,
      claimed: _senders[row['claimed']],
      truncated: row['truncated'] == 1,
    ),
  );

  List<FlaggedMessage> notificationFindingsAwaitingAI(String aiVersion) => [
    for (final row in _db.select(
      "SELECT * FROM flagged WHERE source_type = 'notification' "
      'AND (ai_version IS NULL OR ai_version != ?) '
      'ORDER BY arrived_at DESC LIMIT 100',
      [aiVersion],
    ))
      _message(row),
  ];

  /// Native writes use another SQLite connection; refresh the visible list
  /// when the platform reports a completed transaction.
  void nativeResultsChanged() => notifyListeners();

  /// Copies the Android side's findings in. Android keeps them in a file of
  /// its own, which this store never opens; they arrive as plain maps. Each
  /// version of a finding is copied once. Returns how many were copied.
  int importNative(List<Map<Object?, Object?>> findings) {
    var copied = 0;
    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final row in findings) {
        final key = row['sourceKey'];
        final verdict = Verdict.values.asNameMap()[row['verdict']];
        final reasons = row['reasons'];
        if (key is! String || verdict == null || reasons is! String) continue;
        final nativeId = (row['id'] as num?)?.toInt() ?? 0;
        final rules = row['rulesVersion'] as String?;
        final tag = '$rules|${verdict.name}|$reasons';
        final seen = _db.select(
          'SELECT tag FROM native_findings WHERE source_key = ?',
          [key],
        );
        if (seen.isNotEmpty && seen.first['tag'] == tag) {
          // The alert that points here carries Android's id for it.
          _db.execute(
            'UPDATE native_findings SET native_id = ? WHERE source_key = ?',
            [nativeId, key],
          );
          continue;
        }
        final arrived = (row['arrivedAt'] as num?)?.toInt();
        final checked = (row['checkedAt'] as num?)?.toInt();
        _keepInTransaction(
          CheckResult(
            text: row['text'] as String? ?? '',
            verdict: verdict,
            reasons: [
              for (final item in jsonDecode(reasons) as List)
                CheckReason(
                  (item as Map)['id'] as String,
                  (item['facts'] as Map).cast<String, String>(),
                ),
            ],
            // Android runs the rules only; the wording check comes later.
            phrasing: PhrasingState.skipped,
            linkCount: (row['linkCount'] as num?)?.toInt() ?? 0,
            sender: row['sender'] as String?,
            app: row['app'] as String?,
            truncated: row['truncated'] == true,
          ),
          at: checked == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(checked),
          sourceKey: key,
          sourceType: row['sourceType'] as String?,
          sourcePackage: row['sourcePackage'] as String?,
          arrivedAt: arrived == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(arrived),
          rulesVersion: rules,
        );
        _db.execute(
          'INSERT OR REPLACE INTO native_findings (source_key, native_id, tag) '
          'VALUES (?, ?, ?)',
          [key, nativeId, tag],
        );
        copied++;
      }
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
    if (copied > 0) notifyListeners();
    return copied;
  }

  /// The kept message for Android's finding [nativeId], which is what a scam
  /// alert carries. Null if it was never copied in, or was removed here.
  FlaggedMessage? byNativeId(int nativeId) {
    final rows = _db.select(
      'SELECT flagged.* FROM flagged JOIN native_findings '
      'ON native_findings.source_key = flagged.source_key '
      'WHERE native_findings.native_id = ?',
      [nativeId],
    );
    return rows.isEmpty ? null : _message(rows.first);
  }

  /// Drops one kept message. The text in the SMS app is untouched.
  void remove(int id) {
    _db.execute('DELETE FROM flagged WHERE id = ?', [id]);
    notifyListeners();
  }

  void clear() {
    _db.execute('DELETE FROM flagged');
    notifyListeners();
  }

  void close() => _db.close();
}
