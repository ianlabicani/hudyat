import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The pack ships inside the app. SQLite needs a real file, so it is copied
/// to app storage on every launch; at under 2 MB that is quicker than
/// checking whether the copy is current.
Future<String> installBundledPack() async {
  const asset = 'assets/pack/metro-manila.sqlite';
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, p.basename(asset)));
  final data = await rootBundle.load(asset);
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
  return file.path;
}
