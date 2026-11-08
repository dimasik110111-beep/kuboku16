import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/tournament.dart';
import 'package:junior_u16/tournament_page.dart';

void main() {
  final now=DateTime.utc(2026,11,8);

  test('live table applies current goals and provisional points only to projection',(){
    final matches=<Match>[
      Match('2026-11-01','A','B','3:1','Группа А-II','',status:'FINAL',gameId:1),
      Match('2026-11-08','C','D','2:0','Группа А-II','',status:'LIVE',gameId:2),
    ];
    final cup=CupTournament(matches,teams:['A','B','C','D'],utcNow:now);
    final official=cup.table();
    final live=cup.liveTable();
    expect(official.firstWhere((r)=>r.team=='C').gp,0);
    expect(official.firstWhere((r)=>r.team=='C').pts,0);
    expect(live.firstWhere((r)=>r.team=='C').gp,1);
    expect(live.firstWhere((r)=>r.team=='C').pts,2);
    expect(live.firstWhere((r)=>r.team=='D').pts,0);
    expect(live.firstWhere((r)=>r.team=='C').gf,2);
  });

  test('tied live score awards clearly provisional points to both teams',(){
    final cup=CupTournament([
      Match('2026-11-08','A','B','1:1','Группа А-II','',status:'LIVE',gameId:3),
    ],teams:['A','B'],utcNow:now);
    final rows=cup.liveTable();
    expect(rows.every((r)=>r.pts==1&&r.gp==1&&r.provisionalTie),isTrue);
    expect(cup.table().every((r)=>r.gp==0),isTrue);
  });

  test('LIVE standings use head-to-head before overall goal difference',(){
    final cup=CupTournament([
      Match('2026-11-01','A','B','2:1','Группа А-II','',status:'FINAL',gameId:11),
      Match('2026-11-01','B','C','9:0','Группа А-II','',status:'FINAL',gameId:12),
      Match('2026-11-08','D','E','0:0','Группа А-II','',status:'LIVE',gameId:13),
    ],teams:['A','B','C','D','E'],utcNow:now);
    final rows=cup.liveTable();
    expect(rows.indexWhere((r)=>r.team=='A'),lessThan(rows.indexWhere((r)=>r.team=='B')));
  });

  test('LIVE standings use regulation wins when tied teams have not met',(){
    final cup=CupTournament([
      Match('2026-11-01','A','C','2:1','Группа А-II','',status:'FINAL',gameId:21),
      Match('2026-11-01','B','D','8:7','Группа Б-II','',status:'FINAL',scoreNote:'ОТ',gameId:22),
      Match('2026-11-08','E','F','0:0','Группа В-II','',status:'LIVE',gameId:23),
    ],teams:['A','B','C','D','E','F'],utcNow:now);
    final rows=cup.liveTable();
    expect(rows.indexWhere((r)=>r.team=='A'),lessThan(rows.indexWhere((r)=>r.team=='B')));
  });

  testWidgets('tournament table labels active fixtures and explains provisional rows', (tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:TournamentPage(
      matches:[
        Match('2026-11-08','A','B','2:1','Группа А-II','',status:'LIVE',gameId:10),
      ],teams:const ['A','B'],teamLogo:(_)=>null,onTeam:(_){},onMatch:(_){},
    ))));
    await tester.tap(find.text('ТАБЛИЦЫ'));
    await tester.pumpAndSettle();
    expect(find.text('ОБЩАЯ'),findsOneWidget);
    await tester.tap(find.text('ОБЩАЯ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('LIVE-таблица учитывает текущий счёт'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
