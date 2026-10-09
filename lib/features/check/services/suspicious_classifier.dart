import '../../../core/models/model_runtime.dart';
import '../../../core/models/suspicious_artifact.dart';
export '../../../core/models/suspicious_artifact.dart';

abstract interface class SuspiciousClassifier {
  String get version;
  Future<List<SuspiciousLabel>> classify(String text);
}

class LinearSuspiciousClassifier implements SuspiciousClassifier {
  LinearSuspiciousClassifier(this.artifact, this._embedder);
  final SuspiciousArtifact artifact;
  final TextEmbedder _embedder;

  @override
  String get version => artifact.version;

  @override
  Future<List<SuspiciousLabel>> classify(String text) async {
    if (text.trim().isEmpty) return const [];
    final vector = (await _embedder.embed([text], asQuery: true)).single;
    return artifact.labels(vector);
  }
}
