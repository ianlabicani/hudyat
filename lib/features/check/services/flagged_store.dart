import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/pack/scam_records.dart';
import '../models/check_result.dart';

/// A kept message with the result it was given.
class FlaggedMessage {
  const FlaggedMessage({
    required this.id,
    required this.result,
    required this.checkedAt,
  });

  final int id;
  final CheckResult result;
  final DateTime checkedAt;
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
  checked_at INTEGER NOT NULL
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

  int get count =>
      _db.select('SELECT count(*) AS n FROM flagged').first['n'] as int;

  /// Whether this text from this sender is already kept.
  bool has(CheckResult result) => _db.select(
    'SELECT 1 FROM flagged WHERE text = ? AND sender IS ? LIMIT 1',
    [result.text, result.sender],
  ).isNotEmpty;

  /// Keeps [result] if it is flagged and returns its id; anything else is
  /// ignored and gives null. The same text from the same sender is kept
  /// once, with the latest time.
  int? keep(CheckResult result, {DateTime? at}) {
    if (!result.isFlagged) return null;
    _db
      ..execute('DELETE FROM flagged WHERE text = ? AND sender IS ?', [
        result.text,
        result.sender,
      ])
      ..execute(
        'INSERT INTO flagged (text, sender, app, verdict, reasons, claimed, '
        'truncated, checked_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
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
        ],
      );
    final id = _db.lastInsertRowId;
    notifyListeners();
    return id;
  }

  /// The kept message with [id], if it has not been cleared.
  FlaggedMessage? byId(int id) {
    for (final message in all()) {
      if (message.id == id) return message;
    }
    return null;
  }

  /// Newest first.
  List<FlaggedMessage> all() => [
    for (final row in _db.select(
      'SELECT * FROM flagged ORDER BY checked_at DESC, id DESC',
    ))
      FlaggedMessage(
        id: row['id'] as int,
        checkedAt: DateTime.fromMillisecondsSinceEpoch(
          row['checked_at'] as int,
        ),
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
          phrasing: PhrasingState.checked,
          sender: row['sender'] as String?,
          app: row['app'] as String?,
          claimed: _senders[row['claimed']],
          truncated: row['truncated'] == 1,
        ),
      ),
  ];

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
