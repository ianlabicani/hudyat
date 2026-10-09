import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../state/location_controller.dart';

/// Asks for a city when there is no GPS fix, or when the user wants a
/// different one. Pops with true once a city is set.
class PickCityScreen extends StatefulWidget {
  const PickCityScreen({super.key});

  @override
  State<PickCityScreen> createState() => _PickCityScreenState();
}

class _PickCityScreenState extends State<PickCityScreen> {
  String _filter = '';
  String? _selected;
  bool _gpsFailed = false;

  Future<void> _tryGps(LocationController location) async {
    final navigator = Navigator.of(context);
    final found = await location.refresh();
    if (!mounted) return;
    if (found) {
      navigator.pop(true);
    } else {
      setState(() => _gpsFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final location = scope.location;
    final selected = _selected ?? location.city;
    final needle = _filter.trim().toLowerCase();
    final cities = [
      for (final city in scope.store.cities())
        if (city.toLowerCase().contains(needle)) city,
    ];
    return Scaffold(
      appBar: const TopBar(title: 'Where are you?', gloss: 'Nasaan ka?'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: location,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.all(HudyatShape.gutter),
                  children: [
                    if (location.source != CitySource.gps)
                      Notice(
                        title: _gpsFailed ? 'Still no GPS fix' : 'No GPS fix',
                        body:
                            'Pick your city so we can show the right '
                            'hotlines. Distances stay hidden until we know '
                            'where you are.',
                      ),
                    const SizedBox(height: 16),
                    SecondaryButton(
                      label: location.busy
                          ? 'Looking for GPS…'
                          : 'Try GPS again',
                      onPressed: location.busy ? null : () => _tryGps(location),
                    ),
                    if (location.busy) const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Search city', style: HudyatText.bodyBold),
                    const SizedBox(height: 6),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'e.g. Marikina',
                      ),
                      textInputAction: .search,
                      onChanged: (value) => setState(() => _filter = value),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cities in the ${scope.store.meta.name} pack',
                      style: HudyatText.gloss,
                    ),
                    if (cities.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'No city matches "$_filter".',
                          style: HudyatText.secondary,
                        ),
                      ),
                    for (final city in cities)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _CityOption(
                          city: city,
                          selected: city == selected,
                          onTap: () => setState(() => _selected = city),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: HudyatColors.ground,
                border: Border(top: HudyatShape.ruleBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: PrimaryButton(
                  label: selected == null ? 'Pick a city' : 'Use $selected',
                  onPressed: selected == null
                      ? null
                      : () {
                          location.chooseCity(selected);
                          Navigator.of(context).pop(true);
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityOption extends StatelessWidget {
  const _CityOption({
    required this.city,
    required this.selected,
    required this.onTap,
  });

  final String city;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Material(
        color: HudyatColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: HudyatShape.radius,
          side: selected
              ? HudyatShape.primaryBorder
              : HudyatShape.secondaryBorder,
        ),
        clipBehavior: .antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: HudyatColors.ink,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      city,
                      style: selected ? HudyatText.bodyBold : HudyatText.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
