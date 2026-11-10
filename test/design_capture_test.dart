import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    const match=Match('2026-11-10','Крылья Советов Москва',
      'Авангард Омск','4:2','Группа В-II','',
      status:'FINAL',timeMsk:'18:00');
    await tester.pumpWidget(const RepaintBoundary(key:ValueKey('arena-preview'),
      child:MaterialApp(home:MatchCenterPage(match:match))));
    await tester.pump(const Duration(milliseconds:500));
    expect(tester.takeException(),isNull);
    final boundary=tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('arena-preview')));
    final shot=await boundary.toImage(pixelRatio:1);
    final bytes=await shot.toByteData(format:ui.ImageByteFormat.png);
    expect(bytes,isNotNull);
    print('ARENA_PNG:${base64Encode(bytes!.buffer.asUint8List())}');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
