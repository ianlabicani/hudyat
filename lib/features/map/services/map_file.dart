import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String?>? _cached;

/// Path of the offline map file, copied out of the app on first use, or null
/// when this build has no map. Without it the places list still works; rows
/// just do not open a map.
Future<String?> mapFile() => _cached ??= _install();

Future<String?> _install() async {
  const asset = 'assets/pack/metro-manila.pmtiles';
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, p.basename(asset)));
    // The file is large, so it is copied once rather than on every launch.
    if (!file.existsSync() || file.lengthSync() == 0) {
      final data = await rootBundle.load(asset);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return file.path;
  } on Object {
    return null;
  }
}
