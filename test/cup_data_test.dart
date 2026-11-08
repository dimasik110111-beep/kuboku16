import 'package:flutter_test/flutter_test.dart';
import 'package:junior_u16/cup_data.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 18);
  Match game(String home,String away,String score,String stage,
      {String date='2026-09-10',String status='SCORE_AVAILABLE',String note=''}) {
    return Match(date,home,away,score,stage,'',status:status,scoreNote:note);
  }

  test('FHR group stages and crossover games count as qualifiers',() {
    expect(game('A','B','3:2','Группа A-I').isQualifier,isTrue);
    expect(game('A','B','3:2','Группа Б-II').isQualifier,isTrue);
    expect(game('A','B','3:2','Плей-офф А и Б - II').isQualifier,isTrue);
    expect(game('A','B','3:2','Золотой финал').isQualifier,isFalse);
    expect(game('A','B','3:2','Этап не определён').isQualifier,isFalse);
  });

  test('two points for any win and one point for overtime loss',() {
    final games=[
      game('A','B','3:2','Группа A-I',note:'ОТ'),
      game('B','C','4:1','Группа A-I'),
    ];
    final ranks=ranking(games,utcNow:now);
    final a=ranks.firstWhere((r)=>r.team=='A');
    final b=ranks.firstWhere((r)=>r.team=='B');
    final c=ranks.firstWhere((r)=>r.team=='C');
    expect(a.pts,2);
    expect(b.pts,3);
    expect(c.pts,0);
    expect(a.rw,0);
    expect(b.rw,1);
    expect(b.gp,2);
  });

  test('LIVE score and same-day calendar scores are not assumed final',() {
    final today=game('A','B','4:1','Группа A-I',date:'2026-11-06');
    final live=game('A','B','4:1','Группа A-I',date:'2026-09-10',status:'LIVE');
    expect(today.isResultAt(now),isFalse);
    expect(live.isResultAt(now),isFalse);
    expect(game('A','B','4:1','Группа A-I').isResultAt(now),isTrue);
  });

  test('head-to-head result breaks equal points when the teams played',() {
    final games=[
      game('A','B','3:1','Группа A-I'),
      game('B','C','2:0','Группа A-I'),
      game('C','A','3:1','Группа A-I'),
    ];
    final ranks=ranking(games,utcNow:now);
    expect(ranks.length,3);
    expect(ranks.every((r)=>r.pts==2),isTrue);
  });

  test('API mapping respects match ID, score and stage',() {
    final m=Match.fromApi({
      'gameId':25170469,'date':'2026-09-10','timeMsk':'13:15',
      'home':'КРАСНАЯ МАШИНА ЮНИОР Красногорск','away':'СЕВЕРСТАЛЬ Череповец',
      'homeScore':3,'awayScore':0,'group':'Группа Г-I',
      'status':'SCORE_AVAILABLE','arena':'МАУ ЛК Владимир'});
    expect(m.gameId,25170469);
    expect(m.score,'3:0');
    expect(m.isQualifier,isTrue);
    expect(m.dayLabel,'10.09');
    expect(m.finished,isTrue);
  });

  test('detail accepts numeric or string game IDs returned by the LIVE worker',() {
    const scheduled=Match('2026-11-06','A','B','','Группа А-II','',
      status:'SCHEDULED',gameId:25170469);
    final updated=scheduled.withDetail({'ok':true,'gameId':'25170469',
      'homeScore':2,'awayScore':1,'status':'LIVE'});
    expect(updated.status,'LIVE');
    expect(updated.score,'2:1');
    expect(scheduled.withDetail({'ok':true,'gameId':'999',
      'homeScore':8,'awayScore':0,'status':'LIVE'}).score,'');
  });

  test('partial source marks completeness as unverified',() {
    final feed=FhrFeed.fromApi({
      'ok':true,'groupsFetched':1,
      'groups':[{'name':'Группа A-I','matchesCount':1,'error':null}],
      'matches':[{'gameId':1,'date':'2026-09-10','home':'A','away':'B',
        'group':'Группа A-I','homeScore':1,'awayScore':0,'status':'SCORE_AVAILABLE'}],
    });
    expect(feed.allStagesComplete,isFalse);
    expect(feed.issues,isNotEmpty);
    expect(feed.matches.length,1);
  });
}
