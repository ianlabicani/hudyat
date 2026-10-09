import 'model_runtime.dart';

/// Remembers the vector of the last message embedded as a query. Finding the
/// intent and finding a first-aid card both embed the same message, so the
/// second one costs nothing instead of another run of the model.
class LastQueryEmbedder implements TextEmbedder {
  LastQueryEmbedder(this._inner);

  final TextEmbedder _inner;
  String? _text;
  List<double>? _vector;

  @override
  Future<List<List<double>>> embed(
    List<String> texts, {
    required bool asQuery,
  }) async {
    if (!asQuery || texts.length != 1) {
      return _inner.embed(texts, asQuery: asQuery);
    }
    final text = texts.single;
    if (_vector case final vector? when text == _text) return [vector];
    final vector = (await _inner.embed(texts, asQuery: true)).single;
    _text = text;
    _vector = vector;
    return [vector];
  }
}
