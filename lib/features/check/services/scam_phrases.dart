import 'dart:io';

import '../../../core/models/example_vectors.dart';
import '../../../core/models/model_runtime.dart';
import '../../../core/pack/scam_records.dart';

/// The phrasing check: how close a message is to known scam wording.
class ScamPhrases {
  ScamPhrases({
    required TextEmbedder embedder,
    required this._examples,
    this.threshold = defaultThreshold,
    File? cacheFile,
  }) : _vectors = ExampleVectors(
         embedder: embedder,
         phrases: [for (final example in _examples) example.text],
         cacheFile: cacheFile,
       );

  /// Measured on the Infinix on 2026-10-09 with 20 held-out scam messages
  /// and 25 ordinary ones: the closest ordinary message scored 0.546, and
  /// 12 of the 20 scam messages scored above this. Measure again if the
  /// examples or the model change.
  static const defaultThreshold = 0.56;

  final List<ScamExample> _examples;
  final ExampleVectors _vectors;
  final double threshold;

  bool get isReady => _vectors.isReady;

  Future<void> prepare({void Function(int done, int total)? onProgress}) =>
      _vectors.prepare(onProgress: onProgress);

  /// The closest scam example and its score, with no threshold applied.
  Future<(ScamExample, double)?> nearest(String text) async {
    final scores = await _vectors.scores(text);
    if (scores.isEmpty) return null;
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return (_examples[best], scores[best]);
  }

  /// The kind of scam [text] reads like, or null when it is not close
  /// enough to any example.
  Future<String?> match(String text) async {
    final found = await nearest(text);
    if (found == null || found.$2 < threshold) return null;
    return found.$1.typeLabel;
  }
}
