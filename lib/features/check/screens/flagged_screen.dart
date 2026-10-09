import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../models/flagged_sender.dart';
import '../widgets/flagged_rows.dart';
import 'flagged_sender_screen.dart';

/// The messages Hudyat kept, one row per sender: senders with a
/// "Mukhang scam" text first. A row opens that sender's messages.
class FlaggedScreen extends StatelessWidget {
  const FlaggedScreen({super.key});

  /// Asks first. The texts stay in the SMS app, so "Scan my messages" finds
  /// them again.
  Future<void> _clearAll(BuildContext context) async {
    final flagged = AppScope.of(context).flagged;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all flagged messages?'),
        content: const Text(
          'Nothing is deleted from your SMS app. "Scan my messages" will '
          'find these texts again if they are still there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (sure == true) flagged.clear();
  }

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
            final senders = groupBySender(all);
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
                  // Wraps, so large text puts Clear all under the counts.
                  Wrap(
                    alignment: .spaceBetween,
                    crossAxisAlignment: .center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Column(
                        mainAxisSize: .min,
                        crossAxisAlignment: .start,
                        spacing: 2,
                        children: [
                          Text(
                            [
                              all.length == 1
                                  ? '1 message kept'
                                  : '${all.length} messages kept',
                              senders.length == 1
                                  ? '1 sender'
                                  : '${senders.length} senders',
                            ].join(' · '),
                            style: HudyatText.bodyBold,
                          ),
                          const Text(
                            'On this phone only',
                            style: HudyatText.gloss,
                          ),
                        ],
                      ),
                      SecondaryButton(
                        label: 'Clear all',
                        expand: false,
                        onPressed: () => _clearAll(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final group in senders)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: FlaggedSenderRow(
                        group: group,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FlaggedSenderScreen(
                              sender: group.sender,
                              app: group.app,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Other messages are discarded after the check. Clearing '
                  'this list does not delete anything from your SMS app.',
                  style: HudyatText.data,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
