import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ProtectionSource {
  const ProtectionSource({
    required this.package,
    required this.name,
    required this.installed,
    required this.enabled,
  });

  factory ProtectionSource.fromMap(Map<Object?, Object?> map) =>
      ProtectionSource(
        package: map['package'] as String? ?? '',
        name: map['name'] as String? ?? '',
        installed: map['installed'] as bool? ?? false,
        enabled: map['enabled'] as bool? ?? false,
      );

  final String package;
  final String name;
  final bool installed;
  final bool enabled;
}

class ProtectionStatus {
  const ProtectionStatus({
    this.smsOn = false,
    this.smsRead = false,
    this.smsCapture = false,
    this.appsOn = false,
    this.notificationAccess = false,
    this.listenerConnected = false,
    this.canAlert = false,
    this.lastProcessed,
    this.failure,
    this.sources = const [],
  });

  factory ProtectionStatus.fromMap(Map<Object?, Object?> map) {
    final at = map['lastProcessed'] as int? ?? 0;
    final failure = map['failure'] as String?;
    return ProtectionStatus(
      smsOn: map['smsOn'] as bool? ?? false,
      smsRead: map['smsRead'] as bool? ?? false,
      smsCapture: map['smsCapture'] as bool? ?? false,
      appsOn: map['appsOn'] as bool? ?? false,
      notificationAccess: map['notificationAccess'] as bool? ?? false,
      listenerConnected: map['listenerConnected'] as bool? ?? false,
      canAlert: map['canAlert'] as bool? ?? false,
      lastProcessed: at == 0 ? null : DateTime.fromMillisecondsSinceEpoch(at),
      failure: failure == null || failure.isEmpty ? null : failure,
      sources: [
        for (final source in map['sources'] as List? ?? const [])
          ProtectionSource.fromMap((source as Map).cast<Object?, Object?>()),
      ],
    );
  }

  final bool smsOn;
  final bool smsRead;
  final bool smsCapture;
  final bool appsOn;
  final bool notificationAccess;
  final bool listenerConnected;
  final bool canAlert;
  final DateTime? lastProcessed;
  final String? failure;
  final List<ProtectionSource> sources;

  bool get on => smsOn || appsOn;
  bool get appsReady => appsOn && notificationAccess && listenerConnected;
}

/// Native protection settings and completed-result events. Android performs
/// capture and fast rules without a Flutter engine or a loaded model.
abstract class ProtectionPlatform {
  Future<ProtectionStatus> status();

  /// Every finding the Android side has kept, as plain maps. Dart copies
  /// them into its own store and never opens the Android side's file.
  Future<List<Map<Object?, Object?>>> findings();
  Future<bool> requestSmsCapture();
  Future<ProtectionStatus> setAppsOn(bool enabled);
  Future<ProtectionStatus> setSourceEnabled(String package, bool enabled);
  Future<ProtectionStatus> stopAll();
  Future<void> openNotificationAccess();
  Future<void> openAlertSettings();
  Stream<void> get resultChanges;
}

class AndroidProtectionPlatform implements ProtectionPlatform {
  const AndroidProtectionPlatform();

  static const _channel = MethodChannel('hudyat/protection');
  static const _events = EventChannel('hudyat/protection_events');

  Future<ProtectionStatus> _call(
    String method, [
    Map<String, Object?>? arguments,
  ]) async => ProtectionStatus.fromMap(
    await _channel.invokeMapMethod<Object?, Object?>(method, arguments) ??
        const {},
  );

  @override
  Future<ProtectionStatus> status() => _call('status');

  @override
  Future<List<Map<Object?, Object?>>> findings() async => [
    for (final row
        in await _channel.invokeListMethod<Object?>('findings') ?? const [])
      if (row is Map<Object?, Object?>) row,
  ];

  @override
  Future<bool> requestSmsCapture() async =>
      await _channel.invokeMethod<bool>('requestSmsCapture') ?? false;

  @override
  Future<ProtectionStatus> setAppsOn(bool enabled) =>
      _call('setAppsOn', {'enabled': enabled});

  @override
  Future<ProtectionStatus> setSourceEnabled(String package, bool enabled) =>
      _call('setSourceEnabled', {'package': package, 'enabled': enabled});

  @override
  Future<ProtectionStatus> stopAll() => _call('stopAll');

  @override
  Future<void> openNotificationAccess() =>
      _channel.invokeMethod<void>('openNotificationAccess');

  @override
  Future<void> openAlertSettings() =>
      _channel.invokeMethod<void>('openAlertSettings');

  @override
  Stream<void> get resultChanges =>
      _events.receiveBroadcastStream().map((_) {});
}

class ProtectionController extends ChangeNotifier {
  ProtectionController(
    this._platform, {
    required VoidCallback onResultsChanged,
  }) {
    _subscription = _platform.resultChanges.listen((_) {
      onResultsChanged();
      unawaited(refresh());
    });
  }

  final ProtectionPlatform _platform;
  StreamSubscription<void>? _subscription;
  ProtectionStatus status = const ProtectionStatus();
  bool _disposed = false;

  Future<void> refresh() async {
    try {
      status = await _platform.status();
      if (!_disposed) notifyListeners();
    } on PlatformException {
      // The screen retains its previous status during an Android failure.
    } on MissingPluginException {
      // Other platforms have no live protection.
    }
  }

  /// The Android side's findings, or none when it cannot be asked.
  Future<List<Map<Object?, Object?>>> findings() async {
    try {
      return await _platform.findings();
    } on PlatformException catch (error) {
      debugPrint('Protection: $error');
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  Future<bool> requestSmsCapture() async {
    try {
      final granted = await _platform.requestSmsCapture();
      await refresh();
      return granted;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> setAppsOn(bool enabled) =>
      _apply(() => _platform.setAppsOn(enabled));

  Future<void> setSourceEnabled(String package, bool enabled) =>
      _apply(() => _platform.setSourceEnabled(package, enabled));

  Future<void> stopAll() => _apply(_platform.stopAll);

  Future<void> _apply(Future<ProtectionStatus> Function() call) async {
    try {
      status = await call();
      if (!_disposed) notifyListeners();
    } on PlatformException {
      await refresh();
    } on MissingPluginException {
      // No native implementation on other platforms.
    }
  }

  Future<void> openNotificationAccess() => _platform.openNotificationAccess();
  Future<void> openAlertSettings() => _platform.openAlertSettings();

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
