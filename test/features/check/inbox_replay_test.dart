import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:hudyat/features/check/models/check_result.dart';
import 'package:hudyat/features/check/services/message_checker.dart';

/// Runs a saved SMS inbox through the checker with the shipped pack, to
/// find real messages that get flagged. The inbox file is private and
/// git-ignored (`pack/raw/inbox/`), so this skips itself without one. The
/// phrasing check needs the model and is not part of it.
void main() {
  final folder = Directory('pack/raw/inbox');
  final files = folder.existsSync()
      ? (folder.listSync().whereType<File>().toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];
  final pack = File('assets/pack/metro-manila.sqlite');
  final ready = files.isNotEmpty && pack.existsSync();

  test(
    'a real inbox: only gambling promos, shortened links and hidden links',
    () async {
      final store = PackStore.open(pack.path);
      addTearDown(store.close);
      final checker = MessageChecker(
        senders: store.officialSenders(),
        shorteners: store.linkShorteners(),
        neutralHosts: store.neutralHosts(),
        gambling: store.gamblingRules(),
        bankSenders: store.bankSenders(),
      );
      final inbox = jsonDecode(files.last.readAsStringSync()) as Map;
      final unexpected = <String>[];
      final counts = <String, int>{};
      for (final message in (inbox['messages'] as List).cast<Map>()) {
        final body = message['body'] as String;
        final sender = message['sender'] as String;
        final result = await checker.check(
          body,
          // Mobile numbers are masked in the file; any mobile number will do.
          sender: message['sender_kind'] == 'mobile' ? '09170000000' : sender,
        );
        if (!result.isFlagged) continue;
        final ids = [for (final reason in result.reasons) reason.id];
        final key = '${result.verdict.label}: ${ids.join(' + ')}';
        counts[key] = (counts[key] ?? 0) + 1;
        const expected = {ReasonId.gamblingPromo, ReasonId.linkShortener};
        if (ids.every(expected.contains)) continue;
        // Fake customer-service texts that break up their link with a space
        // ("csraftersales. com"). They are scams, and any other reason on
        // the same message follows from that.
        if (ids.contains(ReasonId.linkHidden)) continue;
        final start = body.replaceAll(RegExp(r'\s+'), ' ');
        unexpected.add(
          '[$sender] $key ${result.reasons.map((r) => r.facts)}\n'
          '    ${start.length > 110 ? start.substring(0, 110) : start}',
        );
      }
      printOnFailure('Flagged: $counts');
      expect(unexpected, isEmpty, reason: unexpected.join('\n'));
    },
    skip: ready ? false : 'No saved inbox in pack/raw/inbox/',
  );
}
