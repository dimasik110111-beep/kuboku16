import 'cup_data.dart';

String clubKey(String value)=>value.toLowerCase().replaceAll('ё','е').replaceAll(RegExp(r'[^а-яa-z0-9]'),'');
bool sameClub(String a,String b)=>clubKey(a)==clubKey(b);
List<Match> teamFixtures(List<Match> matches,String team)=>matches.where((m)=>sameClub(m.home,team)||sameClub(m.away,team)).toList()
  ..sort((a,b)=>'${b.date} ${b.timeMsk}'.compareTo('${a.date} ${a.timeMsk}'));
List<Match> meetings(List<Match> matches,String a,String b)=>teamFixtures(matches,a).where((m)=>sameClub(m.home,b)||sameClub(m.away,b)).toList();
class QualificationBounds {
  final int minPoints,maxPoints,bestBound,worstBound,remaining;
  const QualificationBounds(this.minPoints,this.maxPoints,this.bestBound,this.worstBound,this.remaining);
  // Each club plays 4+5+5 qualifiers. Bounds are deliberately conservative:
  // independent opponent maxima can overestimate how far a team can fall.
  factory QualificationBounds.forTeam(List<Rank> table,Rank team){
    final left=(14-team.gp).clamp(0,14);final max=team.pts+left*2;
    final above=table.where((r)=>r.team!=team.team&&r.pts>max).length;
    final possibleAbove=table.where((r)=>r.team!=team.team&&r.pts+2*(14-r.gp).clamp(0,14)>=team.pts).length;
    return QualificationBounds(team.pts,max,1+above,1+possibleAbove,left);
  }
}
