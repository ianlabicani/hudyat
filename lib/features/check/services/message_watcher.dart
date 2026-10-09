import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/pack/scam_records.dart';
import '../models/check_result.dart';
import 'flagged_store.dart';
import 'message_checker.dart';

/// A notification as another app posted it.
class IncomingNotification {
  const IncomingNotification({
    required this.package,
    required this.title,
    required this.content,
    this.postedAt,
  });

  final String package;

  /// When the other app posted it, if the phone says.
  final DateTime? postedAt;

  /// For message apps this is the sender's name or number.
  final String title;
  final String content;
}

/// Android notification access, behind an interface so the watcher can be
/// tested without a phone.
abstract class NotificationSource {
  Future<bool> isGranted();

  /// Opens Android's notification access setting; true once granted.
  Future<bool> requestAccess();
  Stream<IncomingNotification> get notifications;
}

/// Whether the phone lets the app run while it is in the background. Some
/// phones freeze a backgrounded app within seconds; a frozen app gets the
/// notification only when it is opened again.
abstract class BackgroundRunner {
  Future<bool> isAllowed();

  /// Opens Android's prompt to exempt the app from battery optimisation.
  Future<void> requestAllowed();

  /// Starts or stops the ongoing "Hudyat is checking" notification that
  /// keeps the app from being frozen.
  Future<void> keepAwake({required bool on});
}

/// Posts Hudyat's own notification.
abstract class Alerter {
  /// [onOpen] gets the flagged message's id when its alert is tapped.
  Future<void> start(void Function(int flaggedId) onOpen);
  Future<void> requestPermission();
  Future<void> alert({
    required int flaggedId,
    required String title,
    required String body,
  });
}

/// The automatic path (spec 3.4): reads notifications from message apps,
/// runs the same checker as the manual path, keeps flagged messages and
/// alerts only for "Mukhang scam". Off until the user turns it on.
class MessageWatcher extends ChangeNotifier {
  MessageWatcher({
    required this._source,
    required this._alerter,
    required this._checker,
    required this._flagged,
    required this._wording,
    this._background,
    this.settingsFile,
  });

  /// The apps whose notifications are read. Every other notification is
  /// ignored without being looked at.
  static const watchedApps = {
    'com.google.android.apps.messaging': 'Messages',
    'com.transsion.smartmessage': 'Messages',
    'com.samsung.android.messaging': 'Messages',
    'com.android.mms': 'Messages',
    'com.facebook.orca': 'Messenger',
    'com.viber.voip': 'Viber',
    'com.whatsapp': 'WhatsApp',
    'org.telegram.messenger': 'Telegram',
  };

  final NotificationSource _source;
  final Alerter _alerter;
  final MessageChecker _checker;
  final FlaggedStore _flagged;
  final Map<String, ScamReasonText> _wording;
  final BackgroundRunner? _background;

  /// False when the phone will freeze the app in the background, so
  /// messages are checked only once it is opened again.
  bool runsInBackground = true;

  /// Re-reads [runsInBackground], for when the user returns from Settings.
  Future<void> refreshBackground() async {
    try {
      runsInBackground = await _background?.isAllowed() ?? true;
    } on Object {
      runsInBackground = true;
    }
    notifyListeners();
  }

  /// Asks Android to let the app keep running in the background.
  Future<void> allowBackground() async {
    try {
      await _background?.requestAllowed();
    } on Object {
      // The Notice stays, with the manual route through Settings.
    }
  }

  /// Exists while automatic checking is on, so the choice survives a restart.
  final File? settingsFile;

  StreamSubscription<IncomingNotification>? _subscription;

  // Message apps repost the same notification within seconds; a repost is
  // not a new message. The same text arriving later is.
  static const _repostWindow = Duration(seconds: 60);
  final _seen = <String, DateTime>{};

  /// When this run started reading. Notifications posted before it are the
  /// phone replaying what is still on screen.
  DateTime _listeningSince = DateTime.now();

  /// What the watcher has done since it was turned on in this run, so the
  /// screen can show it is receiving messages even when none is flagged.
  int checkedCount = 0;
  DateTime? lastCheckedAt;
  Verdict? lastVerdict;

  /// How long after the message app posted the notification this app got
  /// to check it. More than a few seconds means the phone had it paused.
  Duration? lastDelay;

  /// True while notifications are being read.
  bool get isOn => _subscription != null;

