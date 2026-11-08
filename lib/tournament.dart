import 'cup_data.dart';

enum CupTour { first, second, third, silver, gold, other }

const int firstTourGames=40;
const int secondTourGames=50;
const int thirdTourGames=50;
const int expectedQualifyingGames=140;
const int expectedParticipants=20;

/// The 2026/27 FHR regulation sets out three qualification rounds and
/// two separately named finals. Only FHR-published fixtures are displayed.
CupTour tourOf(String stage) {
  final s=stage.toUpperCase().replaceAll('Ё','Е').trim();
  if(s.contains('ЗОЛОТОЙ ФИНАЛ'))return CupTour.gold;
  if(s.contains('СЕРЕБРЯНЫЙ ФИНАЛ'))return CupTour.silver;
  // For stages whose title contains a Roman round suffix (including crossovers).
  if(RegExp(r'-\s*III(?:\s|$)').hasMatch(s))return CupTour.third;
  if(RegExp(r'-\s*II(?:\s|$)').hasMatch(s))return CupTour.second;
  if(RegExp(r'-\s*I(?:\s|$)').hasMatch(s))return CupTour.first;
  return CupTour.other;
}

bool isCrossoverStage(String stage) {
  final s=stage.toUpperCase().replaceAll('Ё','Е');
  return s.contains('СТЫКОВ')||s.contains('ПЛЕЙ-ОФФ');
}

bool isQualifyingGroup(String stage) {
  if(isCrossoverStage(stage))return false;
  final s=stage.toUpperCase().replaceAll('Ё','Е');
  return s.startsWith('ГРУППА ') &&
    (tourOf(stage)==CupTour.first||tourOf(stage)==CupTour.second||
     tourOf(stage)==CupTour.third);
}

class CupTourOverview {
  final CupTour tour;
  final String title,dates;
  final int expectedGames;
  final List<Match> matches;
  CupTourOverview(this.tour,this.title,this.dates,this.expectedGames,this.matches);
  int get published=>matches.length;
  int playedAt(DateTime when)=>matches.where((m)=>m.isResultAt(when)).length;
  int get played=>playedAt(DateTime.now().toUtc());
  bool get fullyPlayed=>expectedGames>0&&published>=expectedGames&&played>=expectedGames;
  int get groupCount=>matches.where((m)=>isQualifyingGroup(m.stage)).map((m)=>m.stage).toSet().length;
  int get crossoverCount=>matches.where((m)=>isCrossoverStage(m.stage)).length;
  int get remaining=>published-played;
  bool get hasPublishedMatches=>matches.isNotEmpty;
}

class CupTournament {
  final List<Match> matches;
  final List<String> participants;
  final DateTime now;
  CupTournament(
    List<Match> all,{
    Iterable<String> teams=const <String>[],
    DateTime? utcNow,
  }):matches=List.unmodifiable(all),
     participants=List.unmodifiable({
       ...teams.where((name)=>name.trim().isNotEmpty),
       ...all.where((m)=>m.isQualifier).expand((m)=>[m.home,m.away])
         .where((name)=>name.trim().isNotEmpty)
     }),
     now=utcNow??DateTime.now().toUtc();

  List<Match> tourMatches(CupTour round)=>matches.where((m)=>tourOf(m.stage)==round).toList();

  CupTourOverview overview(CupTour round){
    switch(round) {
      case CupTour.first:return CupTourOverview(round,'ПЕРВЫЙ ТУР','СЕНТЯБРЬ 2026',firstTourGames,tourMatches(round));
      case CupTour.second:return CupTourOverview(round,'ВТОРОЙ ТУР','НОЯБРЬ 2026',secondTourGames,tourMatches(round));
      case CupTour.third:return CupTourOverview(round,'ТРЕТИЙ ТУР','ЯНВАРЬ 2027',thirdTourGames,tourMatches(round));
      case CupTour.silver:return CupTourOverview(round,'СЕРЕБРЯНЫЙ ФИНАЛ','АПРЕЛЬ 2027',0,tourMatches(round));
      case CupTour.gold:return CupTourOverview(round,'ЗОЛОТОЙ ФИНАЛ','АПРЕЛЬ 2027',0,tourMatches(round));
      case CupTour.other:return CupTourOverview(round,'ПРОЧИЕ МАТЧИ','ДАННЫЕ ФХР',0,tourMatches(round));
    }
  }

  List<String> groupNames({CupTour? round}){
    final stages=matches.map((m)=>m.stage)
      .where((s)=>isQualifyingGroup(s)&& (round==null||tourOf(s)==round))
      .toSet().toList();
    stages.sort((a,b){
      const order=[CupTour.first,CupTour.second,CupTour.third];
      final diff=order.indexOf(tourOf(a)).compareTo(order.indexOf(tourOf(b)));
      return diff!=0?diff:a.compareTo(b);
    });
    return stages;
  }
  List<Match> groupMatches(String group)=>matches.where((m)=>m.stage==group&&!m.isCrossover).toList();
  List<Match> crossoverMatches({CupTour? round})=>matches.where((m)=>
    isCrossoverStage(m.stage)&&(round==null||tourOf(m.stage)==round)).toList();

  List<Rank> table({String? group}) {
    final list=group==null?matches.where((m)=>m.isQualifier).toList():groupMatches(group);
    // Do not seed all 20 clubs inside an individual group table.
    return ranking(list,utcNow:now,participants:group==null?participants:const []);
  }

