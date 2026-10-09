import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/calls.dart';
import '../../../core/pack/scam_records.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ai_note.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../models/check_result.dart';
import '../services/flagged_store.dart';
import '../services/result_explainer.dart';
import '../widgets/gambling_help.dart';
import '../widgets/result_rows.dart';
import '../widgets/verdict_badge.dart';

/// One checked message: the verdict, why, and the real contact of whoever
/// it claims to be. Every word here is fixed text or a fact from the pack,
/// except the labelled AI note under a flagged result.
class ResultScreen extends StatefulWidget {
  const ResultScreen({required this.result, super.key});

  final CheckResult result;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  CheckResult get result => widget.result;

  /// The AI note, started once when the result opens.
  Stream<String>? _note;

  /// Null for a result with nothing flagged, and whenever the chat model is
  /// not there: the screen then shows exactly what it did before.
  Stream<String>? _noteFor(Map<String, ScamReasonText> wording) {
    final generator = AppScope.of(context).models.generator;
    if (!ResultExplainer.enabled || generator == null || !result.isFlagged) {
      return null;
    }
    return _note ??= ResultExplainer(generator)
        .explain(result, wording)
        .asBroadcastStream();
  }

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

  /// The sender whose conversation the SMS app can open: a flagged text
  /// that came by SMS and has one.
  String? get _smsSender =>
      result.isFlagged && (result.app == null || result.app == 'Messages')
      ? result.sender
      : null;

  /// Kept gambling promos from this result's sender, this one included.
  int _promosFrom(List<FlaggedMessage> kept) {
    final sender = result.sender;
    if (sender == null) return 0;
    return kept
        .where(
          (item) =>
              item.result.sender == sender && item.result.hasGamblingPromo,
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final wording = scope.store.scamReasons();
    final claimed = result.claimed;
    final crisisLine = result.hasGamblingPromo
        ? scope.store.crisisLine()
        : null;
    final wordingNotice = switch (result.phrasing) {
      PhrasingState.notReady =>
        'The wording check is not ready yet, so only the rules were checked.',
      PhrasingState.skipped => 'The wording check was not run in this scan. Only the rules were checked.',
      PhrasingState.unknown =>
        'Whether the wording was checked was not recorded.',
      PhrasingState.checked => null,
    };
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
                title: 'This is not a guarantee',
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
              const SectionHeading(title: 'Why'),
              for (final reason in result.reasons)
                if (wording[reason.id] case final text?)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ReasonRow(reason: reason, wording: text),
                  ),
              if (wordingNotice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(wordingNotice, style: HudyatText.gloss),
                ),
            ],
            if (result.verdict == Verdict.clear) ...[
              const SizedBox(height: 22),
              const SectionHeading(title: 'What was checked'),
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
                outcome: switch (result.phrasing) {
                  PhrasingState.unknown =>
                    'Whether the wording was checked was not recorded.',
                  PhrasingState.notReady => 'Not ready yet',
                  PhrasingState.skipped => 'Not run in this scan',
                  PhrasingState.checked => 'No scam match',
                },
              ),
            ],
            if (result.hasGamblingPromo) ...[
              const SizedBox(height: 22),
              GamblingHelp(
                promosFromSender: _promosFrom(scope.flagged.all()),
                onBlock: _smsSender == null
                    ? null
                    : () => _openThread(context, _smsSender!),
                crisisLine: crisisLine,
                onCallCrisisLine: crisisLine == null
                    ? null
                    : () => callRecord(context, crisisLine),
                regulatorSite: scope.store.gamblingRegulatorSite(),
              ),
            ],
            if (claimed != null) ...[
              const SizedBox(height: 22),
              const SectionHeading(title: 'The real contact'),
              const SizedBox(height: 10),
              ContactRow(
                sender: claimed,
                onCall: claimed.dialable.isEmpty
                    ? null
                    : () =>
                          callNumbers(context, claimed.name, claimed.dialable),
              ),
            ] else if (!result.hasGamblingPromo) ...[
              const SizedBox(height: 10),
              const Text(
                'No official sender matched this message, so no contact is '
                'shown.',
                style: HudyatText.gloss,
              ),
            ],
            // A gambling promo offers this inside its help section instead.
            if (_smsSender case final from? when !result.hasGamblingPromo) ...[
              const SizedBox(height: 22),
              SecondaryButton(
                label: 'Open in Messages',
                onPressed: () => _openThread(context, from),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hudyat cannot delete texts. Delete this one or block the '
                'sender there.',
                style: HudyatText.gloss,
              ),
            ],
            // Last, so text arriving here never moves a button.
            if (_noteFor(wording) case final note?) AiNote(text: note),
            const SizedBox(height: 22),
            CheckFooter(buildDate: scope.store.meta.buildDate),
          ],
        ),
      ),
    );
  }
}
