import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/geo.dart';
import 'package:hudyat/core/pack/pack_store.dart';

import '../support/fixture_pack.dart';

void main() {
  late PackStore store;

  setUp(() => store = fixtureStore());
  tearDown(() => store.close());

  test('reads meta and knows what area the pack covers', () {
    expect(store.meta.name, 'Test pack');
    expect(store.meta.buildDate, '2026-10-09');
    expect(store.meta.covers(14.57, 121.07), isTrue);
    expect(store.meta.covers(10.31, 123.89), isFalse);
  });

  test('reads the gambling list, or none from an older pack', () {
    final rules = store.gamblingRules();
    expect(rules.brands.first.name, 'BingoPlus');
    expect(rules.brands.first.domains, ['bingoplus.com']);
    expect(rules.hostWords, contains('casino'));
    expect(rules.terms, contains('rebate'));

    final older = fixtureStore(gambling: false);
    addTearDown(older.close);
    expect(older.gamblingRules().brands, isEmpty);
    expect(older.gamblingRules().terms, isEmpty);
  });

  test('lists cities that have places, and their province', () {
    expect(store.cities(), ['Marikina', 'Pasig']);
    expect(store.provinceOf('Pasig'), 'Metro Manila');
    expect(store.provinceOf('Nowhere'), isNull);
  });

  group('hotlines', () {
    test('returns one level at a time', () {
      const cats = ['medical', 'disaster', 'emergency', 'transport'];
      expect(
        store.hotlines(categories: cats, city: 'Pasig').map((r) => r.name),
        [
          'Pasig City General Hospital',
          'Pasig City DRRMO Emergency Hotline',
          'Pasig Health Laboratory',
        ],
      );
      expect(
        store
            .hotlines(categories: cats, province: 'Metro Manila')
            .map((r) => r.name),
        ['Metro Manila Development Authority (MMDA)'],
      );
      expect(store.hotlines(categories: cats).map((r) => r.name), [
        'Red Cross',
        'National Emergency Hotline',
      ]);
    });

    test('filters by category and returns nothing for no categories', () {
      expect(
        store.hotlines(categories: ['disaster'], city: 'Pasig').single.name,
        'Pasig City DRRMO Emergency Hotline',
      );
      expect(store.hotlines(categories: [], city: 'Pasig'), isEmpty);
      expect(
        store.hotlines(categories: ['medical'], city: 'Marikina'),
        isEmpty,
      );
    });

    test('finds the national emergency number', () {
      final emergency = store.nationalEmergency()!;
      expect(emergency.name, 'National Emergency Hotline');
      expect(emergency.dialable.single.dial, '911');
    });

    test('keeps numbers that cannot be dialled, marked as such', () {
      final lab = store
          .hotlines(categories: ['medical'], city: 'Pasig')
          .firstWhere((r) => r.name.contains('Laboratory'));
      expect(lab.canCall, isFalse);
      expect(lab.phones.single.display, '6431234');
    });
  });

  group('places', () {
    test('filters by kind and city', () {
      expect(store.places(kinds: ['hospital']).length, 3);
      expect(
        store.places(kinds: ['hospital'], city: 'Pasig').map((r) => r.name),
        ['Pasig Hospital East', 'Pasig Hospital West'],
      );
      expect(store.places(kinds: ['shelter']), isEmpty);
    });

    test('picks the city most nearby places are in', () {
      expect(store.nearestCity(14.57, 121.07), 'Pasig');
      expect(store.nearestCity(14.66, 121.11), 'Marikina');
    });

    test('measures straight-line distance, or nothing without a position', () {
      final east = store.places(kinds: ['hospital'], city: 'Pasig').first;
      expect(PackStore.distanceTo(east, null), isNull);
      expect(
        PackStore.distanceTo(east, const LatLon(14.56, 121.08)),
        closeTo(0, 0.001),
      );
      expect(PackStore.distanceTo(east, pasigPosition), closeTo(1.55, 0.1));
    });
  });

  group('search', () {
    test('matches every word, by prefix and without accents', () {
      expect(store.search('passport appoint').single.kind, 'service');
      expect(store.search('paranaque').single.name, 'JUAN DELA CRUZ');
      expect(store.search('botik').single.name, 'Botika ng Marikina');
    });

    test('falls back to any word when no record has them all', () {
      expect(
        store.search('barangay clearance').single.name,
        'Renew NBI Clearance',
      );
    });

    test('can be limited to one kind', () {
      expect(store.search('pasig').length, greaterThan(3));
      expect(
        store
            .search('pasig', kind: 'hotline')
            .every((r) => r.kind == 'hotline'),
        isTrue,
      );
      expect(store.search('pasig', kind: 'service'), isEmpty);
    });

    test('returns nothing for empty, symbol-only or unknown queries', () {
      expect(store.search(''), isEmpty);
      expect(store.search('"" * ()'), isEmpty);
      expect(store.search('zzzzqq'), isEmpty);
    });
  });
}
