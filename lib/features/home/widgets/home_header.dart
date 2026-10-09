import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// Opens Setup. Says whether both models are on the phone.
class StatusPill extends StatelessWidget {
  const StatusPill({required this.ready, required this.onPressed, super.key});

  final bool ready;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(ready ? Icons.circle : Icons.circle_outlined, size: 12),
      label: Text(ready ? 'Ready offline' : 'Finish setup'),
      style: OutlinedButton.styleFrom(
        backgroundColor: HudyatColors.surface,
        foregroundColor: HudyatColors.ink,
        side: HudyatShape.secondaryBorder,
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: HudyatText.family, fontSize: 13),
      ),
    );
  }
}

class HomeBrand extends StatelessWidget {
  const HomeBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      crossAxisAlignment: .end,
      spacing: 8,
      children: [
        Text(
          'Hudyat',
          style: TextStyle(
            fontSize: 28,
            fontWeight: .w700,
            letterSpacing: -0.3,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 5),
          child: Text('signal', style: HudyatText.data),
        ),
      ],
    );
  }
}

/// The one-tap national emergency call, with the number from the pack.
class EmergencyButton extends StatelessWidget {
  const EmergencyButton({
    required this.number,
    required this.onPressed,
    super.key,
  });

  final String number;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: HudyatColors.call,
        foregroundColor: HudyatColors.surface,
        minimumSize: const Size.fromHeight(60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: const RoundedRectangleBorder(borderRadius: HudyatShape.radius),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Call emergency hotline',
              style: TextStyle(fontSize: 18, fontWeight: .w700),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            number,
            style: HudyatText.data.copyWith(
              fontSize: 18,
              fontWeight: .w500,
              color: HudyatColors.surface,
            ),
          ),
        ],
      ),
    );
  }
}
