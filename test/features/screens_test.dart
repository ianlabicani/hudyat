import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/app_scope.dart';
import 'package:hudyat/core/geo.dart';
import 'package:hudyat/core/models/model_manager.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/core/theme/tokens.dart';
import 'package:hudyat/core/widgets/panels.dart';
import 'package:hudyat/core/widgets/rows.dart';
import 'package:hudyat/features/card/screens/card_screen.dart';
import 'package:hudyat/features/card/services/resolver.dart';
import 'package:hudyat/features/card/widgets/lead_call.dart';
import 'package:hudyat/features/check/services/flagged_store.dart';
import 'package:hudyat/features/check/services/inbox_scanner.dart';
import 'package:hudyat/features/check/services/scan_index.dart';
import 'package:hudyat/features/check/services/message_checker.dart';
import 'package:hudyat/features/check/services/timed_check.dart';
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
  late TimedCheck timed;
  late InboxScanner scanner;
  late FakeSmsInbox inbox;
  late FakeTimedCheck phone;

  setUp(() {
    store = fixtureStore();
    gps = FakeLocationService();
    location = LocationController(gps, store);
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
        timed: timed,
        scanner: scanner,
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

  group('Borders', () {
    Color sideOf(WidgetTester tester, Finder row) =>
        (tester
                    .widget<Material>(
                      find.descendant(of: row, matching: find.byType(Material)),
                    )
                    .shape!
                as RoundedRectangleBorder)
            .side
            .color;

    testWidgets('ink means tappable; information is boxed in the rule colour', (
      tester,
    ) async {
      final place = store
          .hotlines(categories: ['medical'], city: 'Pasig')
          .first;
      await pump(
        tester,
        Scaffold(
          body: Column(
            children: [
              const Notice(title: 'A note'),
              PlaceRow(key: const Key('opens'), place: place, onTap: () {}),
              PlaceRow(key: const Key('plain'), place: place),
            ],
          ),
        ),
      );
      final note =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(Notice),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect((note.border! as Border).top.color, HudyatColors.rule);
      expect(sideOf(tester, find.byKey(const Key('opens'))), HudyatColors.ink);
      expect(sideOf(tester, find.byKey(const Key('plain'))), HudyatColors.rule);
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
      // The first number leads as one wide call button.
      expect(find.byType(LeadCall), findsOneWidget);
      expect(
        find.descendant(of: find.byType(LeadCall), matching: find.text('Call')),
        findsOneWidget,
      );
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

    testWidgets('without the model, every card keeps a button', (tester) async {
      await models.load();
      await pump(tester, const HomeScreen());
      // Typing only searches here, so these cards need their buttons.
      for (final label in ['Medical', 'Injury', 'Medicine', 'Clinic']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('while the model is still loading, the buttons do not jump', (
      tester,
    ) async {
      // Start-up, before the model has been looked for.
      await pump(tester, const HomeScreen());
      expect(find.text('Medical'), findsOneWidget);
      for (final label in ['Injury', 'Medicine', 'Clinic']) {
        expect(find.text(label), findsNothing);
      }
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

    testWidgets('shows only the one-tap buttons; the rest are typed', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());
      // The fixture pack has one of the four one-tap intents.
      expect(find.text('Medical'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.local_hospital_outlined)).color,
        HudyatColors.danger,
      );
      for (final label in ['Injury', 'Medicine', 'Clinic']) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('names what it understood once typing pauses', (tester) async {
      gps.fix = pasigPosition;
      await pump(tester, const HomeScreen());
      await tester.enterText(
        find.byType(TextField),
        'hindi siya makahinga, dalhin sa ospital',
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(rich('Understood'), findsNothing);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(rich('Understood: Medical emergency'), findsOneWidget);
      expect(find.textContaining('AI on this phone'), findsOneWidget);

      // "Find help" uses that answer instead of embedding the text again.
      final embedder = runtime.embedder! as FakeEmbedder;
      final calls = embedder.calls;
      await tester.tap(find.text('Find help'));
      await tester.pumpAndSettle();
      expect(find.text('Help card'), findsOneWidget);
      expect(embedder.calls, calls);
    });

    testWidgets('tapping what it understood opens the card', (tester) async {
      gps.fix = pasigPosition;
      await pump(tester, const HomeScreen());
      await tester.enterText(
        find.byType(TextField),
        'hindi siya makahinga, dalhin sa ospital',
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      await tester.tap(rich('Understood'));
      await tester.pumpAndSettle();
      expect(find.text('Help card'), findsOneWidget);
    });

    testWidgets('an answer for text since changed is dropped', (tester) async {
      await pump(tester, const HomeScreen());
      await tester.enterText(
        find.byType(TextField),
        'hindi siya makahinga, dalhin sa ospital',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'paano ang passport ko');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(rich('Understood'), findsNothing);
      expect(find.text('Will search the directory'), findsOneWidget);
    });

    testWidgets('a word or two is not matched while typing', (tester) async {
      await pump(tester, const HomeScreen());
      await tester.enterText(find.byType(TextField), 'ospital dito');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(rich('Understood'), findsNothing);
      expect(find.text('Will search the directory'), findsNothing);
    });
  });

  group('Home message guard', () {
    testWidgets('off: says what it does and opens Automatic checking', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());
      expect(find.text('Message guard'), findsOneWidget);
      expect(find.text('OFF'), findsOneWidget);
      expect(find.text('Mukhang scam'), findsNothing);
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(find.text('Check my texts for scams'), findsOneWidget);
    });

    testWidgets('on: the three counts and when texts were checked', (
      tester,
    ) async {
      phone
        ..found = const TimedStatus(
          hasAccess: true,
          scam: 3,
          caution: 1,
          gambling: 2,
          total: 124,
        )
        ..on = true
        ..runs = 1;
      await timed.refresh();
      await pump(tester, const HomeScreen());
      expect(find.text('ON'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      // Each count carries its verdict's colour.
      Color? colourOf(String text) =>
          tester.widget<Text>(find.text(text)).style?.color;
      expect(colourOf('3'), HudyatColors.danger);
      expect(colourOf('1'), HudyatColors.caution);
      expect(find.text('Mukhang scam'), findsOneWidget);
      expect(find.text('Mag-ingat'), findsOneWidget);
      expect(find.text('Sugal promo'), findsOneWidget);
      expect(
        find.text('Last 7 days · 124 texts checked · 20:40'),
        findsOneWidget,
      );
      await tester.tap(find.text('See flagged messages'));
      await tester.pumpAndSettle();
      expect(find.text('No flagged messages'), findsOneWidget);
    });

    testWidgets('on without SMS access: points to Automatic checking', (
      tester,
    ) async {
      phone
        ..found = const TimedStatus()
        ..on = true;
      await timed.refresh();
      await pump(tester, const HomeScreen());
      expect(find.text('Open automatic checking'), findsOneWidget);
      expect(find.text('Mukhang scam'), findsNothing);
      // Pasting a message needs no SMS access, so this stays.
      expect(find.text('Check a message'), findsOneWidget);
    });

    testWidgets('holds up with large text on a narrow screen', (tester) async {
      runtime.embedder = FakeEmbedder();
      await models.load();
      phone
        ..found = const TimedStatus(hasAccess: true, scam: 12, total: 618)
        ..on = true
        ..runs = 1;
      await timed.refresh();
      gps.fix = pasigPosition;
      await location.refresh();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, const HomeScreen());
      tester.view.physicalSize = const Size(320, 6000);
      await tester.pump();
      await tester.enterText(
        find.byType(TextField),
        'hindi siya makahinga, dalhin sa ospital',
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(rich('Understood'), findsOneWidget);
      // A count of zero is muted, so nothing found does not look alarming.
      final zeros = tester.widgetList<Text>(find.text('0'));
      expect(zeros, hasLength(2));
      expect(zeros.every((t) => t.style?.color == HudyatColors.muted), isTrue);

      // The card, with its lead call, at the same size.
      await tester.tap(find.text('Find help'));
      await tester.pumpAndSettle();
      expect(find.byType(LeadCall), findsOneWidget);
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
