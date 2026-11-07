import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/scenario.dart';
import 'package:junior_u16/scenario_page.dart';
import 'package:junior_u16/my_team.dart';

const upcoming=Match('2027-01-10','A','B','','Группа 1-III','',gameId:1);
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Scenario applies 2-1-0 without altering official fixture',(){
    final sim=applyScenario([upcoming],{'1':const ScenarioScore(3,2,overtime:true)});
    final table=ranking(sim.matches);
    expect(table.first.pts,2);expect(table.last.pts,1);
    expect(upcoming.score,'');expect(upcoming.status,'UNKNOWN');expect(sim.applied,1);
    expect(ranking(applyScenario([upcoming],{'1':const ScenarioScore(3,0)}).matches).last.pts,0);
  });
  test('Final, live and final-stage fixtures cannot be overridden',(){
    final games=[const Match('2026-10-01','A','B','2:1','Группа 1-I','',status:'FINAL',gameId:1),const Match('2026-11-07','A','B','1:1','Группа 1-II','',status:'LIVE',gameId:2),const Match('2027-04-01','A','B','','Золотой финал','',gameId:3)];
    final scores={for(final m in games)m.key:const ScenarioScore(0,5)};
    expect(applyScenario(games,scores).applied,0);expect(scenarioFixtures(games),isEmpty);
  });
  test('Reject invalid scores and stale scenario ids',(){
    for(final score in [const ScenarioScore(1,1),const ScenarioScore(-1,0),const ScenarioScore(100,0),const ScenarioScore(4,1,overtime:true)]){expect(score.valid,false);expect(applyScenario([upcoming],{'1':score}).applied,0);}
    expect(applyScenario([upcoming],{'missing':const ScenarioScore(2,0)}).applied,0);
    expect(ScenarioScore.parse({'home':'3','away':1}),null);
  });
  test('Duplicate matches count only once in scenarios',(){
    final result=applyScenario([upcoming,upcoming],{'1':const ScenarioScore(2,0)});
    expect(result.applied,1);expect(result.matches.length,1);expect(ranking(result.matches).first.gp,1);
  });
  test('Next team game prefers live and ignores old unconfirmed fixtures',(){
    final old=const Match('2026-01-01','A','B','','Группа 1-I','');
    expect(nextTeamMatch([old,upcoming],'A',utcNow:DateTime.utc(2026,11,7)),upcoming);
    final live=const Match('2026-11-07','A','B','1:1','Группа 1-II','',status:'LIVE');
    expect(nextTeamMatch([upcoming,live],'A',utcNow:DateTime.utc(2026,11,7)),live);
    expect(nextTeamMatch([old],'A',utcNow:DateTime.utc(2026,11,7)),null);
  });
  testWidgets('Score dialog rejects draws then accepts an overtime result',(tester)async{
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:ScenarioScoreDialog(match:upcoming))));
    await tester.enterText(find.byKey(const ValueKey('scenario-home-score')),'2');
    await tester.enterText(find.byKey(const ValueKey('scenario-away-score')),'2');
    await tester.tap(find.text('Применить'));await tester.pump();
    expect(find.text('Ничьи в хоккее нет.'),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('My team selection persists after card recreation',(tester)async{
    SharedPreferences.setMockInitialValues({});
    const teams=[TeamInfo(10,'A','Москва','A','',null),TeamInfo(20,'B','Казань','B','',null)];
    Widget card()=>MaterialApp(home:Scaffold(body:SingleChildScrollView(child:MyTeamCard(teams:teams,matches:const [upcoming],onTeam:(_){},onMatch:(_){}))));
    await tester.pumpWidget(card());await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать мою команду'));await tester.pumpAndSettle();
    await tester.tap(find.text('A'));await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getInt(myTeamPreference),10);
    await tester.pumpWidget(const SizedBox.shrink());await tester.pumpWidget(card());await tester.pumpAndSettle();
    expect(find.text('Сменить'),findsOneWidget);expect(find.text('A'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('Scenario editor recalculates and persists only private assumptions',(tester)async{
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home:ScenarioPage(matches:[upcoming],teams:['A','B'])));await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Задать'),300,scrollable:find.byType(Scrollable).first);await tester.pumpAndSettle();
    await tester.tap(find.text('Задать'));await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('scenario-home-score')),'3');
    await tester.enterText(find.byKey(const ValueKey('scenario-away-score')),'2');
    await tester.tap(find.byType(Switch));await tester.tap(find.text('Применить'));await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getString('junior_scenario_2026_27'),contains('"overtime":true'));
    expect(upcoming.score,'');expect(tester.takeException(),isNull);
  });
}
