import 'package:flutter/material.dart';

import '../geo.dart';
import '../pack/pack_record.dart';
import '../theme/tokens.dart';
import 'buttons.dart';
import 'panels.dart';

/// A hotline with its number and a Call button. [onCall] is null when the
/// record has no number the dialer accepts; the number is still shown.
class HotlineRow extends StatelessWidget {
  const HotlineRow({required this.record, required this.onCall, super.key});

  final PackRecord record;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final numbers = record.phones;
    final shown = record.dialable.isNotEmpty ? record.dialable.first : null;
    final first =
        shown?.display ?? (numbers.isEmpty ? null : numbers.first.display);
    final more = numbers.length - 1;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                mainAxisAlignment: .center,
                spacing: 2,
                children: [
                  Text(record.name, style: HudyatText.bodyBold),
                  Text(
                    [
                      first ?? 'No number listed',
                      if (more > 0) '+$more more',
                    ].join(' · '),
                    style: HudyatText.data,
                  ),
                ],
              ),
            ),
            if (onCall != null) ...[
              const SizedBox(width: 12),
              CallButton(onPressed: onCall),
            ],
          ],
        ),
      ),
    );
  }
}

/// A nearby place. [onTap] opens the map; without it the row is plain text
/// and has no chevron (map file missing).
class PlaceRow extends StatelessWidget {
  const PlaceRow({required this.place, this.distanceKm, this.onTap, super.key});

  final PackRecord place;
  final double? distanceKm;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final distance = distanceKm;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                mainAxisAlignment: .center,
                spacing: 2,
                children: [
                  Text(place.name, style: HudyatText.bodyBold),
                  Text(
                    place.address ?? place.city ?? 'Address not listed',
                    style: HudyatText.data,
                  ),
                ],
              ),
            ),
            if (distance != null) ...[
              const SizedBox(width: 12),
              Text(
                formatDistance(distance),
                style: HudyatText.data.copyWith(
                  fontSize: 14,
                  fontWeight: .w500,
                  color: HudyatColors.ink,
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: HudyatColors.ink),
            ],
          ],
        ),
      ),
    );
    return Material(
      color: HudyatColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: HudyatShape.radius,
        side: HudyatShape.secondaryBorder,
      ),
      clipBehavior: .antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
