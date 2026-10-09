import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/calls.dart';
import '../../../core/geo.dart';
import '../../../core/pack/pack_record.dart';
import '../../../core/pack/pack_store.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../map_style.dart';
import '../services/map_icons.dart';

/// The offline map for one place: a pin where it is, and a person with a
/// ripple where the user is.
class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.mapPath,
    required this.place,
    this.others = const [],
    this.position,
    super.key,
  });

  final String mapPath;
  final PackRecord place;

  /// The other places on the card, drawn as plain markers.
  final List<PackRecord> others;

  /// Null without a GPS fix: no "You" marker or distance.
  final LatLon? position;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? _map;
  bool _loaded = false;
  Timer? _ripple;
  bool _drawing = false;
  final _clock = Stopwatch();

  static const _rippleCycle = Duration(milliseconds: 1800);

  late final double? _km = PackStore.distanceTo(widget.place, widget.position);
  late final String _style = jsonEncode(
    buildMapStyle(
      mapPath: widget.mapPath,
      selected: widget.place,
      others: widget.others,
      user: widget.position,
    ),
  );

  @override
  void dispose() {
    _ripple?.cancel();
    super.dispose();
  }

  void _onStyleLoaded() {
    setState(() => _loaded = true);
    unawaited(_addIcons(MediaQuery.devicePixelRatioOf(context)));
    // Nothing to ripple without a position, and the marker alone is enough
    // when the phone asks for less motion.
    if (widget.position == null) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _clock.start();
    _ripple ??= Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _drawRipple(),
    );
  }

  /// Puts a pin on the place and a person on the user. If the map refuses
  /// either, the plain circle it would have replaced stays.
  Future<void> _addIcons(double pixelRatio) async {
    final map = _map;
    if (map == null) return;
    try {
      await map.addImage(
        'pin',
        await renderMapIcon(
          Icons.location_on,
          color: HudyatColors.call,
          size: 44,
          pixelRatio: pixelRatio,
        ),
      );
      await map.addSymbolLayer(
        'selected',
        'selected-pin',
        const SymbolLayerProperties(
          iconImage: 'pin',
          iconAnchor: 'bottom',
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ),
        enableInteraction: false,
      );
      await map.removeLayer(selectedLayer);
      if (widget.position == null) return;
      await map.addImage(
        'person',
        await renderMapIcon(
          Icons.person,
          color: HudyatColors.ink,
          size: 20,
          pixelRatio: pixelRatio,
        ),
      );
      await map.addSymbolLayer(
        'user',
        'user-person',
        const SymbolLayerProperties(
          iconImage: 'person',
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ),
        enableInteraction: false,
      );
      await map.removeLayer(userDotLayer);
    } on Exception {
      // The circles from the style still mark both points.
    }
  }

  Future<void> _drawRipple() async {
    final map = _map;
    if (map == null || _drawing) return;
    _drawing = true;
    final frame = rippleAt(
      (_clock.elapsedMilliseconds % _rippleCycle.inMilliseconds) /
          _rippleCycle.inMilliseconds,
    );
    try {
      // Unset properties go back to their defaults, so the colour is resent.
      await map.setLayerProperties(
        rippleLayer,
        CircleLayerProperties(
          circleRadius: frame.radius,
          circleOpacity: frame.opacity,
          circleColor: rippleColor,
        ),
      );
    } on Exception {
      // The map is being torn down or reloading; the marker still shows.
    } finally {
      _drawing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final position = widget.position;
    // Centre between the place and the user when both are known.
    final target = position == null
        ? LatLng(place.lat!, place.lon!)
        : LatLng(
            (place.lat! + position.lat) / 2,
            (place.lon! + position.lon) / 2,
          );
    return Scaffold(
      appBar: const TopBar(title: 'Map'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  MapLibreMap(
                    styleString: _style,
                    initialCameraPosition: CameraPosition(
                      target: target,
                      zoom: zoomForDistance(_km),
                    ),
                    onMapCreated: (controller) => _map = controller,
                    onStyleLoadedCallback: _onStyleLoaded,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    compassEnabled: false,
                  ),
                  if (!_loaded)
                    const ColoredBox(
                      color: HudyatColors.ground,
                      child: Center(
                        child: Column(
                          mainAxisSize: .min,
                          spacing: 12,
                          children: [
                            CircularProgressIndicator(),
                            Text('Loading the offline map…'),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Column(
                      spacing: 8,
                      children: [
                        _MapButton(
                          icon: Icons.add,
                          tooltip: 'Zoom in',
                          onPressed: () =>
                              _map?.animateCamera(CameraUpdate.zoomIn()),
                        ),
                        _MapButton(
                          icon: Icons.remove,
                          tooltip: 'Zoom out',
                          onPressed: () =>
                              _map?.animateCamera(CameraUpdate.zoomOut()),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    left: 8,
                    bottom: 8,
                    child: ColoredBox(
                      color: HudyatColors.surface,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          '© OpenStreetMap contributors',
                          style: HudyatText.data,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _PlaceSheet(place: place, km: _km),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: HudyatColors.surface,
        foregroundColor: HudyatColors.ink,
        minimumSize: const Size(48, 48),
        side: HudyatShape.primaryBorder,
        shape: const RoundedRectangleBorder(borderRadius: HudyatShape.radius),
      ),
    );
  }
}

/// The selected place: name, address, phone, distance and the actions.
class _PlaceSheet extends StatelessWidget {
  const _PlaceSheet({required this.place, required this.km});

  final PackRecord place;
  final double? km;

  Future<void> _openDirections(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await openDirections(place.lat!, place.lon!)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final km = this.km;
    final phone = place.phones.isEmpty ? null : place.phones.first.display;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: HudyatColors.surface,
        border: Border(top: HudyatShape.primaryBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 12,
          children: [
            Row(
              crossAxisAlignment: .start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: 2,
                    children: [
                      Text(place.name, style: HudyatText.section),
                      Text(
                        place.address ?? place.city ?? 'Address not listed',
                        style: HudyatText.data,
                      ),
                      Text(
                        phone ?? 'No phone number listed',
                        style: HudyatText.data,
                      ),
                    ],
                  ),
                ),
                if (km != null) ...[
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: .end,
                    children: [
                      Text(
                        formatDistance(km),
                        style: HudyatText.section.copyWith(fontSize: 24),
                      ),
                      const Text('straight line', style: HudyatText.gloss),
                    ],
                  ),
                ],
              ],
            ),
            Row(
              spacing: 10,
              children: [
                if (place.canCall)
                  Expanded(
                    child: CallButton(
                      onPressed: () => callRecord(context, place),
                    ),
                  ),
                Expanded(
                  child: SecondaryButton(
                    label: 'Back to list',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            SecondaryButton(
              label: 'Directions in Google Maps',
              gloss: 'needs internet',
              onPressed: () => _openDirections(context),
            ),
            Text(
              km == null
                  ? 'No GPS fix, so no distance is shown.'
                  : 'Distance is a straight line, not a road route.',
              style: HudyatText.gloss,
            ),
          ],
        ),
      ),
    );
  }
}
