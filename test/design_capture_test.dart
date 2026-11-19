import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junior_u16/app_theme.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/match_center.dart';

void main() {
  testWidgets('Capture match screen at phone width', (tester) async {
    if (!const bool.fromEnvironment('DESIGN_CAPTURE')) return;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final fonts = FontLoader('Manrope');
    for (final style in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Manrope-$style.ttf'));
    }
    await fonts.load();
    var match = const Match('2026-11-10', 'Крылья Советов Москва',
        'Авангард Омск', '4:2', 'Группа В-II', '',
        status: 'FINAL', timeMsk: '18:00');
    var detail = <String, dynamic>{'ok': false};
    const dataDir = String.fromEnvironment('PREVIEW_DATA_DIR');
    if (dataDir.isNotEmpty) {
      detail =
          jsonDecode(await File('$dataDir/match-25170469.json').readAsString());
      final feed = FhrFeed.fromApi(
          jsonDecode(await File('$dataDir/matches.json').readAsString()));
      match = feed.matches.firstWhere((m) => m.gameId == 25170469);
    }
    await http.runWithClient(() async {
      await tester.pumpWidget(RepaintBoundary(
          key: const ValueKey('match-preview'),
          child: MaterialApp(
              theme: juniorTheme(true), home: MatchCenterPage(match: match))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('match-preview')));
      await tester.runAsync(() async {
        final shot = await boundary.toImage(pixelRatio: 2);
        final bytes = await shot.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/previews/match-v37.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        shot.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((_) async => http.Response(jsonEncode(detail), 200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });
}
