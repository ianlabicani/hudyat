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
    super.key,
  });

  final TimedStatus status;
  final VoidCallback onOpenFlagged;

  /// Opens Automatic checking, to turn it on or to give SMS access.
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 12,
        children: [
          SectionHeading(
            title: 'Bantay sa text',
            gloss: 'Message guard',
            trailing: Tag(status.on ? 'On' : 'Off'),
          ),
          if (!status.on) ...[
            const Text(
              'Hudyat can check your texts for scams, on this phone. '
              'Nothing leaves it.',
              style: HudyatText.secondary,
            ),
            SecondaryButton(
              label: 'Turn on',
              gloss: 'I-on',
              onPressed: onOpenSettings,
            ),
          ] else if (!status.hasAccess) ...[
            const Text(
              'Hudyat cannot read your texts. Open automatic checking to '
              'allow access.',
              style: HudyatText.secondary,
            ),
            SecondaryButton(
              label: 'Open automatic checking',
              onPressed: onOpenSettings,
            ),
          ] else ...[
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _Count(status.scam, 'Mukhang scam'),
                _Count(status.caution, 'Mag-ingat'),
                _Count(status.gambling, 'Sugal promo'),
              ],
            ),
            Text(_checkedLine(status), style: HudyatText.data),
            SecondaryButton(
              label: 'See flagged messages',
              gloss: 'Tingnan',
              onPressed: onOpenFlagged,
            ),
          ],
        ],
      ),
    );
  }

  static String _checkedLine(TimedStatus status) {
    final at = status.checkedAt;
    if (at == null) return 'Last 7 days · not checked yet';
    final hour = at.hour.toString().padLeft(2, '0');
    final minute = at.minute.toString().padLeft(2, '0');
    final texts = status.total == 1 ? '1 text' : '${status.total} texts';
    return 'Last 7 days · $texts checked · $hour:$minute';
  }
}

class _Count extends StatelessWidget {
  const _Count(this.count, this.label);

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count $label',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Text('$count', style: HudyatText.title),
            Text(label, style: HudyatText.gloss),
          ],
        ),
      ),
    );
  }
}
