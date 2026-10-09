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

  test('with a position: marks the user and draws a line to the place', () {
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
    final line = features(style, 'line').single as Map;
    expect((line['geometry'] as Map)['coordinates'], [
      [pasigPosition.lon, pasigPosition.lat],
      [selected.lon, selected.lat],
    ]);
  });

  test('without a position: no user marker and no line', () {
    final style = buildMapStyle(
      mapPath: '/m.pmtiles',
      selected: store.places(kinds: ['hospital']).first,
    );
    expect(features(style, 'user'), isEmpty);
    expect(features(style, 'line'), isEmpty);
  });

  test('zooms out as the place gets farther away', () {
    expect(zoomForDistance(null), 15);
    expect(zoomForDistance(0.2), 16);
    expect(zoomForDistance(1.2), 14);
    expect(zoomForDistance(5), 12);
    expect(zoomForDistance(30), 10);
  });
}
