import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sms_inbox.dart';

/// What the timed check last found in the SMS inbox. Counts only.
class TimedStatus {
  const TimedStatus({
    this.on = false,
    this.hasAccess = false,
    this.scam = 0,
    this.caution = 0,
    this.gambling = 0,
    this.total = 0,
    this.checkedAt,
    this.canNotify = false,
    this.intervalMinutes = 720,
  });

  factory TimedStatus.fromMap(Map<Object?, Object?> map) {
    final at = map['checkedAt'] as int? ?? 0;
    return TimedStatus(
      on: map['on'] as bool? ?? false,
      hasAccess: map['state'] != 'no_access',
      scam: map['scam'] as int? ?? 0,
      caution: map['caution'] as int? ?? 0,
      gambling: map['gambling'] as int? ?? 0,
      total: map['total'] as int? ?? 0,
      checkedAt: at == 0 ? null : DateTime.fromMillisecondsSinceEpoch(at),
      canNotify: map['canNotify'] as bool? ?? false,
      intervalMinutes: map['intervalMinutes'] as int? ?? 720,
    );
  }

  /// Whether the user has turned the timed check on.
  final bool on;

  /// Whether the app may read the SMS inbox.
  final bool hasAccess;

  /// Texts from the last 7 days, by what the rules found.
  final int scam;
  final int caution;
  final int gambling;
  final int total;

  /// When the inbox was last checked, by the timer or by opening the app.
  final DateTime? checkedAt;

  /// Whether Android lets the app show its scam alert.
  final bool canNotify;

  /// How far apart the scheduled checks are: 12 hours, or 2 minutes in a
  /// debug build.
  final int intervalMinutes;

  /// The interval in words, as "12 hours" or "2 minutes".
  String get intervalLabel {
    if (intervalMinutes % 60 != 0) return '$intervalMinutes minutes';
    final hours = intervalMinutes ~/ 60;
    return hours == 1 ? 'hour' : '$hours hours';
  }
}

/// The Android side of the timed check, behind an interface so the screen
/// can be tested without a phone.
abstract class TimedCheckPlatform {
  Future<TimedStatus> status();
  Future<bool> requestNotifications();
  Future<TimedStatus> turnOn();
  Future<TimedStatus> turnOff();
  Future<TimedStatus> checkNow();
}

/// Through `MainActivity`, to `InboxCheck.kt` and `InboxAlarm.kt`.
class AndroidTimedCheck implements TimedCheckPlatform {
  const AndroidTimedCheck();

  static const _channel = MethodChannel('hudyat/timed');

  Future<TimedStatus> _call(String method) async => TimedStatus.fromMap(
    await _channel.invokeMapMethod<Object?, Object?>(method) ?? const {},
  );

  @override
  Future<TimedStatus> status() => _call('status');

  @override
  Future<bool> requestNotifications() async =>
      await _channel.invokeMethod<bool>('requestNotifications') ?? false;

  @override
  Future<TimedStatus> turnOn() => _call('turnOn');

  @override
  Future<TimedStatus> turnOff() => _call('turnOff');

  @override
  Future<TimedStatus> checkNow() => _call('checkNow');
}

/// Automatic checking (spec 3.4): Android wakes the app every 12 hours, a Kotlin
/// copy of the rules checks the last 7 days of texts, alerts for a new
/// "Mukhang scam" one and updates the home screen widget. This class only
/// turns that on and off and reports what it found. Off until the user
/// turns it on.
class TimedCheck extends ChangeNotifier {
  TimedCheck({required this._platform, required this._inbox});

  final TimedCheckPlatform _platform;
  final SmsInbox _inbox;

  TimedStatus status = const TimedStatus();

  Future<void> _apply(Future<TimedStatus> Function() call) async {
    try {
      status = await call();
      notifyListeners();
    } on PlatformException catch (error) {
      debugPrint('TimedCheck: $error');
    } on MissingPluginException {
      // Not on Android: there is no timed check, and the screen says off.
    }
  }

  Future<void> refresh() => _apply(_platform.status);

  /// Runs the check now, so the widget is current after the app was used.
  Future<void> checkNow() => _apply(_platform.checkNow);

  /// Asks for SMS access, then for alerts, and starts the timer. False when
  /// SMS access was not given; alerts are optional, the widget still counts.
  Future<bool> turnOn() async {
    try {
      if (!await _inbox.hasPermission() && !await _inbox.requestPermission()) {
        return false;
      }
      await _platform.requestNotifications();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
    await _apply(_platform.turnOn);
    return status.on;
  }

  Future<void> turnOff() => _apply(_platform.turnOff);
}
