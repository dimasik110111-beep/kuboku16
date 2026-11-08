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
