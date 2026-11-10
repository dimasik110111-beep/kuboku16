import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/match_center.dart';
import 'package:junior_u16/ui_kit.dart';

void main(){
  testWidgets('Capture Ice Signal match screen at phone width',(tester)async{
    if(!const bool.fromEnvironment('DESIGN_CAPTURE'))return;
    tester.view.physicalSize=const Size(390,820);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CupUi.light=true;
    final body=FontLoader('ArenaSans')
      ..addFont(rootBundle.load('assets/fonts/arena/OpenSans-Regular.ttf'));
    final display=FontLoader('ArenaCondensed')
      ..addFont(rootBundle.load('assets/fonts/arena/OpenSans-CondBold.ttf'));
    final icons=FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons.ttf'));
    await body.load();
    await display.load();
    await icons.load();
    const match=Match('2026-11-10','Крылья Советов Москва',
      'Авангард Омск','4:2','Группа В-II','',
      status:'FINAL',timeMsk:'18:00');
    await tester.pumpWidget(RepaintBoundary(key:const ValueKey('arena-preview'),
      child:MaterialApp(theme:ThemeData(fontFamily:'ArenaSans'),
        home:MatchCenterPage(match:match))));
    await tester.pump(const Duration(milliseconds:500));
    expect(tester.takeException(),isNull);
    final boundary=tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('arena-preview')));
    final encoded=await tester.runAsync(()async{
      final shot=await boundary.toImage(pixelRatio:1);
      final bytes=await shot.toByteData(format:ui.ImageByteFormat.png);
      return bytes==null?null:base64Encode(bytes.buffer.asUint8List());
    }).timeout(const Duration(seconds:20));
    expect(encoded,isNotNull);
    print('ARENA_PNG:$encoded');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
