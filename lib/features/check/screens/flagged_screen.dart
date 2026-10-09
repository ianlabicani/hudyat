import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../models/check_result.dart';
import '../services/flagged_store.dart';
import '../widgets/verdict_badge.dart';
import 'result_screen.dart';

/// The messages Hudyat kept: "Mukhang scam" first, then "Mag-ingat".
class FlaggedScreen extends StatelessWidget {
  const FlaggedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flagged = AppScope.of(context).flagged;
    return Scaffold(
      appBar: const TopBar(title: 'Flagged messages'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: flagged,
          builder: (context, _) {
            final all = flagged.all();
            return ListView(
              padding: const EdgeInsets.all(HudyatShape.gutter),
              children: [
                if (all.isEmpty) ...[
                  const Text('No flagged messages', style: HudyatText.section),
                  const SizedBox(height: 6),
                  const Text(
                    'Messages checked as "Mukhang scam" or "Mag-ingat" are '
                    'kept here, on this phone only.',
                    style: HudyatText.secondary,
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          spacing: 2,
                          children: [
                            Text(
                              all.length == 1
                                  ? '1 message kept'
                                  : '${all.length} messages kept',
                              style: HudyatText.bodyBold,
                            ),
                            const Text(
                              'On this phone only',
                              style: HudyatText.gloss,
                            ),
                          ],
                        ),
                      ),
                      SecondaryButton(
                        label: 'Clear all',
                        expand: false,
                        onPressed: flagged.clear,
                      ),
                    ],
                  ),
                  for (final verdict in [Verdict.scam, Verdict.caution])
                    ..._group(context, verdict, all),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Other messages are discarded after the check.',
                  style: HudyatText.data,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _group(
    BuildContext context,
    Verdict verdict,
    List<FlaggedMessage> all,
  ) {
    final items = [
      for (final item in all)
        if (item.result.verdict == verdict) item,
    ];
    if (items.isEmpty) return const [];
    return [
      const SizedBox(height: 20),
      Semantics(
        header: true,
        child: Text(verdict.label, style: HudyatText.section),
      ),
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _FlaggedRow(item: item),
        ),
    ];
  }
}

class _FlaggedRow extends StatelessWidget {
  const _FlaggedRow({required this.item});

  final FlaggedMessage item;

  static String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final result = item.result;
    final at = item.checkedAt;
    final when =
        '${at.year}-${_two(at.month)}-${_two(at.day)} '
        '${_two(at.hour)}:${_two(at.minute)}';
    final who = [
      result.sender ?? 'Sender not given',
      if (result.app case final app?) 'via $app',
    ].join(' · ');
    return Material(
      color: HudyatColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: HudyatShape.radius,
        side: result.verdict == Verdict.scam
            ? HudyatShape.primaryBorder
            : HudyatShape.secondaryBorder,
      ),
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ResultScreen(result: result)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 4,
                  children: [
                    VerdictTag(verdict: result.verdict),
                    Text(who, style: HudyatText.bodyBold),
                    Text(
                      result.text.replaceAll('\n', ' '),
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: HudyatText.data,
                    ),
                    Text(when, style: HudyatText.data),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, color: HudyatColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}
