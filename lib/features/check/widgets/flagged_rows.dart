import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../models/check_result.dart';
import '../models/flagged_sender.dart';
import '../services/flagged_store.dart';
import 'verdict_badge.dart';

/// The outlined, tappable surface both Flagged rows share.
class _RowSurface extends StatelessWidget {
  const _RowSurface({
    required this.verdict,
    required this.onTap,
    required this.children,
  });

  final Verdict verdict;
  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HudyatColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: HudyatShape.radius,
        side: verdict == Verdict.scam
            ? HudyatShape.primaryBorder
            : HudyatShape.secondaryBorder,
      ),
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: children),
        ),
      ),
    );
  }
}

String _oneLine(String text) => text.replaceAll('\n', ' ');

/// One sender in the Flagged list: its worst verdict, how many texts of
/// each kind are kept, and the newest one.
class FlaggedSenderRow extends StatelessWidget {
  const FlaggedSenderRow({required this.group, required this.onTap, super.key});

  final FlaggedSender group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = group.messages.length;
    return _RowSurface(
      verdict: group.worst,
      onTap: onTap,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: 4,
            children: [
              VerdictTag(verdict: group.worst),
              Text(group.title, style: HudyatText.bodyBold),
              Text(group.counts, style: HudyatText.data),
              Text(
                _oneLine(group.latest.result.text),
                maxLines: 1,
                overflow: .ellipsis,
                style: HudyatText.data,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          label: total == 1 ? '1 message' : '$total messages',
          excludeSemantics: true,
          child: Text('$total', style: HudyatText.bodyBold),
        ),
        const Icon(Icons.chevron_right, color: HudyatColors.ink),
      ],
    );
  }
}

/// One kept message on its sender's screen.
class FlaggedMessageRow extends StatelessWidget {
  const FlaggedMessageRow({
    required this.item,
    required this.onTap,
    required this.onRemove,
    super.key,
  });

  final FlaggedMessage item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  static String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final result = item.result;
    final at = item.checkedAt;
    final when =
        '${at.year}-${_two(at.month)}-${_two(at.day)} '
        '${_two(at.hour)}:${_two(at.minute)}';
    return _RowSurface(
      verdict: result.verdict,
      onTap: onTap,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: 4,
            children: [
              VerdictTag(verdict: result.verdict),
              Text(
                _oneLine(result.text),
                maxLines: 2,
                overflow: .ellipsis,
                style: HudyatText.body,
              ),
              Text(when, style: HudyatText.data),
            ],
          ),
        ),
        IconButton(
          onPressed: onRemove,
          tooltip: 'Remove from this list',
          color: HudyatColors.ink,
          icon: const Icon(Icons.delete_outline),
        ),
        const Icon(Icons.chevron_right, color: HudyatColors.ink),
      ],
    );
  }
}
