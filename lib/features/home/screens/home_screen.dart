import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/calls.dart';
import '../../../core/models/model_manager.dart';
import '../../../core/pack/first_aid_card.dart';
import '../../../core/pack/pack_record.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../../card/card_labels.dart';
import '../../card/screens/card_screen.dart';
import '../../check/screens/check_screen.dart';
import '../../location/screens/pick_city_screen.dart';
import '../../location/state/location_controller.dart';
import '../../intent/services/intent_matcher.dart';
import '../../search/screens/search_screen.dart';
import '../../setup/screens/setup_screen.dart';
import '../widgets/quick_buttons.dart';

/// Home: the emergency number, the message box and the quick buttons.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _message = TextEditingController();

  /// True while waiting for the first GPS fix before opening a card.
  bool _locating = false;

  /// True while the message is being matched to an intent.
  bool _matching = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _openCard(
    IntentDef intent, {
    String? message,
    FirstAidCard? firstAid,
  }) async {
    final location = AppScope.of(context).location;
    final navigator = Navigator.of(context);
    if (location.city == null) {
      setState(() => _locating = true);
      await location.refresh();
      if (!mounted) return;
      setState(() => _locating = false);
    } else if (location.source == CitySource.gps) {
      // Show the card from the last fix now; it updates if the phone moved.
      unawaited(location.refresh());
    }
    if (location.city == null) {
      await navigator.push<bool>(
        MaterialPageRoute(builder: (_) => const PickCityScreen()),
      );
      if (location.city == null) return;
    }
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) =>
            CardScreen(intent: intent, message: message, firstAid: firstAid),
      ),
    );
  }

  void _search({String query = '', bool fromMessage = false}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            SearchScreen(initialQuery: query, fromMessage: fromMessage),
      ),
    );
  }

  /// Message → intent → card. Anything that is not clearly an emergency, and
  /// any failure of the model, goes to keyword search instead.
  Future<void> _findHelp() async {
    final text = _message.text.trim();
    if (text.isEmpty || _matching) return;
    final scope = AppScope.of(context);
    final matcher = scope.models.matcher;
    if (matcher == null) return _search(query: text);

    setState(() => _matching = true);
    IntentMatch? match;
    try {
      match = await matcher.match(text);
    } on Object {
      match = null;
    }
    // Only a message that opens a card can carry first aid. A failure here
    // means a card without it, never no card.
    FirstAidCard? firstAid;
    if (match != null) {
      try {
        firstAid = await scope.models.firstAid?.match(text);
      } on Object {
        firstAid = null;
      }
    }
    if (!mounted) return;
    setState(() => _matching = false);

    final intent = match == null ? null : scope.store.intent(match.intentId);
    if (intent == null) return _search(query: text, fromMessage: true);
    await _openCard(intent, message: text, firstAid: firstAid);
  }

  // Back here would close the app and stop automatic checking, so it sends
  // the app to the background instead.
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(sendAppToBackground());
    },
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final emergency = store.nationalEmergency();
    final byId = {for (final intent in store.intents()) intent.id: intent};
    final quick = [
      for (final id in CardLabels.quickIntents)
        if (byId[id] != null) byId[id]!,
    ];
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: scope.models,
          builder: (context, _) {
            final models = scope.models;
            final understands = models.matcher != null;
            return ListView(
              padding: const EdgeInsets.all(HudyatShape.gutter),
              children: [
                // Wraps the status pill under the name when text is large.
                Wrap(
                  alignment: .spaceBetween,
                  crossAxisAlignment: .center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    const _Brand(),
                    _StatusPill(
                      ready: models.allReady,
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(builder: (_) => const SetupScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (emergency != null)
                  _EmergencyButton(
                    number: emergency.dialable.first.display,
                    onPressed: () => callRecord(context, emergency),
                  ),
                const SizedBox(height: 16),
                if (!understands) ...[
                  Notice(
                    title: switch (models.embeddingState) {
                      ModelState.checking => 'Loading the language model',
                      ModelState.preparing =>
                        'Getting the language model ready '
                            '(${models.embeddingProgress}%)',
                      _ => 'Language model not on this phone',
                    },
                    body:
                        'Typing uses keyword search until it is. The buttons '
                        'below work as usual.',
                  ),
                  const SizedBox(height: 16),
                ],
                const Text.rich(
                  TextSpan(
                    text: 'What happened? ',
                    style: TextStyle(fontSize: 18, fontWeight: .w700),
                    children: [
                      TextSpan(
                        text: "Ano'ng nangyari?",
                        style: HudyatText.gloss,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _message,
                  minLines: 3,
                  maxLines: 5,
                  textInputAction: .search,
                  decoration: InputDecoration(
                    hintText: understands
                        ? 'Type in Taglish. e.g. Binabaha na dito sa amin, '
                              'may matanda na hindi makalabas'
                        : 'Type a few words. e.g. baha, ospital, sunog',
                  ),
                  onSubmitted: (_) => _findHelp(),
                ),
                const SizedBox(height: 8),
                if (_matching)
                  const PrimaryButton(label: 'Finding help…', onPressed: null)
                else if (understands)
                  PrimaryButton(
                    label: 'Find help',
                    gloss: 'Humanap ng tulong',
                    onPressed: _findHelp,
                  )
                else
                  PrimaryButton(
                    label: 'Search',
                    gloss: 'Maghanap',
                    onPressed: _findHelp,
                  ),
                const SizedBox(height: 16),
                const Text('Or tap what you need', style: HudyatText.gloss),
                const SizedBox(height: 8),
                if (_locating) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 6),
                  const Text(
                    'Finding where you are…',
                    style: HudyatText.secondary,
                  ),
                  const SizedBox(height: 8),
                ],
                QuickButtons(
                  intents: quick,
                  enabled: !_locating,
                  onTap: _openCard,
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: .start,
                  spacing: 10,
                  children: [
                    Expanded(
                      child: _TwoLineButton(
                        label: 'Look up',
                        gloss: 'Agencies, officials',
                        onPressed: _search,
                      ),
                    ),
                    Expanded(
                      child: _TwoLineButton(
                        label: 'Check a message',
                        gloss: 'Suriin ang mensahe',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CheckScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(top: HudyatShape.ruleBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Pack: ${store.meta.name} · built '
                      '${store.meta.buildDate}\n'
                      'Models: embedding ${models.embeddingState.name} · '
                      'chat ${models.chatState.name}',
                      style: HudyatText.data,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Opens Setup. Says whether both models are on the phone.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.ready, required this.onPressed});

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

class _Brand extends StatelessWidget {
  const _Brand();

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
class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton({required this.number, required this.onPressed});

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
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  'Call emergency hotline',
                  style: TextStyle(fontSize: 18, fontWeight: .w700),
                ),
                Text('Tumawag ngayon', style: TextStyle(fontSize: 14)),
              ],
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

/// One of the two outlined buttons under the quick buttons: a bold label
/// with a smaller line beneath it.
class _TwoLineButton extends StatelessWidget {
  const _TwoLineButton({
    required this.label,
    required this.gloss,
    required this.onPressed,
  });

  final String label;
  final String gloss;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: HudyatColors.ink,
        side: HudyatShape.secondaryBorder,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: const RoundedRectangleBorder(borderRadius: HudyatShape.radius),
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          Text(
            label,
            textAlign: .center,
            style: HudyatText.bodyBold.copyWith(fontSize: 15),
          ),
          Text(
            gloss,
            textAlign: .center,
            style: HudyatText.gloss.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
