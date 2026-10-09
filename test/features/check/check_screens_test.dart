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
import 'package:hudyat/features/check/screens/watcher_setup_screen.dart';
import 'package:hudyat/features/check/services/flagged_store.dart';
import 'package:hudyat/features/check/services/message_checker.dart';
import 'package:hudyat/features/check/services/message_watcher.dart';
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
  late MessageWatcher watcher;
  late FakeNotificationSource notifications;
  late FakeAlerter alerter;

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
    flagged = FlaggedStore(
      sqlite3.openInMemory(),
      senders: store.officialSenders(),
    );
    notifications = FakeNotificationSource();
    alerter = FakeAlerter();
    watcher = MessageWatcher(
      source: notifications,
      alerter: alerter,
      checker: checker,
      flagged: flagged,
      wording: store.scamReasons(),
    );
  });
  tearDown(() {
    watcher.dispose();
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
        watcher: watcher,
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

  group('MessageWatcher', () {
    IncomingNotification sms(String content, {String from = '09171234567'}) =>
        IncomingNotification(
          package: 'com.transsion.smartmessage',
          title: from,
          content: content,
        );

    test('is off until turned on, and asks for access', () async {
      await watcher.start((_) {});
      expect(watcher.isOn, isFalse);
      expect(await watcher.turnOn(), isTrue);
      expect(notifications.requests, 1);
      expect(watcher.isOn, isTrue);
      watcher.turnOff();
      expect(watcher.isOn, isFalse);
    });

    test('stays off when access is refused', () async {
      notifications.grantsOnRequest = false;
      expect(await watcher.turnOn(), isFalse);
      expect(watcher.isOn, isFalse);
    });

    test('alerts for Mukhang scam with the sender and first reason', () async {
      final result = await watcher.handle(sms(scamText));
      expect(result?.verdict, Verdict.scam);
      expect(result?.app, 'Messages');
      final alert = alerter.alerts.single;
      expect(alert.title, 'Mukhang scam ang mensahe mula kay 09171234567');
      expect(alert.body, 'Ginagaya ng link na gcash-verify.com ang GCash.');
      expect(flagged.byId(alert.id)?.result.sender, '09171234567');
    });

    test('keeps Mag-ingat quietly and discards the rest', () async {
      await watcher.handle(sms('GCash: Na-hold ang iyong wallet.'));
      await watcher.handle(sms('Ma, pauwi na ako.'));
      expect(alerter.alerts, isEmpty);
      expect(flagged.count, 1);
      expect(flagged.all().single.result.verdict, Verdict.caution);
    });

    test('ignores other apps, empty text and repeats', () async {
      expect(
        await watcher.handle(
          const IncomingNotification(
            package: 'com.facebook.katana',
            title: 'GCash',
            content: scamText,
          ),
        ),
        isNull,
      );
      expect(await watcher.handle(sms('  ')), isNull);
      expect(await watcher.handle(sms(scamText)), isNotNull);
      expect(await watcher.handle(sms(scamText)), isNull);
      expect(alerter.alerts, hasLength(1));
    });

    test('marks a message the notification cut short', () async {
      final result = await watcher.handle(sms('$scamText and then some...'));
      expect(result?.truncated, isTrue);
    });

    test('reads the stream once on', () async {
      await watcher.turnOn();
      notifications.controller.add(sms(scamText));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(alerter.alerts, hasLength(1));
    });
  });

  group('Watcher setup', () {
    testWidgets('explains, turns on, then offers Turn off', (tester) async {
      await pump(tester, const WatcherSetupScreen());
      expect(find.text('OFF'), findsOneWidget);
      expect(find.text('What Hudyat reads'), findsOneWidget);
      expect(find.text('What it keeps'), findsOneWidget);
      expect(find.text('What leaves the phone'), findsOneWidget);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(find.text('ON'), findsOneWidget);
      expect(
        find.textContaining('Turn off', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('says so when access was not granted', (tester) async {
      notifications.grantsOnRequest = false;
      await pump(tester, const WatcherSetupScreen());
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(
        find.text('Notification access was not turned on'),
        findsOneWidget,
      );
      expect(find.text('OFF'), findsOneWidget);
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
