import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../location/state/location_controller.dart';
import '../models/help_card.dart';

/// Card title, the city in use and how it was decided, and the pack date.
class CardHeader extends StatelessWidget {
  const CardHeader({required this.card, required this.onChangeCity, super.key});

  final HelpCard card;
  final VoidCallback onChangeCity;

  @override
  Widget build(BuildContext context) {
    final how = card.citySource == CitySource.gps
        ? 'from GPS'
        : 'chosen manually';
    return Column(
      crossAxisAlignment: .start,
      spacing: 10,
      children: [
        Semantics(
          header: true,
          child: Text(card.intent.label, style: HudyatText.title),
        ),
        // A Wrap, so with large text or a long city name the button drops
        // below the line instead of squeezing it.
        Wrap(
          alignment: .spaceBetween,
          crossAxisAlignment: .center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text.rich(
              TextSpan(
                text: 'Near ',
                style: HudyatText.body.copyWith(fontSize: 15),
                children: [
                  TextSpan(
                    text: card.city,
                    style: const TextStyle(fontWeight: .w700),
                  ),
                  TextSpan(text: ' · $how'),
                ],
              ),
            ),
            SecondaryButton(
              label: 'Change city',
              expand: false,
              onPressed: onChangeCity,
            ),
          ],
        ),
        Text(
          'Pack built ${card.buildDate}. Numbers may be out of date.',
          style: HudyatText.data,
        ),
      ],
    );
  }
}
