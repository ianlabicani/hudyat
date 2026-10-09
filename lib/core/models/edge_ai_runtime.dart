import 'dart:io';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_embeddings/flutter_edge_ai_embeddings.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:path_provider/path_provider.dart';

import 'model_runtime.dart';
import 'embedding_identity.dart';

/// [ModelRuntime] on `flutter_edge_ai`: EmbeddingGemma for vectors and
/// Gemma 3 1B for wording. Only this file knows the plugin.
class EdgeAiRuntime implements ModelRuntime {
  static const _token = String.fromEnvironment('HUGGINGFACE_TOKEN');

  bool _initialized = false;

  Future<void> _initialize() async {
    if (_initialized) return;
    await FlutterEdgeAi.initialize(
      inferenceEngines: const [LiteRtLmEngine()],
      embeddingBackends: const [LiteRtEmbeddingBackend()],
      embeddingTokenizers: const [GemmaEmbeddingTokenizers()],
      huggingFaceToken: _token.isEmpty ? null : _token,
    );
    _initialized = true;
  }

  @override
  bool get canDownload => _token.isNotEmpty;

  @override
  Future<String?> sideloadFolder() async {
    final base = await getExternalStorageDirectory();
    if (base == null) return null;
    final dir = Directory('${base.path}/models');
    await dir.create(recursive: true);
    return dir.path;
  }

  Future<String?> _sideloaded(String name) async {
    final folder = await sideloadFolder();
    if (folder == null) return null;
    final file = File('$folder/$name');
    return file.existsSync() ? file.path : null;
  }

  @override
  Future<TextEmbedder?> loadEmbedder() async {
    await _initialize();
    if (!FlutterEdgeAi.hasActiveEmbedder()) {
      final model = await _sideloaded(ModelFiles.embedding);
      final tokenizer = await _sideloaded(ModelFiles.tokenizer);
      if (model == null || tokenizer == null) return null;
      await FlutterEdgeAi.installEmbedder()
          .modelFromFile(model)
          .tokenizerFromFile(tokenizer)
          .install();
    }
    return _EdgeEmbedder(await FlutterEdgeAi.getActiveEmbedder());
  }

  @override
  Future<TextGenerator?> loadGenerator() async {
    await _initialize();
    if (!FlutterEdgeAi.hasActiveModel()) {
      final model = await _sideloaded(ModelFiles.chat);
      if (model == null) return null;
      await FlutterEdgeAi.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      ).fromFile(model).install();
    }
    // 1024 is the smallest context a .litertlm model supports; the prompt and
    // a two-sentence reply fit well inside it.
    return _EdgeGenerator(await FlutterEdgeAi.getActiveModel(maxTokens: 1024));
  }

  @override
  Future<TextEmbedder?> downloadEmbedder(
    void Function(int percent) onProgress,
  ) async {
    await _initialize();
    await FlutterEdgeAi.installEmbedder()
        .modelFromNetwork(ModelFiles.embeddingUrl)
        .tokenizerFromNetwork(ModelFiles.tokenizerUrl)
        .withModelProgress(onProgress)
        .install();
    return loadEmbedder();
  }

  @override
  Future<TextGenerator?> downloadGenerator(
    void Function(int percent) onProgress,
  ) async {
    await _initialize();
    await FlutterEdgeAi.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.litertlm,
    ).fromNetwork(ModelFiles.chatUrl).withProgress(onProgress).install();
    return loadGenerator();
  }
}

class _EdgeEmbedder implements IdentifiedEmbedder {
  _EdgeEmbedder(this._model);

  final EmbeddingModel _model;

  @override
  Future<int> dimension() => _model.getDimension();

  @override
  Future<String?> fingerprint() async {
    final spec = FlutterEdgeAi.activeEmbedderSpec;
    if (spec == null) return null;
    // The facade exposes the active spec, but only the file manager exposes
    // its installed paths. Do not hash sideload files which may differ.
    final paths = await FlutterEdgeAiPlugin.instance.modelManager
        .getModelFilePaths(spec);
    if (paths == null || paths.length != 2) return null;
    final model = paths.values.where((path) => path.endsWith('.tflite')).single;
    final tokenizer = paths.values
        .where((path) => path.endsWith('.model'))
        .single;
    return embeddingFingerprint(File(model), File(tokenizer));
  }

  /// One call at a time: a typed message can arrive while the scam phrases
  /// are still being embedded in the background.
  Future<void> _last = Future.value();

  @override
  Future<List<List<double>>> embed(
    List<String> texts, {
    required bool asQuery,
  }) {
    final result = _last.then(
      (_) => _model.generateEmbeddings(
        texts,
        taskType: asQuery
            ? TaskType.retrievalQuery
            : TaskType.retrievalDocument,
      ),
    );
    _last = result.then<void>((_) {}, onError: (_) {});
    return result;
  }
}

class _EdgeGenerator implements TextGenerator {
  _EdgeGenerator(this._model);

  final InferenceModel _model;

  @override
  Stream<String> generate(String prompt, {int maxOutputTokens = 80}) async* {
    final session = await _model.createSession(
      temperature: 0.4,
      topK: 20,
      maxOutputTokens: maxOutputTokens,
    );
    try {
      await session.addQueryChunk(Message(text: prompt, isUser: true));
      yield* session.getResponseAsync();
    } finally {
      await session.close();
    }
  }
}
