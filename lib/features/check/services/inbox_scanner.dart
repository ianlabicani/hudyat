import 'package:flutter/foundation.dart';

import '../models/check_result.dart';
import 'flagged_store.dart';
import 'message_checker.dart';
import 'scan_index.dart';
import 'scam_phrases.dart';
import 'sms_inbox.dart';

/// How far back a scan goes.
enum ScanRange {
  week('Last 7 days', 7),
  month('Last 30 days', 30),
  quarter('Last 3 months', 90),
  all('All messages', null);

  const ScanRange(this.label, this.days);

  final String label;
  final int? days;
}

/// What one scan did.
class ScanSummary {
  const ScanSummary({
    required this.range,
    required this.read,
    required this.skipped,
    required this.scam,
    required this.caution,
    required this.clear,
    this.worded = 0,
    this.stopped = false,
  });

  final ScanRange range;

  /// Texts in the range.
  final int read;

  /// Texts left alone because an earlier scan had already checked them.
  final int skipped;
  final int scam;
  final int caution;
  final int clear;

  /// Texts that also had the slower wording check in this scan.
  final int worded;

  /// The user stopped it part-way. What was done is remembered.
  final bool stopped;

  int get checked => scam + caution + clear;
}

/// Checks the texts already in the SMS inbox (spec 3.4, scan path). The same
/// checker as everywhere else; flagged texts go to the Flagged list and the
/// rest leave only a line in the [ScanIndex].
class InboxScanner extends ChangeNotifier {
  InboxScanner({
    required this._inbox,
    required this._checker,
    required this._flagged,
    required this._index,
    required this.rules,
    this.phrases,
    this._now = DateTime.now,
  });

  final SmsInbox _inbox;
  final MessageChecker _checker;
  final FlaggedStore _flagged;
  final ScanIndex _index;

  /// Identifies the lists and rules in use. When it changes, texts checked
  /// before are checked again.
  final String rules;

  /// The wording check once its examples are embedded, else null.
  final ScamPhrases? Function()? phrases;
  final DateTime Function() _now;

  bool _running = false;
  bool _stop = false;

  bool get running => _running;

  /// Progress of the running scan.
  int done = 0;
  int total = 0;

  /// True while the slower wording pass is the part that is running.
  bool wordingPass = false;

  /// The last finished scan, until the next one starts.
  ScanSummary? last;

  /// SMS access was asked for and not given.
  bool refused = false;

  int get remembered => _index.count;
  bool get canCheckWording => phrases?.call()?.isReady ?? false;

  DateTime? _since(ScanRange range) => switch (range.days) {
    null => null,
    final days => _now().subtract(Duration(days: days)),
  };

  /// How many texts in [range] have not been checked yet, or null without
  /// SMS access. Does not ask for access.
  Future<int?> pending(ScanRange range) async {
    if (!await _inbox.hasPermission()) return null;
    final checked = _index.checked(rules);
    final messages = await _inbox.read(since: _since(range));
    return messages.where((m) => !checked.contains(m.id)).length;
  }

  /// Checks every text in [range] that is not in the index yet. With
  /// [wording], texts the rules left clear also get the wording check,
  /// newest first; that takes about a second each. Returns null when SMS
  /// access is refused.
  Future<ScanSummary?> scan(ScanRange range, {bool wording = false}) async {
    if (_running) return null;
    _running = true;
    _stop = false;
    refused = false;
    last = null;
    done = 0;
    total = 0;
    wordingPass = false;
    notifyListeners();
    try {
      if (!await _inbox.hasPermission() && !await _inbox.requestPermission()) {
        refused = true;
        return null;
      }
      final messages = await _inbox.read(since: _since(range));
      final checked = _index.checked(rules);
      final fresh = [
        for (final message in messages)
          if (!checked.contains(message.id)) message,
      ];
      total = fresh.length;
      notifyListeners();

      final counts = {for (final verdict in Verdict.values) verdict: 0};
      for (final message in fresh) {
        if (_stop) break;
        final result = await _check(message, phrasing: false);
        counts[result.verdict] = counts[result.verdict]! + 1;
        _index.record(
          smsId: message.id,
          sentAt: message.sentAt,
          verdict: result.verdict,
          rules: rules,
          worded: false,
        );
        done++;
        // Often enough to show progress, rarely enough not to slow it.
        if (done % 25 == 0) {
          notifyListeners();
          await Future<void>.delayed(Duration.zero);
        }
      }

      var worded = 0;
      if (wording && !_stop && canCheckWording) {
        final waiting = _index.awaitingWording(rules);
        final queue = [
          for (final message in messages.reversed)
            if (waiting.contains(message.id)) message,
        ];
        wordingPass = true;
        done = 0;
        total = queue.length;
        notifyListeners();
        for (final message in queue) {
          if (_stop) break;
          final result = await _check(message, phrasing: true);
          if (result.verdict != Verdict.clear) {
            counts[Verdict.clear] = (counts[Verdict.clear]! - 1).clamp(
              0,
              1 << 31,
            );
            counts[result.verdict] = counts[result.verdict]! + 1;
          }
          _index.record(
            smsId: message.id,
            sentAt: message.sentAt,
            verdict: result.verdict,
            rules: rules,
            worded: true,
          );
          worded++;
          done++;
          notifyListeners();
        }
      }

      return last = ScanSummary(
        range: range,
        read: messages.length,
        skipped: messages.length - fresh.length,
        scam: counts[Verdict.scam]!,
        caution: counts[Verdict.caution]!,
        clear: counts[Verdict.clear]!,
        worded: worded,
        stopped: _stop,
      );
    } finally {
      _running = false;
      wordingPass = false;
      notifyListeners();
    }
  }

  Future<CheckResult> _check(
    SmsMessage message, {
    required bool phrasing,
  }) async {
    final result = await _checker.check(
      message.body,
      sender: message.sender,
      app: 'Messages',
      phrasing: phrasing,
    );
    // Kept under the time the text arrived, not the time of the scan.
    _flagged.keep(result, at: message.sentAt);
    return result;
  }

  /// Ends the running scan after the text it is on.
  void stop() => _stop = true;

  /// Forgets which texts were checked. Flagged messages stay.
  void forget() {
    _index.clear();
    last = null;
    notifyListeners();
  }
}
