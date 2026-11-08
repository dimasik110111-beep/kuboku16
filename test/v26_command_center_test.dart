import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/command_engine.dart';
import 'package:junior_u16/follow_store.dart';

void main(){
  final now=DateTime.utc(2026,11,11);
  final teams=List.generate(20,(i)=>'Клуб ${i.toString().padLeft(2,'0')}');
  Match fixture(String home,String away,String score,String status,String date,{
    String stage='Группа А-II'
  })=>Match(date,home,away,score,stage,'',status:status);

  test('Race and time machine respect only confirmed historic FHR data',(){
    final races=RaceEngine([
      fixture(teams[0],teams[1],'2:1','FINAL','2026-11-07'),
      fixture(teams[1],teams[2],'3:1','FINAL','2026-11-08'),
      fixture(teams[3],teams[2],'9:0','LIVE','2026-11-09'),
    ],teams,utcNow:now);
    expect(races.historyDates,['2026-11-07','2026-11-08']);
    expect(races.standingsAt('2026-11-07')
      .firstWhere((r)=>r.team==teams[1]).pts,0);
    expect(races.standingsAt('2026-11-08')
      .firstWhere((r)=>r.team==teams[1]).pts,2);
    expect(races.standings.firstWhere((r)=>r.team==teams[3]).pts,0);
    expect(races.seedingAt('2026-11-07').expand((x)=>x).length,20);
  });
  test('Match Impact contrasts possible winners, never changes FHR result',(){
    final completed=fixture(teams[0],teams[1],'3:1','FINAL','2026-11-07');
    final future=fixture(teams[2],teams[3],'','SCHEDULED','2026-11-15');
    final engine=RaceEngine([completed,future],teams,utcNow:now);
    final original=engine.standings.firstWhere((r)=>r.team==teams[0]).pts;
    final home=engine.hypothetical(future,3,1);
    final away=engine.hypothetical(future,1,3);
    expect(home.firstWhere((r)=>r.team==teams[2]).pts,2);
    expect(away.firstWhere((r)=>r.team==teams[3]).pts,2);
    expect(engine.standings.firstWhere((r)=>r.team==teams[0]).pts,original);
    expect(engine.impact(completed).weight,0);
    expect(engine.impact(future).movedTeams,greaterThanOrEqualTo(0));
    expect(engine.mostImportant().first.match.key,future.key);
    expect(engine.helpfulOutcomes(teams[2]),isNotEmpty);
  });
  test('Monte Carlo outputs normalized frequencies and reproducible samples',(){
    final fixtures=[
      fixture(teams[0],teams[1],'2:1','FINAL','2026-11-06'),
      fixture(teams[2],teams[3],'','SCHEDULED','2026-11-14'),
      fixture(teams[0],teams[2],'','SCHEDULED','2026-11-15'),
    ];
    final input=SimulationInput(fixtures,teams,12,93,now);
    final first=simulateCup(input),second=simulateCup(input);
    expect(first.iterations,12);
    expect(first.fullCalendarPublished,false);
    expect(first.predictedPerRun,greaterThan(0));
    expect(first.topEight,second.topEight);
    expect(first.topEight.values.every((p)=>p>=0&&p<=1),true);
    expect(first.placeDistribution.values.every((places)=>
      places.values.fold<double>(0,(sum,p)=>sum+p)>0),true);
    expect(first.placeDistribution.values.every((places)=>
      places.values.fold<double>(0,(sum,p)=>sum+p)<=1.000001),true);
    expect(first.thirdGroups.values.every((groups)=>
      groups.values.every((p)=>p>=0&&p<=1)),true);
    expect(fixtures[0].score,'2:1');
  });
  test('Personal HQ follows persist on device, can be toggled',()async{
    SharedPreferences.setMockInitialValues({});
    expect(await FollowStore.teams(),isEmpty);
    expect(await FollowStore.players(),isEmpty);
    expect(await FollowStore.toggleTeam('Крылья Советов'),true);
    expect(await FollowStore.togglePlayer(271),true);
    expect(await FollowStore.teams(),contains('Крылья Советов'));
    expect(await FollowStore.players(),contains(271));
    expect(await FollowStore.togglePlayer(271),false);
    expect(await FollowStore.toggleTeam('Крылья Советов'),false);
    expect(await FollowStore.players(),isEmpty);
    expect(await FollowStore.teams(),isEmpty);
  });
}
