import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/tournament.dart';
import 'package:junior_u16/tournament_page.dart';

final now=DateTime.utc(2026,11,9,20);

Match game(String home,String away,String score,String stage,{
  String date='2026-09-20',String note='',String status='FINAL',
}) =>Match(date,home,away,score,stage,'ФХР',
  status:status,scoreNote:note);

void main(){
  test('FHR regulation: exactly five tours and 140 qualifier fixtures',(){
    expect(firstTourGames,40);
    expect(secondTourGames,50);
    expect(thirdTourGames,50);
    expect(expectedQualifyingGames,140);
    expect(expectedParticipants,20);
    expect(tourOf('Группа A-I'),CupTour.first);
    expect(tourOf('Группа Б-II'),CupTour.second);
    expect(tourOf('Группа В-III'),CupTour.third);
    expect(tourOf('Плей-офф А и Б - II'),CupTour.second);
    expect(tourOf('Стыковые В и Г - III'),CupTour.third);
    expect(tourOf('Золотой финал'),CupTour.gold);
    expect(tourOf('Серебряный финал'),CupTour.silver);
  });
  test('FHR styk games affect total but never individual group standings',(){
    final games=[
      game('A','B','2:1','Группа A-I'),
      game('B','C','3:0','Плей-офф А и Б - II'),
      game('A','C','1:4','Группа A-I'),
    ];
    final cup=CupTournament(games,utcNow:now);
    expect(cup.crossoverMatches().length,1);
    expect(cup.groupNames().length,1);
    final group=cup.table(group:'Группа A-I');
    final common=cup.table();
    expect(group.firstWhere((r)=>r.team=='B').gp,1);
    expect(common.firstWhere((r)=>r.team=='B').gp,2);
    expect(common.firstWhere((r)=>r.team=='B').pts,2);
  });
  test('A win is 2 points, OT loss gives 1, regular loss 0',(){
    final games=[
      game('A','B','3:2','Группа A-I',note:'ОТ'),
      game('B','C','5:1','Группа A-I'),
    ];
    final rows=ranking(games,utcNow:now);
    expect(rows.firstWhere((r)=>r.team=='A').pts,2);
    expect(rows.firstWhere((r)=>r.team=='B').pts,3);
    expect(rows.firstWhere((r)=>r.team=='C').pts,0);
    expect(rows.firstWhere((r)=>r.team=='B').otLosses,1);
    expect(rows.firstWhere((r)=>r.team=='B').rw,1);
  });
  test('H2H ranks tied teams who played each other',(){
    final games=[
      game('A','B','2:1','Группа A-I'),
      game('B','C','4:0','Группа A-I'),
      game('C','A','1:0','Группа A-I'),
    ];
    final rank=ranking(games,utcNow:now);
    expect(rank.every((r)=>r.pts==2),true);
    // H2H points equal, head-to-head GD decides: B +2, A 0, C -2.
    expect(rank.map((r)=>r.team).toList(),['B','A','C']);
  });
  test('Final games do not pollute qualifying standings',(){
    final games=[
      game('A','B','2:0','Группа A-I'),
      game('B','A','6:0','Золотой финал'),
    ];
    final cup=CupTournament(games,utcNow:now);
    expect(cup.table().first.team,'A');
    expect(cup.finalTable(CupTour.gold).first.team,'B');
    expect(cup.qualifyingFixtureCount,1);
  });
  test('never lock Gold and Silver teams before all three tours',(){
    final cup=CupTournament([
      game('A','B','2:1','Группа A-I'),
    ],teams:List.generate(20,(i)=>'TEAM-$i'),utcNow:now);
    expect(cup.qualificationComplete,false);
    expect(cup.goldQualifiers,isEmpty);
    expect(cup.silverQualifiers,isEmpty);
    expect(cup.thirdTourPreview()[0].first,'Место 1');
  });
  test('third tour snake follows official ranking positions',(){
    expect(CupTournament.thirdTourSnake,[
      [1,8,9,16,17],[2,7,10,15,18],
      [3,6,11,14,19],[4,5,12,13,20],
    ]);
  });
  test('calendar future games with scores during LIVE never counted as final',(){
    final cup=CupTournament([
      game('A','B','3:2','Группа A-II',date:'2026-11-09',status:'LIVE'),
      game('B','C','','Группа A-II',date:'2026-11-10',status:'SCHEDULED'),
    ],utcNow:now);
    expect(cup.completedQualifyingGames,0);
    expect(cup.table().every((r)=>r.pts==0),true);
  });
  testWidgets('v13 tournament navigator offers phases tables and finals',(tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:TournamentPage(
      matches:[game('A','B','2:1','Группа A-I')],
      teams:const ['A','B'],teamLogo:(_)=>null,
      onMatch:(_){},onTeam:(_){},
    ))));
    expect(find.text('Кубок России'),findsOneWidget);
    expect(find.text('ТАБЛИЦЫ'),findsOneWidget);
    await tester.tap(find.text('ТАБЛИЦЫ'));
    await tester.pumpAndSettle();
    expect(find.text('ТАБЛИЦЫ ГРУПП'),findsOneWidget);
    await tester.tap(find.text('ФИНАЛЫ'));
    await tester.pumpAndSettle();
    expect(find.text('ФИНАЛЬНЫЕ ТУРЫ'),findsOneWidget);
  });
}
