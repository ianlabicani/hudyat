import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/features/card/models/help_card.dart';
import 'package:hudyat/features/card/services/explainer.dart';
import 'package:hudyat/features/card/services/resolver.dart';
import 'package:hudyat/features/location/state/location_controller.dart';

import '../../support/fixture_pack.dart';

void main() {
  late PackStore store;
  late HelpCard card;

  setUp(() {
    store = fixtureStore();
    card = Resolver(store).resolve(
      intent: store.intent('medical_emergency')!,
      city: 'Pasig',
      citySource: CitySource.gps,
      position: pasigPosition,
    );
  });
  tearDown(() => store.close());

  group('prompt', () {
    test('gives the model names and distances but no phone numbers', () {
      final facts = cardFacts(card);
      expect(facts, contains('need: Medical emergency'));
      expect(facts, contains('city: Pasig'));
      expect(facts, contains('call first: Pasig City DRRMO Emergency Hotline'));
      expect(facts, contains('nearest place: Pasig Hospital West'));
      for (final hotline in card.hotlines) {
        for (final phone in hotline.phones) {
          expect(facts, isNot(contains(phone.display)));
          expect(facts, isNot(contains(phone.dial)));
        }
      }
    });

    test(
      'forbids adding numbers, names and steps, and carries the message',
      () {
        final prompt = explainerPrompt(card: card, message: 'natumba si papa');
        expect(prompt, contains('Do not add phone numbers, names, places or'));
        expect(prompt, contains('MESSAGE: natumba si papa'));
        expect(prompt, contains(cardFacts(card)));
        expect(explainerPrompt(card: card), isNot(contains('MESSAGE:')));
        // The chat model writes better English than Taglish.
        expect(prompt, contains('plain English'));
        expect(prompt, isNot(contains('Taglish')));
      },
    );
  });

  group('hasInventedNumber', () {
    const facts = 'nearest place: Pasig Hospital West (850 m away)';

    test('flags a phone number or hotline code that is not in the facts', () {
      expect(hasInventedNumber('Tumawag sa 8123-4567.', facts), isTrue);
      expect(hasInventedNumber('Tumawag sa 0917 123 4567.', facts), isTrue);
      expect(hasInventedNumber('I-dial ang 911.', facts), isTrue);
    });

    test('allows numbers taken from the facts, and short counts', () {
      expect(hasInventedNumber('Mga 850 m lang ang layo.', facts), isFalse);
      expect(hasInventedNumber('May 2 ospital na malapit.', facts), isFalse);
      expect(hasInventedNumber('Walang numero dito.', facts), isFalse);
    });
  });

  group('Explainer', () {
    test('emits the note as it grows', () async {
      final generator = FakeGenerator(const ['Tawagan ', 'ang DRRMO.']);
      final notes = await Explainer(generator).explain(card: card).toList();
      expect(notes, ['Tawagan', 'Tawagan ang DRRMO.']);
      expect(generator.lastPrompt, contains('FACTS:'));
    });

    test('blanks the note as soon as an invented number appears', () async {
      final notes = await Explainer(
        FakeGenerator(const ['Tumawag sa ', '8123-4567', ' agad.']),
      ).explain(card: card).toList();
      expect(notes.last, '');
      expect(notes.any((note) => note.contains('8123')), isFalse);
    });

    test('ends quietly when the model throws', () async {
      final notes = await Explainer(
        FakeGenerator(const [], failure: StateError('boom')),
      ).explain(card: card).toList();
      expect(notes, isEmpty);
    });

    test('ends quietly when the model is too slow', () async {
      final notes = await Explainer(
        _StalledGenerator(),
        timeout: const Duration(milliseconds: 20),
      ).explain(card: card).toList();
      expect(notes, isEmpty);
    });
  });
}

class _StalledGenerator extends FakeGenerator {
  _StalledGenerator() : super(const []);

  @override
  Stream<String> generate(String prompt, {int maxOutputTokens = 80}) =>
      Stream.fromFuture(
        Future.delayed(const Duration(seconds: 5), () => 'too late'),
      );
}
