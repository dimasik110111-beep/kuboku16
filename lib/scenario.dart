import 'cup_data.dart';

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
  final result=<String,Match>{};var applied=0;
  for(final m in source){
    if(result.containsKey(m.key))continue;
    final score=scores[m.key];
    if(score==null||!score.valid||!m.isQualifier||m.isResultAt(now)||m.isLive){result[m.key]=m;continue;}
    result[m.key]=Match(m.date,m.home,m.away,'${score.home}:${score.away}',m.stage,m.arena,
      timeMsk:m.timeMsk,status:'FINAL',scoreNote:score.overtime?'ОТ':'',gameId:m.gameId,matchUrl:m.matchUrl);
    applied++;
  }
  return ScenarioResult(result.values.toList(),applied);
}
List<Match> scenarioFixtures(List<Match> matches,{DateTime? utcNow}){
  final now=utcNow??DateTime.now().toUtc();
  final rows={for(final m in matches)m.key:m}.values
    .where((m)=>m.isQualifier&&!m.isResultAt(now)&&!m.isLive).toList();
  rows.sort((a,b)=>'${a.date} ${a.timeMsk} ${a.key}'.compareTo('${b.date} ${b.timeMsk} ${b.key}'));
  return rows;
}
