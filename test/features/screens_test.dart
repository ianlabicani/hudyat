import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/app_scope.dart';
import 'package:hudyat/core/geo.dart';
import 'package:hudyat/core/models/model_manager.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/core/theme/tokens.dart';
import 'package:hudyat/core/widgets/rows.dart';
import 'package:hudyat/features/card/screens/card_screen.dart';
import 'package:hudyat/features/card/services/resolver.dart';
import 'package:hudyat/features/check/services/flagged_store.dart';
import 'package:hudyat/features/check/services/message_checker.dart';
import 'package:hudyat/features/check/services/message_watcher.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:hudyat/features/home/screens/home_screen.dart';
import 'package:hudyat/features/location/state/location_controller.dart';
import 'package:hudyat/features/search/screens/search_screen.dart';

import '../support/fixture_pack.dart';

void main() {
  late PackStore store;
  late FakeLocationService gps;
  late LocationController location;
  late FakeRuntime runtime;
  late ModelManager models;
  late MessageChecker checker;
  late FlaggedStore flagged;
  late MessageWatcher watcher;
  late FakeNotificationSource notifications;
  late FakeAlerter alerter;

  setUp(() {
    store = fixtureStore();
    gps = FakeLocationService();
    location = LocationController(gps, store);
    runtime = FakeRuntime();
    models = ModelManager(runtime: runtime, intents: store.intents());
    checker = MessageChecker(
      senders: store.officialSenders(),
      shorteners: store.linkShorteners(),
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

  /// A narrow, tall phone so every row of a long card is built.
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

  Finder rich(String text) => find.textContaining(text, findRichText: true);

  group('HotlineRow', () {
    testWidgets('shows the name, the number and a Call button', (tester) async {
      final record = store
          .hotlines(categories: ['medical'], city: 'Pasig')
          .first;
      var calls = 0;
      await pump(
        tester,
        Scaffold(
          body: HotlineRow(record: record, onCall: () => calls++),
        ),
      );
      expect(find.text('Pasig City General Hospital'), findsOneWidget);
      expect(find.text('86427379 · +1 more'), findsOneWidget);
      await tester.tap(find.text('Call'));
      expect(calls, 1);
    });

    testWidgets('has no Call button when there is nothing to dial', (
      tester,
    ) async {
      final lab = store
          .hotlines(categories: ['medical'], city: 'Pasig')
          .firstWhere((r) => !r.canCall);
      await pump(tester, Scaffold(body: HotlineRow(record: lab, onCall: null)));
      expect(find.text('6431234'), findsOneWidget);
      expect(find.text('Call'), findsNothing);
    });
  });

  group('Card', () {
    testWidgets('with GPS: city numbers, level badge and distances', (
      tester,
    ) async {
      gps.fix = pasigPosition;
      await location.refresh();
      await pump(
        tester,
        CardScreen(intent: store.intent('medical_emergency')!),
      );

      expect(find.text('Medical emergency'), findsOneWidget);
      expect(rich('from GPS'), findsOneWidget);
      expect(find.text('CITY · PASIG'), findsOneWidget);
      expect(find.text('Pasig City DRRMO Emergency Hotline'), findsOneWidget);
      expect(find.text('Nearest hospitals'), findsOneWidget);
      expect(find.text('Straight-line distance'), findsOneWidget);
      expect(find.text('Pasig Hospital West'), findsOneWidget);
      // The national number is offered below the city ones, labelled as such.
      expect(find.text('NATIONAL'), findsOneWidget);
      expect(find.text('National Emergency Hotline'), findsOneWidget);
      expect(
        find.text('Pack built 2026-10-09. Numbers may be out of date.'),
        findsNWidgets(2),
      );
      expect(rich('© OpenStreetMap contributors'), findsOneWidget);
    });

    testWidgets('city chosen by hand: fallback notice and no distances', (
      tester,
    ) async {
      location.chooseCity('Marikina');
      await pump(
        tester,
        CardScreen(intent: store.intent('medical_emergency')!),
      );

      expect(rich('chosen manually'), findsOneWidget);
      expect(find.text('No hotline listed for Marikina'), findsOneWidget);
      expect(find.text('NATIONAL'), findsOneWidget);
      expect(find.text('Hospitals in Marikina'), findsOneWidget);
      expect(find.text('Distances hidden'), findsOneWidget);
      expect(find.text('Try GPS again'), findsOneWidget);
      expect(find.text('Marikina Valley Hospital'), findsOneWidget);
      expect(find.textContaining(' km'), findsNothing);
    });

    testWidgets('a GPS fix arriving later brings the distances back', (
      tester,
    ) async {
      location.chooseCity('Pasig');
      await pump(
        tester,
        CardScreen(intent: store.intent('medical_emergency')!),
      );
      expect(find.text('Distances hidden'), findsOneWidget);

      gps.fix = pasigPosition;
      await tester.tap(find.text('Try GPS again'));
      await tester.pumpAndSettle();
      expect(find.text('Straight-line distance'), findsOneWidget);
      expect(rich('from GPS'), findsOneWidget);
    });

    testWidgets('an intent with no hotline shows only places', (tester) async {
      location.chooseCity('Marikina');
      await pump(tester, CardScreen(intent: store.intent('need_medicine')!));
      expect(find.text('Call now'), findsNothing);
      expect(find.text('Botika ng Marikina'), findsOneWidget);
    });
  });

  group('Home', () {
    testWidgets('a quick button opens the card when GPS has a fix', (
      tester,
    ) async {
      gps.fix = pasigPosition;
      await pump(tester, const HomeScreen());
      expect(find.text('911'), findsOneWidget);
      await tester.tap(find.text('Medical'));
      await tester.pumpAndSettle();
      expect(find.text('Help card'), findsOneWidget);
      expect(find.text('CITY · PASIG'), findsOneWidget);
    });

    testWidgets('without GPS it asks for a city first', (tester) async {
      await pump(tester, const HomeScreen());
      await tester.tap(find.text('Medical'));
      await tester.pumpAndSettle();
      expect(rich('Where are you?'), findsOneWidget);
      expect(find.text('No GPS fix'), findsOneWidget);
      expect(find.text('Pick a city'), findsOneWidget);

      await tester.tap(find.text('Marikina'));
      await tester.pump();
      await tester.tap(find.text('Use Marikina'));
      await tester.pumpAndSettle();
      expect(find.text('Help card'), findsOneWidget);
      expect(rich('chosen manually'), findsOneWidget);
    });

    testWidgets('a GPS fix outside the pack area also asks for a city', (
      tester,
    ) async {
      gps.fix = const LatLon(10.31, 123.89); // Cebu
      await pump(tester, const HomeScreen());
      await tester.tap(find.text('Medical'));
      await tester.pumpAndSettle();
      expect(rich('Where are you?'), findsOneWidget);
    });

    testWidgets('typing goes to keyword search', (tester) async {
      await pump(tester, const HomeScreen());
      await tester.enterText(find.byType(TextField), 'passport');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.text('Search results'), findsOneWidget);
      expect(
        find.text('Schedule Passport Application Appointment'),
        findsOneWidget,
      );
    });
  });

  group('Search', () {
    testWidgets('rows show kind, scope and a Call button when dialable', (
      tester,
    ) async {
      await pump(tester, const SearchScreen(initialQuery: 'passport'));
      expect(find.text('SERVICE'), findsOneWidget);
      expect(find.text('NEEDS INTERNET'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
    });

    testWidgets('filters by kind', (tester) async {
      await pump(tester, const SearchScreen(initialQuery: 'pasig'));
      expect(find.text('Pasig Police'), findsOneWidget);
      await tester.tap(find.text('Hotlines'));
      await tester.pump();
      expect(find.text('Pasig Police'), findsNothing);
      expect(find.text('Pasig City General Hospital'), findsOneWidget);
    });

    testWidgets('empty state offers the emergency number', (tester) async {
      await pump(tester, const SearchScreen(initialQuery: 'zzzzqq'));
      expect(find.text('No results for "zzzzqq"'), findsOneWidget);
      expect(find.text('Call this number'), findsOneWidget);
      expect(find.text('Tap what you need instead'), findsOneWidget);
    });

    testWidgets('a message that was not an emergency says so', (tester) async {
      await pump(
        tester,
        const SearchScreen(initialQuery: 'passport', fromMessage: true),
      );
      expect(
        find.textContaining('did not look like an emergency'),
        findsOneWidget,
      );
      await tester.tap(find.text('It is an emergency. Show the hotline.'));
      await tester.pumpAndSettle();
      expect(
        find.text('We could not match this to a help card.'),
        findsOneWidget,
      );
      expect(find.text('911'), findsOneWidget);
    });
  });
  group('Home with the language model', () {
    setUp(() async {
      runtime.embedder = FakeEmbedder();
      await models.load();
    });

    testWidgets('a message that matches an intent opens its card', (
      tester,
    ) async {
      gps.fix = pasigPosition;
      await pump(tester, const HomeScreen());
      expect(find.text('Find help'), findsOneWidget);
      expect(find.textContaining('keyword search'), findsNothing);

      await tester.enterText(
        find.byType(TextField),
        'hindi siya makahinga, dalhin sa ospital',
      );
      await tester.tap(find.text('Find help'));
      await tester.pumpAndSettle();
      expect(find.text('Help card'), findsOneWidget);
      expect(find.text('Medical emergency'), findsOneWidget);
    });

    testWidgets('an everyday question goes to search, and says why', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());
      await tester.enterText(find.byType(TextField), 'paano ang passport');
      await tester.tap(find.text('Find help'));
      await tester.pumpAndSettle();
      expect(find.text('Search results'), findsOneWidget);
      expect(
        find.textContaining('did not look like an emergency'),
        findsOneWidget,
      );
    });

    testWidgets('a message close to nothing also goes to search', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());
      await tester.enterText(find.byType(TextField), 'kumusta ka');
      await tester.tap(find.text('Find help'));
      await tester.pumpAndSettle();
      expect(find.text('Search results'), findsOneWidget);
    });

    testWidgets('if the model fails mid-match, typing still reaches search', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());
      (runtime.embedder! as FakeEmbedder).failure = StateError('model died');
      await tester.enterText(find.byType(TextField), 'passport');
      await tester.tap(find.text('Find help'));
      await tester.pumpAndSettle();
      expect(find.text('Search results'), findsOneWidget);
    });
  });

  group('AI note', () {
    Future<void> openCard(WidgetTester tester, FakeGenerator generator) async {
      runtime.generator = generator;
      await models.load();
      gps.fix = pasigPosition;
      await location.refresh();
      await pump(
        tester,
        CardScreen(intent: store.intent('medical_emergency')!),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows under the card, labelled as AI-written', (tester) async {
      await openCard(
        tester,
        FakeGenerator(const ['Tawagan muna ang ', 'Pasig DRRMO.']),
      );
      expect(find.text('AI-WRITTEN · MAY BE WRONG'), findsOneWidget);
      expect(find.text('Tawagan muna ang Pasig DRRMO.'), findsOneWidget);
    });

    testWidgets('is dropped if the model writes a number of its own', (
      tester,
    ) async {
      await openCard(
        tester,
        FakeGenerator(const ['Tumawag sa ', '8123-4567 ngayon.']),
      );
      expect(find.text('AI-WRITTEN · MAY BE WRONG'), findsNothing);
      expect(find.textContaining('8123'), findsNothing);
      // The card itself is untouched.
      expect(find.text('Pasig City DRRMO Emergency Hotline'), findsOneWidget);
    });

    testWidgets('a failing chat model leaves the card as it was', (
      tester,
    ) async {
      await openCard(
        tester,
        FakeGenerator(const [], failure: StateError('out of memory')),
      );
      expect(find.text('AI-WRITTEN · MAY BE WRONG'), findsNothing);
      expect(find.text('CITY · PASIG'), findsOneWidget);
      expect(find.text('Pasig Hospital West'), findsOneWidget);
    });
  });

  group('Setup', () {
    testWidgets('lists the pack and both models, and never blocks', (
      tester,
    ) async {
      await models.load();
      await pump(tester, const HomeScreen());
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();
      expect(find.text('Test pack pack'), findsOneWidget);
      expect(find.text('NOT ON PHONE'), findsNWidgets(2));
      expect(find.textContaining('/phone/models'), findsOneWidget);
      // No download token in this build, so no Download button.
      expect(find.text('Download'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Or tap what you need'), findsOneWidget);
    });

    testWidgets('picks up models copied over after "Check again"', (
      tester,
    ) async {
      await models.load();
      await pump(tester, const HomeScreen());
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();

      runtime
        ..embedder = FakeEmbedder()
        ..generator = FakeGenerator(const ['ok']);
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();
      expect(find.text('NOT ON PHONE'), findsNothing);
      expect(find.text('Check again'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Ready offline'), findsOneWidget);
    });
  });
}
