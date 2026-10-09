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
import '../../check/screens/flagged_screen.dart';
import '../../check/screens/timed_check_screen.dart';
import '../../intent/services/first_aid_matcher.dart';
import '../../location/screens/pick_city_screen.dart';
import '../../location/state/location_controller.dart';
import '../../search/screens/search_screen.dart';
import '../../setup/screens/setup_screen.dart';
import '../widgets/guard_panel.dart';
import '../widgets/home_header.dart';
import '../widgets/quick_buttons.dart';
import '../widgets/understood_strip.dart';

/// What the language model made of one message: the intent to open a card
/// for, or none when the message belongs in keyword search.
class _Understood {
  const _Understood(this.text, this.intent, this.firstAid, this.elapsed);

  final String text;
  final IntentDef? intent;
  final FirstAidCard? firstAid;
  final Duration elapsed;
}

/// Home in two blocks: getting help (the emergency number, the message box
/// and the quick buttons) and the message guard.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// How long typing must pause before the message is matched.
  static const _pause = Duration(milliseconds: 600);

  /// Fewer words than this are not matched while typing.
  static const _minWords = 3;

  final _message = TextEditingController();

  /// True while waiting for the first GPS fix before opening a card.
  bool _locating = false;

  /// True while "Find help" waits for the message to be matched.
  bool _matching = false;

  Timer? _typingPause;

  /// Raised for every new match, so an answer for older text is dropped.
  int _matchRound = 0;

  /// The match for the text now in the box, once there is one.
  _Understood? _understood;

  @override
  void dispose() {
    _typingPause?.cancel();
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

  void _push(Widget screen) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen));
  }

  /// Message → intent and first-aid card, timed. Any failure of the model
  /// counts as no match, which sends the message to keyword search.
  Future<_Understood> _match(String text) async {
    final scope = AppScope.of(context);
    final watch = Stopwatch()..start();
    IntentDef? intent;
    try {
      final match = await scope.models.matcher?.match(text);
      intent = match == null ? null : scope.store.intent(match.intentId);
    } on Object {
      intent = null;
    }
    // Only a message about an injury can carry first aid. A failure here
    // means a card without it, never no card.
    FirstAidCard? firstAid;
    if (intent != null && FirstAidMatcher.intents.contains(intent.id)) {
      try {
        firstAid = await scope.models.firstAid?.match(text);
      } on Object {
        firstAid = null;
      }
    }
    watch.stop();
    return _Understood(text, intent, firstAid, watch.elapsed);
  }

  /// Matches the message once typing pauses, so the answer is on screen
  /// before "Find help" is pressed.
  void _typed(String value) {
    _typingPause?.cancel();
    _matchRound++;
    final text = value.trim();
    if (_understood != null && _understood!.text != text) {
      setState(() => _understood = null);
    }
    if (AppScope.of(context).models.matcher == null) return;
    if (text.split(RegExp(r'\s+')).length < _minWords) return;
    if (_understood?.text == text) return;
    final round = _matchRound;
    _typingPause = Timer(_pause, () async {
      final understood = await _match(text);
      if (!mounted || round != _matchRound || _matching) return;
      setState(() => _understood = understood);
    });
  }

  void _open(_Understood understood) {
    final intent = understood.intent;
    if (intent == null) {
      return _search(query: understood.text, fromMessage: true);
    }
    unawaited(
      _openCard(
        intent,
        message: understood.text,
        firstAid: understood.firstAid,
      ),
    );
  }

  /// Message → intent → card. Anything that is not clearly an emergency, and
  /// any failure of the model, goes to keyword search instead.
  Future<void> _findHelp() async {
    final text = _message.text.trim();
    if (text.isEmpty || _matching) return;
    _typingPause?.cancel();
    _matchRound++;
    if (AppScope.of(context).models.matcher == null) {
      return _search(query: text);
    }
    // Already matched while typing: do not embed the message twice.
    var understood = _understood;
    if (understood == null || understood.text != text) {
      setState(() => _matching = true);
      understood = await _match(text);
      if (!mounted) return;
      setState(() {
        _matching = false;
        _understood = understood;
      });
    }
    _open(understood);
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
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            scope.models,
            scope.timed,
            ?scope.protection,
          ]),
          builder: (context, _) {
            final models = scope.models;
            final understands = models.matcher != null;
            final understood = _understood;
            // Not while the model is still loading at start-up: the buttons
            // would show and then vanish a few seconds later.
            final noModel =
                models.embeddingState == ModelState.missing ||
                models.embeddingState == ModelState.failed;
            final quick = [
              for (final id in [
                ...CardLabels.quickIntents,
                // Without the model, typing cannot open these cards.
                if (noModel) ...CardLabels.typedIntents,
              ])
                if (byId[id] != null) byId[id]!,
            ];
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
                    const HomeBrand(),
                    StatusPill(
                      ready: models.allReady,
                      onPressed: () => _push(const SetupScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (emergency != null)
                  EmergencyButton(
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
                const Text(
                  'What happened?',
                  style: TextStyle(fontSize: 18, fontWeight: .w700),
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
                  onChanged: _typed,
                  onSubmitted: (_) => _findHelp(),
                ),
                const SizedBox(height: 8),
                if (understood != null && !_matching) ...[
                  UnderstoodStrip(
                    intentLabel: understood.intent?.label,
                    icon: understood.intent == null
                        ? null
                        : CardLabels.icon(understood.intent!.id),
                    iconColor: understood.intent == null
                        ? HudyatColors.ink
                        : CardLabels.iconColor(understood.intent!.id),
                    firstAidTitle: understood.firstAid?.title,
                    elapsed: understood.elapsed,
                    onPressed: () => _open(understood),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_matching)
                  const PrimaryButton(label: 'Finding help…', onPressed: null)
                else if (understands)
                  PrimaryButton(label: 'Find help', onPressed: _findHelp)
                else
                  PrimaryButton(label: 'Search', onPressed: _findHelp),
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
                const SizedBox(height: 22),
                GuardPanel(
                  status: scope.timed.status,
                  appsOn: scope.protection?.status.appsOn ?? false,
                  onOpenFlagged: () => _push(const FlaggedScreen()),
                  onOpenSettings: () => _push(const TimedCheckScreen()),
                  onCheckMessage: () => _push(const CheckScreen()),
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
                      '${store.meta.buildDate}',
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
