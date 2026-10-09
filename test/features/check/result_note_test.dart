import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/app_scope.dart';
import 'package:hudyat/core/models/model_manager.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/core/theme/tokens.dart';
import 'package:hudyat/features/card/services/resolver.dart';
import 'package:hudyat/features/check/models/check_result.dart';
import 'package:hudyat/features/check/screens/result_screen.dart';
import 'package:hudyat/features/check/services/flagged_store.dart';
import 'package:hudyat/features/check/services/inbox_scanner.dart';
import 'package:hudyat/features/check/services/message_checker.dart';
import 'package:hudyat/features/check/services/timed_check.dart';
import 'package:hudyat/features/check/services/result_explainer.dart';
import 'package:hudyat/features/check/services/scan_index.dart';
import 'package:hudyat/features/location/state/location_controller.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import '../../support/fixture_pack.dart';

void main() {
  late PackStore store;
  late LocationController location;
  late FakeRuntime runtime;
  late ModelManager models;
  late MessageChecker checker;
  late FlaggedStore flagged;
  late TimedCheck timed;
  late InboxScanner scanner;

  setUp(() {
    store = fixtureStore();
    location = LocationController(FakeLocationService(), store);
    runtime = FakeRuntime();
    models = ModelManager(runtime: runtime, intents: store.intents());
    checker = MessageChecker(
      senders: store.officialSenders(),
      shorteners: store.linkShorteners(),
      neutralHosts: store.neutralHosts(),
      gambling: store.gamblingRules(),
      phrases: () => models.scamPhrases,
    );
    final kept = sqlite3.openInMemory();
    flagged = FlaggedStore(kept, senders: store.officialSenders());
    scanner = InboxScanner(
      inbox: FakeSmsInbox(),
      checker: checker,
      flagged: flagged,
      index: ScanIndex(kept),
      rules: 'r1',
      phrases: () => models.scamPhrases,
    );
    timed = TimedCheck(platform: FakeTimedCheck(), inbox: FakeSmsInbox());
  });
  tearDown(() {
    timed.dispose();
    scanner.dispose();
    location.dispose();
    models.dispose();
    flagged.close();
    store.close();
  });

  const scamText = 'GCash: I-verify ang account mo sa https://gcash-verify.com';
  const label = 'AI-WRITTEN · MAY BE WRONG';

  Future<FakeGenerator> open(
    WidgetTester tester,
    CheckResult result,
    FakeGenerator generator,
  ) async {
    runtime.generator = generator;
    await models.load();
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
        child: MaterialApp(
          theme: hudyatTheme(),
          home: ResultScreen(result: result),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return generator;
  }

  group('resultFacts', () {
    test('holds the verdict and the filled reasons, and no numbers', () async {
      final result = await checker.check(
        'GCash: Na-hold ang iyong wallet',
        sender: '+639171234567',
      );
      final facts = resultFacts(result, store.scamReasons());
      expect(facts, contains('Mag-ingat'));
      expect(facts, contains('GCash'));
      expect(facts, isNot(contains('639171234567')));
      expect(facts, isNot(contains(RegExp(r'\d{3}'))));
    });
  });

  group('Result note', () {
    testWidgets('shows under a scam result, labelled as AI-written', (
      tester,
    ) async {
      final generator = await open(
        tester,
        await checker.check(scamText),
        FakeGenerator(const ['Hindi opisyal ', 'ang link na ito.']),
      );
      expect(find.text(label), findsOneWidget);
      expect(find.text('Hindi opisyal ang link na ito.'), findsOneWidget);
      // The model is never handed the contact's number.
      expect(generator.lastPrompt, isNot(contains('7213')));
      expect(generator.lastPrompt, contains('gcash-verify.com'));
    });

    testWidgets('shows under a Mag-ingat result', (tester) async {
      final result = await checker.check(
        'GCash: Na-hold ang iyong wallet',
        sender: '+639171234567',
      );
      final generator = await open(
        tester,
        result,
        FakeGenerator(const ['Galing ito sa ordinaryong numero.']),
      );
      expect(find.text('Mag-ingat'), findsOneWidget);
      expect(find.text(label), findsOneWidget);
      expect(generator.lastPrompt, isNot(contains('639171234567')));
    });

    testWidgets('never shows when no problem was found', (tester) async {
      final generator = await open(
        tester,
        await checker.check('Ma, pauwi na ako.'),
        FakeGenerator(const ['Mukhang ayos ito.']),
      );
      expect(find.text(label), findsNothing);
      expect(generator.lastPrompt, isNull);
      expect(find.text('Hindi ito garantiya'), findsOneWidget);
    });

    testWidgets('is dropped if the model writes a number of its own', (
      tester,
    ) async {
      await open(
        tester,
        await checker.check(scamText),
        FakeGenerator(const ['Tumawag sa ', '8123-4567 ngayon.']),
      );
      expect(find.text(label), findsNothing);
      expect(find.textContaining('8123'), findsNothing);
    });

    testWidgets('is dropped if the model writes a link of its own', (
      tester,
    ) async {
      await open(
        tester,
        await checker.check(scamText),
        FakeGenerator(const ['Pumunta sa gcash-help.net para ayusin.']),
      );
      expect(find.text(label), findsNothing);
    });

    testWidgets('is dropped if the model calls the message safe', (
      tester,
    ) async {
      await open(
        tester,
        await checker.check(scamText),
        FakeGenerator(const ['Mukhang ', 'ligtas naman ito.']),
      );
      expect(find.text(label), findsNothing);
      expect(find.textContaining('ligtas'), findsNothing);
    });

    testWidgets('a failing chat model leaves the result as it was', (
      tester,
    ) async {
      await open(
        tester,
        await checker.check(scamText),
        FakeGenerator(const [], failure: StateError('out of memory')),
      );
      expect(find.text(label), findsNothing);
      expect(find.text('Looks like a scam'), findsOneWidget);
      expect(find.text('The real contact'), findsOneWidget);
    });

    testWidgets('no chat model means no note', (tester) async {
      await models.load();
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
          child: MaterialApp(
            theme: hudyatTheme(),
            home: ResultScreen(result: await checker.check(scamText)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(label), findsNothing);
      expect(find.text('Looks like a scam'), findsOneWidget);
    });
  });
}
