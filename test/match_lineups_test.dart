import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junior_u16/match_lineups.dart';

Map<String,dynamic> validData()=>{
  'matchLineups':{
    'available':true,
    'source':'FHR_MATCH',
    'teams':[
      {
        'side':'home','verified':true,
        'players':[
          {
            'name':'Иван Петров','number':'7','position':'FORWARD',
            'captainRole':'C','stats':{'goals':1,'assists':2,'points':3,'penaltyMinutes':0}
          },
          {
            'name':'Александр Иванов','number':'33','position':'GOALIE',
            'assignment':'ОВ'
          }
        ],
        'staff':[{'name':'Сергей Васильев','position':'Главный тренер'}]
      },
      {
        'side':'away','verified':true,
        'players':[{
          'name':'Павел Сидоров','number':'18','position':'DEFENDER',
          'captainRole':'A','stats':{'goals':0,'assists':1,'points':1,'penaltyMinutes':2}
        },{
          'name':'Денис Орлов','number':'31','position':'Вратарь',
        }],
        'staff':[]
      }
    ]
  }
};

void main(){
  test('v12 uses FHR match-specific roster not tournament rosters',(){
    final data=GameLineups.fromDetail(validData());
    expect(data.available,isTrue);
    expect(data.teams.length,2);
    expect(data.side('home')!.players.length,2);
    expect(data.side('away')!.players.length,2);
    expect(data.side('home')!.goalies,1);
    expect(data.side('away')!.goalies,1);
    expect(data.side('home')!.players.first.captainRole,'C');
    expect(data.side('home')!.players.first.stats!.points,3);
    expect(data.side('away')!.players.first.stats!.penaltyMinutes,2);
    expect(data.side('home')!.staff.first.position,'Главный тренер');
  });
  test('v12 never substitutes club roster for missing game lineup',(){
    final data=GameLineups.fromDetail({'ok':true,'matchLineups':{'available':false,'teams':[]}});
    expect(data.available,isFalse);
    expect(data.teams,isEmpty);
    expect(GameLineups.fromDetail({'ok':true}).available,isFalse);
  });
  test('both goalkeeper sides survive missing side labels and Russian positions',(){
    final data=GameLineups.fromDetail({'matchLineups':{'available':true,'teams':[
      {'players':[{'name':'Первый','position':'GOALTENDER','number':'1'}]},
      {'players':[{'name':'Второй','position':'Вратарь','number':'30'}]},
    ]}});
    expect(data.side('home')!.goalies,1);
    expect(data.side('away')!.goalies,1);
    expect(data.side('away')!.players.first.name,'Второй');
  });
  testWidgets('v12 has native match lineup controls and player box score',(tester)async{
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:MatchLineupPanel(
        lineups:GameLineups.fromDetail(validData()),
        home:'ЦСКА Москва',away:'Локомотив Ярославль',
      )),
    )));
    expect(find.text('ЗАЯВКА НА МАТЧ'),findsOneWidget);
    expect(find.text('ПОДТВЕРЖДЕНО ФХР'),findsOneWidget);
    expect(find.text('Иван Петров'),findsOneWidget);
    expect(find.text('Г 1   П 2   О 3   Штр 0'),findsOneWidget);
    expect(find.text('Сергей Васильев'),findsOneWidget);
    await tester.tap(find.text('Локомотив Ярославль'));
    await tester.pumpAndSettle();
    expect(find.text('Павел Сидоров'),findsOneWidget);
    expect(find.text('Денис Орлов'),findsOneWidget);
    expect(find.text('ВРАТАРИ'),findsOneWidget);
    expect(find.text('Иван Петров'),findsNothing);
  });
  testWidgets('v12 explicitly shows unavailable game-specific roster',(tester)async{
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:MatchLineupPanel(lineups:GameLineups.fromDetail(null),
        home:'А',away:'Б'))));
    expect(find.text('Заявка ещё не опубликована'),findsOneWidget);
  });
}
