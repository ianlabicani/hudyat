import 'dart:async';

import '../../../core/geo.dart';
import '../../../core/models/model_runtime.dart';
import '../models/help_card.dart';

/// The card facts the chat model is allowed to talk about. Phone numbers are
/// deliberately left out: the model cannot repeat what it was never given.
String cardFacts(HelpCard card) {
  final nearest = card.places.isEmpty ? null : card.places.first;
  final distance = nearest?.distanceKm;
  return [
    'need: ${card.intent.label}',
    'city: ${card.city}',
    if (card.hotlines.isNotEmpty) 'call first: ${card.hotlines.first.name}',
    if (card.hotlines.length > 1) 'also: ${card.hotlines[1].name}',
    if (nearest != null)
      'nearest place: ${nearest.place.name}'
          '${distance == null ? '' : ' (${formatDistance(distance)} away)'}',
  ].join('\n');
}

String explainerPrompt({required HelpCard card, String? message}) =>
    'Ikaw ay tumutulong sa taong nangangailangan ng tulong. Sumulat ng isa o '
    'dalawang maikli at mahinahong pangungusap sa Taglish na nagsasabi kung '
    'sino ang unang tatawagan at saan ang pinakamalapit na mapupuntahan.\n'
    'Rules: Use only the FACTS. Do not add phone numbers, names, places or '
    'steps that are not in the FACTS. Do not give medical advice.\n'
    '${message == null ? '' : 'MESSAGE: $message\n'}'
    'FACTS:\n${cardFacts(card)}';

/// Whether [text] contains a run of three or more digits that is not in
/// [facts]. Such a run would be a number the model made up, so the note is
/// thrown away rather than shown.
bool hasInventedNumber(String text, String facts) =>
    RegExp(r'\d[\d\s().-]{1,}\d')
        .allMatches(text)
        .map((m) => m.group(0)!.replaceAll(RegExp(r'\D'), ''))
        .any(
          (digits) =>
              digits.length >= 3 &&
              !facts.replaceAll(RegExp(r'\D'), '').contains(digits),
        );

/// Streams the optional Taglish note for a card (spec 3.2). The stream ends
/// quietly on any error or when the model is too slow; the card is never
/// affected.
class Explainer {
  Explainer(this._generator, {this.timeout = const Duration(seconds: 12)});

  final TextGenerator _generator;

  /// Longest wait for the next piece of text before giving up.
  final Duration timeout;

  /// Emits the note so far each time it grows. Emits an empty string if the
  /// model wrote a number that is not in the card's facts.
  Stream<String> explain({required HelpCard card, String? message}) async* {
    final facts = cardFacts(card);
    final note = StringBuffer();
    try {
      final tokens = _generator
          .generate(explainerPrompt(card: card, message: message))
          .timeout(timeout);
      await for (final token in tokens) {
        note.write(token);
        final text = note.toString().trim();
        if (hasInventedNumber(text, facts)) {
          yield '';
          return;
        }
        if (text.isNotEmpty) yield text;
      }
    } on Object {
      // Missing, slow or failing model: the note simply does not appear.
    }
  }
}
