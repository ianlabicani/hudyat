import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/features/card/services/resolver.dart';
import 'package:hudyat/features/location/state/location_controller.dart';

import '../../support/fixture_pack.dart';

void main() {
  late PackStore store;
  late Resolver resolver;

  setUp(() {
    store = fixtureStore();
    resolver = Resolver(store);
  });
  tearDown(() => store.close());

  group('hotline level', () {
    test('uses city numbers when the city has them', () {
      final card = resolver.resolve(
        intent: store.intent('medical_emergency')!,
        city: 'Pasig',
        citySource: CitySource.gps,
        position: pasigPosition,
      );
      expect(card.hotlineLevel, HotlineLevel.city);
      expect(card.hotlineLevelName, 'Pasig');
      expect(card.isFallback, isFalse);
      // The office that answers emergencies goes first; the laboratory with
      // no dialable number is left out.
      expect(card.hotlines.map((r) => r.name), [
        'Pasig City DRRMO Emergency Hotline',
        'Pasig City General Hospital',
      ]);
      expect(card.nationalEmergency?.name, 'National Emergency Hotline');
    });

    test('falls back to the province when the city has none', () {
      final card = resolver.resolve(
        intent: store.intent('traffic')!,
        city: 'Marikina',
        citySource: CitySource.manual,
      );
      expect(card.hotlineLevel, HotlineLevel.province);
      expect(card.hotlineLevelName, 'Metro Manila');
      expect(card.isFallback, isTrue);
      expect(card.hotlines.single.name, contains('MMDA'));
    });

    test('falls back to national when city and province have none', () {
      final card = resolver.resolve(
        intent: store.intent('medical_emergency')!,
        city: 'Marikina',
        citySource: CitySource.manual,
      );
      expect(card.hotlineLevel, HotlineLevel.national);
      expect(card.hotlineLevelName, isNull);
      expect(card.isFallback, isTrue);
      expect(card.hotlines.map((r) => r.name), [
        'National Emergency Hotline',
        'Red Cross',
      ]);
      // Already national, so no separate national row.
      expect(card.nationalEmergency, isNull);
    });

    test('an intent with no hotline categories has no hotlines', () {
      final card = resolver.resolve(
        intent: store.intent('need_medicine')!,
        city: 'Marikina',
        citySource: CitySource.manual,
      );
      expect(card.hotlines, isEmpty);
      expect(card.isFallback, isFalse);
    });
  });

  group('places', () {
    test('with a position: nearest first, across cities, with distances', () {
      final card = resolver.resolve(
        intent: store.intent('medical_emergency')!,
        city: 'Pasig',
        citySource: CitySource.gps,
        position: pasigPosition,
      );
      expect(card.places.map((hit) => hit.place.name), [
        'Pasig Hospital West',
        'Pasig Hospital East',
        'Marikina Valley Hospital',
      ]);
      expect(card.hasDistances, isTrue);
      expect(card.places.first.distanceKm, lessThan(1));
      expect(card.places.last.distanceKm, greaterThan(8));
    });

    test('without a position: the city list, no distances', () {
      final card = resolver.resolve(
        intent: store.intent('medical_emergency')!,
        city: 'Pasig',
        citySource: CitySource.manual,
      );
      expect(card.places.map((hit) => hit.place.name), [
        'Pasig Hospital East',
        'Pasig Hospital West',
      ]);
      expect(card.hasDistances, isFalse);
      expect(card.places.every((hit) => hit.distanceKm == null), isTrue);
    });

    test('a city with none of that kind gives an empty list', () {
      final card = resolver.resolve(
        intent: store.intent('need_medicine')!,
        city: 'Pasig',
        citySource: CitySource.manual,
      );
      expect(card.places, isEmpty);
    });
  });

  test('carries the pack build date onto the card', () {
    final card = resolver.resolve(
      intent: store.intent('traffic')!,
      city: 'Pasig',
      citySource: CitySource.manual,
    );
    expect(card.buildDate, '2026-10-09');
  });
}
