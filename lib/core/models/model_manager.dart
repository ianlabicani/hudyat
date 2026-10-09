import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/intent/services/intent_matcher.dart';
import '../pack/pack_record.dart';
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
  });

  final ModelRuntime _runtime;
  final List<IntentDef> _intents;
  final File? cacheFile;

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
  }

  Future<void> downloadEmbedding() => _embedding(
    () => _runtime.downloadEmbedder((percent) {
      embeddingProgress = percent;
      notifyListeners();
    }),
    downloading: true,
  );

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
