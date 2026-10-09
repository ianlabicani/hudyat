import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/panels.dart';
import '../models/check_result.dart';
import '../models/flagged_sender.dart';
import '../services/flagged_store.dart';
import '../widgets/flagged_rows.dart';
import 'result_screen.dart';

/// The kept messages from one sender: "Mukhang scam" first, then
/// "Mag-ingat", then gambling promos.
class FlaggedSenderScreen extends StatelessWidget {
  const FlaggedSenderScreen({this.sender, this.app, super.key});

  /// Null for the texts kept without a sender.
  final String? sender;
  final String? app;

  @override
  Widget build(BuildContext context) {
    final flagged = AppScope.of(context).flagged;
    return ListenableBuilder(
      listenable: flagged,
      builder: (context, _) {
        final group = senderGroup(flagged.all(), sender: sender, app: app);
        final title =
            group?.title ??
            FlaggedSender(sender: sender, app: app, messages: const []).title;

        void remove(int id) {
          final last = group?.messages.length == 1;
          flagged.remove(id);
          if (last) Navigator.of(context).maybePop();
        }

        return Scaffold(
          appBar: TopBar(title: title),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(HudyatShape.gutter),
              children: [
                if (group == null) ...[
                  const Text('No flagged messages', style: HudyatText.section),
                  const SizedBox(height: 6),
                  const Text(
                    'Nothing from this sender is kept any more.',
                    style: HudyatText.secondary,
                  ),
                ] else ...[
                  Text(
                    group.messages.length == 1
                        ? '1 message kept'
                        : '${group.messages.length} messages kept',
                    style: HudyatText.bodyBold,
                  ),
                  const SizedBox(height: 2),
                  const Text('On this phone only', style: HudyatText.gloss),
                  ..._section(context, Verdict.scam.label, group.scam, remove),
                  ..._section(
                    context,
                    Verdict.caution.label,
                    group.caution,
                    remove,
                  ),
                  ..._section(
                    context,
                    FlaggedSender.promoLabel,
                    group.promo,
                    remove,
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Removing one here does not delete it from your SMS app.',
                  style: HudyatText.data,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    List<FlaggedMessage> items,
    void Function(int id) onRemove,
  ) {
    if (items.isEmpty) return const [];
    return [
      const SizedBox(height: 20),
      Semantics(
        header: true,
        child: Text('$title · ${items.length}', style: HudyatText.section),
      ),
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: FlaggedMessageRow(
            item: item,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ResultScreen(result: item.result),
              ),
            ),
            onRemove: () => onRemove(item.id),
          ),
        ),
    ];
  }
}
