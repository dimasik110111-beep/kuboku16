import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junior_u16/home_app.dart';
import 'package:junior_u16/ui_kit.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Light colors are a true contrasting palette, not photo inversion',(){
    CupUi.light=false;
    final darkBg=CupUi.background;
    final darkText=CupUi.white;
    CupUi.light=true;
    expect(CupUi.background,isNot(darkBg));
    expect(CupUi.white,isNot(darkText));
    expect(CupUi.surface,Colors.white);
    expect(CupUi.white,CupUi.navy);
    CupUi.light=false;
  });

  testWidgets('User can toggle theme and preference is saved',(tester)async{
    SharedPreferences.setMockInitialValues({});
    CupUi.light=false;
    await tester.pumpWidget(const JuniorApp());
    await tester.pump(const Duration(milliseconds:200));
    expect(CupUi.light,isTrue);
    await tester.tap(find.byTooltip('Разделы'));
    await tester.pump();
    await tester.tap(find.text('Сменить тему'));
    await tester.pump(const Duration(milliseconds:200));
    expect(CupUi.light,isFalse);
    final prefs=await SharedPreferences.getInstance();
    expect(prefs.getBool('junior_u16_light_theme'),isFalse);
    await tester.tap(find.byTooltip('Разделы'));
    await tester.pump();
    await tester.tap(find.text('Сменить тему'));
    await tester.pump(const Duration(milliseconds:200));
    expect(CupUi.light,isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
