import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The pack ships inside the app. SQLite needs a real file, so it is copied
/// to app storage, but only when the copy there is missing or different.
Future<String> installBundledPack() async {
  const asset = 'assets/pack/metro-manila.sqlite';
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, p.basename(asset)));
  final data = await rootBundle.load(asset);
  final wrote = await installPack(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    file,
  );
  debugPrint('Pack: ${wrote ? 'written to app storage' : 'already current'}');
  return file.path;
}

/// Puts [bytes] at [file] unless they are already there. Returns whether it
/// wrote.
///
/// The Android side opens this same file whenever a text arrives or its alarm
/// fires, so it is never rewritten in place: the new copy is written beside
/// it and renamed over it. A reader that already has the old file keeps it
/// whole, and the next open sees the whole new one.
Future<bool> installPack(Uint8List bytes, File file) async {
  if (file.existsSync() && file.lengthSync() == bytes.length) {
    // Reading it back is cheaper than writing and flushing it again.
    if (listEquals(await file.readAsBytes(), bytes)) return false;
  }
  final fresh = File('${file.path}.new');
  await fresh.writeAsBytes(bytes, flush: true);
  await fresh.rename(file.path);
  return true;
}
