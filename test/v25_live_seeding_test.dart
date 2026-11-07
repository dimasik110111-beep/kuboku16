import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/tournament.dart';
import 'package:junior_u16/tournament_page.dart';

void main(){
  final now=DateTime.utc(2026,11,10,12);
  final clubs=List.generate(20,(i)=>'Club ${i.toString().padLeft(2,'0')}');
  Match game(String home,String away,String score,String status,{String stage='Группа А-II'})=>
    Match('2026-11-09',home,away,score,stage,'',
      status:status);

  test('Live third-tour projection is populated before round two finishes',(){
    final cup=CupTournament([
      game(clubs[19],clubs[0],'4:1','FINAL'),
    ],teams:clubs,utcNow:now);
    expect(cup.firstTwoComplete,isFalse);
    expect(cup.thirdTourProjection().length,4);
    expect(cup.thirdTourProjection().every((g)=>g.length==5),isTrue);
    expect(cup.thirdTourProjection()[0][0],clubs[19]);
    expect(cup.thirdTourPreview()[0][0],'Место 1');
  });

  test('Official final triggers immediate re-seeding; live score does not',(){
    final confirmed=game(clubs[19],clubs[0],'4:1','FINAL');
    final live=game(clubs[18],clubs[19],'8:0','LIVE');
    final liveCup=CupTournament([confirmed,live],teams:clubs,utcNow:now);
    expect(liveCup.thirdTourProjection()[0].first,clubs[19]);
    final finalCup=CupTournament([
      confirmed,game(clubs[18],clubs[19],'8:0','FINAL'),
    ],teams:clubs,utcNow:now);
    expect(finalCup.thirdTourProjection()[0].first,clubs[18]);
    expect(finalCup.thirdTourProjection()[0].first,
      isNot(liveCup.thirdTourProjection()[0].first));
  });

  test('The snake includes 20 distinct participants, without duplicates',(){
    final cup=CupTournament([],teams:clubs,utcNow:now);
    final projected=cup.thirdTourProjection().expand((g)=>g).toList();
    expect(projected.length,20);
    expect(projected.toSet().length,20);
    expect(CupTournament.thirdTourSnake[0],[1,8,9,16,17]);
  });

  testWidgets('Dedicated seeding tab exposes current teams',(tester)async{
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:TournamentPage(
      matches:[game(clubs[19],clubs[0],'4:1','FINAL')],
      teams:clubs,teamLogo:(_)=>null,onTeam:(_){},onMatch:(_){},
    ))));
    await tester.tap(find.text('РАССЕВ III'));
    await tester.pumpAndSettle();
    expect(find.text('LIVE-РАССЕВ III ТУРА'),findsOneWidget);
    expect(find.text('ГРУППА А'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
