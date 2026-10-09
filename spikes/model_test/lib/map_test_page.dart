import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_provider/path_provider.dart';

/// Loads the bundled Metro Manila PMTiles file with no network. Labels are
/// left out on purpose: they need glyph files, which the spike does not ship.
class MapTestPage extends StatefulWidget {
  const MapTestPage({super.key});

  @override
  State<MapTestPage> createState() => _MapTestPageState();
}

class _MapTestPageState extends State<MapTestPage> {
  String? _style;
  String _status = 'Tap "Load map"';
  final _watch = Stopwatch();

  Future<void> _load() async {
    _watch
      ..reset()
      ..start();
    setState(() => _status = 'Copying map file…');
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/metro-manila.pmtiles');
    if (!file.existsSync()) {
      final data = await rootBundle.load('assets/metro-manila.pmtiles');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    final copyMs = _watch.elapsedMilliseconds;
    setState(() {
      _status =
          'Copied ${(file.lengthSync() / 1e6).round()} MB in $copyMs ms. '
          'Loading style…';
      _style = jsonEncode(_buildStyle(file.path));
    });
  }

  Map<String, dynamic> _buildStyle(String path) {
    Map<String, dynamic> fill(String id, String layer, String color) => {
      'id': id,
      'type': 'fill',
      'source': 'basemap',
      'source-layer': layer,
      'paint': {'fill-color': color},
    };
    return {
      'version': 8,
      'sources': {
        'basemap': {'type': 'vector', 'url': 'pmtiles://file://$path'},
      },
      'layers': [
        {
          'id': 'background',
          'type': 'background',
          'paint': {'background-color': '#E4E2DA'},
        },
        fill('earth', 'earth', '#F2F1EC'),
        fill('landuse', 'landuse', '#E6E9DF'),
        fill('water', 'water', '#B9CFDA'),
        {...fill('buildings', 'buildings', '#D9D6CC'), 'minzoom': 14},
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
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              FilledButton(onPressed: _load, child: const Text('Load map')),
              const SizedBox(width: 12),
              Expanded(child: Text(_status)),
            ],
          ),
        ),
        Expanded(
          child: style == null
              ? const Center(child: Text('Map not loaded'))
              : MapLibreMap(
                  styleString: style,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(14.5995, 121.0437),
                    zoom: 11,
                  ),
                  onStyleLoadedCallback: () => setState(
                    () => _status =
                        'RESULT map: style loaded '
                        '${_watch.elapsedMilliseconds} ms after tap. '
                        'Pan and zoom in airplane mode.',
                  ),
                ),
        ),
      ],
    );
  }
}
