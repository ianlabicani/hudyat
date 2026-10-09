import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/pack/pack_installer.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('hudyat-pack');
    file = File('${dir.path}/metro-manila.sqlite');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Uint8List bytes(int fill, [int length = 4096]) =>
      Uint8List.fromList(List.filled(length, fill));

  test('writes the pack when there is none', () async {
    expect(await installPack(bytes(1), file), isTrue);
    expect(file.readAsBytesSync(), bytes(1));
  });

  test('writes nothing when the same pack is already there', () async {
    await installPack(bytes(1), file);
    // An old timestamp, so an untouched file is told from a rewritten one.
    final before = DateTime(2020);
    file.setLastModifiedSync(before);
    expect(await installPack(bytes(1), file), isFalse);
    expect(file.lastModifiedSync(), before);
  });

  test('replaces a different pack, of the same size or not', () async {
    await installPack(bytes(1), file);
    expect(await installPack(bytes(2), file), isTrue);
    expect(file.readAsBytesSync(), bytes(2));
    expect(await installPack(bytes(2, 8192), file), isTrue);
    expect(file.lengthSync(), 8192);
  });

  test('leaves no half-written copy behind', () async {
    await installPack(bytes(1), file);
    await installPack(bytes(2), file);
    expect(dir.listSync().map((f) => f.path), [file.path]);
  });
}