  /// A live-only projection of the qualification table. Confirmed results keep
  /// the official FHR tie-break order; active scorelines add provisional goals,
  /// games and points without changing the official table.
  List<Rank> liveTable({String? group}) {
    final official=table(group:group);
    final liveMatches=matches.where((m)=>m.isQualifier&&m.isLive&&m.goals!=null&&
      (group==null||m.stage==group&&!m.isCrossover)).toList();
    if(liveMatches.isEmpty)return official;
    final rows=<String,Rank>{for(final row in official)
      row.team:Rank(row.team)
        ..gp=row.gp..pts=row.pts..w=row.w..rw=row.rw
        ..gf=row.gf..ga=row.ga..otLosses=row.otLosses};
    final confirmed=matches.where((m)=>m.isResultAt(now)&&
      (group==null?m.isQualifier:m.stage==group&&!m.isCrossover)).toList();
    final provisionalWins=<Match>[];
    for(final match in liveMatches) {
      final g=match.goals!;
      final home=rows.putIfAbsent(match.home,()=>Rank(match.home));
      final away=rows.putIfAbsent(match.away,()=>Rank(match.away));
      home.gp++;away.gp++;
      home.gf+=g[0];home.ga+=g[1];away.gf+=g[1];away.ga+=g[0];
      if(g[0]!=g[1]){
        final winner=g[0]>g[1]?home:away;
        final loser=g[0]>g[1]?away:home;
        winner.pts+=2;winner.w++;
        if(match.overtime){loser.pts++;loser.otLosses++;}else{winner.rw++;}
        provisionalWins.add(Match(match.date,match.home,match.away,match.score,
          match.stage,match.arena,status:'FINAL',scoreNote:match.scoreNote,
          gameId:match.gameId));
      }
      else {home.pts++;away.pts++;home.provisionalTie=true;away.provisionalTie=true;}
    }
    return regulationOrder(rows.values,[...confirmed,...provisionalWins]);
  }
  List<Rank> finalTable(CupTour finalRound){
    if(finalRound!=CupTour.gold&&finalRound!=CupTour.silver)return [];
    return ranking(tourMatches(finalRound),utcNow:now,includeFinals:true);
  }

  int get completedQualifyingGames=>matches.where((m)=>m.isQualifier&&m.isResultAt(now)).length;
  int get qualifyingFixtureCount=>matches.where((m)=>m.isQualifier).length;
  int get totalFixturesPublished=>matches.length;

  bool get firstComplete=>overview(CupTour.first).playedAt(now)>=firstTourGames;
  bool get firstTwoComplete=>firstComplete && overview(CupTour.second).playedAt(now)>=secondTourGames;
  bool get qualificationComplete=>firstTwoComplete&&overview(CupTour.third).playedAt(now)>=thirdTourGames&&
    completedQualifyingGames>=expectedQualifyingGames&&participants.length==expectedParticipants;

  List<Rank> get qualificationRanking=>table();

  /// Second-round groups from Article 4:
  /// Group 1 = all first places plus last place of initial group 4;
  /// Group 2 = all second places plus last place of initial group 3;
  /// Group 3 = all third places plus last place of initial group 2;
  /// Group 4 = all fourth places plus last place of initial group 1.
  List<List<String>> secondTourPreview(){
    final groups=groupNames(round:CupTour.first);
    final positions=[
      [1,1,1,1,5],
      [2,2,2,2,5],
      [3,3,3,3,5],
      [4,4,4,4,5],
    ];
    final lastGroups=[3,2,1,0];
    return [
      for(var i=0;i<4;i++)[
        for(var g=0;g<4;g++)
          _firstTourSeed(groups,g,positions[i][g]),
        _firstTourSeed(groups,lastGroups[i],5),
      ],
    ];
  }

  String _firstTourSeed(List<String> groups,int groupIndex,int position){
    if(!firstComplete||groups.length!=4){
      return '$position-е место группы ${groupIndex+1} I тура';
    }
    final ranks=table(group:groups[groupIndex]);
    if(ranks.length<position)return '$position-е место группы ${groupIndex+1} I тура';
    return ranks[position-1].team;
  }

  /// The third tour is seeded by a snake distribution over the combined
  /// standings after rounds one and two (Article 4).
  static const List<List<int>> thirdTourSnake=[
    [1,8,9,16,17],
    [2,7,10,15,18],
    [3,6,11,14,19],
    [4,5,12,13,20],
  ];
  List<List<String>> thirdTourPreview(){
    final ranked=ranking(matches.where((m)=>
      tourOf(m.stage)==CupTour.first||tourOf(m.stage)==CupTour.second).toList(),
      utcNow:now,participants:participants);
    return [
      for(final indexes in thirdTourSnake)
        [for(final pos in indexes)
          firstTwoComplete&&ranked.length>=pos?ranked[pos-1].team:'Место $pos']
    ];
  }

  /// Live third-tour forecast, even while rounds I or II are still underway.
  /// Uses the current combined standings and the regulation snake, rather than
  /// waiting for every game to be final.
  List<List<String>> thirdTourProjection(){
    final ranked=ranking(matches.where((m)=>
      tourOf(m.stage)==CupTour.first||tourOf(m.stage)==CupTour.second).toList(),
      utcNow:now,participants:participants);
    return [
      for(final indexes in thirdTourSnake)
        [for(final pos in indexes)
          ranked.length>=pos?ranked[pos-1].team:'Место $pos']
    ];
  }

  List<Rank> get goldQualifiers=>
    qualificationComplete?qualificationRanking.take(8).toList():[];
  List<Rank> get silverQualifiers=>
    qualificationComplete?qualificationRanking.skip(8).take(12).toList():[];

  /// FHR Article 4 does not prescribe invented knockout pairings; display
  /// only fixtures provided by the published gold/silver final calendars.
  bool get goldFixturesPublished=>tourMatches(CupTour.gold).isNotEmpty;
  bool get silverFixturesPublished=>tourMatches(CupTour.silver).isNotEmpty;
}
