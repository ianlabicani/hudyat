import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/dashed_panel.dart';
import '../../../core/widgets/panels.dart';
import '../widgets/emergency_panel.dart';
import '../widgets/search_result_row.dart';
import 'no_match_screen.dart';

/// Keyword search over the pack: hotlines, places, agencies, officials and
/// services. Also where a typed message lands when it is not an emergency.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    this.initialQuery = '',
    this.fromMessage = false,
    super.key,
  });

  final String initialQuery;

  /// True when the query is a Home message that matched no help card, so the
  /// screen says why the user is seeing a list.
  final bool fromMessage;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _filters = <(String label, String? kind)>[
    ('All', null),
    ('Hotlines', 'hotline'),
    ('Places', 'place'),
    ('Agencies', 'agency'),
    ('Officials', 'official'),
    ('Services', 'service'),
  ];

  late final _controller = TextEditingController(text: widget.initialQuery);
  String? _kind;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    final query = _controller.text.trim();
    final results = store.search(query, kind: _kind);
    return Scaffold(
      appBar: const TopBar(title: 'Search results'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HudyatShape.gutter),
          children: [
            const Text('Search', style: HudyatText.bodyBold),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              autofocus: widget.initialQuery.isEmpty,
              textInputAction: .search,
              decoration: const InputDecoration(
                hintText: 'An office, a service, a place',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (widget.fromMessage) ...[
              const SizedBox(height: 16),
              DashedPanel(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    const Text(
                      'This did not look like an emergency, so these are '
                      'search results, not a help card.',
                      style: HudyatText.body,
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: HudyatColors.call,
                        minimumSize: const Size(48, 44),
                        padding: EdgeInsets.zero,
                        alignment: .centerLeft,
                        textStyle: HudyatText.button.copyWith(
                          fontSize: 15,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => NoMatchScreen(message: query),
                        ),
                      ),
                      child: const Text(
                        'It is an emergency. Show the hotline.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, kind) in _filters)
                  ChoiceChip(
                    label: Text(label),
                    selected: _kind == kind,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _kind = kind),
                    materialTapTargetSize: .padded,
                    backgroundColor: HudyatColors.surface,
                    selectedColor: HudyatColors.ink,
                    side: HudyatShape.secondaryBorder,
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(
                      fontFamily: HudyatText.family,
                      fontSize: 14,
                      fontWeight: .w700,
                      color: _kind == kind
                          ? HudyatColors.surface
                          : HudyatColors.ink,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (query.isEmpty)
              const Text(
                'Type a name, an office or a service.',
                style: HudyatText.secondary,
              )
            else if (results.isEmpty)
              ..._empty(query)
            else
              for (final record in results)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SearchResultRow(record: record),
                ),
            const SizedBox(height: 12),
            PackFooter(buildDate: store.meta.buildDate),
          ],
        ),
      ),
    );
  }

  List<Widget> _empty(String query) => [
    Semantics(
      header: true,
      child: Text(
        'No results for "$query"',
        style: HudyatText.title.copyWith(fontSize: 24, height: 1.2),
      ),
    ),
    const SizedBox(height: 6),
    const Text(
      'Try a shorter or different word, or tap what you need instead.',
      style: HudyatText.secondary,
    ),
    const SizedBox(height: 20),
    EmergencyPanel(hotline: AppScope.of(context).store.nationalEmergency()),
    const SizedBox(height: 20),
    SecondaryButton(
      label: 'Tap what you need instead',
      onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
    ),
    const SizedBox(height: 10),
  ];
}
