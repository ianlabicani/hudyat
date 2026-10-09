import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../widgets/emergency_panel.dart';

/// Shown when a message fits no help card: the emergency number and a way
/// back. Both buttons return to Home, where the message is still in the box.
class NoMatchScreen extends StatelessWidget {
  const NoMatchScreen({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    void backToHome() => Navigator.of(context).popUntil((r) => r.isFirst);
    return Scaffold(
      appBar: const TopBar(title: 'No match'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HudyatShape.gutter),
          children: [
            const Text('You wrote', style: HudyatText.gloss),
            const SizedBox(height: 6),
            Panel(
              primary: false,
              padding: const EdgeInsets.all(12),
              child: Text(message, style: HudyatText.body),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                'We could not match this to a help card.',
                style: HudyatText.title.copyWith(fontSize: 24, height: 1.2),
              ),
            ),
            const SizedBox(height: 20),
            EmergencyPanel(hotline: store.nationalEmergency()),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Edit my message', onPressed: backToHome),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Tap what you need instead',
              onPressed: backToHome,
            ),
            const SizedBox(height: 22),
            PackFooter(buildDate: store.meta.buildDate),
          ],
        ),
      ),
    );
  }
}
