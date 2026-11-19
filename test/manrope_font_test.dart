import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Uint8List> fontTables(ByteData data) {
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  return {
    for (var i = 0; i < data.getUint16(4); i++)
      String.fromCharCodes(bytes.sublist(12 + i * 16, 16 + i * 16)):
          bytes.sublist(data.getUint32(20 + i * 16),
              data.getUint32(20 + i * 16) + data.getUint32(24 + i * 16)),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Manrope weights use distinct static glyphs and matching font metadata',
      () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    final family =
        manifest.cast<Map>().singleWhere((font) => font['family'] == 'Manrope');
    final fonts = (family['fonts'] as List).cast<Map>();
    expect(fonts.map((font) => font['weight']).toSet(), {400, 600, 700, 800});
    expect(fonts.map((font) => font['asset']).toSet(), hasLength(4));
    final outlines = <String>{};
    for (final font in fonts) {
      final tables = fontTables(await rootBundle.load(font['asset'] as String));
      expect(tables, isNot(contains('fvar')),
          reason: 'A weight entry must pin the variable axis');
      final os2 = ByteData.sublistView(tables['OS/2']!);
      expect(os2.getUint16(4), font['weight'], reason: font['asset'] as String);
      outlines.add(base64Encode(tables['glyf']!));
    }
    expect(outlines, hasLength(4),
        reason: 'Bold entries must change glyph shapes, not just font labels');
  });
}
