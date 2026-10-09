import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:path_provider/path_provider.dart';

const chatFile = 'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';
const embedFile = 'embeddinggemma-300M_seq256_mixed-precision.tflite';
const tokenizerFile = 'sentencepiece.model';

class ModelTestPage extends StatefulWidget {
  const ModelTestPage({super.key});

  @override
  State<ModelTestPage> createState() => _ModelTestPageState();
}

class _ModelTestPageState extends State<ModelTestPage>
    with AutomaticKeepAliveClientMixin {
  final _log = StringBuffer();
  bool _running = false;
  String? _modelsDir;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkFiles();
  }

  void _say(String line) {
    debugPrint('[spike] $line');
    setState(() => _log.writeln(line));
  }

  Future<String> _dir() async {
    final base = await getExternalStorageDirectory();
    final dir = Directory('${base!.path}/models');
    await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> _checkFiles() async {
    final dir = await _dir();
    _modelsDir = dir;
    _say('Model folder:\n$dir');
    for (final name in [chatFile, embedFile, tokenizerFile]) {
      final file = File('$dir/$name');
      final found = file.existsSync();
      final size = found ? '${(file.lengthSync() / 1e6).round()} MB' : '';
      _say('${found ? 'FOUND  ' : 'MISSING'} $name $size');
    }
  }

  Future<void> _guard(Future<void> Function() body) async {
    if (_running) return;
    setState(() => _running = true);
    try {
      await body();
    } catch (error, stack) {
      _say('ERROR: $error');
      debugPrintStack(stackTrace: stack);
    } finally {
      setState(() => _running = false);
    }
  }

  Future<List<dynamic>> _json(String asset) async =>
      jsonDecode(await rootBundle.loadString(asset)) as List<dynamic>;

  double _cosine(List<double> a, List<double> b) {
    var dot = 0.0, na = 0.0, nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }

  Future<void> _embeddingTest() => _guard(() async {
    final dir = _modelsDir!;
    final intents = await _json('assets/intents.json');
    final tests = await _json('assets/test_messages.json');

    _say('\n== Embedding match ==');
    var watch = Stopwatch()..start();
    await FlutterEdgeAi.installEmbedder()
        .modelFromFile('$dir/$embedFile')
        .tokenizerFromFile('$dir/$tokenizerFile')
        .install();
    final embedder = await FlutterEdgeAi.getActiveEmbedder();
    _say(
      'Embedder loaded in ${watch.elapsedMilliseconds} ms, '
      'dimension ${await embedder.getDimension()}',
    );

    // Two ways to embed the example phrases: as documents (asymmetric) or as
    // queries (symmetric). Whichever scores better is what the product uses.
    for (final task in TaskType.values) {
      watch = Stopwatch()..start();
      final ids = <String>[];
      final vectors = <List<double>>[];
      for (final intent in intents) {
        final examples = (intent['examples'] as List).cast<String>();
        final embedded = await embedder.generateEmbeddings(
          examples,
          taskType: task,
        );
        for (final vector in embedded) {
          ids.add(intent['id'] as String);
          vectors.add(vector);
        }
      }
      _say(
        '\nExamples as ${task.name}: ${vectors.length} vectors in '
        '${watch.elapsedMilliseconds} ms',
      );

      var correct = 0;
      var totalMs = 0;
      for (final test in tests) {
        watch = Stopwatch()..start();
        final query = await embedder.generateEmbedding(test['text'] as String);
        final best = <String, double>{};
        for (var i = 0; i < vectors.length; i++) {
          final score = _cosine(query, vectors[i]);
          if (score > (best[ids[i]] ?? -1)) best[ids[i]] = score;
        }
        totalMs += watch.elapsedMilliseconds;
        final ranked = best.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final ok = ranked.first.key == test['intent'];
        if (ok) correct++;
        _say(
          '${ok ? 'OK  ' : 'MISS'} ${ranked.first.key} '
          '${ranked.first.value.toStringAsFixed(3)} | 2nd ${ranked[1].key} '
          '${ranked[1].value.toStringAsFixed(3)} | want ${test['intent']}',
        );
      }
      _say(
        'RESULT ${task.name}: $correct of ${tests.length} correct, '
        '${(totalMs / tests.length).round()} ms per message',
      );
    }
  });

  Future<void> _chatTest() => _guard(() async {
    final dir = _modelsDir!;
    final intents = await _json('assets/intents.json');
    final tests = await _json('assets/test_messages.json');

    _say('\n== Chat model ==');
    var watch = Stopwatch()..start();
    await FlutterEdgeAi.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.litertlm,
    ).fromFile('$dir/$chatFile').install();
    final model = await FlutterEdgeAi.getActiveModel(maxTokens: 1024);
    _say(
      'Chat model loaded in ${watch.elapsedMilliseconds} ms, '
      'backend ${model.activeBackend}',
    );

    // Wording step: time to first token and total time. Run twice, since the
    // first run includes warm-up.
    const wordingPrompt =
        'Sumulat ng isa o dalawang maikling pangungusap sa Taglish para sa '
        'taong humihingi ng tulong. Gamitin lang ang FACTS. Huwag magdagdag '
        'ng numero, pangalan o hakbang na wala sa FACTS.\n'
        'MESSAGE: Tulong, biglang natumba si papa at hindi na sumasagot\n'
        'FACTS: intent=medical emergency; city=Pasig; '
        'hotline=Pasig Emergency Hotline; nearest hospital=Pasig City '
        'General Hospital, 1.2 km';
    for (var run = 1; run <= 2; run++) {
      final session = await model.createSession(
        temperature: 0.4,
        topK: 20,
        maxOutputTokens: 80,
      );
      watch = Stopwatch()..start();
      int? firstTokenMs;
      var tokens = 0;
      final reply = StringBuffer();
      await session.addQueryChunk(
        const Message(text: wordingPrompt, isUser: true),
      );
      await for (final token in session.getResponseAsync()) {
        firstTokenMs ??= watch.elapsedMilliseconds;
        tokens++;
        reply.write(token);
      }
      final total = watch.elapsedMilliseconds;
      await session.close();
      _say(
        'RESULT wording run $run: first token $firstTokenMs ms, total '
        '$total ms, $tokens chunks\n> ${reply.toString().trim()}',
      );
    }

    // Decision step alternative: force the chat model to pick an intent id.
    _say('\nForced choice:');
    final ids = [for (final intent in intents) intent['id'] as String];
    var correct = 0;
    var totalMs = 0;
    for (final test in tests) {
      final session = await model.createSession(
        temperature: 0.4,
        topK: 20,
        maxOutputTokens: 16,
      );
      watch = Stopwatch()..start();
      await session.addQueryChunk(
        Message(
          text:
              'Classify the message into exactly one of these ids:\n'
              '${ids.join(', ')}\n'
              'Reply with the id only.\n'
              'Message: ${test['text']}',
          isUser: true,
        ),
      );
      final reply = (await session.getResponse()).trim();
      totalMs += watch.elapsedMilliseconds;
      await session.close();
      final picked = ids.firstWhere(reply.contains, orElse: () => '?');
      final ok = picked == test['intent'];
      if (ok) correct++;
      _say('${ok ? 'OK  ' : 'MISS'} "$reply" | want ${test['intent']}');
    }
    _say(
      'RESULT forced choice: $correct of ${tests.length} correct, '
      '${(totalMs / tests.length).round()} ms per message',
    );
  });

  /// Writes every example and test-message vector to a file, so scoring
  /// rules can be compared on the laptop against this phone's real output.
  Future<void> _exportVectors() => _guard(() async {
    final dir = _modelsDir!;
    final intents = await _json('assets/intents.json');
    final tests = await _json('assets/test_messages.json');
    await FlutterEdgeAi.installEmbedder()
        .modelFromFile('$dir/$embedFile')
        .tokenizerFromFile('$dir/$tokenizerFile')
        .install();
    final embedder = await FlutterEdgeAi.getActiveEmbedder();
    final watch = Stopwatch()..start();

    final examples = <Map<String, Object>>[];
    for (final intent in intents) {
      final texts = (intent['examples'] as List).cast<String>();
      final vectors = await embedder.generateEmbeddings(
        texts,
        taskType: TaskType.retrievalDocument,
      );
      for (var i = 0; i < texts.length; i++) {
        examples.add({
          'intent': intent['id'] as String,
          'text': texts[i],
          'vector': vectors[i],
        });
      }
      _say('examples ${examples.length} (${watch.elapsed.inSeconds}s)');
    }
    final messages = <Map<String, Object>>[];
    for (final test in tests) {
      messages.add({
        'intent': test['intent'] as String,
        'text': test['text'] as String,
        'vector': await embedder.generateEmbedding(test['text'] as String),
      });
    }
    final out = File('${Directory(dir).parent.path}/vectors.json');
    await out.writeAsString(
      jsonEncode({'examples': examples, 'messages': messages}),
    );
    _say(
      'RESULT export: ${examples.length} examples and ${messages.length} '
      'messages in ${watch.elapsed.inSeconds}s\n${out.path}',
    );
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _running ? null : _checkFiles,
                child: const Text('Check files'),
              ),
              FilledButton(
                onPressed: _running ? null : _embeddingTest,
                child: const Text('1. Embedding test'),
              ),
              FilledButton(
                onPressed: _running ? null : _chatTest,
                child: const Text('2. Chat test'),
              ),
              FilledButton(
                onPressed: _running ? null : _exportVectors,
                child: const Text('3. Export vectors'),
              ),
              OutlinedButton(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: _log.toString())),
                child: const Text('Copy log'),
              ),
            ],
          ),
        ),
        if (_running) const LinearProgressIndicator(),
        Expanded(
          child: SingleChildScrollView(
            reverse: true,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              _log.toString(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
