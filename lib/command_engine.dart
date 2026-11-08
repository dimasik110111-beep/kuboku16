import 'dart:math';
import 'cup_data.dart';
import 'tournament.dart';
import 'scenario.dart';
import 'gold_odds.dart';

/// Confirmed FHR data is immutable: all what-ifs are isolated from the feed.
class RaceEngine {
  final List<Match> matches;
  final List<String> teams;
  final DateTime now;
  RaceEngine(this.matches,Iterable<String> participants,{DateTime? utcNow})
    :teams=participants.toSet().toList(),now=utcNow??DateTime.now().toUtc();

  late final CupTournament _cup=CupTournament(matches,teams:teams,utcNow:now);
  CupTournament get cup=>_cup;
  late final List<Rank> _standings=_cup.table();
  List<Rank> get standings=>_standings;
  final Map<String,List<Rank>> _whatIfCache={};
  final Map<String,List<Rank>> _historicCache={};
  final Map<String,List<List<String>>> _seedingHistoryCache={};
  final Map<String,List<ImpactScore>> _impactCache={};
  final Map<String,List<HelpfulOutcome>> _helpCache={};
  List<Match> get upcoming=>matches.where((m)=>
      m.isQualifier&&!m.isResultAt(now)&&!m.isLive).toList()
      ..sort((a,b)=>'${a.date} ${a.timeMsk}'.compareTo('${b.date} ${b.timeMsk}'));
  List<String> get historyDates=>matches.where((m)=>m.isQualifier&&
      m.isResultAt(now)&&m.matchDate!=null).map((m)=>m.date).toSet().toList()..sort();

  List<Rank> standingsAt(String date)=>_historicCache.putIfAbsent(date,()=>
    ranking(matches.where((m)=>m.isQualifier&&m.date.compareTo(date)<=0&&
      m.isResultAt(now)).toList(),utcNow:now,participants:teams));
  List<List<String>> seedingAt(String date)=>_seedingHistoryCache.putIfAbsent(date,()=>
    CupTournament(matches.where((m)=>m.isQualifier&&m.date.compareTo(date)<=0&&
      m.isResultAt(now)).toList(),teams:teams,utcNow:now).thirdTourProjection());

  late final Map<String,int> positionChanges=_calculatePositionChanges();
  Map<String,int> _calculatePositionChanges(){
    final dates=historyDates;
    final previous=dates.length<2?standings:standingsAt(dates[dates.length-2]);
    final prior={for(var i=0;i<previous.length;i++)previous[i].team:i+1};
    return {for(var i=0;i<standings.length;i++)
      standings[i].team:(prior[standings[i].team]??i+1)-(i+1)};
  }
  late final Map<String,String> projectedGroups=_calculateProjectedGroups();
  Map<String,String> _calculateProjectedGroups(){
    final data=cup.thirdTourProjection();
    const names=['А','Б','В','Г'];
    return {for(var i=0;i<data.length;i++)for(final name in data[i])name:names[i]};
  }
  List<Match> teamGames(String club,{bool completed=false})=>matches.where((m)=>
    m.isQualifier&&(m.home==club||m.away==club)&&
    (completed?m.isResultAt(now):!m.isResultAt(now)&&!m.isLive)).toList()
    ..sort((a,b)=>'${a.date} ${a.timeMsk}'.compareTo('${b.date} ${b.timeMsk}'));

