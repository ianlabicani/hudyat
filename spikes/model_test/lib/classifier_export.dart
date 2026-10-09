import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';

// Export is explicitly invoked in the spike. No input texts or vectors are
// bundled with the product or printed in its log.
Future<int> exportClassifierInputs(
  String modelsDir,
  List<dynamic> baselineExamples,
) async {
  final files = Directory(modelsDir).parent.path;
  final input = jsonDecode(
    await File('$files/classifier-inputs.json').readAsString(),
  ) as Map<String, dynamic>;
  final records = input['records'] as List;
  final model = await FlutterEdgeAi.getActiveEmbedder();
  final spec = FlutterEdgeAi.activeEmbedderSpec;
  if (spec == null) throw StateError('No active embedder');
  final paths = await FlutterEdgeAiPlugin.instance.modelManager
      .getModelFilePaths(spec);
  if (paths == null || paths.length != 2) {
    throw StateError('Model paths unavailable');
  }
  final modelFile = paths.values.singleWhere((p) => p.endsWith('.tflite'));
  final tokenizer = paths.values.singleWhere((p) => p.endsWith('.model'));
  Future<String> hash(String path) async =>
      (await sha256.bind(File(path).openRead()).first).toString();
  final fingerprint =
      'sha256:${await hash(modelFile)}:${await hash(tokenizer)}';
  List<double> norm(List<double> v) {
    final n = math.sqrt(v.fold<double>(0, (s, x) => s + x * x));
    if (n == 0 || !n.isFinite || v.any((x) => !x.isFinite)) {
      throw const FormatException('Invalid embedding');
    }
    return [for (final x in v) x / n];
  }

  // Baseline intentionally retains its existing document examples. Every
  // classifier input below uses the query task, including training examples.
  final baseline = <List<double>>[];
  for (final example in baselineExamples) {
    baseline.add(
      norm(
        await model.generateEmbedding(
          example['text'] as String,
          taskType: TaskType.retrievalDocument,
        ),
      ),
    );
  }
  final vectors = <Map<String, Object>>[];
  final scores = <String, double>{};
  for (final record in records) {
    final vector = norm(
      await model.generateEmbedding(
        record['text'] as String,
        taskType: TaskType.retrievalQuery,
      ),
    );
    final id = record['id'] as String;
    vectors.add({'id': id, 'vector': vector});
    var best = -1.0;
    for (final candidate in baseline) {
      if (candidate.length != vector.length) {
        throw const FormatException('Dimension mismatch');
      }
      var dot = 0.0;
      for (var i = 0; i < vector.length; i++) {
        dot += vector[i] * candidate[i];
      }
      best = math.max(best, dot);
    }
    scores[id] = best;
  }
  await File('$files/classifier-vectors.json').writeAsString(
    jsonEncode({
      'preprocessing': 'query-l2-v1',
      'task': 'retrievalQuery',
      'fingerprint': fingerprint,
      'corpus_sha256': input['corpus_sha256'],
      'dimension': await model.getDimension(),
      'records': vectors,
      'baseline_scores': scores,
      'baseline_threshold': 0.56,
      'baseline_version':
          'phrasing:${sha256.convert(utf8.encode(jsonEncode({
            'algorithm': 'nearest-example-v1',
            'threshold': 0.56,
            'examples': [
              for (final e in baselineExamples) [e['text'], e['type_label']],
            ],
          })))}',
    }),
  );
  return vectors.length;
}
