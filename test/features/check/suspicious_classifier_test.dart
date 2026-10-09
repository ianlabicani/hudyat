import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/models/model_manager.dart';
import 'package:hudyat/features/check/models/check_result.dart';
import 'package:hudyat/features/check/services/message_checker.dart';
import 'package:hudyat/features/check/services/suspicious_classifier.dart';

import '../../support/classifier_fixture.dart';
import '../../support/fixture_pack.dart';

void main() {
  test('valid payload is disabled without a complete release gate', () {
    expect(
      SuspiciousArtifact.fromJson(classifierEnvelope())!.approved,
      isFalse,
    );
    final approved = classifierEnvelope(approved: true);
    expect(SuspiciousArtifact.fromJson(approved)!.approved, isTrue);
    (approved['release'] as Map)['final_ordinary'] = 99;
    expect(SuspiciousArtifact.fromJson(approved)!.approved, isFalse);
  });
  test(
    'rejects stale hashes, bad dimensions, preprocessing and missing heads',
    () {
      final envelope = classifierEnvelope();
      envelope['version'] = 'stale';
      expect(SuspiciousArtifact.fromJson(envelope), isNull);
      for (final patch in [
        {'dimension': 3},
        {'preprocessing': 'document'},
        {'fingerprint': 'wrong'},
        {'heads': {}},
      ]) {
        final changed = classifierEnvelope();
        final payload =
            jsonDecode(changed['payload'] as String) as Map<String, dynamic>;
        payload.addAll(patch);
        changed['payload'] = jsonEncode(payload);
        changed['version'] = sha256
            .convert(utf8.encode(changed['payload'] as String))
            .toString();
        expect(SuspiciousArtifact.fromJson(changed), isNull);
      }
    },
  );
  test(
    'normalizes vectors, includes equality at threshold, rejects invalid input',
    () {
      final artifact = SuspiciousArtifact.fromJson(classifierEnvelope())!;
      expect(artifact.labels([3, 4]), SuspiciousLabel.values);
      expect(artifact.scores([30, 40]), artifact.scores([3, 4]));
      for (final vector in [
        [0.0, 0.0],
        [1.0],
        [double.nan, 1.0],
      ]) {
        expect(() => artifact.scores(vector), throwsFormatException);
      }
    },
  );
  test('scores match the independently computed Python fixture', () {
    final fixture = jsonDecode(
      File('pack/classifier/score_fixture.json').readAsStringSync(),
    ) as Map;
    final artifact = SuspiciousArtifact.fromJson(
      Map<String, dynamic>.from(fixture['artifact'] as Map),
    )!;
    final scores = artifact.scores(
      (fixture['vector'] as List).map((v) => (v as num).toDouble()).toList(),
    );
    for (final label in SuspiciousLabel.values) {
      expect(
        scores[label],
        closeTo((fixture['scores'] as Map)[label.name] as num, 1e-12),
      );
    }
  });
  test('one query embedding serves all labels', () async {
    final embedder = VectorEmbedder();
    final classifier = LinearSuspiciousClassifier(
      SuspiciousArtifact.fromJson(classifierEnvelope())!,
      embedder,
    );
    expect(await classifier.classify('text'), hasLength(5));
    expect(embedder.calls, 1);
    expect(embedder.query, isTrue);
  });
  test('several labels alone are caution; another group escalates; hard links stay scam', () async {
    final store = fixtureStore();
    addTearDown(store.close);
    final classifier = LinearSuspiciousClassifier(
      SuspiciousArtifact.fromJson(classifierEnvelope())!,
      VectorEmbedder(),
    );
    final checker = MessageChecker(
      senders: store.officialSenders(),
      classifier: () => classifier,
      shorteners: ['bit.ly'],
    );
    expect(
      (await checker.check('Send your password now')).verdict,
      Verdict.caution,
    );
    expect(
      (await checker.check('Send your password at bit.ly/code')).verdict,
      Verdict.scam,
    );
    expect(
      (await checker.check('GCash: go to gcash-fake.com')).verdict,
      Verdict.scam,
    );
    expect(
      (await checker.check('hi', phrasing: false)).phrasing,
      PhrasingState.skipped,
    );
  });
  test('model manager enables only matching approved artifact and falls back otherwise', () async {
    final store = fixtureStore();
    addTearDown(store.close);
    for (final approved in [false, true]) {
      for (final matching in [false, true]) {
        final embedder = VectorEmbedder()
          ..identity = matching ? fixtureFingerprint : null;
        final manager = ModelManager(
          runtime: FakeRuntime(embedder: embedder),
          intents: [],
          scamExamples: store.scamExamples(),
          suspiciousArtifact: SuspiciousArtifact.fromJson(
            classifierEnvelope(approved: approved),
          ),
        );
        await manager.load();
        expect(manager.suspiciousClassifier != null, approved && matching);
        expect(manager.scamPhrases!.isReady, isTrue);
        manager.dispose();
      }
    }
  });
  test('dimension mismatch falls back; explicit debug trial can exercise an unapproved candidate', () async {
    final store = fixtureStore();
    addTearDown(store.close);
    final mismatch = ModelManager(
      runtime: FakeRuntime(embedder: VectorEmbedder()),
      intents: [],
      scamExamples: store.scamExamples(),
      suspiciousArtifact: SuspiciousArtifact.fromJson(
        classifierEnvelope(approved: true, dimension: 3),
      ),
    );
    await mismatch.load();
    expect(mismatch.suspiciousClassifier, isNull);
    expect(mismatch.scamPhrases!.isReady, isTrue);
    mismatch.dispose();
    final trial = ModelManager(
      runtime: FakeRuntime(embedder: VectorEmbedder()),
      intents: [],
      phoneTest: true,
      suspiciousArtifact: SuspiciousArtifact.fromJson(classifierEnvelope()),
    );
    await trial.load();
    expect(trial.suspiciousClassifier, isNotNull);
    trial.dispose();
  });
}