  List<Rank> hypothetical(Match match,int home,int away,{bool overtime=false}){
    if(match.isResultAt(now)||match.isLive||!match.isQualifier)return standings;
    return _whatIfCache.putIfAbsent('${match.key}:$home:$away:$overtime',(){
      final changed=Match(match.date,match.home,match.away,'$home:$away',
        match.stage,match.arena,status:'FINAL',scoreNote:overtime?'ОТ':'',
        timeMsk:match.timeMsk,gameId:match.gameId,matchUrl:match.matchUrl);
      final rows=<Match>[
        for(final m in matches)if(m.key==match.key)changed else m,
      ];
      if(!matches.any((m)=>m.key==match.key))rows.add(changed);
      return CupTournament(rows,teams:teams,utcNow:now).table();
    });
  }
  ImpactScore impact(Match match,{String? focusedTeam}){
    if(match.isResultAt(now)||match.isLive||!match.isQualifier){
      return ImpactScore(match,0,0,0,0);
    }
    final original=standings;
    final a=hypothetical(match,3,1),b=hypothetical(match,1,3);
    final aPlaces={for(var i=0;i<a.length;i++)a[i].team:i+1};
    final bPlaces={for(var i=0;i<b.length;i++)b[i].team:i+1};
    var different=0,cutoff=0;
    for(final name in teams){
      final p=aPlaces[name],q=bPlaces[name];
      if(p==null||q==null)continue;
      if(p!=q)different++;
      if((p<=8)!=(q<=8))cutoff++;
    }
    final focus=focusedTeam==null?0:
      (bPlaces[focusedTeam]??0)-(aPlaces[focusedTeam]??0);
    final current={for(var i=0;i<original.length;i++)original[i].team:i+1};
    final changes=teams.where((t)=>aPlaces[t]!=current[t]||bPlaces[t]!=current[t]).length;
    return ImpactScore(match,different,cutoff,focus,changes);
  }
  List<ImpactScore> mostImportant({String? focus,int limit=12}){
    final ranked=_impactCache.putIfAbsent(focus??'@all',(){
      return [for(final match in upcoming)impact(match,focusedTeam:focus)]
        ..sort((a,b)=>b.weight.compareTo(a.weight));
    });
    return ranked.take(limit).toList();
  }
  List<HelpfulOutcome> helpfulOutcomes(String club,{int limit=8})=>
    _helpCache.putIfAbsent(club,()=>_calculateHelpful(club)).take(limit).toList();
  List<HelpfulOutcome> _calculateHelpful(String club){
    final current=standings;
    final previous={for(var i=0;i<current.length;i++)current[i].team:i+1};
    final list=<HelpfulOutcome>[];
    for(final m in upcoming){
      final variants=[
        hypothetical(m,3,1),hypothetical(m,1,3),
        hypothetical(m,3,2,overtime:true),
        hypothetical(m,2,3,overtime:true),
      ];
      final positions=[for(final rows in variants)rows.indexWhere((r)=>r.team==club)+1];
      if(positions.any((p)=>p<=0))continue;
      final best=positions.reduce(min),worst=positions.reduce(max);
      if(best==worst&&previous[club]==best)continue;
      final idx=positions.indexOf(best);
      list.add(HelpfulOutcome(m,
        ['Победа хозяев','Победа гостей','Победа хозяев в ОТ','Победа гостей в ОТ'][idx],
        best,worst,previous[club]??0));
    }
    list.sort((a,b){
      final d=b.swing.compareTo(a.swing);
      return d!=0?d:a.match.date.compareTo(b.match.date);
    });
    return list;
  }
  int get confirmed=>matches.where((m)=>m.isQualifier&&m.isResultAt(now)).length;
  int get published=>matches.where((m)=>m.isQualifier).length;
}
class ImpactScore {
  final Match match;
  final int movedTeams,cutoffSwitches,focusDelta,changedFromCurrent;
  const ImpactScore(this.match,this.movedTeams,this.cutoffSwitches,
    this.focusDelta,this.changedFromCurrent);
  int get weight=>cutoffSwitches*20+movedTeams*3+focusDelta.abs()*5;
}
class HelpfulOutcome {
  final Match match;
  final String usefulResult;
  final int bestPlace,worstPlace,currentPlace;
  const HelpfulOutcome(this.match,this.usefulResult,this.bestPlace,
    this.worstPlace,this.currentPlace);
  int get swing=>worstPlace-bestPlace;
}

class SimulationReport {
  final int iterations,publishedQualifiers,expectedQualifiers,predictedPerRun;
  final Map<String,double> topEight,averagePlace;
  final Map<String,Map<int,double>> placeDistribution;
  final Map<String,Map<String,double>> thirdGroups;
  const SimulationReport(this.iterations,this.publishedQualifiers,
    this.expectedQualifiers,this.predictedPerRun,this.topEight,
    this.averagePlace,this.placeDistribution,this.thirdGroups);
  bool get fullCalendarPublished=>publishedQualifiers>=expectedQualifiers;
  String get warning =>fullCalendarPublished
    ?'Модельные доли, не гарантия. Будущие результаты непредсказуемы.'
    :'Календарь неполный ($publishedQualifiers из $expectedQualifiers). '
      'Доли условны: не все будущие игры опубликованы. '
      'Расчётные пары III тура не являются официальным расписанием.';
}
class SimulationInput {
  final List<Match> matches;
  final List<String> teams;
  final int count,seed;
  final DateTime now;
  const SimulationInput(this.matches,this.teams,this.count,this.seed,this.now);
}

