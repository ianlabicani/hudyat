import 'dart:io';

import '../../../core/models/example_vectors.dart';
import '../../../core/models/model_runtime.dart';
import '../../../core/pack/pack_record.dart';

export '../../../core/models/example_vectors.dart' show cosine;

/// The decision step's whole output: an intent id and a score, never text.
class IntentMatch {
  const IntentMatch(this.intentId, this.score);

  final String intentId;
  final double score;
}

/// Maps a message to one of the pack's fixed intents by comparing its
/// embedding with each intent's example phrases (spec 3.1).
class IntentMatcher {
  IntentMatcher({
    required this._embedder,
    required this._intents,
    this.threshold = defaultThreshold,
    this.cacheFile,
  });

  /// Scores below this are treated as an everyday lookup. Measured on the
  /// Infinix on 2026-10-09: over 33 test messages, real emergencies scored
  /// 0.506 or more and small talk 0.470 or less. Measure again if the example
  /// phrases or the model change.
  static const defaultThreshold = 0.49;

  /// When a calm intent wins but an urgent one is this close behind, the
  /// urgent one is used. Sending a possible emergency to a clinic list is the
  /// costlier mistake.
  static const escalationMargin = 0.04;
  static const _urgent = ['medical_emergency', 'injury'];
  static const _calm = ['need_clinic', 'need_medicine'];

  /// The intent that means "not an emergency": it sends the user to search.
  static const lookupIntent = 'general_lookup';

  final TextEmbedder _embedder;
  final List<IntentDef> _intents;
  final double threshold;

  /// Where example vectors are kept between launches, so they are computed
  /// on this phone once and always match its model.
  final File? cacheFile;

  late final _ids = [
    for (final intent in _intents)
      for (final _ in intent.examples) intent.id,
  ];
  late final _examples = ExampleVectors(
    embedder: _embedder,
    phrases: [for (final intent in _intents) ...intent.examples],
    cacheFile: cacheFile,
  );

  bool get isReady => _examples.isReady;

  /// Embeds every example phrase, or reads them back from the cache.
  Future<void> prepare({void Function(int done, int total)? onProgress}) =>
      _examples.prepare(onProgress: onProgress);

  /// The intent to act on for [message], or null when the message should go
  /// to keyword search instead: nothing scored high enough, or the best
  /// match was the lookup intent.
  Future<IntentMatch?> match(String message) async {
    final scores = await scoreAll(message);
    if (scores.isEmpty) return null;
    var best = scores.first;
    if (_calm.contains(best.intentId)) {
      for (final other in scores) {
        if (_urgent.contains(other.intentId) &&
            other.score >= best.score - escalationMargin) {
          best = other;
          break;
        }
      }
    }
    if (best.score < threshold || best.intentId == lookupIntent) return null;
    return best;
  }

  /// The top-scoring intent with no threshold or escalation applied.
  Future<IntentMatch?> rank(String message) async {
    final scores = await scoreAll(message);
    return scores.isEmpty ? null : scores.first;
  }

  /// Every intent with the score of its closest example, best first. An
  /// intent is as close as its single nearest phrase: on the phone that beat
  /// averaging several phrases or comparing with an intent's centre.
  Future<List<IntentMatch>> scoreAll(String message) async {
    final scores = await _examples.scores(message);
    final best = <String, double>{};
    for (var i = 0; i < scores.length; i++) {
      if (scores[i] > (best[_ids[i]] ?? -1)) best[_ids[i]] = scores[i];
    }
    return [
      for (final entry in best.entries) IntentMatch(entry.key, entry.value),
    ]..sort((a, b) => b.score.compareTo(a.score));
  }
}
