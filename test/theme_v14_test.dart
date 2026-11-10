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
    expect(CupUi.surface,const Color(0xFFFFFEFA));
    expect(CupUi.white,const Color(0xFF17271E));
    CupUi.light=false;
  });

  testWidgets('User can toggle theme and preference is saved',(tester)async{
    SharedPreferences.setMockInitialValues({});
    CupUi.light=false;
    await tester.pumpWidget(const JuniorApp());
    await tester.pump(const Duration(milliseconds:200));
    expect(CupUi.light,isFalse);
    expect(find.byIcon(Icons.light_mode_outlined),findsOneWidget);
    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pump(const Duration(milliseconds:200));
    expect(CupUi.light,isTrue);
    expect(find.byIcon(Icons.dark_mode_outlined),findsOneWidget);
    final prefs=await SharedPreferences.getInstance();
    expect(prefs.getBool('junior_u16_light_theme'),isTrue);
    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pump(const Duration(milliseconds:200));
    expect(CupUi.light,isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
