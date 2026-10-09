import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/app_scope.dart';
import 'package:hudyat/core/models/last_query_embedder.dart';
import 'package:hudyat/core/models/model_manager.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/core/theme/tokens.dart';
import 'package:hudyat/features/card/screens/card_screen.dart';
import 'package:hudyat/features/card/services/resolver.dart';
import 'package:hudyat/features/card/widgets/first_aid_section.dart';
import 'package:hudyat/features/check/services/flagged_store.dart';
import 'package:hudyat/features/check/services/inbox_scanner.dart';
import 'package:hudyat/features/check/services/message_checker.dart';
import 'package:hudyat/features/check/services/message_watcher.dart';
import 'package:hudyat/features/check/services/scan_index.dart';
import 'package:hudyat/features/home/screens/home_screen.dart';
import 'package:hudyat/features/intent/services/first_aid_matcher.dart';
import 'package:hudyat/features/location/state/location_controller.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import '../../support/fixture_pack.dart';

void main() {
  late PackStore store;
  late FakeLocationService gps;
  late LocationController location;
  late FakeRuntime runtime;
  late ModelManager models;
  late MessageChecker checker;
  late FlaggedStore flagged;
  late MessageWatcher watcher;
  late InboxScanner scanner;

  setUp(() {
    store = fixtureStore();
    gps = FakeLocationService(pasigPosition);
    location = LocationController(gps, store);
    runtime = FakeRuntime(embedder: FakeEmbedder());
    models = ModelManager(
      runtime: runtime,
      intents: store.intents(),
      firstAidCards: store.firstAidCards(),
    );
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
    watcher = MessageWatcher(
      source: FakeNotificationSource(),
      alerter: FakeAlerter(),
      checker: checker,
      flagged: flagged,
      wording: store.scamReasons(),
    );
  });
  tearDown(() {
    watcher.dispose();
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
        watcher: watcher,
        scanner: scanner,
        child: MaterialApp(theme: hudyatTheme(), home: home),
      ),
    );
  }

  Future<void> findHelp(WidgetTester tester, String message) async {
    await pump(tester, const HomeScreen());
    await tester.enterText(find.byType(TextField), message);
    await tester.tap(find.text('Find help'));
    await tester.pumpAndSettle();
  }

  const tag = 'FIRST AID · FIXED CARD';

  group('PackStore', () {
    test('reads the cards with their steps and source', () {
      final cards = store.firstAidCards();
      expect(cards.map((card) => card.id), ['bleeding', 'burn']);
      expect(cards.first.title, 'Severe bleeding');
      expect(cards.first.titleTl, 'Malakas na pagdurugo');
      expect(cards.first.steps, hasLength(2));
      expect(cards.first.sourceUrl, 'https://example.org/bleeding');
    });

    test('has none in a pack built before the cards existed', () {
      final old = fixtureStore(firstAid: false);
      addTearDown(old.close);
      expect(old.firstAidCards(), isEmpty);
    });
  });

  group('FirstAidMatcher', () {
    FirstAidMatcher matcher(FakeEmbedder embedder, {double threshold = 0.56}) =>
        FirstAidMatcher(
          embedder: embedder,
          cards: store.firstAidCards(),
          threshold: threshold,
        );

    test('picks the card whose example is closest', () async {
      final m = matcher(FakeEmbedder());
      await m.prepare();
      expect((await m.match('ang daming dugo sa sugat'))?.id, 'bleeding');
      expect((await m.match('napaso ang kamay ko'))?.id, 'burn');
    });

    test('is null when nothing is close enough', () async {
      final m = matcher(FakeEmbedder());
      await m.prepare();
      expect(await m.match('sobrang trapik sa EDSA'), isNull);
      // One shared word out of two is 0.707: under a stricter bar, no card.
      final strict = matcher(FakeEmbedder(), threshold: 0.8);
      await strict.prepare();
      expect(await strict.match('may dugo'), isNull);
      expect((await strict.nearest('may dugo'))?.$1.id, 'bleeding');
    });

    test('is null until its examples are embedded', () async {
      final m = matcher(FakeEmbedder());
      expect(m.isReady, isFalse);
      expect(await m.match('ang daming dugo sa sugat'), isNull);
    });

    test('shares one embedding of the message with the intent match', () async {
      final embedder = FakeEmbedder();
      final shared = LastQueryEmbedder(embedder);
      await shared.embed(['ang daming dugo'], asQuery: true);
      await shared.embed(['ang daming dugo'], asQuery: true);
      expect(embedder.embedded, 1);
      await shared.embed(['napaso ako'], asQuery: true);
      await shared.embed(['ang daming dugo'], asQuery: true);
      expect(embedder.embedded, 3);
      // Example phrases are never served from the memo.
      await shared.embed(['ang daming dugo'], asQuery: false);
      expect(embedder.embedded, 4);
    });
  });

  group('ModelManager', () {
    test('prepares the first-aid match once the embedder is there', () async {
      expect(models.firstAid, isNull);
      await models.load();
      expect(models.firstAid?.isReady, isTrue);
    });

    test('has no first-aid match without the embedding model', () async {
      runtime.embedder = null;
      await models.load();
      expect(models.firstAid, isNull);
    });
  });

  group('Resolver', () {
    test('carries a matched first-aid card onto the help card', () {
      final resolver = Resolver(store);
      final firstAid = store.firstAidCards().first;
      final card = resolver.resolve(
        intent: store.intent('injury')!,
        city: 'Pasig',
        citySource: CitySource.gps,
        firstAid: firstAid,
      );
      expect(card.firstAid, same(firstAid));
      expect(
        resolver
            .resolve(
              intent: store.intent('injury')!,
              city: 'Pasig',
              citySource: CitySource.gps,
            )
            .firstAid,
        isNull,
      );
    });
  });

  group('Card with first aid', () {
    testWidgets('a message about bleeding shows the steps and their source', (
      tester,
    ) async {
      await models.load();
      await findHelp(tester, 'malalim ang sugat, ang daming dugo');
      expect(find.text('Help card'), findsOneWidget);
      expect(find.text('Injury'), findsOneWidget);
      expect(find.text(tag), findsOneWidget);
      expect(find.text('Severe bleeding'), findsOneWidget);
      expect(find.text('Malakas na pagdurugo'), findsOneWidget);
      expect(find.text('Diinan nang mariin ang sugat.'), findsOneWidget);
      expect(find.text('Tumawag sa hotline sa itaas.'), findsOneWidget);
      expect(
        find.text('Source: Test Red Cross · https://example.org/bleeding'),
        findsOneWidget,
      );
      // The hotlines and places are still there, around it.
      expect(find.text('Pasig City DRRMO Emergency Hotline'), findsOneWidget);
      expect(find.text('Pasig Hospital West'), findsOneWidget);
    });

    testWidgets('never shows an AI note beside the fixed steps', (
      tester,
    ) async {
      final generator = FakeGenerator(const ['Tawagan ang Pasig DRRMO.']);
      runtime.generator = generator;
      await models.load();
      await findHelp(tester, 'malalim ang sugat, ang daming dugo');
      expect(find.text(tag), findsOneWidget);
      expect(find.text('AI-WRITTEN · MAY BE WRONG'), findsNothing);
      expect(generator.lastPrompt, isNull);
    });

    testWidgets('a message that matches no card shows the card without it', (
      tester,
    ) async {
      runtime.generator = FakeGenerator(const ['Tawagan ang Pasig DRRMO.']);
      await models.load();
      await findHelp(tester, 'hindi siya makahinga, dalhin sa ospital');
      expect(find.text('Medical emergency'), findsOneWidget);
      expect(find.text(tag), findsNothing);
      expect(find.text('AI-WRITTEN · MAY BE WRONG'), findsOneWidget);
    });

    testWidgets('a quick button, with no message, shows no first aid', (
      tester,
    ) async {
      await models.load();
      await location.refresh();
      await pump(tester, CardScreen(intent: store.intent('injury')!));
      await tester.pumpAndSettle();
      expect(find.text('Injury'), findsOneWidget);
      expect(find.text(tag), findsNothing);
    });

    testWidgets('a pack with no cards leaves the card as it was', (
      tester,
    ) async {
      models.dispose();
      models = ModelManager(runtime: runtime, intents: store.intents());
      await models.load();
      expect(models.firstAid, isNull);
      await findHelp(tester, 'malalim ang sugat, ang daming dugo');
      expect(find.text('Injury'), findsOneWidget);
      expect(find.text(tag), findsNothing);
      expect(find.text('Pasig City DRRMO Emergency Hotline'), findsOneWidget);
    });

    testWidgets('the whole card holds up with large text on a narrow screen', (
      tester,
    ) async {
      await models.load();
      await location.refresh();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 8000);
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
          scanner: scanner,
          child: MaterialApp(
            theme: hudyatTheme(),
            home: CardScreen(
              intent: store.intent('injury')!,
              firstAid: store.firstAidCards().first,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Change city'), findsOneWidget);
      expect(find.text(tag), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the section holds up with large text on a narrow screen', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: hudyatTheme(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(HudyatShape.gutter),
              children: [FirstAidSection(card: store.firstAidCards().first)],
            ),
          ),
        ),
      );
      expect(find.text(tag), findsOneWidget);
      expect(find.text('Tumawag sa hotline sa itaas.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
