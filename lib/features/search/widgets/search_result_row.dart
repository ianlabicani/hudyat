import 'package:flutter/material.dart';

import '../../../core/calls.dart';
import '../../../core/pack/pack_record.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';

/// One search hit: what it is, where it applies, and a Call button when the
/// pack has a number the dialer accepts.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({required this.record, super.key});

  final PackRecord record;

  /// Where the record applies, or that a service needs a connection.
  String get _note => switch (record.kind) {
    'service' => 'NEEDS INTERNET',
    'agency' => 'NATIONAL',
    _ => (record.city ?? record.province ?? 'National').toUpperCase(),
  };

  String get _detail {
    final phone = record.phones.isEmpty ? null : record.phones.first.display;
    final host = Uri.tryParse(record.url ?? '')?.host;
    final parts = switch (record.kind) {
      'service' => [record.parent, phone, host],
      'official' => [record.category, phone],
      'agency' => [phone, record.address],
      'place' => [record.category.replaceAll('_', ' '), record.address],
      _ => [phone],
    };
    return [
      for (final part in parts)
        if (part != null && part.isNotEmpty) part,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Panel(
      primary: false,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: 6,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: .center,
                  children: [
                    Tag(record.kind),
                    Text(_note, style: HudyatText.data),
                  ],
                ),
                Text(record.name, style: HudyatText.bodyBold),
                if (detail.isNotEmpty) Text(detail, style: HudyatText.data),
              ],
            ),
          ),
          if (record.canCall) ...[
            const SizedBox(width: 12),
            CallButton(onPressed: () => callRecord(context, record)),
          ],
        ],
      ),
    );
  }
}