  /// Resumes after a restart if the user had turned it on and access is
  /// still granted. [onOpen] gets a flagged id when an alert is tapped.
  Future<void> start(void Function(int flaggedId) onOpen) async {
    try {
      await _alerter.start(onOpen);
    } on Object catch (error) {
      // Reading must not depend on alerts: flagged messages are still kept.
      debugPrint('MessageWatcher: alerts unavailable: $error');
    }
    try {
      if ((settingsFile?.existsSync() ?? false) && await _source.isGranted()) {
        _listen();
        await refreshBackground();
      }
    } on Object catch (error) {
      // No notification access on this platform: the manual check remains.
      debugPrint('MessageWatcher: not listening: $error');
    }
  }

  /// Asks for notification access and starts reading. False when the user
  /// came back without granting it.
  Future<bool> turnOn() async {
    try {
      final granted =
          await _source.isGranted() || await _source.requestAccess();
      if (!granted) return false;
      await _alerter.requestPermission();
    } on Object {
      return false;
    }
    _writeSetting(on: true);
    _listen();
    await refreshBackground();
    if (!runsInBackground) await allowBackground();
    return true;
  }

  void turnOff() {
    _subscription?.cancel();
    _subscription = null;
    _writeSetting(on: false);
    unawaited(_keepAwake(on: false));
    notifyListeners();
  }

  Future<void> _keepAwake({required bool on}) async {
    try {
      await _background?.keepAwake(on: on);
    } on Object catch (error) {
      debugPrint('MessageWatcher: keep-awake failed: $error');
    }
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = _source.notifications.listen(
      (notification) => unawaited(
        handle(notification).catchError((Object error) {
          debugPrint('MessageWatcher: check failed: $error');
          return null;
        }),
      ),
      onError: (Object error) {
        debugPrint('MessageWatcher: stream error: $error');
      },
    );
    _listeningSince = DateTime.now();
    unawaited(_keepAwake(on: true));
    notifyListeners();
  }

  /// Checks one notification. Returns the result for a watched app's new
  /// message, or null when it was ignored.
  @visibleForTesting
  Future<CheckResult?> handle(IncomingNotification notification) async {
    final app = watchedApps[notification.package];
    final text = notification.content.trim();
    if (app == null || text.isEmpty) return null;
    final key = '${notification.package}|${notification.title}|$text';
    final now = DateTime.now();
    final last = _seen[key];
    if (last != null && now.difference(last) < _repostWindow) return null;
    _seen[key] = now;
    _seen.removeWhere((_, at) => now.difference(at) >= _repostWindow);

    final sender = notification.title.trim();
    final posted = notification.postedAt;
    final result = await _checker.check(
      text,
      sender: sender,
      app: app,
      // Android cuts long text and marks the cut with an ellipsis.
      truncated: text.endsWith('...') || text.endsWith('…'),
      // Rules only. The model may not be allowed to run while the app is
      // in the background, and an alert must not wait on it (spec 3.4).
      phrasing: false,
    );
    // After a restart the phone replays the notifications still on screen.
    // One that is already kept was alerted the first time. The same text
    // sent again later is a new message and is alerted again.
    final known =
        _flagged.has(result) &&
        posted != null &&
        posted.isBefore(_listeningSince);
    final id = _flagged.keep(result);
    checkedCount++;
    lastCheckedAt = now;
    lastVerdict = result.verdict;
    lastDelay = posted == null ? null : now.difference(posted);
    notifyListeners();
    debugPrint(
      'MessageWatcher: $app message checked: ${result.verdict.name} '
      '[${result.reasons.map((r) => r.id).join(', ')}]',
    );
    if (id != null && !known && result.verdict == Verdict.scam) {
      final first = result.reasons.first;
      await _alerter.alert(
        flaggedId: id,
        title:
            'Mukhang scam ang mensahe mula kay '
            '${sender.isEmpty ? app : sender}',
        body: first.fill(_wording[first.id]?.tl ?? Verdict.scam.label),
      );
    }
    return result;
  }

  void _writeSetting({required bool on}) {
    final file = settingsFile;
    if (file == null) return;
    try {
      if (on) {
        file.writeAsStringSync('on');
      } else if (file.existsSync()) {
        file.deleteSync();
      }
    } on FileSystemException {
      // The choice is then asked again after a restart.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
