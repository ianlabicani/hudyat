import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/dashed_panel.dart';
import '../models/check_result.dart';

/// What to do next, in fixed Tagalog. The clear verdict gets a Notice
/// instead, since it must never read as "safe".
String? adviceFor(Verdict verdict) => switch (verdict) {
  Verdict.scam =>
    'Huwag pindutin ang link. Huwag magbigay ng OTP, password o pera.',
  Verdict.caution => 'I-verify muna gamit ang opisyal na contact bago kumilos.',
  Verdict.clear => null,
};

/// The verdict at the top of a result: danger fill for "Mukhang scam",
/// outlined in the caution colour for "Mag-ingat", dashed and muted for
/// "Walang nakitang problema". Shape differs as well as colour. The call
/// accent is never used here, and neither is green.
class VerdictBadge extends StatelessWidget {
  const VerdictBadge({required this.verdict, super.key});

  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final filled = verdict == Verdict.scam;
    final dashed = verdict == Verdict.clear;
    final ink = filled ? HudyatColors.surface : HudyatColors.ink;
    // The colour that carries the verdict; body text stays ink for contrast.
    final tone = switch (verdict) {
      Verdict.scam => HudyatColors.danger,
      Verdict.caution => HudyatColors.caution,
      Verdict.clear => HudyatColors.muted,
    };
    final accent = filled ? HudyatColors.surface : tone;
    final advice = adviceFor(verdict);
    final content = Column(
      crossAxisAlignment: .start,
      spacing: 8,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: HudyatShape.badgeRadius,
            border: Border.all(color: accent, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              'VERDICT',
              style: HudyatText.data.copyWith(color: accent),
            ),
          ),
        ),
        Semantics(
          header: true,
          child: Text(
            verdict.label,
            style: HudyatText.title.copyWith(
              color: dashed ? HudyatColors.ink : accent,
              fontSize: dashed ? 26 : 28,
            ),
          ),
        ),
        Text(
          verdict.gloss,
          style: HudyatText.gloss.copyWith(
            color: filled ? HudyatColors.rule : HudyatColors.muted,
          ),
        ),
        if (advice != null)
          Text(advice, style: HudyatText.body.copyWith(color: ink)),
      ],
    );
    if (dashed) {
      return DashedPanel(padding: const EdgeInsets.all(16), child: content);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? tone : HudyatColors.surface,
        borderRadius: HudyatShape.radius,
        border: Border.all(color: tone, width: 2),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }
}

/// The small verdict tag on a row of the Flagged list.
class VerdictTag extends StatelessWidget {
  const VerdictTag({required this.verdict, super.key});

  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final filled = verdict == Verdict.scam;
    final tone = filled ? HudyatColors.danger : HudyatColors.caution;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? tone : null,
        borderRadius: HudyatShape.badgeRadius,
        border: Border.all(color: tone, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          filled ? 'SCAM' : 'MAG-INGAT',
          style: HudyatText.data.copyWith(
            color: filled ? HudyatColors.surface : tone,
          ),
        ),
      ),
    );
  }
}
