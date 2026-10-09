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

  test('a source key keeps one row with a stable id across updates', () {
    final db = sqlite3.openInMemory();
    final store = FlaggedStore(db);
    addTearDown(store.close);
    const result = CheckResult(
      text: 'Claim your prize now',
      verdict: Verdict.caution,
      reasons: [CheckReason(ReasonId.linkShortener)],
      phrasing: PhrasingState.skipped,
    );
    final first = store.keep(result, sourceKey: 'sms_broadcast:abc')!;
    final second = store.keep(
      CheckResult(
        text: result.text,
        verdict: Verdict.scam,
        reasons: result.reasons,
        phrasing: PhrasingState.checked,
      ),
      sourceKey: 'sms_broadcast:abc',
      aiVersion: 'ai-2',
    );
    expect(second, first);
    expect(store.count, 1);
    final updated = store.byId(first)!;
    expect(updated.result.verdict, Verdict.scam);
    expect(updated.aiVersion, 'ai-2');
  });

  test('source identity, arrival time and versions round trip', () {
    final db = sqlite3.openInMemory();
    final store = FlaggedStore(db);
    addTearDown(store.close);
    final id = store.keep(
      const CheckResult(
        text: 'suspicious text',
        verdict: Verdict.caution,
        reasons: [CheckReason(ReasonId.linkShortener)],
        phrasing: PhrasingState.skipped,
      ),
      sourceKey: 'notification:com.whatsapp:key1',
      sourceType: 'notification',
      sourcePackage: 'com.whatsapp',
      arrivedAt: DateTime.fromMillisecondsSinceEpoch(456000),
      rulesVersion: 'rules-9',
    )!;
    final saved = FlaggedStore(db).byId(id)!;
    expect(saved.sourceKey, 'notification:com.whatsapp:key1');
    expect(saved.sourceType, 'notification');
    expect(saved.sourcePackage, 'com.whatsapp');
    expect(saved.arrivedAt?.millisecondsSinceEpoch, 456000);
    expect(saved.rulesVersion, 'rules-9');
    expect(saved.aiVersion, isNull);
  });

  test('only notification findings missing the current AI version wait', () {
    final db = sqlite3.openInMemory();
    final store = FlaggedStore(db);
    addTearDown(store.close);
    const result = CheckResult(
      text: 'text',
      verdict: Verdict.caution,
      reasons: [CheckReason(ReasonId.linkShortener)],
      phrasing: PhrasingState.skipped,
    );
    final waiting = store.keep(
      result,
      sourceKey: 'n:1',
      sourceType: 'notification',
    );
    final stale = store.keep(
      const CheckResult(
        text: 'other',
        verdict: Verdict.caution,
        reasons: [CheckReason(ReasonId.linkShortener)],
        phrasing: PhrasingState.skipped,
      ),
      sourceKey: 'n:2',
      sourceType: 'notification',
      aiVersion: 'ai-1',
    );
    store.keep(
      const CheckResult(
        text: 'done',
        verdict: Verdict.caution,
        reasons: [CheckReason(ReasonId.linkShortener)],
        phrasing: PhrasingState.checked,
      ),
      sourceKey: 'n:3',
      sourceType: 'notification',
      aiVersion: 'ai-2',
    );
    store.keep(
      const CheckResult(
        text: 'sms text',
        verdict: Verdict.caution,
        reasons: [CheckReason(ReasonId.linkShortener)],
        phrasing: PhrasingState.skipped,
      ),
      sourceKey: 's:1',
      sourceType: 'sms',
    );
    final pending = store.notificationFindingsAwaitingAI('ai-2');
    expect(pending.map((m) => m.id), containsAll([waiting, stale]));
    expect(pending, hasLength(2));
  });

  test('a clear verdict removes the saved row for the same source', () {
    final db = sqlite3.openInMemory();
    final store = FlaggedStore(db);
    addTearDown(store.close);
    final id = store.keep(
      const CheckResult(
        text: 'was flagged',
        verdict: Verdict.caution,
        reasons: [CheckReason(ReasonId.linkShortener)],
        phrasing: PhrasingState.skipped,
      ),
      sourceKey: 'n:9',
      sourceType: 'notification',
    )!;
    store.keep(
      const CheckResult(
        text: 'was flagged',
        verdict: Verdict.clear,
        reasons: [],
        phrasing: PhrasingState.checked,
      ),
      sourceKey: 'n:9',
      sourceType: 'notification',
    );
    expect(store.byId(id), isNull);
    expect(store.count, 0);
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
