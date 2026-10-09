/// Turns text into vectors. The decision step's only model dependency.
abstract class TextEmbedder {
  /// [asQuery] marks text the user typed; false marks stored example
  /// phrases. The model embeds the two slightly differently.
  Future<List<List<double>>> embed(List<String> texts, {required bool asQuery});
}

/// Optional identity of the exact installed embedding model and tokenizer.
abstract interface class IdentifiedEmbedder implements TextEmbedder {
  Future<String?> fingerprint();
  Future<int> dimension();
}

/// Streams generated text. Used only for the optional wording step.
abstract class TextGenerator {
  Stream<String> generate(String prompt, {int maxOutputTokens = 80});
}

/// The on-device model layer, behind an interface so everything above it can
/// be tested without a phone. Either loader returns null when its model is
/// not on the device.
abstract class ModelRuntime {
  /// Folder where model files copied over USB are picked up, if any.
  Future<String?> sideloadFolder();

  /// Whether a download can be offered (needs a Hugging Face token at build).
  bool get canDownload;

  Future<TextEmbedder?> loadEmbedder();
  Future<TextGenerator?> loadGenerator();

  /// Download with progress from 0 to 100, then load.
  Future<TextEmbedder?> downloadEmbedder(void Function(int percent) onProgress);
  Future<TextGenerator?> downloadGenerator(
    void Function(int percent) onProgress,
  );
}

/// The model files the app expects. Both repositories are gated on Hugging
/// Face; the builder accepts the Gemma terms personally (spec section 6).
abstract final class ModelFiles {
  static const embedding = 'embeddinggemma-300M_seq256_mixed-precision.tflite';
  static const tokenizer = 'sentencepiece.model';
  static const chat = 'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';

  static const _hub = 'https://huggingface.co/litert-community';
  static const embeddingUrl =
      '$_hub/embeddinggemma-300m/resolve/main/$embedding';
  static const tokenizerUrl =
      '$_hub/embeddinggemma-300m/resolve/main/$tokenizer';
  static const chatUrl = '$_hub/Gemma3-1B-IT/resolve/main/$chat';

  /// The pages a person opens to accept the Gemma terms and get the files.
  static const embeddingPage = '$_hub/embeddinggemma-300m';
  static const chatPage = '$_hub/Gemma3-1B-IT';
}
