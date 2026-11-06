import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junior_u16/home_app.dart';
import 'package:junior_u16/player_insights.dart';
import 'package:junior_u16/player_statistics.dart';
import 'package:junior_u16/team_hub.dart';
import 'package:junior_u16/cup_data.dart';
import 'player_stats_v14_test.dart' show sampleStats;

void main(){
  testWidgets('Comparison chooses both players and shows points per game',(tester)async{
    await tester.pumpWidget(MaterialApp(home:PlayerComparisonPage(data:CupStatistics.fromApi(sampleStats()))));
    await tester.tap(find.text('Выбрать первого игрока'));await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),'Иван');await tester.pumpAndSettle();
    await tester.tap(find.text('Иван Первый'));await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать второго игрока'));await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),'Алексей');await tester.pumpAndSettle();
    await tester.tap(find.text('Алексей Второй'));await tester.pumpAndSettle();
    expect(find.text('Очки за игру'),findsOneWidget);expect(find.text('1.25'),findsOneWidget);expect(find.text('1.13'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('Small phone keeps navigation after background and resume',(tester)async{
    tester.view.physicalSize=const Size(360,800);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const JuniorApp());await tester.pump(const Duration(milliseconds:200));
    await tester.tap(find.text('Избранное'));await tester.pump(const Duration(milliseconds:200));
    expect((await SharedPreferences.getInstance()).getInt('junior_tab'),5);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds:30));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds:200));
    expect(find.text('Избранное пока пусто'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Team hub exposes schedule meetings and qualification',(tester)async{
    const team=TeamInfo(1,'A','','A','',null);
    await tester.pumpWidget(const MaterialApp(home:TeamHubPage(team:team,matches:[],teams:[team])));
    await tester.pump(const Duration(milliseconds:100));
    expect(find.text('Личные встречи'),findsOneWidget);
    await tester.tap(find.text('Расклады'));await tester.pumpAndSettle();
    expect(find.text('Диапазон очков: 0–28'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
