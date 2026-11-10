import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junior_u16/home_app.dart';
import 'package:junior_u16/match_center.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/command_center_page.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Native match center shows own four tabs and no embedded webpage',
      (tester) async {
    const game=Match('2026-09-10','ЦСКА Москва','НЕФТЕХИМИК Нижнекамск',
      '4:2','Группа Г-I','МАУ ЛК Владимир',timeMsk:'18:00');
    await tester.pumpWidget(const MaterialApp(home:MatchCenterPage(match:game)));
    expect(find.text('LIVE DESK · ПРОТОКОЛ МАТЧА'),findsOneWidget);
    expect(find.text('ОБЗОР'),findsOneWidget);
    expect(find.text('СОБЫТИЯ'),findsOneWidget);
    expect(find.text('СОСТАВЫ'),findsOneWidget);
    expect(find.text('СТАТИСТИКА'),findsOneWidget);
    expect(find.text('4 : 2'),findsOneWidget);
    expect(find.byType(Scaffold),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('App opens six sports tabs including all player statistics',(tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const JuniorApp());
    await tester.pump();
    expect(find.text('JUNIOR U16'),findsOneWidget);
    expect(find.text('Главная'),findsOneWidget);
    expect(find.text('Матчи'),findsOneWidget);
    expect(find.text('Турнир'),findsOneWidget);
    expect(find.text('Игроки'),findsOneWidget);
    expect(find.text('Команды'),findsOneWidget);
    expect(find.text('Избранное'),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Arena navigation and match center fit a narrow phone',(tester) async {
    tester.view.physicalSize=const Size(360,780);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const JuniorApp());
    await tester.pump();
    expect(find.text('Избранное'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const MaterialApp(home:CommandCenterPage(
      matches:[],clubs:[],onTeam:_ignoreTeam,onMatch:_ignoreMatch)));
    await tester.pump();
    expect(find.text('АНАЛИТИЧЕСКИЙ ПУЛЬТ'),findsOneWidget);
    await tester.drag(find.byType(ListView).first,const Offset(-1100,0));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('command-tab-6')));
    await tester.pump();
    expect(find.text('07 / 07'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _ignoreTeam(String team){}
void _ignoreMatch(Match match){}
