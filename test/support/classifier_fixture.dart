import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hudyat/core/models/model_runtime.dart';
import 'package:hudyat/features/check/services/suspicious_classifier.dart';

final fixtureFingerprint = 'sha256:${'a' * 64}:${'b' * 64}';
Map<String, dynamic> classifierEnvelope({
  bool approved = false,
  int dimension = 2,
}) {
  final payload = jsonEncode({
    'schema': 1,
    'preprocessing': 'query-l2-v1',
    'dimension': dimension,
    'fingerprint': fixtureFingerprint,
    'heads': {
      for (final label in SuspiciousLabel.values)
        label.name: {
          'weights': List.filled(dimension, 0.0),
          'bias': 0.0,
          'threshold': 0.5,
        },
    },
  });
  final version = sha256.convert(utf8.encode(payload)).toString();
  return {
    'payload': payload,
    'version': version,
    if (approved)
      'release': {
        'artifact_version': version,
        'evaluation_passed': true,
        'phone_verified': true,
        'regression_scams': 20,
        'regression_detected': 13,
        'final_scams': 20,
        'final_ordinary': 100,
        'final_detected': 15,
        'baseline_detected': 12,
        'additional_ordinary_warnings': 0,
        'report_sha256': 'c' * 64,
        'phone_checks': {
          'offline': true,
          'responsive': true,
          'resumable': true,
          'fallback': true,
        },
      },
  };
}

class VectorEmbedder implements IdentifiedEmbedder {
  int calls = 0;
  bool? query;
  String? identity = fixtureFingerprint;
  @override
  Future<int> dimension() async => 2;

  @override
  Future<String?> fingerprint() async => identity;
  @override
  Future<List<List<double>>> embed(
    List<String> texts, {
    required bool asQuery,
  }) async {
    calls++;
    query = asQuery;
    return [
      for (final _ in texts) [3.0, 4.0],
    ];
  }
}
