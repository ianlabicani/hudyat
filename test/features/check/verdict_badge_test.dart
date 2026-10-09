import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/theme/tokens.dart';
import 'package:hudyat/features/check/models/check_result.dart';
import 'package:hudyat/features/check/widgets/verdict_badge.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: hudyatTheme(),
      home: Scaffold(body: child),
    ),
  );

  Color? titleColour(WidgetTester tester, Verdict verdict) =>
      tester.widget<Text>(find.text(verdict.label)).style?.color;

  BoxDecoration box(WidgetTester tester, Finder within) =>
      tester
              .widgetList<DecoratedBox>(
                find.descendant(
                  of: within,
                  matching: find.byType(DecoratedBox),
                ),
              )
              .first
              .decoration
          as BoxDecoration;

  group('VerdictBadge', () {
    testWidgets('"Mukhang scam" is filled with the danger colour', (
      tester,
    ) async {
      await pump(tester, const VerdictBadge(verdict: Verdict.scam));
      expect(box(tester, find.byType(VerdictBadge)).color, HudyatColors.danger);
      expect(titleColour(tester, Verdict.scam), HudyatColors.surface);
    });

    testWidgets('"Mag-ingat" is outlined and titled in the caution colour', (
      tester,
    ) async {
      await pump(tester, const VerdictBadge(verdict: Verdict.caution));
      expect(
        box(tester, find.byType(VerdictBadge)).color,
        HudyatColors.surface,
      );
      expect(titleColour(tester, Verdict.caution), HudyatColors.caution);
    });

    testWidgets('"Walang nakitang problema" has no colour, least of all '
        'green', (tester) async {
      await pump(tester, const VerdictBadge(verdict: Verdict.clear));
      expect(titleColour(tester, Verdict.clear), HudyatColors.ink);
    });
  });

  testWidgets('VerdictTag takes its verdict colour', (tester) async {
    await pump(
      tester,
      const Column(
        children: [
          VerdictTag(verdict: Verdict.scam),
          VerdictTag(verdict: Verdict.caution),
        ],
      ),
    );
    expect(
      box(tester, find.byType(VerdictTag).first).color,
      HudyatColors.danger,
    );
    expect(
      tester.widget<Text>(find.text('MAG-INGAT')).style?.color,
      HudyatColors.caution,
    );
  });
}
