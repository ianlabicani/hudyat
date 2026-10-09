import '../../core/geo.dart';
import '../../core/pack/pack_record.dart';

/// Builds the MapLibre style for the Map screen: the offline basemap plus the
/// places, the user's position and a straight line between the two. Markers
/// are circle layers, so the style needs no icon or font files.
///
/// Street labels are left out: they need glyph files the app does not ship.
Map<String, dynamic> buildMapStyle({
  required String mapPath,
  required PackRecord selected,
  List<PackRecord> others = const [],
  LatLon? user,
}) {
  Map<String, dynamic> point(double lat, double lon) => {
    'type': 'Feature',
    'geometry': {
      'type': 'Point',
      'coordinates': [lon, lat],
    },
  };
  Map<String, dynamic> collection(List<Map<String, dynamic>> features) => {
    'type': 'geojson',
    'data': {'type': 'FeatureCollection', 'features': features},
  };
  Map<String, dynamic> fill(String id, String color, {int? minzoom}) => {
    'id': id,
    'type': 'fill',
    'source': 'basemap',
    'source-layer': id,
    'paint': {'fill-color': color},
    'minzoom': ?minzoom,
  };
  Map<String, dynamic> circle(
    String id,
    String source, {
    required double radius,
    required String color,
    required double stroke,
  }) => {
    'id': id,
    'type': 'circle',
    'source': source,
    'paint': {
      'circle-radius': radius,
      'circle-color': color,
      'circle-stroke-color': '#1B1B19',
      'circle-stroke-width': stroke,
    },
  };

  final selectedLat = selected.lat!;
  final selectedLon = selected.lon!;
  return {
    'version': 8,
    'sources': {
      'basemap': {'type': 'vector', 'url': 'pmtiles://file://$mapPath'},
      'others': collection([
        for (final place in others)
          if (place.id != selected.id && place.lat != null && place.lon != null)
            point(place.lat!, place.lon!),
      ]),
      'selected': collection([point(selectedLat, selectedLon)]),
      'user': collection([if (user != null) point(user.lat, user.lon)]),
      'line': collection([
        if (user != null)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [user.lon, user.lat],
                [selectedLon, selectedLat],
              ],
            },
          },
      ]),
    },
    'layers': [
      {
        'id': 'background',
        'type': 'background',
        'paint': {'background-color': '#E4E2DA'},
      },
      fill('earth', '#F2F1EC'),
      fill('landuse', '#E6E9DF'),
      fill('water', '#B9CFDA'),
      fill('buildings', '#D9D6CC', minzoom: 14),
      {
        'id': 'roads',
        'type': 'line',
        'source': 'basemap',
        'source-layer': 'roads',
        'paint': {
          'line-color': '#FFFFFF',
          'line-width': [
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            0.5,
            16,
            4,
          ],
        },
      },
      {
        'id': 'line',
        'type': 'line',
        'source': 'line',
        'paint': {
          'line-color': '#1B1B19',
          'line-width': 3,
          'line-dasharray': [2, 2],
        },
      },
      circle('others', 'others', radius: 7, color: '#FFFFFF', stroke: 2),
      circle('selected', 'selected', radius: 11, color: '#B93A0B', stroke: 3),
      circle('user', 'user', radius: 9, color: '#FFFFFF', stroke: 3),
      circle('user-dot', 'user', radius: 3, color: '#1B1B19', stroke: 0),
    ],
  };
}

/// A zoom level that keeps both ends of a [km]-long line on a phone screen.
double zoomForDistance(double? km) {
  if (km == null) return 15;
  const levels = [
    (0.3, 16.0),
    (0.7, 15.0),
    (1.5, 14.0),
    (3.0, 13.0),
    (6.0, 12.0),
  ];
  for (final (limit, zoom) in levels) {
    if (km <= limit) return zoom;
  }
  return km <= 12 ? 11 : 10;
}
