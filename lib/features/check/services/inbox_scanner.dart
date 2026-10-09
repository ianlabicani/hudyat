import 'dart:async';

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
  bool get canCheckWording => _checker.canCheckWording;
  bool _foreground = true;
  bool _autoPaused = false;
  bool _disposed = false;
  Timer? _continuation;
  bool _resumeRequested = false;

  void setForeground(bool value) {
    _foreground = value;
    if (!value) {
      _continuation?.cancel();
      _stop = true;
    } else {
      _autoPaused = false;
      if (_running) _resumeRequested = true;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stop = true;
    _continuation?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  DateTime? _since(ScanRange range) => switch (range.days) {
    null => null,
    final days => _now().subtract(Duration(days: days)),
  };

  /// How many texts in [range] have not been checked yet, or null without
  /// SMS access. Does not ask for access.
  Future<int?> pending(ScanRange range) async {
    if (_disposed || !await _inbox.hasPermission() || _disposed) return null;
    final checked = _index.checked(rules);
    final messages = await _inbox.read(since: _since(range));
    return messages.where((m) => !checked.contains(m.id)).length;
  }

  /// Fast rules first, then a resumable AI pass over clear/caution texts.
  Future<ScanSummary?> scan(ScanRange range, {bool wording = false}) {
    _autoPaused = true;
    _continuation?.cancel();
    return _scan(range, wording: wording, askPermission: true);
  }

  Future<ScanSummary?> _scan(
    ScanRange range, {
    required bool wording,
    required bool askPermission,
    Duration? wordingBudget,
    bool quiet = false,
  }) async {
    if (_running || _disposed) return null;
    _running = true;
    _stop = !_foreground;
    refused = false;
    if (!quiet) last = null;
    done = 0;
    total = 0;
    wordingPass = false;
    _notify();
    try {
      if (!await _inbox.hasPermission()) {
        if (!askPermission || !await _inbox.requestPermission()) {
          refused = askPermission;
          return null;
        }
      }
      if (_disposed) return null;
      final messages = await _inbox.read(since: _since(range));
      if (_disposed) return null;
      final checked = _index.checked(rules);
      final fresh = [
        for (final message in messages)
          if (!checked.contains(message.id)) message,
      ];
      total = fresh.length;
      _notify();

      // One entry per SMS, so a rules check followed by AI is counted once.
      final touched = <int, Verdict>{};
      for (final message in fresh) {
        if (_stop) break;
        final result = await _check(message, phrasing: false);
        if (_disposed) return null;
        touched[message.id] = result.verdict;
        _index.record(
          smsId: message.id,
          sentAt: message.sentAt,
          verdict: result.verdict,
          rules: rules,
          worded: false,
        );
        done++;
        if (done % 25 == 0) {
          _notify();
          await Future<void>.delayed(Duration.zero);
        }
      }

      var worded = 0;
      final aiVersion = _checker.aiVersion;
      if (wording && !_stop && aiVersion != null) {
        final waiting = _index.awaitingWording(rules, aiVersion: aiVersion);
        final queue = [
          for (final message in messages.reversed)
            if (waiting.contains(message.id)) message,
        ];
        wordingPass = true;
        done = 0;
        total = queue.length;
        final watch = Stopwatch()..start();
        _notify();
        for (final message in queue) {
          if (_stop ||
              !_foreground ||
              _checker.aiVersion != aiVersion ||
              (wordingBudget != null && watch.elapsed >= wordingBudget)) {
            break;
          }
          final result = await _check(message, phrasing: true);
          if (_disposed) return null;
          // A failed model must not mark a message as AI-complete.
          if (result.phrasing != PhrasingState.checked) break;
          touched[message.id] = result.verdict;
          _index.recordAI(
            smsId: message.id,
            rules: rules,
            verdict: result.verdict,
            aiVersion: aiVersion,
          );
          worded++;
          done++;
          _notify();
          // Let interactive requests enqueue before the next inbox inference.
          await Future<void>.delayed(Duration.zero);
        }
      }
      final summary = ScanSummary(
        range: range,
        read: messages.length,
        skipped: messages.length - touched.length,
        scam: touched.values.where((v) => v == Verdict.scam).length,
        caution: touched.values.where((v) => v == Verdict.caution).length,
        clear: touched.values.where((v) => v == Verdict.clear).length,
        worded: worded,
        stopped: _stop,
      );
      if (!quiet) last = summary;
      return summary;
    } finally {
      _running = false;
      wordingPass = false;
      _notify();
      if (_resumeRequested && !_disposed && _foreground && !_autoPaused) {
        _resumeRequested = false;
        _continuation?.cancel();
        _continuation = Timer(Duration.zero, () => unawaited(catchUp()));
      }
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
    if (!_disposed) {
      _flagged.keep(
        result,
        at: message.sentAt,
        sourceKey: 'sms:${message.id}',
        sourceType: 'sms',
        arrivedAt: message.sentAt,
        rulesVersion: rules,
        aiVersion: result.phrasing == PhrasingState.checked
            ? _checker.aiVersion
            : null,
      );
    }
    return result;
  }

  /// Quiet rules pass on open, without a permission prompt or AI delay.
  Future<void> catchUp() async {
    if (!_foreground || _disposed) return;
    if (_running) {
      _resumeRequested = true;
      return;
    }
    try {
      await _scan(
        ScanRange.week,
        wording: false,
        askPermission: false,
        quiet: true,
      );
      unawaited(resumeWording());
    } on Object {
      // A failed inbox read must not break startup or navigation.
    }
  }

  /// Called on model readiness/foreground entry. Each pass has a 30-second
  /// budget; completion is stored after each message and errors stay pending.
  Future<void> resumeWording({
    Duration budget = const Duration(seconds: 30),
  }) async {
    if (!_foreground || _autoPaused || _disposed || !canCheckWording) return;
    if (_running) {
      _resumeRequested = true;
      return;
    }
    try {
      final result = await _scan(
        ScanRange.week,
        wording: true,
        askPermission: false,
        quiet: true,
        wordingBudget: budget,
      );
      if (result != null &&
          result.worded > 0 &&
          !_stop &&
          _foreground &&
          !_autoPaused &&
          !_disposed) {
        _continuation?.cancel();
        _continuation = Timer(const Duration(milliseconds: 100), () {
          unawaited(resumeWording(budget: budget));
        });
      }
    } on Object {
      // Retried on the next foreground/model-ready event, not a tight loop.
    }
  }

  /// Stop after the current text, including automatic foreground checks.
  void stop() {
    _stop = true;
    _autoPaused = true;
    _continuation?.cancel();
  }

  /// Forgets which texts were checked. Flagged messages stay.
  void forget() {
    _index.clear();
    last = null;
    _notify();
  }
}
