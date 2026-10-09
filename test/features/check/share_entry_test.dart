import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/features/check/services/share_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('hudyat/incoming');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Map<String, String>? pending;

  setUp(() {
    messenger.setMockMethodCallHandler(channel, (call) async {
      final payload = pending;
      pending = null;
      return payload;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('hands shared text over once', () async {
    pending = {'text': '  GCash: i-verify ang account  '};
    final entry = ShareEntry();
    expect((await entry.take())?.text, 'GCash: i-verify ang account');
    expect(await entry.take(), isNull);
  });

  test('something shared with no text has a null text', () async {
    pending = {'text': ''};
    final shared = await ShareEntry().take();
    expect(shared, isNotNull);
    expect(shared!.text, isNull);
  });

  test('a tap on an alert or the widget asks for the Flagged list', () async {
    pending = {'open': 'flagged'};
    final shared = await ShareEntry().take();
    expect(shared!.openFlagged, isTrue);
    expect(shared.text, isNull);
  });

  test('is null where the platform has no share channel', () async {
    messenger.setMockMethodCallHandler(channel, null);
    expect(await ShareEntry().take(), isNull);
  });

  test('tells the app when text arrives while it is open', () async {
    var calls = 0;
    final entry = ShareEntry()..listen(() => calls++);
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('incoming')),
      (_) {},
    );
    expect(calls, 1);
    entry.dispose();
  });
}
