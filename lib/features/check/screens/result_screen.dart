import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/calls.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../models/check_result.dart';
import '../widgets/result_rows.dart';
import '../widgets/verdict_badge.dart';

/// One checked message: the verdict, why, and the real contact of whoever
/// it claims to be. Every word here is fixed text or a fact from the pack.
class ResultScreen extends StatelessWidget {
  const ResultScreen({required this.result, super.key});

  final CheckResult result;

  String get _links => switch (result.linkCount) {
    0 => 'None found',
    1 => '1 found, not flagged',
    final n => '$n found, none flagged',
  };

  /// [known] are sender names real organisations text from. Matching one
  /// is worth saying, but it clears nothing: a sender name can be faked.
  String _sender(List<String> known) {
    final from = result.sender?.toLowerCase();
    if (from == null) return 'Not given / Hindi ibinigay';
    if (known.any((name) => name.toLowerCase() == from)) {
      return 'A known sender name, which can be faked';
    }
    return result.claimed == null ? 'No claim found' : 'No problem found';
  }

  Future<void> _openThread(BuildContext context, String sender) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await openSmsThread(sender)) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open Messages. Open it yourself to delete the text.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final wording = scope.store.scamReasons();
    final claimed = result.claimed;
    final notReady = result.phrasing == PhrasingState.notReady;
    return Scaffold(
      appBar: const TopBar(title: 'Message check'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HudyatShape.gutter),
          children: [
            VerdictBadge(verdict: result.verdict),
            if (result.verdict == Verdict.clear) ...[
              const SizedBox(height: 22),
              const Notice(
                title: 'Hindi ito garantiya',
                body:
                    'Hudyat can miss scams. If the message asks for money, '
                    'an OTP or a password, check with the sender another '
                    'way first.',
              ),
            ],
            const SizedBox(height: 22),
            MessageQuote(result: result),
            if (result.reasons.isNotEmpty) ...[
              const SizedBox(height: 22),
              const SectionHeading(title: 'Why', gloss: 'Bakit'),
              for (final reason in result.reasons)
                if (wording[reason.id] case final text?)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ReasonRow(reason: reason, wording: text),
                  ),
              if (notReady)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'The wording check is not ready yet, so only links and '
                    'the sender were checked.',
                    style: HudyatText.gloss,
                  ),
                ),
            ],
            if (result.verdict == Verdict.clear) ...[
              const SizedBox(height: 22),
              const SectionHeading(
                title: 'What was checked',
                gloss: 'Ano ang sinuri',
              ),
              const SizedBox(height: 10),
              CheckedRow(name: 'Links', outcome: _links),
              const SizedBox(height: 10),
              CheckedRow(
                name: 'Sender',
                outcome: _sender(scope.store.knownSenderIds()),
              ),
              const SizedBox(height: 10),
              CheckedRow(
                name: 'Phrasing',
                outcome: notReady ? 'Not ready yet' : 'No scam match',
              ),
            ],
            if (claimed != null) ...[
              const SizedBox(height: 22),
              const SectionHeading(
                title: 'The real contact',
                gloss: 'Ang tunay na contact',
              ),
              const SizedBox(height: 10),
              ContactRow(
                sender: claimed,
                onCall: claimed.dialable.isEmpty
                    ? null
                    : () =>
                          callNumbers(context, claimed.name, claimed.dialable),
              ),
            ] else ...[
              const SizedBox(height: 10),
              const Text(
                'No official sender matched this message, so no contact is '
                'shown.',
                style: HudyatText.gloss,
              ),
            ],
            if (result.sender case final from? when result.isFlagged) ...[
              const SizedBox(height: 22),
              SecondaryButton(
                label: 'Open in Messages',
                gloss: 'Buksan sa Messages',
                onPressed: () => _openThread(context, from),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hudyat cannot delete texts. Delete this one or block the '
                'sender there.',
                style: HudyatText.gloss,
              ),
            ],
            const SizedBox(height: 22),
            CheckFooter(buildDate: scope.store.meta.buildDate),
          ],
        ),
      ),
    );
  }
}
