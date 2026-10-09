import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../../check/services/timed_check.dart';

/// What automatic checking found in the last 7 days, on Home. The same
/// counts as the home screen widget: numbers only, never a message or a
/// sender.
class GuardPanel extends StatelessWidget {
  const GuardPanel({
    required this.status,
    required this.onOpenFlagged,
    required this.onOpenSettings,
    required this.onCheckMessage,
    this.appsOn = false,
    super.key,
  });

  final TimedStatus status;
  final bool appsOn;
  final VoidCallback onOpenFlagged;

  /// Opens Automatic checking, to turn it on or to give SMS access.
  final VoidCallback onOpenSettings;

  /// Opens the manual check. Offered in every state: pasting or sharing a
  /// message needs no SMS access.
  final VoidCallback onCheckMessage;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 12,
        children: [
          SectionHeading(
            title: 'Message guard',
            trailing: Tag(status.on || appsOn ? 'On' : 'Off'),
          ),
          if (!status.on && !appsOn) ...[
            const Text(
              'Hudyat can check your texts for scams, on this phone. '
              'Nothing leaves it.',
              style: HudyatText.secondary,
            ),
            SecondaryButton(label: 'Turn on', onPressed: onOpenSettings),
          ] else if (status.on && !status.hasAccess) ...[
            const Text(
              'Hudyat cannot read your texts. Open automatic checking to '
              'allow access.',
              style: HudyatText.secondary,
            ),
            SecondaryButton(
              label: 'Open automatic checking',
              onPressed: onOpenSettings,
            ),
          ] else if (status.on) ...[
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _Count(status.scam, 'Mukhang scam', HudyatColors.danger),
                _Count(status.caution, 'Mag-ingat', HudyatColors.caution),
                _Count(status.gambling, 'Sugal promo', HudyatColors.ink),
              ],
            ),
            Text(_checkedLine(context, status), style: HudyatText.data),
            SecondaryButton(
              label: 'Flagged messages',
              onPressed: onOpenFlagged,
            ),
          ] else ...[
            const Text(
              'Messaging app previews are being checked. The widget counts '
              'only SMS from the last 7 days.',
              style: HudyatText.secondary,
            ),
            SecondaryButton(
              label: 'Flagged messages',
              onPressed: onOpenFlagged,
            ),
          ],
          SecondaryButton(label: 'Check a message', onPressed: onCheckMessage),
        ],
      ),
    );
  }

  /// The time follows the phone's 12 or 24-hour setting, as the widget does.
  static String _checkedLine(BuildContext context, TimedStatus status) {
    final at = status.checkedAt;
    if (at == null) return 'Last 7 days · not checked yet';
    final time = TimeOfDay.fromDateTime(at).format(context);
    final texts = status.total == 1 ? '1 text' : '${status.total} texts';
    return 'Last 7 days · $texts checked · $time';
  }
}

class _Count extends StatelessWidget {
  const _Count(this.count, this.label, this.color);

  final int count;
  final String label;

  /// The verdict's colour. A zero is muted, so nothing found looks calm.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count $label',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Text(
              '$count',
              style: HudyatText.title.copyWith(
                color: count == 0 ? HudyatColors.muted : color,
              ),
            ),
            Text(label, style: HudyatText.gloss),
          ],
        ),
      ),
    );
  }
}
