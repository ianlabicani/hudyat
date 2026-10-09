import 'dart:async';

import 'model_runtime.dart';

/// Whether [text] contains a run of three or more digits that is not in
/// [facts]. Such a run would be a number the model made up, so the note is
/// thrown away rather than shown.
bool hasInventedNumber(String text, String facts) =>
    RegExp(r'\d[\d\s().-]{1,}\d')
        .allMatches(text)
        .map((m) => m.group(0)!.replaceAll(RegExp(r'\D'), ''))
        .any(
          (digits) =>
              digits.length >= 3 &&
              !facts.replaceAll(RegExp(r'\D'), '').contains(digits),
        );

/// Streams an optional AI-written note, emitting the note so far each time
/// it grows. It emits an empty string and stops if the model writes a number
/// that is not in [facts], or anything [reject] refuses. The stream ends
/// quietly on any error or when the model is slower than [timeout] between
/// pieces, so whatever the note sits under is never affected.
Stream<String> guardedNote(
  TextGenerator generator, {
  required String prompt,
  required String facts,
  required Duration timeout,
  bool Function(String text)? reject,
}) async* {
  final note = StringBuffer();
  try {
    await for (final token in generator.generate(prompt).timeout(timeout)) {
      note.write(token);
      final text = note.toString().trim();
      if (hasInventedNumber(text, facts) || (reject?.call(text) ?? false)) {
        yield '';
        return;
      }
      if (text.isNotEmpty) yield text;
    }
  } on Object {
    // Missing, slow or failing model: the note simply does not appear.
  }
}
