import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

import 'message_watcher.dart';

/// Android notification access through `notification_listener_service`.
class AndroidNotificationSource implements NotificationSource {
  const AndroidNotificationSource();

  @override
  Future<bool> isGranted() => NotificationListenerService.isPermissionGranted();

  @override
  Future<bool> requestAccess() =>
      NotificationListenerService.requestPermission();

  @override
  Stream<IncomingNotification> get notifications => NotificationListenerService
      .notificationsStream
      .where((event) => !event.hasRemoved)
      .map(
        (event) => IncomingNotification(
          package: event.packageName,
          title: event.title,
          content: event.content,
          postedAt: event.timestamp > 0 ? event.humanTime : null,
        ),
      );
}

/// Battery-optimisation exemption, through `MainActivity`.
class AndroidBackgroundRunner implements BackgroundRunner {
  const AndroidBackgroundRunner();

  static const _channel = MethodChannel('hudyat/power');

  @override
  Future<bool> isAllowed() async =>
      await _channel.invokeMethod<bool>('isExempt') ?? true;

  @override
  Future<void> requestAllowed() =>
      _channel.invokeMethod<bool>('requestExemption');

  @override
  Future<void> keepAwake({required bool on}) =>
      _channel.invokeMethod<bool>(on ? 'startWatching' : 'stopWatching');
}

/// Hudyat's own alert: a standard Android notification with one action.
class LocalAlerter implements Alerter {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'scam_alerts',
      'Scam alerts',
      channelDescription: 'Incoming messages checked as "Mukhang scam"',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
      actions: [
        AndroidNotificationAction('open', 'Tingnan', showsUserInterface: true),
      ],
    ),
  );

  @override
  Future<void> start(void Function(int flaggedId) onOpen) async {
    void open(NotificationResponse response) {
      final id = int.tryParse(response.payload ?? '');
      if (id != null) onOpen(id);
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: open,
    );
    // The app was closed and an alert opened it.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
      open(response);
    }
  }

  @override
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> alert({
    required int flaggedId,
    required String title,
    required String body,
  }) => _plugin.show(
    id: flaggedId,
    title: title,
    body: body,
    notificationDetails: _details,
    payload: '$flaggedId',
  );
}
