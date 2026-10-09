import 'package:flutter/services.dart';

/// Something another app handed to Hudyat. [text] is null when it had no
/// text in it.
class SharedText {
  const SharedText(this.text, {this.openFlagged = false, this.resultId});

  final String? text;

  /// True for a tap on a scam alert or on the home screen widget, which
  /// carries no text and asks for the Flagged list.
  final bool openFlagged;
  final int? resultId;
}

/// The two ways in from other apps: the share sheet and "Check with Hudyat"
/// in the text selection menu. Android's side is `ShareActivity`, which
/// passes the text to the running app over this channel.
class ShareEntry {
  ShareEntry([this._channel = const MethodChannel('hudyat/incoming')]);

  final MethodChannel _channel;

  /// Calls [onIncoming] when text arrives while the app is open.
  void listen(void Function() onIncoming) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'incoming') onIncoming();
    });
  }

  /// The text waiting to be checked, if any. It is handed over once.
  Future<SharedText?> take() async {
    try {
      final payload = await _channel.invokeMapMethod<String, String>('take');
      if (payload == null) return null;
      if (payload['open'] == 'flagged') {
        return const SharedText(null, openFlagged: true);
      }
      if (payload['open'] == 'result') {
        return SharedText(
          null,
          resultId: int.tryParse(payload['resultId'] ?? ''),
        );
      }
      final text = payload['text']?.trim() ?? '';
      return SharedText(text.isEmpty ? null : text);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      // Not on Android: nothing can be shared in.
      return null;
    }
  }

  void dispose() => _channel.setMethodCallHandler(null);
}
