import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/app_scope.dart';
import 'package:hudyat/core/models/model_manager.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/core/theme/tokens.dart';
import 'package:hudyat/core/widgets/buttons.dart';
import 'package:hudyat/features/card/services/resolver.dart';
import 'package:hudyat/features/check/models/check_result.dart';
import 'package:hudyat/features/check/screens/check_screen.dart';
import 'package:hudyat/features/check/screens/flagged_screen.dart';
import 'package:hudyat/features/check/screens/result_screen.dart';
import 'package:hudyat/features/check/screens/timed_check_screen.dart';
import 'package:hudyat/features/check/services/flagged_store.dart';
import 'package:hudyat/features/check/services/inbox_scanner.dart';
import 'package:hudyat/features/check/services/scan_index.dart';
import 'package:hudyat/features/check/services/message_checker.dart';
import 'package:hudyat/features/check/services/timed_check.dart';
import 'package:hudyat/features/home/screens/home_screen.dart';
import 'package:hudyat/features/location/state/location_controller.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import '../../support/fixture_pack.dart';

void main() {
  late PackStore store;
  late LocationController location;
  late ModelManager models;
  late MessageChecker checker;
  late FlaggedStore flagged;
  late TimedCheck timed;
  late InboxScanner scanner;
  late FakeSmsInbox inbox;
  late FakeTimedCheck phone;

  ModelManager manager(FakeRuntime runtime) => ModelManager(
    runtime: runtime,
    intents: store.intents(),
    scamExamples: store.scamExamples(),
  );

  setUp(() {
    store = fixtureStore();
    location = LocationController(FakeLocationService(), store);
    models = manager(FakeRuntime());
    checker = MessageChecker(
      senders: store.officialSenders(),
      shorteners: store.linkShorteners(),
      neutralHosts: store.neutralHosts(),
      gambling: store.gamblingRules(),
      phrases: () => models.scamPhrases,
    );
    final kept = sqlite3.openInMemory();
    flagged = FlaggedStore(kept, senders: store.officialSenders());
    inbox = FakeSmsInbox();
    scanner = InboxScanner(
      inbox: inbox,
      checker: checker,
      flagged: flagged,
      index: ScanIndex(kept),
      rules: 'r1',
      phrases: () => models.scamPhrases,
      now: () => DateTime(2026, 10, 9, 20),
    );
    phone = FakeTimedCheck();
    timed = TimedCheck(platform: phone, inbox: inbox);
  });
  tearDown(() {
    timed.dispose();
    scanner.dispose();
    location.dispose();
    models.dispose();
    flagged.close();
    store.close();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
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
        scanner: scanner,
        child: MaterialApp(theme: hudyatTheme(), home: home),
      ),
    );
  }

  const scamText = 'GCash: I-verify ang account mo sa https://gcash-verify.com';

  group('FlaggedStore', () {
    test('keeps flagged results and never a clear one', () async {
      flagged
        ..keep(await checker.check('Ma, pauwi na ako.'))
        ..keep(await checker.check(scamText, sender: '0917 123 4567'));
      expect(flagged.count, 1);
      final kept = flagged.all().single.result;
      expect(kept.verdict, Verdict.scam);
      expect(kept.sender, '0917 123 4567');
      expect(kept.reasons.first.facts['domain'], 'gcash-verify.com');
      // The contact comes from the pack again, not from the stored row.
      expect(kept.claimed?.dialable.first.dial, '0272139999');
    });

    test('keeps the same message once, newest first, and clears', () async {
      final scam = await checker.check(scamText);
      final caution = await checker.check('Tingnan mo bit.ly/abc');
      flagged
        ..keep(scam, at: DateTime(2026, 10, 9, 20))
        ..keep(caution, at: DateTime(2026, 10, 9, 21))
        ..keep(scam, at: DateTime(2026, 10, 9, 22));
      expect(flagged.count, 2);
      expect(flagged.all().first.result.verdict, Verdict.scam);
      flagged.clear();
      expect(flagged.count, 0);
    });
  });

  group('ModelManager', () {
    test('embeds the scam phrases after the intent phrases', () async {
      final embedder = FakeEmbedder();
      models = manager(FakeRuntime(embedder: embedder));
      final ready = <bool>[];
      models.addListener(() {
        if (models.scamProgress != null) {
          ready.add(models.embeddingState == ModelState.ready);
        }
      });
      await models.load();
      expect(ready, isNotEmpty);
      expect(ready, everyElement(isTrue));
      expect(models.scamPhrases?.isReady, isTrue);
      expect(models.scamProgress, isNull);
    });

    test('has no phrasing check without the embedding model', () async {
      await models.load();
      expect(models.scamPhrases, isNull);
    });
  });

  group('Home', () {
    testWidgets('has Look up and Check a message side by side', (tester) async {
      await pump(tester, const HomeScreen());
      expect(find.text('Look up'), findsOneWidget);
      await tester.tap(find.text('Check a message'));
      await tester.pumpAndSettle();
      expect(find.text('Is this message real?'), findsOneWidget);
    });
  });

  group('Check', () {
    testWidgets('Check is disabled until there is a message', (tester) async {
      await pump(tester, const CheckScreen());
      PrimaryButton button() => tester.widget(find.byType(PrimaryButton));
      expect(button().onPressed, isNull);
      expect(find.textContaining('not sent anywhere'), findsOneWidget);
      expect(find.textContaining('0 kept', findRichText: true), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, scamText);
      await tester.pump();
      expect(button().onPressed, isNotNull);
    });

    testWidgets('a scam message opens its result and is kept', (tester) async {
      await pump(tester, const CheckScreen());
      await tester.enterText(find.byType(TextField).first, scamText);
      await tester.enterText(find.byType(TextField).last, '09171234567');
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(find.text('Mukhang scam'), findsOneWidget);
      expect(find.textContaining('Huwag pindutin ang link'), findsOneWidget);
      expect(
        find.text('Ginagaya ng link na gcash-verify.com ang GCash.'),
        findsOneWidget,
      );
      expect(find.text('Opisyal: gcash.com'), findsOneWidget);
      expect(find.text('From 09171234567'), findsOneWidget);
      expect(flagged.count, 1);
    });

    testWidgets('shared text is filled in and checked at once', (tester) async {
      await pump(tester, const CheckScreen(initialText: scamText));
      await tester.pumpAndSettle();
      expect(find.text('Mukhang scam'), findsOneWidget);
    });

    testWidgets('something shared without text says so', (tester) async {
      await pump(tester, const CheckScreen(sharedWithoutText: true));
      expect(find.text('Nothing to check was shared'), findsOneWidget);
    });
  });

  group('Result', () {
    testWidgets('Mukhang scam shows the real contact with Call', (
      tester,
    ) async {
      await pump(tester, ResultScreen(result: await checker.check(scamText)));
      expect(find.text('Looks like a scam'), findsOneWidget);
      expect(find.text('The real contact'), findsOneWidget);
      expect(find.textContaining('(02) 7213-9999'), findsOneWidget);
      expect(find.byType(CallButton), findsOneWidget);
      expect(find.textContaining('Details may be out of date'), findsOneWidget);
      expect(find.text('Hindi ito garantiya'), findsNothing);
    });

    testWidgets('Mag-ingat from a notification may be cut short', (
      tester,
    ) async {
      final result = await checker.check(
        'GCash: Na-hold ang iyong wallet',
        sender: '+639171234567',
        app: 'Messages',
        truncated: true,
      );
      await pump(tester, ResultScreen(result: result));
      expect(find.text('Mag-ingat'), findsOneWidget);
      expect(find.text('From +639171234567 · via Messages'), findsOneWidget);
      expect(find.textContaining('may be cut short'), findsOneWidget);
      expect(find.text('Galing sa: +639171234567'), findsOneWidget);
    });

    testWidgets('a contact with no number has no Call button', (tester) async {
      final result = await checker.check(
        'BDO: Update your details at http://secure-bank.xyz',
      );
      await pump(tester, ResultScreen(result: result));
      expect(find.text('No number listed'), findsOneWidget);
      expect(find.byType(CallButton), findsNothing);
    });

    testWidgets('a gambling promo names its source and offers Messages', (
      tester,
    ) async {
      final result = await checker.check(
        'Get UP TO 1.5% Rebate! bingoplus.com/channels/slot',
        sender: 'BingoPlus',
      );
      await pump(tester, ResultScreen(result: result));
      expect(find.text('Mag-ingat'), findsOneWidget);
      expect(find.text('Promo ito ng online na sugal.'), findsOneWidget);
      expect(find.text('Mula sa: BingoPlus'), findsOneWidget);
      // The fake launcher refuses, as a phone with no SMS app would.
      final opened = <Object?>[];
      const launcher = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(launcher, (
        call,
      ) async {
        opened.add((call.arguments as Map)['url']);
        return false;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          launcher,
          null,
        ),
      );
      await tester.tap(find.text('Open in Messages'));
      await tester.pumpAndSettle();
      expect(opened, ['sms:BingoPlus']);
      expect(find.textContaining('Could not open Messages'), findsOneWidget);
    });

    testWidgets('no Messages button without a sender or a finding', (
      tester,
    ) async {
      await pump(
        tester,
        ResultScreen(result: await checker.check('Tingnan mo bit.ly/abc')),
      );
      expect(find.text('Open in Messages'), findsNothing);
      await pump(
        tester,
        ResultScreen(
          result: await checker.check('Ma, pauwi na ako.', sender: 'Mama'),
        ),
      );
      expect(find.text('Open in Messages'), findsNothing);
    });

    testWidgets('a clear result is never called safe', (tester) async {
      await pump(
        tester,
        ResultScreen(result: await checker.check('Ma, pauwi na ako.')),
      );
      expect(find.text('Walang nakitang problema'), findsOneWidget);
      expect(find.text('Hindi ito garantiya'), findsOneWidget);
      expect(find.text('What was checked'), findsOneWidget);
      expect(find.text('None found'), findsOneWidget);
      expect(find.text('Not given / Hindi ibinigay'), findsOneWidget);
      expect(find.text('Not ready yet'), findsOneWidget);
      expect(find.textContaining('no contact is shown'), findsOneWidget);
      expect(
        find.textContaining(RegExp('safe|legit', caseSensitive: false)),
        findsNothing,
      );
    });
  });

  group('TimedCheck', () {
    test('is off until turned on, and asks for SMS access first', () async {
      inbox.granted = false;
      await timed.refresh();
      expect(timed.status.on, isFalse);
      expect(await timed.turnOn(), isTrue);
      expect(inbox.granted, isTrue);
      expect(phone.notificationRequests, 1);
      expect(timed.status.on, isTrue);
      expect(timed.status.checkedAt, isNotNull);
      await timed.turnOff();
      expect(timed.status.on, isFalse);
    });

    test('stays off when SMS access is refused', () async {
      inbox
        ..granted = false
        ..grantsOnRequest = false;
      expect(await timed.turnOn(), isFalse);
      expect(phone.on, isFalse);
      expect(phone.notificationRequests, 0);
    });

    test('turns on without alerts when notifications are refused', () async {
      expect(await timed.turnOn(), isTrue);
      expect(timed.status.canNotify, isFalse);
    });

    test('says the interval in words', () {
      expect(const TimedStatus().intervalLabel, '12 hours');
      expect(const TimedStatus(intervalMinutes: 2).intervalLabel, '2 minutes');
      expect(const TimedStatus(intervalMinutes: 60).intervalLabel, 'hour');
    });

    test('reads the counts the phone reports', () {
      final status = TimedStatus.fromMap(const {
        'on': true,
        'state': 'checked',
        'scam': 3,
        'caution': 1,
        'gambling': 2,
        'total': 124,
        'checkedAt': 1791549600000,
        'canNotify': true,
        'intervalMinutes': 720,
      });
      expect(status.on, isTrue);
      expect(status.hasAccess, isTrue);
      expect((status.scam, status.caution, status.gambling), (3, 1, 2));
      expect(status.total, 124);
      expect(status.checkedAt, isNotNull);
      expect(
        TimedStatus.fromMap(const {'state': 'no_access'}).hasAccess,
        isFalse,
      );
    });
  });

  group('Automatic checking', () {
    testWidgets('explains, turns on, shows counts, offers Turn off', (
      tester,
    ) async {
      phone.found = const TimedStatus(
        hasAccess: true,
        scam: 3,
        caution: 1,
        gambling: 2,
        total: 124,
        canNotify: true,
      );
      await pump(tester, const TimedCheckScreen());
      await tester.pumpAndSettle();
      expect(find.text('OFF'), findsOneWidget);
      expect(find.text('What Hudyat reads'), findsOneWidget);
      expect(find.text('What it keeps'), findsOneWidget);
      expect(find.text('What leaves the phone'), findsOneWidget);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(find.text('ON'), findsOneWidget);
      expect(
        find.text('3 Mukhang scam · 1 Mag-ingat · 2 sugal promo'),
        findsOneWidget,
      );
      expect(find.textContaining('124 texts checked'), findsOneWidget);
      expect(find.text('Alerts are turned off for Hudyat'), findsNothing);
      expect(
        find.textContaining('Turn off', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('says so when SMS access was not given', (tester) async {
      inbox
        ..granted = false
        ..grantsOnRequest = false;
      await pump(tester, const TimedCheckScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(find.text('SMS access was not given'), findsOneWidget);
      expect(find.text('OFF'), findsOneWidget);
    });

    testWidgets('says so when alerts are turned off', (tester) async {
      await pump(tester, const TimedCheckScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(find.text('ON'), findsOneWidget);
      expect(find.text('Alerts are turned off for Hudyat'), findsOneWidget);
    });
  });

  group('Flagged', () {
    testWidgets('empty says so', (tester) async {
      await pump(tester, const FlaggedScreen());
      expect(find.text('No flagged messages'), findsOneWidget);
    });

    testWidgets('groups by verdict, opens a result, clears', (tester) async {
      flagged
        ..keep(await checker.check(scamText, sender: 'GCASH'))
        ..keep(await checker.check('Tingnan mo bit.ly/abc'));
      await pump(tester, const FlaggedScreen());
      expect(find.text('2 messages kept'), findsOneWidget);
      expect(find.text('SCAM'), findsOneWidget);
      expect(find.text('MAG-INGAT'), findsOneWidget);
      expect(find.text('Sender not given'), findsOneWidget);
      await tester.tap(find.text('GCASH'));
      await tester.pumpAndSettle();
      expect(find.text('Looks like a scam'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear all'));
      await tester.pump();
      expect(find.text('No flagged messages'), findsOneWidget);
    });

    testWidgets('one message can be removed from the list', (tester) async {
      flagged
        ..keep(await checker.check(scamText, sender: 'GCASH'))
        ..keep(await checker.check('Tingnan mo bit.ly/abc'));
      await pump(tester, const FlaggedScreen());
      await tester.tap(find.byTooltip('Remove from this list').first);
      await tester.pump();
      expect(find.text('1 message kept'), findsOneWidget);
      expect(find.text('GCASH'), findsNothing);
      expect(find.text('Sender not given'), findsOneWidget);
    });
  });
}
