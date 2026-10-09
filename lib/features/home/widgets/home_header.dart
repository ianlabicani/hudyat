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
      icon: Icon(
        ready ? Icons.circle : Icons.circle_outlined,
        size: 12,
        color: ready ? HudyatColors.ready : null,
      ),
      label: Text(ready ? 'Ready offline' : 'Finish setup'),
      style: OutlinedButton.styleFrom(
        backgroundColor: HudyatColors.surface,
        foregroundColor: HudyatColors.ink,
        side: ready
            ? HudyatShape.secondaryBorder.copyWith(color: HudyatColors.ready)
            : HudyatShape.secondaryBorder,
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
    return Semantics(
      label: 'Hudyat',
      header: true,
      child: ExcludeSemantics(
        child: Wrap(
          crossAxisAlignment: .center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Image.asset(
              'assets/brand/hudyat_mark_c.png',
              width: 32,
              height: 32,
              excludeFromSemantics: true,
            ),
            const Text(
              'hudyat',
              style: TextStyle(
                fontFamily: HudyatText.family,
                fontSize: 28,
                fontWeight: .w700,
                letterSpacing: -0.56,
              ),
            ),
          ],
        ),
      ),
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
