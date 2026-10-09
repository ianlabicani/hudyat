import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// What the language model on the phone made of the message so far, shown
/// under the box while the user is still typing. Tapping it opens the same
/// place "Find help" would.
class UnderstoodStrip extends StatelessWidget {
  const UnderstoodStrip({
    required this.elapsed,
    required this.onPressed,
    this.intentLabel,
    this.icon,
    this.firstAidTitle,
    super.key,
  });

  /// The matched intent's label from the pack, or null when the message
  /// will go to keyword search.
  final String? intentLabel;
  final IconData? icon;

  /// The matched first-aid card's title, when there is one.
  final String? firstAidTitle;

  /// How long the match took on this phone. Measured, never a fixed figure.
  final Duration elapsed;

  final VoidCallback onPressed;

  static String _seconds(Duration elapsed) {
    final tenths = (elapsed.inMilliseconds / 100).round();
    return tenths == 0 ? 'under 0.1 s' : '${tenths ~/ 10}.${tenths % 10} s';
  }

  @override
  Widget build(BuildContext context) {
    final intentLabel = this.intentLabel;
    final firstAidTitle = this.firstAidTitle;
    return Material(
      color: HudyatColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: HudyatShape.radius,
        side: HudyatShape.secondaryBorder,
      ),
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon ?? Icons.search, size: 26, color: HudyatColors.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: 2,
                    children: [
                      if (intentLabel != null)
                        Text.rich(
                          TextSpan(
                            text: 'Naintindihan: ',
                            style: HudyatText.body,
                            children: [
                              TextSpan(
                                text: intentLabel,
                                style: HudyatText.bodyBold,
                              ),
                            ],
                          ),
                        )
                      else
                        const Text(
                          'Hahanapin sa listahan',
                          style: HudyatText.bodyBold,
                        ),
                      if (firstAidTitle != null)
                        Text(
                          '+ First aid: $firstAidTitle',
                          style: HudyatText.secondary,
                        ),
                      Text(
                        intentLabel != null
                            ? 'AI on this phone · ${_seconds(elapsed)}'
                            : 'Not an emergency card · will search the '
                                  'directory',
                        style: HudyatText.data,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: HudyatColors.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
