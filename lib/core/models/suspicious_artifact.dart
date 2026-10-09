import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

enum SuspiciousLabel { credentials, money, action, pressure, bait }

/// Validated numerical payload. Release approval is checked separately so
/// experiments can score fixtures without enabling an unmeasured artifact.
class SuspiciousArtifact {
  SuspiciousArtifact._(
    this.version,
    this.fingerprint,
    this.dimension,
    this.heads,
    this.approved,
  );

  static const preprocessing = 'query-l2-v1';
  final String version;
  final String fingerprint;
  final int dimension;
  final Map<SuspiciousLabel, LinearHead> heads;
  final bool approved;

  static SuspiciousArtifact? fromJson(Map<String, dynamic> json) {
    try {
      final payload = json['payload'] as String;
      final version = sha256.convert(utf8.encode(payload)).toString();
      if (json['version'] != version) return null;
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final dimension = data['dimension'] as int;
      final fingerprint = data['fingerprint'] as String;
      if (data['schema'] != 1 ||
          data['preprocessing'] != preprocessing ||
          dimension < 1 ||
          dimension > 4096 ||
          !RegExp(r'^sha256:[a-f0-9]{64}:[a-f0-9]{64}$')
              .hasMatch(fingerprint)) {
        return null;
      }
      final entries = data['heads'] as Map<String, dynamic>;
      if (entries.length != SuspiciousLabel.values.length) return null;
      final heads = <SuspiciousLabel, LinearHead>{};
      for (final label in SuspiciousLabel.values) {
        final head = entries[label.name] as Map<String, dynamic>;
        final weights = (head['weights'] as List)
            .map((w) => (w as num).toDouble())
            .toList();
        final bias = (head['bias'] as num).toDouble();
        final threshold = (head['threshold'] as num).toDouble();
        if (weights.length != dimension ||
            weights.any((w) => !w.isFinite) ||
            !bias.isFinite ||
            !threshold.isFinite ||
            threshold <= 0 ||
            threshold > 1) {
          return null;
        }
        heads[label] = LinearHead(List.unmodifiable(weights), bias, threshold);
      }
      final release = json['release'] as Map<String, dynamic>?;
      var approved = false;
      try {
        approved =
            release != null &&
            const [
              'regression_scams',
              'regression_detected',
              'final_scams',
              'final_ordinary',
              'final_detected',
              'baseline_detected',
              'additional_ordinary_warnings',
            ].every(
              (key) => release[key] is int && (release[key] as int) >= 0,
            ) &&
            (release['regression_detected'] as int) <=
                (release['regression_scams'] as int) &&
            (release['final_detected'] as int) <=
                (release['final_scams'] as int) &&
            (release['baseline_detected'] as int) <=
                (release['final_scams'] as int) &&
            release['artifact_version'] == version &&
            release['evaluation_passed'] == true &&
            release['phone_verified'] == true &&
            release['regression_scams'] == 20 &&
            (release['regression_detected'] as num) >= 13 &&
            (release['final_scams'] as num) >= 20 &&
            (release['final_ordinary'] as num) >= 100 &&
            (release['final_detected'] as num) >
                (release['baseline_detected'] as num) &&
            release['additional_ordinary_warnings'] == 0 &&
            RegExp(r'^[a-f0-9]{64}$')
                .hasMatch(release['report_sha256'] as String) &&
            (release['phone_checks'] as Map).values.every((v) => v == true) &&
            (release['phone_checks'] as Map).keys.toSet().containsAll([
              'offline',
              'responsive',
              'resumable',
              'fallback',
            ]);
      } on Object {
        approved = false;
      }
      return SuspiciousArtifact._(
        version,
        fingerprint,
        dimension,
        Map.unmodifiable(heads),
        approved,
      );
    } on Object {
      return null;
    }
  }

  Map<SuspiciousLabel, double> scores(List<double> vector) {
    if (vector.length != dimension || vector.any((v) => !v.isFinite)) {
      throw const FormatException('Invalid classifier embedding');
    }
    final norm = math.sqrt(vector.fold<double>(0, (sum, v) => sum + v * v));
    if (!norm.isFinite || norm == 0) {
      throw const FormatException('Zero embedding');
    }
    final normalized = [for (final value in vector) value / norm];
    return {
      for (final entry in heads.entries)
        entry.key: entry.value.score(normalized),
    };
  }

  List<SuspiciousLabel> labels(List<double> vector) => [
    for (final entry in scores(vector).entries)
      if (entry.value >= heads[entry.key]!.threshold) entry.key,
  ];
}

class LinearHead {
  const LinearHead(this.weights, this.bias, this.threshold);
  final List<double> weights;
  final double bias;
  final double threshold;

  double score(List<double> vector) {
    var logit = bias;
    for (var i = 0; i < weights.length; i++) {
      logit += weights[i] * vector[i];
    }
    if (logit.isNaN) throw const FormatException('Invalid classifier score');
    // Stable sigmoid, including very large positive/negative logits.
    if (logit >= 0) return 1 / (1 + math.exp(-logit));
    final exp = math.exp(logit);
    return exp / (1 + exp);
  }
}
