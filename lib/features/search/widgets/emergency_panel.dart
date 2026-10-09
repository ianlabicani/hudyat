import 'package:flutter/material.dart';

import '../../../core/calls.dart';
import '../../../core/pack/pack_record.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';

/// "If this is an emergency, call this number now", with the national
/// emergency number from the pack. Shown wherever the app could not help.
class EmergencyPanel extends StatelessWidget {
  const EmergencyPanel({required this.hotline, super.key});

  /// Null only if the pack has no national emergency number.
  final PackRecord? hotline;

  @override
  Widget build(BuildContext context) {
    final hotline = this.hotline;
    if (hotline == null) {
      return const Notice(
        title: 'No emergency number in this pack',
        body: 'Dial the emergency number you know.',
      );
    }
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 12,
        children: [
          const Text(
            'If this is an emergency, call this number now.',
            style: HudyatText.body,
          ),
          Column(
            crossAxisAlignment: .start,
            children: [
              Text(hotline.name, style: HudyatText.bodyBold),
              Text(
                hotline.dialable.first.display,
                style: HudyatText.data.copyWith(
                  fontSize: 22,
                  fontWeight: .w500,
                  color: HudyatColors.ink,
                ),
              ),
            ],
          ),
          CallButton(
            large: true,
            label: 'Call this number',
            gloss: 'Tawagan ang numerong ito',
            onPressed: () => callRecord(context, hotline),
          ),
        ],
      ),
    );
  }
}
