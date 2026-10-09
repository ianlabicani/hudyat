import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/check/services/scam_phrases.dart';
import '../../features/intent/services/intent_matcher.dart';
import '../pack/pack_record.dart';
import '../pack/scam_records.dart';
import 'model_runtime.dart';

enum ModelState { checking, preparing, missing, downloading, ready, failed }

/// Loads the two models and reports where each stands. Nothing in the app
/// waits on this: until [matcher] is set, typing uses keyword search, and
/// until [generator] is set, cards show without the AI note.
class ModelManager extends ChangeNotifier {
  ModelManager({
    required this._runtime,
    required this._intents,
    this.cacheFile,
    this.scamExamples = const [],
    this.scamCacheFile,
  });

  final ModelRuntime _runtime;
  final List<IntentDef> _intents;
  final File? cacheFile;

  /// Scam wording for the message check's phrasing step.
  final List<ScamExample> scamExamples;
  final File? scamCacheFile;

  ModelState embeddingState = ModelState.checking;
  ModelState chatState = ModelState.checking;
  int embeddingProgress = 0;
  int chatProgress = 0;
  String? embeddingError;
  String? chatError;

  /// Where files copied over USB are picked up.
  String? sideloadFolder;

  IntentMatcher? matcher;
  TextGenerator? generator;

  /// The phrasing check, set once its examples are embedded. That happens
  /// after everything else, so it never delays "Find help".
  ScamPhrases? scamPhrases;

  /// 0 to 100 while the scam examples are being embedded, else null.
  int? scamProgress;
  TextEmbedder? _embedder;

  bool get canDownload => _runtime.canDownload;
  bool get allReady =>
      embeddingState == ModelState.ready && chatState == ModelState.ready;

  /// True while [load] is running, so it is not started twice.
  bool get loading => _loading;
  bool _loading = false;

  /// Looks for both models on the device. Safe to call again after copying
  /// files over; a call while one is running does nothing.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      await _load();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _load() async {
    try {
      sideloadFolder = await _runtime.sideloadFolder();
    } on Object {
      sideloadFolder = null;
    }
    await _embedding(_runtime.loadEmbedder);
    await _chat(_runtime.loadGenerator);
    await _scam();
  }

  /// Embeds the scam examples with whichever embedder is loaded. A failure
  /// leaves the message check on its link and sender rules.
  Future<void> _scam() async {
    final embedder = _embedder;
    if (embedder == null || scamExamples.isEmpty) return;
    final prepared = ScamPhrases(
      embedder: embedder,
      examples: scamExamples,
      cacheFile: scamCacheFile,
    );
    scamProgress = 0;
    notifyListeners();
    try {
      await prepared.prepare(
        onProgress: (done, total) {
          scamProgress = (done * 100 / total).round();
          notifyListeners();
        },
      );
      scamPhrases = prepared;
    } on Object {
      scamPhrases = null;
    }
    scamProgress = null;
    notifyListeners();
  }

  Future<void> downloadEmbedding() async {
    await _embedding(
      () => _runtime.downloadEmbedder((percent) {
        embeddingProgress = percent;
        notifyListeners();
      }),
      downloading: true,
    );
    await _scam();
  }

  Future<void> downloadChat() => _chat(
    () => _runtime.downloadGenerator((percent) {
      chatProgress = percent;
      notifyListeners();
    }),
    downloading: true,
  );

  Future<void> _embedding(
    Future<TextEmbedder?> Function() obtain, {
    bool downloading = false,
  }) async {
    embeddingState = downloading ? ModelState.downloading : ModelState.checking;
    embeddingError = null;
    notifyListeners();
    try {
      final embedder = await obtain();
      _embedder = embedder;
      if (embedder == null) {
        embeddingState = ModelState.missing;
      } else {
        // Example phrases are embedded on this phone, so they always match
        // the model that is actually installed.
        final prepared = IntentMatcher(
          embedder: embedder,
          intents: _intents,
          cacheFile: cacheFile,
        );
        // About a second per phrase the first time; cached afterwards.
        embeddingState = ModelState.preparing;
        embeddingProgress = 0;
        notifyListeners();
        await prepared.prepare(
          onProgress: (done, total) {
            embeddingProgress = (done * 100 / total).round();
            notifyListeners();
          },
        );
        matcher = prepared;
        embeddingState = ModelState.ready;
      }
    } on Object catch (error) {
      matcher = null;
      _embedder = null;
      embeddingState = ModelState.failed;
      embeddingError = '$error';
    }
    notifyListeners();
  }

  Future<void> _chat(
    Future<TextGenerator?> Function() obtain, {
    bool downloading = false,
  }) async {
    chatState = downloading ? ModelState.downloading : ModelState.checking;
    chatError = null;
    notifyListeners();
    try {
      generator = await obtain();
      chatState = generator == null ? ModelState.missing : ModelState.ready;
    } on Object catch (error) {
      generator = null;
      chatState = ModelState.failed;
      chatError = '$error';
    }
    notifyListeners();
  }
}
