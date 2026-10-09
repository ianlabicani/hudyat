// Private corpus in, text-free rule evidence out. Run from the project root.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/features/check/services/message_checker.dart';

Object? sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final k in keys) k: sorted(value[k])};
  }
  if (value is List) return value.map(sorted).toList();
  return value;
}

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    throw ArgumentError('corpus.json pack.sqlite output.json');
  }
  final rows = jsonDecode(await File(args[0]).readAsString()) as List;
  final store = PackStore.open(args[1]);
  try {
    final checker = MessageChecker(
      senders: store.officialSenders(),
      shorteners: store.linkShorteners(),
      neutralHosts: store.neutralHosts(),
      gambling: store.gamblingRules(),
    );
    final output = <Map<String, Object>>[];
    for (final row in rows) {
      final result = await checker.check(
        row['text'] as String,
        sender: row['sender'] as String?,
        phrasing: false,
      );
      output.add({
        'id': row['id'] as String,
        'reasons': [for (final r in result.reasons) r.id],
      });
    }
    final canonical = jsonEncode(sorted(rows));
    await File(args[2]).writeAsString(
      jsonEncode({
        'corpus_sha256': sha256.convert(utf8.encode(canonical)).toString(),
        'rules_version': '${store.rulesVersion()}-$checkerVersion',
        'records': output,
      }),
    );
    // Phone exporter reads this exact canonical corpus hash, not a new split.
    await File('${File(args[0]).parent.path}/classifier-inputs.json')
        .writeAsString(
          jsonEncode({
            'corpus_sha256': sha256.convert(utf8.encode(canonical)).toString(),
            'records': rows,
          }),
        );
    stdout.writeln(
      'Prepared ${rows.length} rule records and private export inputs.',
    );
  } finally {
    store.close();
  }
}
