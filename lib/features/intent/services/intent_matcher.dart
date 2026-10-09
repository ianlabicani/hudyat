import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../../core/models/model_runtime.dart';
import '../../../core/pack/pack_record.dart';

/// The decision step's whole output: an intent id and a score, never text.
class IntentMatch {
  const IntentMatch(this.intentId, this.score);

  final String intentId;
  final double score;
}

double cosine(List<double> a, List<double> b) {
  var dot = 0.0, normA = 0.0, normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA == 0 || normB == 0) return 0;
  return dot / (math.sqrt(normA) * math.sqrt(normB));
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

  final _ids = <String>[];
  final _vectors = <List<double>>[];

  bool get isReady => _vectors.isNotEmpty;

  /// Embeds every example phrase, or reads them back from the cache.
  /// Embedding takes about a second per phrase on a phone, so [onProgress]
  /// reports how many are done.
  Future<void> prepare({void Function(int done, int total)? onProgress}) async {
    final phrases = <String>[];
    final ids = <String>[];
    for (final intent in _intents) {
      for (final example in intent.examples) {
        ids.add(intent.id);
        phrases.add(example);
      }
    }
    final key = _fingerprint(phrases);
    var vectors = _readCache(key);
    if (vectors == null || vectors.length != phrases.length) {
      vectors = [];
      const batch = 5;
      for (var start = 0; start < phrases.length; start += batch) {
        final end = (start + batch).clamp(0, phrases.length);
        vectors.addAll(
          await _embedder.embed(phrases.sublist(start, end), asQuery: false),
        );
        onProgress?.call(end, phrases.length);
      }
      _writeCache(key, vectors);
    }
    _ids
      ..clear()
      ..addAll(ids);
    _vectors
      ..clear()
      ..addAll(vectors);
  }

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
    if (!isReady || message.trim().isEmpty) return const [];
    final query = (await _embedder.embed([message], asQuery: true)).single;
    final best = <String, double>{};
    for (var i = 0; i < _vectors.length; i++) {
      final score = cosine(query, _vectors[i]);
      if (score > (best[_ids[i]] ?? -1)) best[_ids[i]] = score;
    }
    return [
      for (final entry in best.entries) IntentMatch(entry.key, entry.value),
    ]..sort((a, b) => b.score.compareTo(a.score));
  }

  /// Changes whenever the phrases do, so a stale cache is never used.
  String _fingerprint(List<String> phrases) {
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(phrases.join('\n'))) {
      hash = ((hash ^ unit) * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }

  List<List<double>>? _readCache(String key) {
    final file = cacheFile;
    if (file == null || !file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      if (json['key'] != key) return null;
      return [
        for (final vector in json['vectors'] as List)
          [for (final value in vector as List) (value as num).toDouble()],
      ];
    } on Object {
      return null;
    }
  }

  void _writeCache(String key, List<List<double>> vectors) {
    try {
      cacheFile?.writeAsStringSync(
        jsonEncode({'key': key, 'vectors': vectors}),
      );
    } on FileSystemException {
      // The cache only saves time; matching works without it.
    }
  }
}
