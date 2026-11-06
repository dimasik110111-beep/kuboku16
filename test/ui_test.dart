import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junior_u16/home_app.dart';
import 'package:junior_u16/match_center.dart';
import 'package:junior_u16/cup_data.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Native match center shows own four tabs and no embedded webpage',
      (tester) async {
    const game=Match('2026-09-10','ЦСКА Москва','НЕФТЕХИМИК Нижнекамск',
      '4:2','Группа Г-I','МАУ ЛК Владимир',timeMsk:'18:00');
    await tester.pumpWidget(const MaterialApp(home:MatchCenterPage(match:game)));
    expect(find.text('МАТЧ-ЦЕНТР · U16'),findsOneWidget);
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
}
