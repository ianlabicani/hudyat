import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/models/model_manager.dart';
import 'package:hudyat/core/models/model_runtime.dart';
import 'package:hudyat/core/pack/pack_record.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/features/intent/services/intent_matcher.dart';

import '../../support/fixture_pack.dart';

void main() {
  late PackStore store;
  late FakeEmbedder embedder;
  late Directory dir;

  setUp(() {
    store = fixtureStore();
    embedder = FakeEmbedder();
    dir = Directory.systemTemp.createTempSync('hudyat-matcher-');
  });
  tearDown(() {
    store.close();
    dir.deleteSync(recursive: true);
  });

  IntentMatcher matcher({double threshold = 0.5, File? cache}) => IntentMatcher(
    embedder: embedder,
    intents: store.intents(),
    threshold: threshold,
    cacheFile: cache,
  );

  test('cosine is 1 for the same direction, 0 for unrelated or empty', () {
    expect(cosine([1, 2, 0], [2, 4, 0]), closeTo(1, 1e-9));
    expect(cosine([1, 0], [0, 1]), 0);
    expect(cosine([0, 0], [1, 1]), 0);
  });

  group('match', () {
    test('returns the intent whose example is closest', () async {
      final m = matcher();
      await m.prepare();
      expect(
        (await m.match('dalhin sa ospital, hindi makahinga'))?.intentId,
        'medical_emergency',
      );
      expect((await m.match('bibili ng gamot'))?.intentId, 'need_medicine');
      expect((await m.match('ang daming dugo'))?.intentId, 'injury');
    });

    test('gives an id and a score, nothing else', () async {
      final m = matcher();
      await m.prepare();
      final match = (await m.match('nawalan ng malay'))!;
      expect(match.intentId, 'medical_emergency');
      expect(match.score, closeTo(1, 1e-9));
    });

    test('is null below the threshold', () async {
      // Shares one word of three with the nearest example: cosine about 0.58.
      const message = 'gamot at dugo at trapik';
      final loose = matcher(threshold: 0.5);
      await loose.prepare();
      expect(await loose.match(message), isNotNull);
      final strict = matcher(threshold: 0.9);
      await strict.prepare();
      expect(await strict.match(message), isNull);
    });

    test('is null when the lookup intent wins, or nothing is close', () async {
      final m = matcher();
      await m.prepare();
      expect(await m.match('paano mag renew ng passport'), isNull);
      expect(
        (await m.rank('paano mag renew ng passport'))?.intentId,
        IntentMatcher.lookupIntent,
      );
      expect(await m.match('kumusta'), isNull);
      expect(await m.match('   '), isNull);
    });

    test(
      'a calm intent gives way to an urgent one that is nearly as close',
      () async {
        // Clinic lies along the first axis; the emergency example sits 15
        // degrees away from it.
        final m = IntentMatcher(
          embedder: _TableEmbedder({
            'clinic example': [1, 0],
            'emergency example': [0.966, 0.259],
            'close call': [1, 0],
            'plainly a clinic': [1, -0.5],
          }),
          intents: const [
            IntentDef(
              id: 'need_clinic',
              label: 'Clinic',
              hotlineCategories: [],
              placeKinds: ['clinic'],
              examples: ['clinic example'],
            ),
            IntentDef(
              id: 'medical_emergency',
              label: 'Medical emergency',
              hotlineCategories: ['medical'],
              placeKinds: ['hospital'],
              examples: ['emergency example'],
            ),
          ],
        );
        await m.prepare();

        // Clinic scores highest (1.0 against 0.966), but the emergency is
        // within the margin, so the emergency card is shown.
        expect((await m.rank('close call'))?.intentId, 'need_clinic');
        expect((await m.match('close call'))?.intentId, 'medical_emergency');
        // Well clear of the margin (0.89 against 0.75): clinic stands.
        expect((await m.match('plainly a clinic'))?.intentId, 'need_clinic');
      },
    );

    test('is null before prepare has run', () async {
      expect(await matcher().match('ospital'), isNull);
    });
  });

  group('example vector cache', () {
    int exampleCount() =>
        store.intents().fold(0, (sum, intent) => sum + intent.examples.length);

    test('embeds each example once, then reads them back', () async {
      final cache = File('${dir.path}/vectors.json');
      final progress = <(int, int)>[];
      await matcher(cache: cache)
          .prepare(onProgress: (done, total) => progress.add((done, total)));
      expect(embedder.embedded, exampleCount());
      expect(progress.last, (exampleCount(), exampleCount()));
      expect(cache.existsSync(), isTrue);

      final second = matcher(cache: cache);
      await second.prepare();
      expect(embedder.embedded, exampleCount());
      expect(
        (await second.match('nawalan ng malay'))?.intentId,
        'medical_emergency',
      );
    });

    test(
      'ignores a cache written for different phrases, or a broken one',
      () async {
        final cache = File('${dir.path}/vectors.json')
          ..writeAsStringSync('{"key":"other","vectors":[[1.0]]}');
        await matcher(cache: cache).prepare();
        expect(embedder.embedded, exampleCount());

        cache.writeAsStringSync('not json');
        await matcher(cache: cache).prepare();
        expect(embedder.embedded, exampleCount() * 2);
      },
    );
  });

  group('ModelManager', () {
    test(
      'with no models: both missing, nothing ready, nothing thrown',
      () async {
        final models = ModelManager(
          runtime: FakeRuntime(),
          intents: store.intents(),
        );
        await models.load();
        expect(models.embeddingState, ModelState.missing);
        expect(models.chatState, ModelState.missing);
        expect(models.matcher, isNull);
        expect(models.generator, isNull);
        expect(models.sideloadFolder, '/phone/models');
      },
    );

    test(
      'with models on the phone: matcher prepared and generator set',
      () async {
        final models = ModelManager(
          runtime: FakeRuntime(
            embedder: embedder,
            generator: FakeGenerator(const ['ok']),
          ),
          intents: store.intents(),
        );
        await models.load();
        expect(models.allReady, isTrue);
        expect(models.matcher!.isReady, isTrue);
        expect(models.generator, isNotNull);
      },
    );

    test(
      'a model that fails to load is reported and does not stop the other',
      () async {
        final runtime = FakeRuntime(generator: FakeGenerator(const ['ok']))
          ..loadFailure = StateError('native library missing');
        final models = ModelManager(runtime: runtime, intents: store.intents());
        await models.load();
        expect(models.embeddingState, ModelState.failed);
        expect(models.embeddingError, contains('native library missing'));
        expect(models.matcher, isNull);
        expect(models.chatState, ModelState.ready);
      },
    );

    test('a second load while one is running does nothing', () async {
      final models = ModelManager(
        runtime: FakeRuntime(embedder: embedder),
        intents: store.intents(),
      );
      final first = models.load();
      expect(models.loading, isTrue);
      await models.load();
      await first;
      expect(models.loading, isFalse);
      expect(
        embedder.embedded,
        store.intents().fold<int>(
          0,
          (sum, intent) => sum + intent.examples.length,
        ),
      );
      expect(models.embeddingState, ModelState.ready);
    });

    test('download reports progress and ends ready', () async {
      final models = ModelManager(
        runtime: FakeRuntime(canDownload: true),
        intents: store.intents(),
      );
      final seen = <int>[];
      models.addListener(() => seen.add(models.embeddingProgress));
      await models.downloadEmbedding();
      expect(seen, containsAllInOrder([50, 100]));
      expect(models.embeddingState, ModelState.ready);
      expect(models.matcher, isNotNull);
    });
  });
}

/// Returns a fixed vector for each known text.
class _TableEmbedder implements TextEmbedder {
  _TableEmbedder(this.table);

  final Map<String, List<double>> table;

  @override
  Future<List<List<double>>> embed(
    List<String> texts, {
    required bool asQuery,
  }) async => [for (final text in texts) table[text]!];
}
