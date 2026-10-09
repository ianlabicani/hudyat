import 'package:flutter/services.dart';

/// One text from the phone's SMS inbox.
class SmsMessage {
  const SmsMessage({
    required this.id,
    required this.sender,
    required this.sentAt,
    required this.body,
  });

  /// Android's own id for the text. It is what the scan index remembers.
  final int id;
  final String sender;
  final DateTime sentAt;
  final String body;
}

/// The phone's SMS inbox, behind an interface so scanning can be tested
/// without a phone.
abstract class SmsInbox {
  Future<bool> hasPermission();

  /// Shows Android's permission prompt; true once SMS access is granted.
  Future<bool> requestPermission();

  /// Texts received at or after [since] (all of them when null), oldest
  /// id first.
  Future<List<SmsMessage>> read({DateTime? since});
}

/// Reads the inbox through `SmsReader.kt`. Needs the `READ_SMS` permission,
/// asked for only when the user starts a scan.
class AndroidSmsInbox implements SmsInbox {
  const AndroidSmsInbox([this._channel = const MethodChannel('hudyat/sms')]);

  final MethodChannel _channel;
  static const _page = 200;

  @override
  Future<bool> hasPermission() => _flag('hasPermission');

  @override
  Future<bool> requestPermission() => _flag('requestPermission');

  Future<bool> _flag(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Not on Android: there is no inbox to read.
      return false;
    }
  }

  @override
  Future<List<SmsMessage>> read({DateTime? since}) async {
    final messages = <SmsMessage>[];
    var afterId = 0;
    while (true) {
      final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'read',
        {
          'since': since?.millisecondsSinceEpoch ?? 0,
          'afterId': afterId,
          'limit': _page,
        },
      );
      if (rows == null || rows.isEmpty) break;
      for (final row in rows) {
        messages.add(
          SmsMessage(
            id: row['id']! as int,
            sender: row['sender'] as String? ?? '',
            sentAt: DateTime.fromMillisecondsSinceEpoch(row['date']! as int),
            body: row['body'] as String? ?? '',
          ),
        );
      }
      afterId = messages.last.id;
      if (rows.length < _page) break;
    }
    return messages;
  }
}
