import 'dart:io';

import 'package:crypto/crypto.dart';

/// Hashes file contents, not names. Only needed for the optional classifier.
Future<String> embeddingFingerprint(File model, File tokenizer) async {
  final modelHash = await sha256.bind(model.openRead()).first;
  final tokenizerHash = await sha256.bind(tokenizer.openRead()).first;
  return 'sha256:$modelHash:$tokenizerHash';
}
