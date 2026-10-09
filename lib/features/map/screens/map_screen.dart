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

/// The offline map for one place: where it is, where the user is, and the
/// straight line between them.
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

  /// Null without a GPS fix: no "You" marker, line or distance.
  final LatLon? position;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? _map;
  bool _loaded = false;

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
  Widget build(BuildContext context) {
    final place = widget.place;
    final position = widget.position;
    // Centre between the two ends when there is a line to show.
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
                    onStyleLoadedCallback: () => setState(() => _loaded = true),
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

/// The selected place: name, address, phone, distance and the two actions.
class _PlaceSheet extends StatelessWidget {
  const _PlaceSheet({required this.place, required this.km});

  final PackRecord place;
  final double? km;

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
