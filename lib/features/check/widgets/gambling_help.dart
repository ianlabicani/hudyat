import 'package:flutter/material.dart';

import '../../../core/pack/pack_record.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../../../core/widgets/rows.dart';

/// What someone can do about a gambling promo: block the sender, see how
/// many it has sent, talk to someone, and ask to be excluded. The number
/// and the web address are pack data; the sentences are fixed.
class GamblingHelp extends StatelessWidget {
  const GamblingHelp({
    required this.promosFromSender,
    this.onBlock,
    this.crisisLine,
    this.onCallCrisisLine,
    this.regulatorSite,
    super.key,
  });

  /// Opens the sender's conversation in the SMS app. Null when the result
  /// has no sender, or did not come from SMS.
  final VoidCallback? onBlock;

  /// Kept promos from this sender, this one included.
  final int promosFromSender;

  /// A free line to talk to someone, from the pack. Null when the pack has
  /// none: that part is then left out.
  final PackRecord? crisisLine;
  final VoidCallback? onCallCrisisLine;

  /// The regulator's website from the pack, without the scheme.
  final String? regulatorSite;

  @override
  Widget build(BuildContext context) {
    final onBlock = this.onBlock;
    final crisisLine = this.crisisLine;
    final regulatorSite = this.regulatorSite;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 10,
      children: [
        const SectionHeading(title: 'Want fewer of these?'),
        if (promosFromSender >= 2)
          Text(
            'This sender has sent you $promosFromSender promos that Hudyat '
            'kept.',
            style: HudyatText.body,
          ),
        if (onBlock != null) ...[
          SecondaryButton(
            label: 'Block this sender in Messages',
            onPressed: onBlock,
          ),
          const Text(
            'Hudyat cannot block or delete texts. Messages opens at this '
            'sender, where you can do both.',
            style: HudyatText.gloss,
          ),
        ],
        if (crisisLine != null) ...[
          const Text(
            'If gambling is getting hard to control, you can talk to '
            'someone, free:',
            style: HudyatText.body,
          ),
          HotlineRow(record: crisisLine, onCall: onCallCrisisLine),
        ],
        Text(
          'PAGCOR, the regulator, has an exclusion programme: you can ask '
          'to be barred from licensed gambling, or a close family member '
          'can ask for you.'
          '${regulatorSite == null ? '' : ' See $regulatorSite · needs '
                    'internet.'}',
          style: HudyatText.secondary,
        ),
      ],
    );
  }
}
