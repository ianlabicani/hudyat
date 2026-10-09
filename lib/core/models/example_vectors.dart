import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'model_runtime.dart';

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

/// A fixed list of example phrases and their vectors. The vectors are
/// computed on this phone, so they always match its model, and are kept in
/// [cacheFile] between launches.
class ExampleVectors {
  ExampleVectors({
    required this._embedder,
    required this.phrases,
    this.cacheFile,
  });

  final TextEmbedder _embedder;
  final List<String> phrases;
  final File? cacheFile;

  List<List<double>> _vectors = const [];

  bool get isReady => phrases.isNotEmpty && _vectors.length == phrases.length;

  /// Embeds every phrase, or reads them back from the cache. Embedding takes
  /// about a second per phrase on a phone, so [onProgress] reports how many
  /// are done.
  Future<void> prepare({void Function(int done, int total)? onProgress}) async {
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
    _vectors = vectors;
  }

  /// How close [text] is to each phrase, in phrase order. Empty until
  /// [prepare] has run, or for blank text.
  Future<List<double>> scores(String text) async {
    if (!isReady || text.trim().isEmpty) return const [];
    final query = (await _embedder.embed([text], asQuery: true)).single;
    return [for (final vector in _vectors) cosine(query, vector)];
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