/// Deterministic Monte Carlo; run using Flutter compute() off the UI isolate.
/// Fixture scores are sampled from the same smoothed goal model as Gold Odds.
SimulationReport simulateCup(SimulationInput input){
  final random=Random(input.seed);
  final now=input.now;
  final clubs=input.teams.toSet().toList();
  final oddsCache=<String,GoldOdds>{};
  double poisson(double lambda){
    final limit=exp(-lambda);var product=1.0;var goals=0;
    do {goals++;product*=random.nextDouble();} while(product>limit&&goals<30);
    return (goals-1).toDouble();
  }
  ScenarioScore sample(Match m){
    final odds=oddsCache.putIfAbsent(m.key,()=>GoldOdds.forMatch(input.matches,m,utcNow:now));
    var home=poisson(odds.homeGoals).toInt();
    var away=poisson(odds.awayGoals).toInt();
    if(home==away){
      final homeWins=random.nextDouble()<odds.homeWin;
      if(homeWins)home++;else away++;
      return ScenarioScore(home,away,overtime:true);
    }
    return ScenarioScore(home,away);
  }
  final top8=<String,int>{for(final t in clubs)t:0};
  final positions=<String,int>{for(final t in clubs)t:0};
  final placeCounts=<String,Map<int,int>>{
    for(final t in clubs)t:{for(var place=1;place<=clubs.length;place++)place:0}};
  final groupCount=<String,Map<String,int>>{
    for(final t in clubs)t:{'А':0,'Б':0,'В':0,'Г':0}};
  var maxPredicted=0;
  for(var i=0;i<input.count;i++){
    final predictions=<String,ScenarioScore>{};
    for(final phase in [0,1,2,3,4]){
      final fixtures=scenarioFixtures(input.matches,scores:predictions,utcNow:now);
      for(final m in fixtures){
        if(predictions.containsKey(m.key)||m.isResultAt(now)||m.isLive)continue;
        final tour=tourOf(m.stage);
        final current=(tour==CupTour.first?0:
          tour==CupTour.second?(m.isCrossover?2:1):
          tour==CupTour.third?(m.isCrossover?4:3):5);
        if(current!=phase)continue;
        predictions[m.key]=sample(m);
      }
    }
    if(predictions.length>maxPredicted)maxPredicted=predictions.length;
    final result=applyScenario(input.matches,predictions,utcNow:now);
    final cup=CupTournament(result.matches,teams:clubs,utcNow:now);
    final table=cup.table();
    for(var rank=0;rank<table.length;rank++){
      final name=table[rank].team;
      if(!top8.containsKey(name))continue;
      if(rank<8)top8[name]=top8[name]!+1;
      positions[name]=positions[name]!+rank+1;
      placeCounts[name]![rank+1]=placeCounts[name]![rank+1]!+1;
    }
    final projected=cup.thirdTourProjection();
    for(var group=0;group<projected.length;group++){
      final letter=['А','Б','В','Г'][group];
      for(final name in projected[group]){
        if(!groupCount.containsKey(name))continue;
        groupCount[name]![letter]=groupCount[name]![letter]!+1;
      }
    }
  }
  final n=max(1,input.count);
  return SimulationReport(input.count,
    input.matches.where((m)=>m.isQualifier).length,
    expectedQualifyingGames,maxPredicted,
    {for(final name in clubs)name:(top8[name]??0)/n},
    {for(final name in clubs)name:(positions[name]??0)/n},
    {for(final name in clubs)name:{
      for(final place in placeCounts[name]!.keys)
        place:(placeCounts[name]![place]??0)/n,
    }},
    {for(final name in clubs)name:{
      for(final letter in ['А','Б','В','Г'])
        letter:(groupCount[name]?[letter]??0)/n,
    }});
}
