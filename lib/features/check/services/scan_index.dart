import 'package:sqlite3/sqlite3.dart';

import '../models/check_result.dart';

/// Remembers which texts a scan has already checked, so the next scan only
/// reads new ones. It holds Android's id for each text, when it was
/// received and the verdict. It never holds the text or who sent it.
class ScanIndex {
  ScanIndex(this._db) {
    _db.execute('''
CREATE TABLE IF NOT EXISTS scanned (
  sms_id INTEGER PRIMARY KEY,
  sent_at INTEGER NOT NULL,
  verdict TEXT NOT NULL,
  rules TEXT NOT NULL,
  worded INTEGER NOT NULL
)''');
  }

  final Database _db;

  /// Ids already checked with this version of the rules. A text checked
  /// with older rules is not in it, so it is checked again.
  Set<int> checked(String rules) => {
    for (final row in _db.select('SELECT sms_id FROM scanned WHERE rules = ?', [
      rules,
    ]))
      row['sms_id'] as int,
  };

  /// Ids that came out clear from the rules and have not had the slower
  /// wording check yet.
  Set<int> awaitingWording(String rules) => {
    for (final row in _db.select(
      'SELECT sms_id FROM scanned WHERE rules = ? AND worded = 0 '
      "AND verdict = 'clear'",
      [rules],
    ))
      row['sms_id'] as int,
  };

  void record({
    required int smsId,
    required DateTime sentAt,
    required Verdict verdict,
    required String rules,
    required bool worded,
  }) => _db.execute(
    'INSERT OR REPLACE INTO scanned (sms_id, sent_at, verdict, rules, worded) '
    'VALUES (?, ?, ?, ?, ?)',
    [smsId, sentAt.millisecondsSinceEpoch, verdict.name, rules, worded ? 1 : 0],
  );

  /// How many texts are remembered, whatever rules checked them.
  int get count =>
      _db.select('SELECT count(*) AS n FROM scanned').first['n'] as int;

  /// Forgets everything, so the next scan starts over. Flagged messages
  /// are kept; they have their own list.
  void clear() => _db.execute('DELETE FROM scanned');
}
