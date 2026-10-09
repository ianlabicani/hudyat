import 'package:flutter/material.dart';

import '../../../core/pack/first_aid_card.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/panels.dart';

/// A matched first-aid card: numbered steps and where they come from. All of
/// it is fixed text from the pack, and it says so.
class FirstAidSection extends StatelessWidget {
  const FirstAidSection({required this.card, super.key});

  final FirstAidCard card;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 12,
        children: [
          const Tag('First aid · fixed card'),
          Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  card.title,
                  style: HudyatText.section.copyWith(fontSize: 22),
                ),
                Text(card.titleTl, style: HudyatText.gloss),
              ],
            ),
          ),
          for (final (index, step) in card.steps.indexed)
            Row(
              crossAxisAlignment: .start,
              spacing: 12,
              children: [
                _StepNumber(index + 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      step,
                      style: HudyatText.body.copyWith(fontSize: 17),
                    ),
                  ),
                ),
              ],
            ),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: HudyatShape.ruleBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Source: ${card.sourceName} · ${card.sourceUrl}',
                style: HudyatText.data,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepNumber extends StatelessWidget {
  const _StepNumber(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(HudyatShape.primaryBorder),
        ),
        child: SizedBox.square(
          dimension: 32,
          child: Center(child: Text('$number', style: HudyatText.bodyBold)),
        ),
      ),
    );
  }
}
