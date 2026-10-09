import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/features/map/map_style.dart';

import '../../support/fixture_pack.dart';

void main() {
  late PackStore store;

  setUp(() => store = fixtureStore());
  tearDown(() => store.close());

  Map<String, dynamic> source(Map<String, dynamic> style, String id) =>
      (style['sources'] as Map)[id] as Map<String, dynamic>;
  List<dynamic> features(Map<String, dynamic> style, String id) =>
      (source(style, id)['data'] as Map)['features'] as List;

  test('reads the basemap from the bundled file, with no network sources', () {
    final hospitals = store.places(kinds: ['hospital']);
    final style = buildMapStyle(
      mapPath: '/data/app/metro-manila.pmtiles',
      selected: hospitals.first,
    );
    expect(
      source(style, 'basemap')['url'],
      'pmtiles://file:///data/app/metro-manila.pmtiles',
    );
    expect(style.toString(), isNot(contains('http')));
    // Labels would need glyph files fetched from a server.
    expect(style.containsKey('glyphs'), isFalse);
    expect(
      (style['layers'] as List).any(
        (layer) => (layer as Map)['type'] == 'symbol',
      ),
      isFalse,
    );
  });

  test('with a position: marks the user, with no line to the place', () {
    final hospitals = store.places(kinds: ['hospital']);
    final selected = hospitals.first;
    final style = buildMapStyle(
      mapPath: '/m.pmtiles',
      selected: selected,
      others: hospitals,
      user: pasigPosition,
    );
    expect(features(style, 'selected'), hasLength(1));
    // The selected place is not drawn twice.
    expect(features(style, 'others'), hasLength(hospitals.length - 1));
    expect(features(style, 'user'), hasLength(1));
    expect((style['sources'] as Map).containsKey('line'), isFalse);
    expect(
      (style['layers'] as List).any(
        (layer) =>
            (layer as Map)['type'] == 'line' && layer['source'] != 'basemap',
      ),
      isFalse,
    );
  });

  test('without a position: no user marker', () {
    final style = buildMapStyle(
      mapPath: '/m.pmtiles',
      selected: store.places(kinds: ['hospital']).first,
    );
    expect(features(style, 'user'), isEmpty);
  });

  test('the ripple sits under the selected marker and starts hidden', () {
    final style = buildMapStyle(
      mapPath: '/m.pmtiles',
      selected: store.places(kinds: ['hospital']).first,
    );
    final ids = [
      for (final layer in style['layers'] as List) (layer as Map)['id'],
    ];
    expect(ids.indexOf(rippleLayer), lessThan(ids.indexOf('selected')));
    final ripple = (style['layers'] as List).firstWhere(
      (layer) => (layer as Map)['id'] == rippleLayer,
    ) as Map;
    expect(ripple['source'], 'selected');
    expect((ripple['paint'] as Map)['circle-opacity'], 0);
  });

  test('the ripple grows and fades through a cycle', () {
    final start = rippleAt(0);
    final middle = rippleAt(0.5);
    final end = rippleAt(1);
    expect(start.radius, lessThan(middle.radius));
    expect(middle.radius, lessThan(end.radius));
    expect(start.opacity, greaterThan(middle.opacity));
    expect(end.opacity, 0);
    expect(rippleAt(2), end);
  });

  test('zooms out as the place gets farther away', () {
    expect(zoomForDistance(null), 15);
    expect(zoomForDistance(0.2), 16);
    expect(zoomForDistance(1.2), 14);
    expect(zoomForDistance(5), 12);
    expect(zoomForDistance(30), 10);
  });
}
