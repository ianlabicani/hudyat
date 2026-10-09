// Throwaway test of Android notification access (spec 3.4). It answers:
// can access be granted on this phone, do message notifications arrive while
// the app is in the background, and how much of a long message they carry.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

class NotificationTestPage extends StatefulWidget {
  const NotificationTestPage({super.key});

  @override
  State<NotificationTestPage> createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage>
    with AutomaticKeepAliveClientMixin {
  final _log = StringBuffer();
  StreamSubscription<ServiceNotificationEvent>? _subscription;
  bool? _granted;
  int _count = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _say(String line) => setState(() => _log.writeln(line));

  Future<void> _check() async {
    try {
      final granted = await NotificationListenerService.isPermissionGranted();
      setState(() => _granted = granted);
      _say('access granted: $granted');
    } on Object catch (error) {
      _say('ERROR check: $error');
    }
  }

  Future<void> _request() async {
    try {
      final granted = await NotificationListenerService.requestPermission();
      setState(() => _granted = granted);
      _say('after settings screen, access granted: $granted');
    } on Object catch (error) {
      _say('ERROR request: $error');
    }
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = NotificationListenerService.notificationsStream.listen((
      event,
    ) {
      if (event.hasRemoved) return;
      _count++;
      final now = DateTime.now();
      final time =
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}';
      _say(
        '#$_count $time ${event.packageName}\n'
        '  title: ${event.title}\n'
        '  content (${event.content.length} chars): ${event.content}',
      );
    }, onError: (Object error) => _say('ERROR stream: $error'));
    _say('listening. Put the app in the background and send a message.');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _check,
                child: const Text('1. Check access'),
              ),
              FilledButton(
                onPressed: _request,
                child: const Text('2. Ask for access'),
              ),
              FilledButton(
                onPressed: _granted == true ? _listen : null,
                child: const Text('3. Listen'),
              ),
              OutlinedButton(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: _log.toString())),
                child: const Text('Copy log'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            reverse: true,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              _log.toString(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
