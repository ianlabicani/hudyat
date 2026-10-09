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
  });

  final String package;

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

  /// Exists while automatic checking is on, so the choice survives a restart.
  final File? settingsFile;

  StreamSubscription<IncomingNotification>? _subscription;

  // Message apps repost the same notification; each is checked once.
  final _seen = <String>[];

  /// True while notifications are being read.
  bool get isOn => _subscription != null;

  /// Resumes after a restart if the user had turned it on and access is
  /// still granted. [onOpen] gets a flagged id when an alert is tapped.
  Future<void> start(void Function(int flaggedId) onOpen) async {
    try {
      await _alerter.start(onOpen);
      if ((settingsFile?.existsSync() ?? false) && await _source.isGranted()) {
        _listen();
      }
    } on Object {
      // No notification access on this platform: the manual check remains.
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
    return true;
  }

  void turnOff() {
    _subscription?.cancel();
    _subscription = null;
    _writeSetting(on: false);
    notifyListeners();
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = _source.notifications.listen(
      (notification) => unawaited(handle(notification)),
      onError: (Object _) {},
    );
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
    if (_seen.contains(key)) return null;
    _seen.add(key);
    if (_seen.length > 50) _seen.removeAt(0);

    final sender = notification.title.trim();
    final result = await _checker.check(
      text,
      sender: sender,
      app: app,
      // Android cuts long text and marks the cut with an ellipsis.
      truncated: text.endsWith('...') || text.endsWith('…'),
    );
    final id = _flagged.keep(result);
    if (id != null && result.verdict == Verdict.scam) {
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
