import 'package:flutter/material.dart';

import '../../../core/pack/scam_records.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../models/check_result.dart';

/// The checked message in the data face, with who sent it and through which
/// app when that is known.
class MessageQuote extends StatelessWidget {
  const MessageQuote({required this.result, super.key});

  final CheckResult result;

  @override
  Widget build(BuildContext context) {
    final from = [
      if (result.sender case final sender?) 'From $sender',
      if (result.app case final app?) 'via $app',
    ].join(' · ');
    return Panel(
      primary: false,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 8,
        children: [
          if (from.isNotEmpty) Text(from, style: HudyatText.data),
          Text(
            result.text,
            style: HudyatText.data.copyWith(
              fontSize: 14,
              color: HudyatColors.ink,
            ),
          ),
          if (result.truncated)
            const Text(
              'Read from a notification. The message may be cut short.',
              style: HudyatText.gloss,
            ),
        ],
      ),
    );
  }
}

/// One reason: the fixed Tagalog sentence, its English line, and the fact
/// from the pack or the message that backs it.
class ReasonRow extends StatelessWidget {
  const ReasonRow({required this.reason, required this.wording, super.key});

  final CheckReason reason;
  final ScamReasonText wording;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          const ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: .circle,
                border: Border.fromBorderSide(HudyatShape.primaryBorder),
              ),
              child: SizedBox.square(
                dimension: 28,
                child: Center(
                  child: Text('!', style: TextStyle(fontWeight: .w700)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: 4,
              children: [
                Text(reason.fill(wording.en), style: HudyatText.bodyBold),
                Text(reason.fill(wording.fact), style: HudyatText.data),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The real contact of whoever the message claims to be. [onCall] is null
/// when the pack has no number for them; the website is still shown.
class ContactRow extends StatelessWidget {
  const ContactRow({required this.sender, required this.onCall, super.key});

  final OfficialSender sender;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final numbers = sender.dialable;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                mainAxisAlignment: .center,
                spacing: 2,
                children: [
                  Text(sender.name, style: HudyatText.bodyBold),
                  Text(
                    numbers.isEmpty
                        ? 'No number listed'
                        : [
                            numbers.first.display,
                            if (numbers.length > 1)
                              '+${numbers.length - 1} more',
                          ].join(' · '),
                    style: HudyatText.data,
                  ),
                  Text(sender.domains.first, style: HudyatText.data),
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

/// One line of "What was checked" on a clear result.
class CheckedRow extends StatelessWidget {
  const CheckedRow({required this.name, required this.outcome, super.key});

  final String name;
  final String outcome;

  @override
  Widget build(BuildContext context) {
    return Panel(
      primary: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
          children: [
            Text(name, style: HudyatText.bodyBold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(outcome, textAlign: .end, style: HudyatText.data),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who checked it and how fresh the list is. Goes at the bottom of results.
class CheckFooter extends StatelessWidget {
  const CheckFooter({required this.buildDate, super.key});

  final String buildDate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: HudyatShape.ruleBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          'Checked on this phone · Official list: bettergovph/bettergov, '
          'company websites\n'
          'Pack built $buildDate. Details may be out of date.',
          style: HudyatText.data,
        ),
      ),
    );
  }
}
