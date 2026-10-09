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

/// The verdict at the top of a result: ink fill for "Mukhang scam",
/// outlined for "Mag-ingat", dashed and muted for "Walang nakitang
/// problema". The call accent is never used here.
class VerdictBadge extends StatelessWidget {
  const VerdictBadge({required this.verdict, super.key});

  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final filled = verdict == Verdict.scam;
    final dashed = verdict == Verdict.clear;
    final ink = filled ? HudyatColors.surface : HudyatColors.ink;
    final advice = adviceFor(verdict);
    final content = Column(
      crossAxisAlignment: .start,
      spacing: 8,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: HudyatShape.badgeRadius,
            border: Border.all(
              color: dashed ? HudyatColors.muted : ink,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text('VERDICT', style: HudyatText.data.copyWith(color: ink)),
          ),
        ),
        Semantics(
          header: true,
          child: Text(
            verdict.label,
            style: HudyatText.title.copyWith(
              color: ink,
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
        color: filled ? HudyatColors.ink : HudyatColors.surface,
        borderRadius: HudyatShape.radius,
        border: const Border.fromBorderSide(HudyatShape.primaryBorder),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? HudyatColors.ink : null,
        borderRadius: HudyatShape.badgeRadius,
        border: const Border.fromBorderSide(HudyatShape.secondaryBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          filled ? 'SCAM' : 'MAG-INGAT',
          style: HudyatText.data.copyWith(
            color: filled ? HudyatColors.surface : HudyatColors.ink,
          ),
        ),
      ),
    );
  }
}
