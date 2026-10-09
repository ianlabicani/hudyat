import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:hudyat/features/check/models/check_result.dart';
import 'package:hudyat/features/check/services/flagged_store.dart';
import 'package:hudyat/features/check/services/inbox_scanner.dart';
import 'package:hudyat/features/check/services/message_checker.dart';
import 'package:hudyat/features/check/services/scan_index.dart';
import 'package:hudyat/features/check/services/sms_inbox.dart';
import 'package:hudyat/features/check/services/suspicious_classifier.dart';

import '../../support/fixture_pack.dart';

class ControlledClassifier implements SuspiciousClassifier {
  @override
  String version = 'v1';
  final calls = <String>[];
  Completer<void>? hold;
  bool fail = false;
  @override
  Future<List<SuspiciousLabel>> classify(String text) async {
    calls.add(text);
    await hold?.future;
    if (fail) throw StateError('inference unavailable');
    return [SuspiciousLabel.credentials, SuspiciousLabel.pressure];
  }
}

void main() {
  final now = DateTime(2026, 10, 9, 22);
  late Database db;
  late FlaggedStore flagged;
  late ScanIndex index;
  late FakeSmsInbox inbox;
  late InboxScanner scanner;
  ControlledClassifier? classifier;
  setUp(() {
    db = sqlite3.openInMemory();
    flagged = FlaggedStore(db);
    index = ScanIndex(db);
    classifier = null;
    inbox = FakeSmsInbox()
      ..messages.addAll([
        SmsMessage(
          id: 1,
          sender: 'person',
          sentAt: now,
          body: 'send your code',
        ),
        SmsMessage(id: 2, sender: 'person', sentAt: now, body: 'bit.ly/pay'),
        SmsMessage(
          id: 3,
          sender: 'person',
          sentAt: now,
          body: 'Customer service po! Visit csraftersales. com po',
        ),
      ]);
    scanner = InboxScanner(
      inbox: inbox,
      checker: MessageChecker(
        senders: [],
        shorteners: ['bit.ly'],
        classifier: () => classifier,
      ),
      flagged: flagged,
      index: index,
      rules: 'rules',
      now: () => now,
    );
  });
  tearDown(() {
    scanner.dispose();
    flagged.close();
  });
  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 10));
  test(
    'rules finish before ready AI starts; caution escalates, hard scam skipped',
    () async {
      await scanner.catchUp();
      expect(index.checked('rules'), {1, 2, 3});
      expect(classifier, isNull);
      classifier = ControlledClassifier()..hold = Completer<void>();
      final work = scanner.resumeWording();
      await tick();
      expect(scanner.wordingPass, isTrue);
      expect(classifier!.calls, hasLength(1));
      classifier!.hold!.complete();
      await work;
      scanner.stop();
      expect(classifier!.calls, hasLength(2));
      expect(
        db
            .select('SELECT rule_verdict,verdict FROM scanned WHERE sms_id=2')
            .single
            .values,
        ['caution', 'scam'],
      );
      expect(index.awaitingWording('rules', aiVersion: 'v1'), isEmpty);
      expect(
        flagged.all().where((r) => r.result.phrasing == PhrasingState.checked),
        hasLength(2),
      );
    },
  );
  test(
    'background stops after current message, next foreground resumes',
    () async {
      await scanner.catchUp();
      classifier = ControlledClassifier()..hold = Completer<void>();
      final work = scanner.resumeWording();
      await tick();
      scanner.setForeground(false);
      classifier!.hold!.complete();
      await work;
      expect(classifier!.calls, hasLength(1));
      expect(index.awaitingWording('rules', aiVersion: 'v1'), hasLength(1));
      scanner.setForeground(true);
      await scanner.resumeWording();
      scanner.stop();
      expect(classifier!.calls, hasLength(2));
      expect(index.awaitingWording('rules', aiVersion: 'v1'), isEmpty);
    },
  );
  test(
    'failed inference remains pending and readiness event retries it',
    () async {
      await scanner.catchUp();
      classifier = ControlledClassifier()..fail = true;
      await scanner.resumeWording();
      expect(index.awaitingWording('rules', aiVersion: 'v1'), hasLength(2));
      classifier!.fail = false;
      await scanner.resumeWording();
      scanner.stop();
      expect(index.awaitingWording('rules', aiVersion: 'v1'), isEmpty);
    },
  );
  test(
    'new artifact invalidates only AI; resumed summaries count once',
    () async {
      classifier = ControlledClassifier();
      final first = (await scanner.scan(ScanRange.week, wording: true))!;
      expect(first.checked, 3);
      expect(first.worded, 2);
      classifier!.version = 'v2';
      expect(index.checked('rules'), {1, 2, 3});
      expect(index.awaitingWording('rules', aiVersion: 'v2'), {1, 2});
      final again = (await scanner.scan(ScanRange.week, wording: true))!;
      expect(again.checked, 2);
      expect(again.worded, 2);
      expect(again.skipped, 1);
      expect((await scanner.scan(ScanRange.week, wording: true))!.checked, 0);
    },
  );
  test('30-second pass boundary allows current inference to finish', () async {
    await scanner.catchUp();
    classifier = ControlledClassifier()..hold = Completer<void>();
    final work = scanner.resumeWording(budget: const Duration(milliseconds: 1));
    await tick();
    classifier!.hold!.complete();
    await work;
    scanner.stop();
    expect(classifier!.calls, hasLength(1));
    expect(index.awaitingWording('rules', aiVersion: 'v1'), hasLength(1));
  });
  test(
    'Stop cancels automatic continuation until next foreground entry',
    () async {
      await scanner.catchUp();
      classifier = ControlledClassifier()..hold = Completer<void>();
      final work = scanner.resumeWording();
      await tick();
      scanner.stop();
      classifier!.hold!.complete();
      await work;
      await scanner.resumeWording();
      expect(classifier!.calls, hasLength(1));
      scanner.setForeground(true);
      await scanner.resumeWording();
      scanner.stop();
      expect(classifier!.calls, hasLength(2));
    },
  );
  test('readiness changes during an active pass schedule catch-up for the new version', () async {
    await scanner.catchUp();
    classifier = ControlledClassifier()..hold = Completer<void>();
    final work = scanner.resumeWording();
    await tick();
    classifier!.version = 'v2';
    await scanner.resumeWording(); // busy: remember the request
    classifier!.hold!.complete();
    await work;
    final watch = Stopwatch()..start();
    while (index.awaitingWording('rules', aiVersion: 'v2').isNotEmpty &&
        watch.elapsedMilliseconds < 1000) {
      await tick();
    }
    scanner.stop();
    expect(index.awaitingWording('rules', aiVersion: 'v2'), isEmpty);
    expect(classifier!.calls, hasLength(3));
    expect(await scanner.pending(ScanRange.week), 0);
  });

  test('legacy scan index migrates without discarding rules completion', () {
    final old = sqlite3.openInMemory();
    old.execute(
      'CREATE TABLE scanned (sms_id INTEGER PRIMARY KEY,sent_at INTEGER,verdict TEXT,rules TEXT,worded INTEGER)',
    );
    old.execute("INSERT INTO scanned VALUES (9,0,'caution','old',1)");
    final migrated = ScanIndex(old);
    expect(migrated.checked('old'), {9});
    expect(migrated.awaitingWording('old', aiVersion: 'new'), {9});
    ScanIndex(old);
    expect(migrated.count, 1);
    old.close();
  });
}
