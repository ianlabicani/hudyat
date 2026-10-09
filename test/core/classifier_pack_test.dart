import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hudyat/core/pack/pack_store.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/classifier_fixture.dart';

void main() {
  test('old packs, corrupt entries and incompatible payloads fall back', () {
    final db = sqlite3.openInMemory();
    db.execute('CREATE TABLE meta (key TEXT,value TEXT)');
    final pack = PackStore(db);
    addTearDown(pack.close);
    expect(pack.suspiciousArtifact(), isNull);
    db.execute("INSERT INTO meta VALUES ('suspicious_classifier','invalid')");
    expect(pack.suspiciousArtifact(), isNull);
    db.execute("UPDATE meta SET value=?", [
      jsonEncode({'payload': '{}', 'version': 'wrong'}),
    ]);
    expect(pack.suspiciousArtifact(), isNull);
    db.execute('UPDATE meta SET value=?', [
      jsonEncode(classifierEnvelope(approved: true)),
    ]);
    expect(pack.suspiciousArtifact()!.approved, isTrue);
  });
}
