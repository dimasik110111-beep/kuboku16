import 'package:flutter_test/flutter_test.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/command_engine.dart';
import 'package:junior_u16/scenario.dart';

void main(){
  final now=DateTime.utc(2026,11,12);
  final teams=List.generate(20,(i)=>'Team $i');

  test('Synthetic slots never carry a forecast into a new matchup',(){
    final oldPair=Match('',teams[0],teams[1],'','Стыковые А и Б - II','',
      gameId:-2000);
    final newPair=Match('',teams[0],teams[2],'','Стыковые А и Б - II','',
      gameId:-2000);
    expect(oldPair.key,isNot(newPair.key));
    final saved={oldPair.key:const ScenarioScore(4,1)};
    expect(saved[newPair.key],isNull);
    // Real game identifiers must stay stable during status updates.
    final real=Match('2026-11-05',teams[0],teams[1],'','Группа А-II','',
      gameId:7345,status:'SCHEDULED');
    final finished=Match('2026-11-05',teams[0],teams[1],'3:1','Группа А-II','',
      gameId:7345,status:'FINAL');
    expect(real.key,finished.key);
  });
  test('Partial FHR feed preserves old games but updates newly published scores',(){
    final first=Match('2026-10-10',teams[0],teams[1],'3:1',
      'Группа А-I','',status:'FINAL',gameId:1201);
    final second=Match('2026-11-01',teams[2],teams[3],'',
      'Группа Б-II','',status:'SCHEDULED',gameId:1202);
    final updated=Match('2026-11-01',teams[2],teams[3],'2:1',
      'Группа Б-II','',status:'FINAL',gameId:1202);
    final partial=reconcileCalendar([first,second],[updated],partial:true);
    expect(partial.length,2);
    expect(partial.singleWhere((m)=>m.gameId==1202).score,'2:1');
    expect(partial.singleWhere((m)=>m.gameId==1201).score,'3:1');
    final complete=reconcileCalendar([first,second],[updated],partial:false);
    expect(complete.length,1);
    expect(complete.single.gameId,1202);
  });
  test('Race engine caches immutable snapshots between redraws',(){
    final played=Match('2026-11-05',teams[0],teams[1],'3:1',
      'Группа А-II','',status:'FINAL',gameId:41);
    final future=Match('2026-11-15',teams[0],teams[2],'',
      'Группа А-II','',status:'SCHEDULED',gameId:42);
    final engine=RaceEngine([played,future],teams,utcNow:now);
    expect(identical(engine.standings,engine.standings),isTrue);
    expect(identical(engine.positionChanges,engine.positionChanges),isTrue);
    expect(identical(engine.standingsAt('2026-11-05'),
      engine.standingsAt('2026-11-05')),isTrue);
    expect(identical(engine.hypothetical(future,3,1),
      engine.hypothetical(future,3,1)),isTrue);
    expect(engine.hypothetical(future,3,1)
      .firstWhere((row)=>row.team==teams[0]).pts,4);
    expect(engine.standings.firstWhere((row)=>row.team==teams[0]).pts,2);
  });
  test('What-if cache never changes confirmed LIVE or finished scores',(){
    final live=Match('2026-11-11',teams[0],teams[1],'2:1',
      'Группа А-II','',status:'LIVE',gameId:43);
    final completed=Match('2026-11-10',teams[0],teams[2],'3:1',
      'Группа А-II','',status:'FINAL',gameId:44);
    final engine=RaceEngine([live,completed],teams,utcNow:now);
    expect(identical(engine.hypothetical(live,0,9),engine.standings),isTrue);
    expect(identical(engine.hypothetical(completed,1,9),engine.standings),isTrue);
    expect(engine.upcoming,isEmpty);
  });
}
