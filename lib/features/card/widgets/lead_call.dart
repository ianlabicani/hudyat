import 'package:flutter/material.dart';

import '../../../core/pack/pack_record.dart';
import '../../../core/theme/tokens.dart';

/// The first hotline on a card as one full-width call button: the name and
/// the number, both from the pack. Only for a record with a dialable number.
class LeadCall extends StatelessWidget {
  const LeadCall({required this.record, required this.onCall, super.key});

  final PackRecord record;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final more = record.phones.length - 1;
    const onAccent = HudyatColors.surface;
    return FilledButton(
      onPressed: onCall,
      style: FilledButton.styleFrom(
        backgroundColor: HudyatColors.call,
        foregroundColor: onAccent,
        minimumSize: const Size.fromHeight(72),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: const RoundedRectangleBorder(borderRadius: HudyatShape.radius),
      ),
      child: Row(
        children: [
          const Icon(Icons.call, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: 2,
              children: [
                const Text(
                  'Tawagan · Call',
                  style: TextStyle(fontSize: 14, color: onAccent),
                ),
                Text(
                  record.name,
                  style: HudyatText.bodyBold.copyWith(
                    fontSize: 18,
                    color: onAccent,
                  ),
                ),
                Text(
                  [
                    record.dialable.first.display,
                    if (more > 0) '+$more more',
                  ].join(' · '),
                  style: HudyatText.data.copyWith(
                    fontSize: 16,
                    fontWeight: .w500,
                    color: onAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
