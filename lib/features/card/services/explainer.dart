import '../../../core/geo.dart';
import '../../../core/models/guarded_note.dart';
import '../../../core/models/model_runtime.dart';
import '../models/help_card.dart';

export '../../../core/models/guarded_note.dart' show hasInventedNumber;

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
  Stream<String> explain({required HelpCard card, String? message}) =>
      guardedNote(
        _generator,
        prompt: explainerPrompt(card: card, message: message),
        facts: cardFacts(card),
        timeout: timeout,
      );
}
