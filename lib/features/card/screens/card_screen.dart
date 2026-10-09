import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/calls.dart';
import '../../../core/pack/first_aid_card.dart';
import '../../../core/pack/pack_record.dart';
import '../../../core/pack/pack_store.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ai_note.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/panels.dart';
import '../../../core/widgets/rows.dart';
import '../../location/screens/pick_city_screen.dart';
import '../../location/state/location_controller.dart';
import '../../map/screens/map_screen.dart';
import '../../map/services/map_file.dart';
import '../card_labels.dart';
import '../models/help_card.dart';
import '../services/explainer.dart';
import '../widgets/card_header.dart';
import '../widgets/first_aid_section.dart';
import '../widgets/lead_call.dart';

/// The help card for one intent. It is built from the pack alone and shows
/// at once; nothing here waits for a model.
class CardScreen extends StatefulWidget {
  const CardScreen({
    required this.intent,
    this.message,
    this.firstAid,
    super.key,
  });

  final IntentDef intent;

  /// The first-aid card [message] matched, shown under the hotlines.
  final FirstAidCard? firstAid;

  /// What the user typed, when the card came from a message rather than a
  /// quick button. Only the AI note uses it.
  final String? message;

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  /// How many hotlines show before "Show all".
  static const _collapsedHotlines = 4;

  bool _showAllHotlines = false;

  /// Path of the offline map, or null until it is ready or if this build
  /// has none. Place rows only open the map when it is set.
  String? _mapPath;

  @override
  void initState() {
    super.initState();
    mapFile().then((path) {
      if (mounted) setState(() => _mapPath = path);
    });
  }

  void _openMap(HelpCard card, PlaceHit hit, LocationController location) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          mapPath: _mapPath!,
          place: hit.place,
          others: [for (final other in card.places) other.place],
          position: location.position,
        ),
      ),
    );
  }

  /// The AI note, started once for the first card shown.
  Stream<String>? _note;

  /// Null on a card with first aid: generated sentences never sit next to
  /// fixed first-aid steps.
  Stream<String>? _noteFor(HelpCard card) {
    final generator = AppScope.of(context).models.generator;
    if (generator == null || card.firstAid != null) return null;
    return _note ??= Explainer(generator)
        .explain(card: card, message: widget.message)
        .asBroadcastStream();
  }

  Future<void> _changeCity() async {
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const PickCityScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.location,
      builder: (context, _) {
        final location = scope.location;
        final card = scope.resolver.resolve(
          intent: widget.intent,
          city: location.city!,
          citySource: location.source!,
          position: location.position,
          firstAid: widget.firstAid,
        );
        return Scaffold(
          appBar: const TopBar(title: 'Help card'),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(HudyatShape.gutter),
              children: [
                CardHeader(card: card, onChangeCity: _changeCity),
                if (location.busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (card.hotlines.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  ..._hotlineSection(card),
                ],
                if (card.firstAid case final firstAid?) ...[
                  const SizedBox(height: 22),
                  FirstAidSection(card: firstAid),
                ],
                if (card.intent.placeKinds.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  ..._placeSection(card, location),
                ],
                if (_noteFor(card) case final note?) AiNote(text: note),
                const SizedBox(height: 22),
                PackFooter(
                  buildDate: card.buildDate,
                  hotlineSources: {
                    for (final hotline in card.hotlines) hotline.source,
                  }.toList(),
                  showsPlaces: card.places.isNotEmpty,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _hotlineSection(HelpCard card) {
    final shown = _showAllHotlines
        ? card.hotlines
        : card.hotlines.take(_collapsedHotlines).toList();
    final hidden = card.hotlines.length - shown.length;
    final emergency = card.nationalEmergency;
    return [
      if (card.isFallback) ...[
        Notice(
          title: 'No hotline listed for ${card.city}',
          body: card.hotlineLevel == HotlineLevel.province
              ? 'Showing ${card.hotlineLevelName} numbers instead. '
                    'They cover your city.'
              : 'Showing national numbers instead. A city or province '
                    'office may be faster if you can reach one.',
        ),
        const SizedBox(height: 22),
      ],
      SectionHeading(
        title: 'Call now',
        trailing: LevelBadge(
          level: card.hotlineLevel,
          name: card.hotlineLevelName,
        ),
      ),
      for (final (index, hotline) in shown.indexed) ...[
        const SizedBox(height: 10),
        // The first number is the one to call: it gets the whole width.
        if (index == 0 && hotline.dialable.isNotEmpty)
          LeadCall(record: hotline, onCall: () => callRecord(context, hotline))
        else
          HotlineRow(
            record: hotline,
            onCall: () => callRecord(context, hotline),
          ),
      ],
      if (hidden > 0) ...[
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Show all ${card.hotlines.length} numbers',
          onPressed: () => setState(() => _showAllHotlines = true),
        ),
      ],
      if (emergency != null) ...[
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: Text(
                'Works anywhere in the country',
                style: HudyatText.secondary,
              ),
            ),
            LevelBadge(level: HotlineLevel.national),
          ],
        ),
        const SizedBox(height: 10),
        HotlineRow(
          record: emergency,
          onCall: () => callRecord(context, emergency),
        ),
      ],
    ];
  }

  List<Widget> _placeSection(HelpCard card, LocationController location) {
    final labels = CardLabels.places(card.intent.placeKinds.first);
    final byDistance = card.hasDistances;
    return [
      SectionHeading(
        title: byDistance
            ? 'Nearest $labels'
            : '${_capitalise(labels)} in ${card.city}',
        trailing: Text(
          byDistance ? 'Straight-line distance' : 'Distances hidden',
          style: HudyatText.gloss.copyWith(fontSize: 13),
        ),
      ),
      if (!byDistance) ...[
        const SizedBox(height: 10),
        Notice(
          title: 'No GPS fix',
          body:
              'We cannot say which is nearest. Turn on GPS to see '
              'distances.',
          action: SecondaryButton(
            label: location.busy ? 'Looking for GPS…' : 'Try GPS again',
            expand: false,
            onPressed: location.busy ? null : location.refresh,
          ),
        ),
      ],
      if (card.places.isEmpty) ...[
        const SizedBox(height: 10),
        Text(
          'No $labels listed in ${card.city} in this pack.',
          style: HudyatText.secondary,
        ),
      ],
      for (final hit in card.places) ...[
        const SizedBox(height: 10),
        PlaceRow(
          place: hit.place,
          distanceKm: hit.distanceKm,
          onTap: _mapPath == null ? null : () => _openMap(card, hit, location),
        ),
      ],
    ];
  }

  String _capitalise(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
