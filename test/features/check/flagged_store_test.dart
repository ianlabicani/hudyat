import 'dart:io';

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

  group('findings from the Android side', () {
    Map<Object?, Object?> finding({
      int id = 10,
      String key = 'sms:819',
      String verdict = 'scam',
      String rules = 'r1',
    }) => {
      'id': id,
      'text': 'Verify at tbpluswin. com',
      'sender': '+639171234567',
      'app': 'Messages',
      'verdict': verdict,
      'reasons': '[{"id":"link_hidden","facts":{"domain":"tbpluswin.com"}}]',
      'truncated': false,
      'checkedAt': 1000,
      'linkCount': 1,
      'sourceKey': key,
      'sourceType': 'sms',
      'sourcePackage': null,
      'arrivedAt': 1000,
      'rulesVersion': rules,
    };

    test('are copied in once, and found by the id an alert carries', () {
      final store = FlaggedStore(sqlite3.openInMemory());
      addTearDown(store.close);
      expect(store.importNative([finding()]), 1);
      expect(store.importNative([finding()]), 0);
      expect(store.count, 1);

      final kept = store.byNativeId(10)!;
      expect(kept.result.verdict, Verdict.scam);
      expect(kept.result.reasons.single.facts['domain'], 'tbpluswin.com');
      expect(kept.result.phrasing, PhrasingState.skipped);
      expect(kept.sourceKey, 'sms:819');
      expect(store.byNativeId(99), isNull);
    });

    test('one the user removed is not brought back', () {
      final store = FlaggedStore(sqlite3.openInMemory());
      addTearDown(store.close);
      store.importNative([finding()]);
      store.remove(store.byNativeId(10)!.id);
      expect(store.importNative([finding()]), 0);
      expect(store.count, 0);
    });

    test('a finding Android judged anew replaces the old copy', () {
      final store = FlaggedStore(sqlite3.openInMemory());
      addTearDown(store.close);
      store.importNative([finding()]);
      final id = store.byNativeId(10)!.id;
      expect(store.importNative([finding(verdict: 'caution', rules: 'r2')]), 1);
      expect(store.count, 1);
      expect(store.byId(id)!.result.verdict, Verdict.caution);
    });

    test('a row that cannot be read is skipped, not fatal', () {
      final store = FlaggedStore(sqlite3.openInMemory());
      addTearDown(store.close);
      expect(
        store.importNative([
          {'id': 1, 'verdict': 'scam'},
          finding(),
        ]),
        1,
      );
    });
  });

  test('promosFrom counts only that sender\'s gambling promos', () {
    final store = FlaggedStore(sqlite3.openInMemory());
    addTearDown(store.close);
    CheckResult kept(String text, String sender, String reason) => CheckResult(
      text: text,
      verdict: Verdict.caution,
      reasons: [
        CheckReason(reason, const {'source': 'BingoPlus'}),
      ],
      phrasing: PhrasingState.skipped,
      sender: sender,
    );
    store
      ..keep(kept('promo one', 'BingoPlus', ReasonId.gamblingPromo))
      ..keep(kept('promo two', 'BingoPlus', ReasonId.gamblingPromo))
      ..keep(kept('a short link', 'BingoPlus', ReasonId.linkShortener))
      ..keep(kept('another promo', 'OKBet', ReasonId.gamblingPromo));
    expect(store.promosFrom('BingoPlus'), 2);
    expect(store.promosFrom('OKBet'), 1);
    expect(store.promosFrom('GCash'), 0);
  });

  group('openFlaggedDatabase', () {
    test('moves a damaged file aside and starts a new one', () {
      final dir = Directory.systemTemp.createTempSync('hudyat-flagged');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/flagged.sqlite';
      // Long enough to look like a database, and not one.
      File(path).writeAsBytesSync(List.filled(8192, 0x41));

      final store = FlaggedStore(openFlaggedDatabase(path));
      addTearDown(store.close);
      expect(store.count, 0);
      // The damaged file is kept beside it, not deleted.
      expect(
        dir.listSync().where((f) => f.path.contains('.damaged-')),
        hasLength(1),
      );
    });

    test('opens a good file as it is', () {
      final dir = Directory.systemTemp.createTempSync('hudyat-flagged');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/flagged.sqlite';
      FlaggedStore(openFlaggedDatabase(path))
        ..keep(
          const CheckResult(
            text: 'bit.ly/x',
            verdict: Verdict.caution,
            reasons: [CheckReason(ReasonId.linkShortener)],
            phrasing: PhrasingState.skipped,
          ),
        )
        ..close();
      final again = FlaggedStore(openFlaggedDatabase(path));
      addTearDown(again.close);
      expect(again.count, 1);
      expect(
        dir.listSync().where((f) => f.path.contains('.damaged-')),
        isEmpty,
      );
    });
  });
}
