import 'package:flutter/material.dart';

import '../../../core/pack/pack_record.dart';
import '../../../core/theme/tokens.dart';
import '../../card/card_labels.dart';

/// The grid of "tap what you need" buttons. Two columns, falling to one when
/// the text is large enough that two would be cramped.
class QuickButtons extends StatelessWidget {
  const QuickButtons({
    required this.intents,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final List<IntentDef> intents;
  final ValueChanged<IntentDef> onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 320 || scale > 1.3 ? 1 : 2;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final intent in intents)
              SizedBox(
                width: width,
                child: OutlinedButton.icon(
                  onPressed: enabled ? () => onTap(intent) : null,
                  icon: Icon(
                    CardLabels.icon(intent.id),
                    size: 28,
                    // Null when disabled, so it greys with the label.
                    color: enabled ? CardLabels.iconColor(intent.id) : null,
                  ),
                  label: Text(CardLabels.quickLabel(intent.id, intent.label)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: HudyatColors.surface,
                    foregroundColor: HudyatColors.ink,
                    side: HudyatShape.primaryBorder,
                    minimumSize: const Size.fromHeight(64),
                    alignment: .centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: HudyatShape.radius,
                    ),
                    textStyle: HudyatText.button,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
