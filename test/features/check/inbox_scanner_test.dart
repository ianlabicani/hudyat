import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/app_scope.dart';
import 'package:hudyat/core/models/model_manager.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/core/theme/tokens.dart';
import 'package:hudyat/core/widgets/buttons.dart';
import 'package:hudyat/features/card/services/resolver.dart';
import 'package:hudyat/features/check/models/check_result.dart';
import 'package:hudyat/features/check/screens/scan_screen.dart';
import 'package:hudyat/features/check/services/flagged_store.dart';
import 'package:hudyat/features/check/services/inbox_scanner.dart';
import 'package:hudyat/features/check/services/message_checker.dart';
import 'package:hudyat/features/check/services/timed_check.dart';
import 'package:hudyat/features/check/services/scam_phrases.dart';
import 'package:hudyat/features/check/services/scan_index.dart';
import 'package:hudyat/features/check/services/sms_inbox.dart';
import 'package:hudyat/features/location/state/location_controller.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../support/fixture_pack.dart';

void main() {
  final now = DateTime(2026, 10, 9, 20);
  late PackStore store;
  late Database kept;
  late FlaggedStore flagged;
  late MessageChecker checker;
  late FakeSmsInbox inbox;
  ScamPhrases? phrases;

  const scamText = 'GCash: I-verify ang account mo sa https://gcash-verify.com';
  const hiddenLink = 'Customer service po! Visit csraftersales. com po';

  SmsMessage sms(int id, int daysAgo, String body, {String from = 'GCash'}) =>
      SmsMessage(
        id: id,
        sender: from,
        sentAt: now.subtract(Duration(days: daysAgo)),
        body: body,
      );

  InboxScanner scanner({String rules = 'r1'}) => InboxScanner(
    inbox: inbox,
    checker: checker,
    flagged: flagged,
    index: ScanIndex(kept),
    rules: rules,
    phrases: () => phrases,
    now: () => now,
  );

  setUp(() {
    store = fixtureStore();
    kept = sqlite3.openInMemory();
    flagged = FlaggedStore(kept, senders: store.officialSenders());
    phrases = null;
    checker = MessageChecker(
      senders: store.officialSenders(),
      shorteners: store.linkShorteners(),
      neutralHosts: store.neutralHosts(),
      phrases: () => phrases,
    );
    inbox = FakeSmsInbox()
      ..messages.addAll([
        sms(1, 80, 'Ma, pauwi na ako.', from: '09171234567'),
        sms(2, 20, scamText, from: '09171234567'),
        sms(3, 5, 'Tingnan mo to bit.ly/abc', from: '09181234567'),
        sms(4, 1, 'Your GCash OTP is 482913.'),
      ]);
  });
  tearDown(() {
    flagged.close();
    store.close();
  });

  group('InboxScanner', () {
    test('a range reads only the texts inside it', () async {
      final summary = (await scanner().scan(ScanRange.week))!;
      expect(summary.read, 2);
      expect(summary.caution, 1);
      expect(summary.clear, 1);
      expect(summary.scam, 0);
    });

    test('keeps flagged texts under the time they arrived', () async {
      final summary = (await scanner().scan(ScanRange.all))!;
      expect((summary.scam, summary.caution, summary.clear), (1, 1, 2));
      expect(flagged.count, 2);
      final scam = flagged.all().firstWhere(
        (m) => m.result.verdict == Verdict.scam,
      );
      expect(scam.checkedAt, now.subtract(const Duration(days: 20)));
      expect(scam.result.sender, '09171234567');
      expect(scam.result.app, 'Messages');
    });

    test('a second scan checks nothing and says they were skipped', () async {
      final s = scanner();
      await s.scan(ScanRange.all);
      final again = (await s.scan(ScanRange.all))!;
      expect(again.read, 4);
      expect(again.skipped, 4);
      expect(again.checked, 0);
      expect(flagged.count, 2);
    });

    test('a wider range after a narrow one checks only the rest', () async {
      final s = scanner();
      expect(await s.pending(ScanRange.all), 4);
      await s.scan(ScanRange.week);
      expect(await s.pending(ScanRange.all), 2);
      final wider = (await s.scan(ScanRange.all))!;
      expect(wider.skipped, 2);
      expect(wider.checked, 2);
      expect(wider.scam, 1);
    });

    test('new texts are picked up by the next scan', () async {
      final s = scanner();
      await s.scan(ScanRange.all);
      inbox.messages.add(sms(5, 0, hiddenLink, from: '09191234567'));
      final next = (await s.scan(ScanRange.all))!;
      expect(next.skipped, 4);
      expect(next.scam, 1);
    });

    test('changed rules check every text again', () async {
      await scanner().scan(ScanRange.all);
      final updated = scanner(rules: 'r2');
      expect(await updated.pending(ScanRange.all), 4);
      final summary = (await updated.scan(ScanRange.all))!;
      expect(summary.skipped, 0);
      expect(summary.checked, 4);
      // Kept once, not twice.
      expect(flagged.count, 2);
    });

    test('the index holds ids, times and verdicts, and no text', () async {
      await scanner().scan(ScanRange.all);
      final rows = kept.select('SELECT * FROM scanned ORDER BY sms_id');
      expect(rows.columnNames, [
        'sms_id',
        'sent_at',
        'verdict',
        'rules',
        'worded',
        'rule_verdict',
        'ai_version',
      ]);
      expect(
        [for (final row in rows) row['verdict']],
        ['clear', 'scam', 'caution', 'clear'],
      );
      final dump = rows.map((row) => row.values.join('|')).join('\n');
      expect(dump, isNot(contains('gcash')));
      expect(dump, isNot(contains('0917')));
    });

    test('forgetting the index keeps the flagged messages', () async {
      final s = scanner();
      await s.scan(ScanRange.all);
      s.forget();
      expect(s.remembered, 0);
      expect(flagged.count, 2);
      expect(await s.pending(ScanRange.all), 4);
    });
    test('catch-up flags recent texts quietly, and never asks', () async {
      final s = scanner();
      await s.catchUp();
      expect(flagged.count, 1);
      expect(s.last, isNull);
      expect(s.remembered, 2);

      inbox.granted = false;
      inbox.messages.add(sms(9, 0, hiddenLink, from: '09191234567'));
      await s.catchUp();
      expect(flagged.count, 1);
      expect(s.refused, isFalse);
    });

    test('refused SMS access scans nothing and says so', () async {
      inbox
        ..granted = false
        ..grantsOnRequest = false;
      final s = scanner();
      expect(await s.pending(ScanRange.all), isNull);
      expect(await s.scan(ScanRange.all), isNull);
      expect(s.refused, isTrue);
      expect(inbox.reads, 0);
      expect(s.running, isFalse);
    });

    test('access granted at the prompt lets the scan run', () async {
      inbox.granted = false;
      expect((await scanner().scan(ScanRange.all))?.read, 4);
    });

    test('stopping part-way remembers what was done', () async {
      inbox.messages.addAll([
        for (var i = 10; i < 70; i++) sms(i, 2, 'Text number $i'),
      ]);
      final s = scanner();
      void stopEarly() {
        if (s.done >= 25) s.stop();
      }

      s.addListener(stopEarly);
      final summary = (await s.scan(ScanRange.all))!;
      s.removeListener(stopEarly);
      expect(summary.stopped, isTrue);
      expect(summary.checked, lessThan(64));
      expect(s.remembered, summary.checked);
      final rest = (await s.scan(ScanRange.all))!;
      expect(rest.skipped, summary.checked);
      expect(rest.checked + rest.skipped, 64);
    });

    test('the rules pass leaves the wording check out', () async {
      phrases = ScamPhrases(
        embedder: FakeEmbedder(),
        examples: store.scamExamples(),
        threshold: 0.6,
      );
      await phrases!.prepare();
      inbox.messages.add(sms(6, 0, 'Na-lock ang wallet, i-verify na'));
      final s = scanner();
      final fast = (await s.scan(ScanRange.week))!;
      expect(fast.caution, 1);
      expect(fast.clear, 2);
      expect(fast.worded, 0);

      // The wording pass covers rules-clear and rules-caution texts, once.
      final slow = (await s.scan(ScanRange.week, wording: true))!;
      expect(slow.checked, 3);
      expect(slow.worded, 3);
      expect(slow.caution, 2);
      expect(flagged.count, 2);
      final again = (await s.scan(ScanRange.week, wording: true))!;
      expect(again.worded, 0);
    });
  });

  group('Scan screen', () {
    late LocationController location;
    late ModelManager models;
    late TimedCheck timed;
    late InboxScanner shown;

    setUp(() {
      location = LocationController(FakeLocationService(), store);
      models = ModelManager(runtime: FakeRuntime(), intents: store.intents());
      timed = TimedCheck(platform: FakeTimedCheck(), inbox: FakeSmsInbox());
      shown = scanner();
    });
    tearDown(() {
      shown.dispose();
      timed.dispose();
      models.dispose();
      location.dispose();
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppScope(
          store: store,
          resolver: Resolver(store),
          location: location,
          models: models,
          checker: checker,
          flagged: flagged,
          timed: timed,
          scanner: shown,
          child: MaterialApp(theme: hudyatTheme(), home: const ScanScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows what is pending, scans, and sums up', (tester) async {
      await pump(tester);
      expect(
        find.textContaining('remembers only that they were checked'),
        findsOneWidget,
      );
      expect(
        find.textContaining('3 not yet checked in this range'),
        findsOneWidget,
      );
      await tester.tap(find.text('All messages'));
      await tester.pumpAndSettle();
      expect(find.textContaining('4 not yet checked'), findsOneWidget);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(find.text('Scan finished'), findsOneWidget);
      expect(find.text('1 Mukhang scam'), findsOneWidget);
      expect(find.text('1 Mag-ingat'), findsOneWidget);
      expect(
        find.textContaining('Nothing new to check in this range'),
        findsOneWidget,
      );
      expect(find.textContaining('Already checked: 4'), findsOneWidget);

      await tester.tap(find.text('Flagged messages'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 messages kept · '), findsOneWidget);
    });

    testWidgets('a second scan says nothing was new', (tester) async {
      await shown.scan(ScanRange.all);
      await pump(tester);
      await tester.tap(find.text('All messages'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(find.text('Nothing new to check'), findsOneWidget);
      expect(find.textContaining('4 already checked, skipped'), findsOneWidget);
    });

    testWidgets('refused access explains and offers no count', (tester) async {
      inbox
        ..granted = false
        ..grantsOnRequest = false;
      await pump(tester);
      expect(find.textContaining('not yet checked'), findsNothing);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(find.text('SMS access was not given'), findsOneWidget);
    });

    testWidgets('the wording switch is off without the model', (tester) async {
      await pump(tester);
      expect(find.textContaining('Needs the language model'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
    });
  });
}
