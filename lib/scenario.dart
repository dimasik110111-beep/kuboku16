import 'cup_data.dart';
import 'tournament.dart';

class ScenarioScore {
  final int home,away;final bool overtime;
  const ScenarioScore(this.home,this.away,{this.overtime=false});
  bool get valid=>home>=0&&away>=0&&home<=99&&away<=99&&home!=away&&(!overtime||(home-away).abs()==1);
  Map<String,dynamic> toJson()=>{'home':home,'away':away,'overtime':overtime};
  static ScenarioScore? parse(dynamic raw){
    if(raw is! Map||raw['home'] is! int||raw['away'] is! int)return null;
    final s=ScenarioScore(raw['home'],raw['away'],overtime:raw['overtime']==true);
    return s.valid?s:null;
  }
}
class ScenarioResult {
  final List<Match> matches;final int applied;
  const ScenarioResult(this.matches,this.applied);
}
ScenarioResult applyScenario(List<Match> source,Map<String,ScenarioScore> scores,{DateTime? utcNow}){
  final now=utcNow??DateTime.now().toUtc();
  final expanded=scenarioMatches(source,scores:scores,utcNow:now);
  final result=<String,Match>{};var applied=0;
  for(final m in expanded){
    if(result.containsKey(m.key))continue;
    final score=scores[m.key];
    if(score==null||!score.valid||!m.isQualifier||m.isResultAt(now)||m.isLive){result[m.key]=m;continue;}
    result[m.key]=Match(m.date,m.home,m.away,'${score.home}:${score.away}',m.stage,m.arena,
      timeMsk:m.timeMsk,status:'FINAL',scoreNote:score.overtime?'ОТ':'',gameId:m.gameId,matchUrl:m.matchUrl);
    applied++;
  }
  return ScenarioResult(result.values.toList(),applied);
}
List<Match> scenarioFixtures(List<Match> matches,{Map<String,ScenarioScore> scores=const {},DateTime? utcNow}){
  final now=utcNow??DateTime.now().toUtc();
  final originals={for(final m in matches)m.key:m};
  final rows={for(final m in scenarioMatches(matches,scores:scores,utcNow:now))m.key:m}.values
    .where((m){
      if(!m.isQualifier)return false;
      final original=originals[m.key];
      if(original!=null&&(original.isResultAt(now)||original.isLive))return false;
      return scores.containsKey(m.key)||(!m.isResultAt(now)&&!m.isLive);
    }).toList();
  rows.sort((a,b)=>'${a.date} ${a.timeMsk} ${a.key}'.compareTo('${b.date} ${b.timeMsk} ${b.key}'));
  return rows;
}


/// Adds unpublished fixtures to the prediction model. These rows are synthetic:
/// no dates or venues are invented, and official games always take precedence.
List<Match> scenarioMatches(List<Match> source,{Map<String,ScenarioScore> scores=const {},DateTime? utcNow}){
  final now=utcNow??DateTime.now().toUtc();
  final all=<String,Match>{for(final m in source)m.key:m};
  List<Match> withScores()=>[
    for(final m in all.values)
      if(scores[m.key]!=null&&scores[m.key]!.valid&&!m.isResultAt(now)&&!m.isLive)
        Match(m.date,m.home,m.away,'${scores[m.key]!.home}:${scores[m.key]!.away}',m.stage,m.arena,
          status:'FINAL',scoreNote:scores[m.key]!.overtime?'ОТ':'',gameId:m.gameId)
      else m,
  ];
  String? groupCode(String stage){
    final m=RegExp(r'ГРУППА\s+([^\s-]+)-II(?:\s|$)',caseSensitive:false).firstMatch(stage);
    return m?.group(1)?.toUpperCase().replaceAll('Ё','Е');
  }
  int groupOrder(String? code){
    switch(code){case 'А':case 'A':return 0;case 'Б':case 'B':return 1;case 'В':case 'V':return 2;case 'Г':case 'G':return 3;default:return 9;}
  }
  String letter(int index)=>const ['А','Б','В','Г'][index];
  bool containsPair(List<Match> rows,String stage,String home,String away)=>rows.any((m)=>m.stage==stage&&
    ((m.home==home&&m.away==away)||(m.home==away&&m.away==home)));
  // Round II crossovers: equal places between groups А/Б and В/Г.
  final secondGroups=<String,List<Match>>{};
  for(final m in all.values){final code=groupCode(m.stage);if(code!=null&&!m.isCrossover)secondGroups.putIfAbsent(code,()=>[]).add(m);}
  if(secondGroups.length>=4){
    final codes=secondGroups.keys.toList()..sort((a,b)=>groupOrder(a).compareTo(groupOrder(b)));
    final current=withScores();
    for(final offset in [0,2]){
      final left=codes[offset],right=codes[offset+1];
      final lhs=ranking(current.where((m)=>m.stage.startsWith('ГРУППА ')&&groupCode(m.stage)==left).toList(),utcNow:now);
      final rhs=ranking(current.where((m)=>m.stage.startsWith('ГРУППА ')&&groupCode(m.stage)==right).toList(),utcNow:now);
      if(lhs.length<5||rhs.length<5)continue;
      for(var pos=0;pos<5;pos++){
        final stage='Стыковые ${letter(groupOrder(left))} и ${letter(groupOrder(right))} - II';
        if(!containsPair(current,stage,lhs[pos].team,rhs[pos].team)){
          final id=-2000-offset*10-pos;
          all['$id']=Match('',lhs[pos].team,rhs[pos].team,'',stage,'',gameId:id);
        }
      }
    }
  }
  // Round III groups follow the regulation's 1,8,9,16,17 snake after tours I+II.
  final preceding=withScores().where((m)=>tourOf(m.stage)==CupTour.first||tourOf(m.stage)==CupTour.second).toList();
  final participants=<String>{...source.where((m)=>m.isQualifier).expand((m)=>[m.home,m.away])};
  final ranked=ranking(preceding,utcNow:now,participants:participants.toList());
  const snake=[[1,8,9,16,17],[2,7,10,15,18],[3,6,11,14,19],[4,5,12,13,20]];
  if(ranked.length>=20){
    final rosters=<List<String>>[for(final places in snake)[for(final place in places)ranked[place-1].team]];
    final current=withScores();
    for(var g=0;g<4;g++){
      final stage='ГРУППА ${letter(g)}-III';final roster=rosters[g];var slot=0;
      for(var i=0;i<roster.length;i++)for(var j=i+1;j<roster.length;j++,slot++){
        if(!containsPair(current,stage,roster[i],roster[j])){
          final id=-3000-g*10-slot;
          all['$id']=Match('',roster[i],roster[j],'',stage,'',gameId:id);
        }
      }
    }
    // Round III crossovers use equal places between the two group pairs.
    final rowsNow=withScores();
    for(final pair in [[0,1],[2,3]]){
      final a=pair[0],b=pair[1];
      final la=ranking(rowsNow.where((m)=>m.stage=='ГРУППА ${letter(a)}-III').toList(),utcNow:now);
      final lb=ranking(rowsNow.where((m)=>m.stage=='ГРУППА ${letter(b)}-III').toList(),utcNow:now);
      if(la.length<5||lb.length<5)continue;
      for(var pos=0;pos<5;pos++){
        final stage='Стыковые ${letter(a)} и ${letter(b)} - III';
        if(!containsPair(rowsNow,stage,la[pos].team,lb[pos].team)){
          final id=-4000-a*10-pos;
          all['$id']=Match('',la[pos].team,lb[pos].team,'',stage,'',gameId:id);
        }
      }
    }
  }
  return all.values.toList();
}
