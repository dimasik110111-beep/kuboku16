import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:junior_u16/player_statistics.dart';
import 'package:junior_u16/player_statistics_page.dart';

Map<String,dynamic> skater(int id,String name,int goals,int assists,String team)=> {
  'id':id,'name':name,'number':'7','position':'Нападающий',
  'team':team,'city':'Москва','photo':'','teamLogo':'',
  'profile':'https://junior.fhr.ru/player/test-$id/',
  'gp':8,'goals':goals,'assists':assists,'points':goals+assists,
  'plusMinus':3,'pim':2,'pointsPerGame':(goals+assists)/8,
};
Map<String,dynamic> goalie(int id,String name,double ratio,double gaa)=> {
  'id':id,'name':name,'number':'30','position':'Вратарь',
  'team':'ДИНАМО','city':'Москва','photo':'','teamLogo':'',
  'profile':'https://junior.fhr.ru/player/test-$id/',
  'gp':8,'wins':4,'losses':2,'savePercentage':ratio,'gaa':gaa,
  'shotsAgainst':105,'saves':98,'goalsAgainst':7,'shutouts':1,
};
Map<String,dynamic> sampleStats() => {
  'ok':true,'complete':true,'group':'Общая статистика',
  'fetchedAt':'2026-11-07T00:00:00Z',
  'sourceUrl':'https://junior.fhr.ru/tournaments/kubokrossii-25008909/stats/',
  'availableGroups':['Общая статистика','Группа A-I'],
  'skaterCount':3,'goalieCount':2,
  'skaters':[skater(1,'Иван Первый',4,6,'ЦСКА'),
    skater(2,'Алексей Второй',9,0,'СПАРТАК'),
    skater(3,'Даниил Третий',2,1,'ЦСКА')],
  'goalies':[goalie(100,'Вратарь Один',.92,1.87),
    goalie(200,'Вратарь Два',.98,1.07)],
};
void main(){
  test('All official skater rows preserved, even different clubs for a transferred athlete',(){
    final raw=sampleStats();
    raw['skaters']=[...raw['skaters'] as List,skater(1,'Иван Первый',2,4,'СПАРТАК')];
    raw['skaterCount']=4;
    final stats=CupStatistics.fromApi(raw);
    expect(stats.skaters.length,4);
    expect(stats.playersCount,6);
    expect(stats.skaters.where((p)=>p.id==1).length,2);
  });
  test('Rankings order by official points, goals and assists',(){
    final stats=CupStatistics.fromApi(sampleStats());
    expect(sortCupPlayers(stats.skaters,PlayerStatSort.points).first.name,'Иван Первый');
    expect(sortCupPlayers(stats.skaters,PlayerStatSort.goals).first.name,'Алексей Второй');
    expect(sortCupPlayers(stats.skaters,PlayerStatSort.assists).first.name,'Иван Первый');
  });
  test('Goalie 0.98 fraction correctly displayed as 98.0 percent',(){
    final stats=CupStatistics.fromApi(sampleStats());
    final goalies=sortCupPlayers(stats.goalies,PlayerStatSort.savesPercentage);
    expect(goalies.first.name,'Вратарь Два');
    expect(goalies.first.savePercentText,'98.0%');
    expect(sortCupPlayers(stats.goalies,PlayerStatSort.gaa).first.gaaText,'1.07');
  });
  test('Absent or incomplete FHR player table is rejected, never invented',(){
    final incomplete=sampleStats();
    incomplete['skaterCount']=600;
    expect(()=>CupStatistics.fromApi(incomplete),throwsFormatException);
    incomplete['complete']=false;
    expect(()=>CupStatistics.fromApi(incomplete),throwsFormatException);
  });
  testWidgets('Dedicated Players screen renders skaters and switches to goalies',
      (tester)async{
    SharedPreferences.setMockInitialValues({});
    final client=MockClient((request)async{
      expect(request.url.path,'/api/v1/stats');
      return http.Response(jsonEncode(sampleStats()),200,
        headers:{'content-type':'application/json'});
    });
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:PlayerStatisticsPage(client:client))));
    await tester.pumpAndSettle();
    expect(find.text('СТАТИСТИКА ИГРОКОВ'),findsOneWidget);
    expect(find.textContaining('3 полевых'),findsOneWidget);
    await tester.drag(find.byType(CustomScrollView),const Offset(0,-400));
    await tester.pumpAndSettle();
    expect(find.text('Иван Первый'),findsWidgets);
    await tester.drag(find.byType(CustomScrollView),const Offset(0,600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ВРАТАРИ'));
    await tester.pumpAndSettle();
    // The ranking rows are below the scroll viewport in the compact test window.
    expect(find.text('СЕЙВЫ'),findsWidgets);
    expect(find.text('КН'),findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });
}

