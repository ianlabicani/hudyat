import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/features/check/models/check_result.dart';
import 'package:hudyat/features/check/services/flagged_store.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('legacy migration preserves messages and does not claim AI ran', () {
    final db = sqlite3.openInMemory();
    db.execute('''CREATE TABLE flagged (
id INTEGER PRIMARY KEY, text TEXT NOT NULL, sender TEXT, app TEXT,
verdict TEXT NOT NULL, reasons TEXT NOT NULL, claimed TEXT,
truncated INTEGER NOT NULL, checked_at INTEGER NOT NULL)''');
    db.execute(
      "INSERT INTO flagged VALUES (7, 'old text', 'sender', 'Messages', 'caution', '[]', NULL, 1, 123)",
    );
    final store = FlaggedStore(db);
    addTearDown(store.close);
    // Opening an already migrated database is safe too.
    FlaggedStore(db);
    final message = store.byId(7)!;
    expect(message.result.text, 'old text');
    expect(message.result.sender, 'sender');
    expect(message.result.truncated, isTrue);
    expect(message.checkedAt.millisecondsSinceEpoch, 123);
    expect(message.result.phrasing, PhrasingState.unknown);
    expect(message.result.linkCount, 0);
  });

  for (final state in PhrasingState.values) {
    test('saved ${state.name} metadata survives reopening', () {
      final db = sqlite3.openInMemory();
      final store = FlaggedStore(db);
      addTearDown(store.close);
      store.keep(
        CheckResult(
          text: 'test message',
          verdict: Verdict.caution,
          reasons: const [CheckReason(ReasonId.linkShortener)],
          phrasing: state,
          linkCount: 2,
        ),
      );
      final reopened = FlaggedStore(db).all().single.result;
      expect(reopened.phrasing, state);
      expect(reopened.linkCount, 2);
    });
  }
}
