import '../../../core/models/guarded_note.dart';
import '../../../core/models/model_runtime.dart';
import '../../../core/pack/scam_records.dart';
import '../models/check_result.dart';

/// What the chat model may talk about for a result: the verdict and the
/// fixed reasons already on screen. The sender's number and the real
/// contact's details are left out, so the model cannot repeat them.
String resultFacts(CheckResult result, Map<String, ScamReasonText> wording) => [
  'verdict: ${result.verdict.gloss}',
  for (final reason in result.reasons)
    if (wording[reason.id] case final text?)
      'reason: '
          '${CheckReason(reason.id, {...reason.facts}..remove('sender')).fill(text.en)}',
].join('\n');

String resultPrompt(String facts) =>
    'Explain in one or two short, calm sentences in plain English why a '
    'check of a message gave this result.\n'
    'Rules: Use only the FACTS. Do not add numbers, links, names or advice '
    'that are not in the FACTS. Never say the message is safe.\n'
    'FACTS:\n$facts';

final _callsItSafe = RegExp(
  r'\b(safe|legit\w*|ligtas|lehitimo)\b',
  caseSensitive: false,
);
final _link = RegExp(r'[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}');

/// Whether a note must be thrown away: it calls the message safe, which the
/// app never does, or it names a link that is not in [facts].
bool rejectsResultNote(String text, String facts) {
  if (_callsItSafe.hasMatch(text)) return true;
  final known = facts.toLowerCase();
  return _link
      .allMatches(text.toLowerCase())
      .any((match) => !known.contains(match.group(0)!));
}

/// Streams the optional English explanation under a flagged result (spec
/// 3.4, stage 2). The verdict and reasons never depend on it.
class ResultExplainer {
  ResultExplainer(
    this._generator, {
    this.timeout = const Duration(seconds: 12),
  });

  /// The spec's cut rule: set to false if the wording is still poor on the
  /// phone, and results show no note. The fixed reasons already explain the
  /// verdict.
  static const enabled = true;

  final TextGenerator _generator;

  /// Longest wait for the next piece of text before giving up.
  final Duration timeout;

  /// Emits the note so far each time it grows, or an empty string if the
  /// note had to be thrown away.
  Stream<String> explain(
    CheckResult result,
    Map<String, ScamReasonText> wording,
  ) {
    final facts = resultFacts(result, wording);
    return guardedNote(
      _generator,
      prompt: resultPrompt(facts),
      facts: facts,
      timeout: timeout,
      reject: (text) => rejectsResultNote(text, facts),
    );
  }
}
