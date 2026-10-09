import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/models/example_vectors.dart';
import '../../../core/models/model_runtime.dart';
import '../../../core/pack/first_aid_card.dart';

/// Picks the first-aid card a message is about, by comparing its embedding
/// with each card's example phrases (spec 3.1). The output is a card from
/// the pack or nothing; no text is generated.
class FirstAidMatcher {
  FirstAidMatcher({
    required TextEmbedder embedder,
    required this._cards,
    this.threshold = defaultThreshold,
    File? cacheFile,
  }) : _vectors = ExampleVectors(
         embedder: embedder,
         phrases: [for (final card in _cards) ...card.examples],
         cacheFile: cacheFile,
       );

  /// Not yet measured on the phone. It starts at the scam check's value,
  /// which is on the strict side: showing the wrong first aid is worse than
  /// showing none. Measure with real messages and set it from the scores
  /// this class logs in a debug build.
  static const defaultThreshold = 0.56;

  /// The intents whose card may carry first aid (spec 3.1). A message
  /// about anything else gets none, however close it is to a card: a flood
  /// message with no one hurt once matched "Broken bone".
  static const intents = {'injury'};

  final List<FirstAidCard> _cards;
  final ExampleVectors _vectors;
  final double threshold;

  /// The card each example phrase belongs to, in phrase order.
  late final _owners = [
    for (final card in _cards)
      for (final _ in card.examples) card,
  ];

  bool get isReady => _vectors.isReady;

  /// Embeds every example phrase, or reads them back from the cache.
  Future<void> prepare({void Function(int done, int total)? onProgress}) =>
      _vectors.prepare(onProgress: onProgress);

  /// The card with the closest example and its score, with no threshold
  /// applied.
  Future<(FirstAidCard, double)?> nearest(String message) async {
    final scores = await _vectors.scores(message);
    if (scores.isEmpty) return null;
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return (_owners[best], scores[best]);
  }

  /// The card to show for [message], or null when none is close enough.
  Future<FirstAidCard?> match(String message) async {
    final found = await nearest(message);
    if (found == null) return null;
    final (card, score) = found;
    if (kDebugMode) {
      debugPrint('FirstAidMatcher: ${card.id} ${score.toStringAsFixed(3)}');
    }
    return score < threshold ? null : card;
  }
}
