import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_services.dart';

const fhrApiBase = 'https://kubok-u16-live.dimasik110111.workers.dev';
const fhrCalendarUrl = 'https://junior.fhr.ru/tournaments/kubokrossii-25008909/calendar/';

class Match {
  final String date, home, away, score, stage, arena, timeMsk, status, scoreNote;
  final int? gameId;
  final String? matchUrl;
  const Match(this.date, this.home, this.away, this.score, this.stage, this.arena,
      {this.timeMsk = '', this.status = 'UNKNOWN', this.scoreNote = '', this.gameId, this.matchUrl});

  factory Match.fromApi(Map<String, dynamic> item) {
    final hs = item['homeScore'];
    final as = item['awayScore'];
    final score = hs is num && as is num ? '${hs.toInt()}:${as.toInt()}' : '';
    final id = item['gameId'];
    return Match(
      item['date']?.toString() ?? '',
      item['home']?.toString().trim() ?? '',
      item['away']?.toString().trim() ?? '',
      score,
      (item['group']??item['stage'])?.toString().trim() ?? 'Этап не определён',
      item['arena']?.toString().trim() ?? '',
      timeMsk: item['timeMsk']?.toString() ?? '',
      scoreNote: item['scoreNote']?.toString() ?? '',
      status: item['status']?.toString() ?? 'UNKNOWN',
      gameId: id is num ? id.toInt() : int.tryParse(id?.toString() ?? ''),
      matchUrl: item['matchUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date, 'home': home, 'away': away, 'group': stage, 'arena': arena,
    'timeMsk': timeMsk, 'status': status, 'scoreNote': scoreNote,
    'gameId': gameId, 'matchUrl': matchUrl,
    'homeScore': goals?[0], 'awayScore': goals?[1],
  };

  bool get hasScore => RegExp(r'^\d+:\d+$').hasMatch(score);
  List<int>? get goals {
    if (!hasScore) return null;
    final p = score.split(':');
    return [int.parse(p[0]), int.parse(p[1])];
  }
  bool get isLive => status == 'LIVE' || status == 'LIVE_PAUSED';
  bool get isFinalConfirmed => status == 'FINAL';
  // Calendar SCORE_AVAILABLE alone is not proof of a finished game:
  // for ranking, wait until the next calendar day (Moscow time).
  bool isResultAt(DateTime utcNow) {
    if (!hasScore || isLive) return false;
    if (isFinalConfirmed) return true;
    if (status != 'SCORE_AVAILABLE') return false;
    final day = DateTime.tryParse(date);
    if (day == null) return false;
    final mskToday = utcNow.toUtc().add(const Duration(hours: 3));
    final mskDay = DateTime.utc(mskToday.year, mskToday.month, mskToday.day);
    return date.compareTo('${mskDay.year.toString().padLeft(4, '0')}-${mskDay.month.toString().padLeft(2, '0')}-${mskDay.day.toString().padLeft(2, '0')}') < 0;
  }
  bool get finished => isResultAt(DateTime.now().toUtc());
  bool get overtime {
    final note = scoreNote.toUpperCase().replaceAll('Ё', 'Е').trim();
    return note == 'ОТ' || note == 'ПБ' || note == 'ПП' ||
        note.contains('БУЛ') || note.contains('ОВЕР');
  }
  bool get isQualifier {
    final s = stage.toUpperCase().replaceAll('Ё','Е');
    if (s.contains('ЗОЛОТОЙ ФИНАЛ') || s.contains('СЕРЕБРЯНЫЙ ФИНАЛ')) return false;
    return RegExp(r'ГРУППА\s+[^ ]+-(I|II|III)(\s|$)').hasMatch(s) ||
      s.contains('СТЫКОВ') || s.contains('ПЛЕЙ-ОФФ');
  }
  bool get isCrossover {
    final s=stage.toUpperCase().replaceAll('Ё','Е');
    return (s.contains('СТЫКОВ') || s.contains('ПЛЕЙ-ОФФ')) &&
      !s.contains('ЗОЛОТОЙ ФИНАЛ') && !s.contains('СЕРЕБРЯНЫЙ ФИНАЛ');
  }
  bool get isFinalStage {
    final s=stage.toUpperCase().replaceAll('Ё','Е');
    return s.contains('ЗОЛОТОЙ ФИНАЛ') || s.contains('СЕРЕБРЯНЫЙ ФИНАЛ');
  }
  // Synthetic match IDs are only positional slots in a projected bracket.
  // Include both clubs in the key: a re-seeded pairing must NEVER inherit a
  // user's forecast intended for two different teams.
  String get key => gameId!=null&&gameId!<0
    ? '${gameId!}|$stage|$home|$away'
    : (gameId?.toString() ?? '$stage|$date|$home|$away');
  DateTime? get matchDate => DateTime.tryParse(date);
  String get dayLabel {
    final dt = matchDate;
    if (dt == null) return date;
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
  }
  Match withDetail(Map<String, dynamic> detail) {
    if (detail['ok'] != true || gameId == null || detail['gameId'] != gameId) return this;
    final hs = detail['homeScore'];
    final as = detail['awayScore'];
    return Match(date, home, away,
      hs is num && as is num ? '${hs.toInt()}:${as.toInt()}' : score,
      stage, arena,
      timeMsk: timeMsk, gameId: gameId, matchUrl: matchUrl,
      status: detail['status']?.toString() ?? status,
      scoreNote: scoreNote);
  }
}

class FhrFeed {
  final List<Match> matches;
  final DateTime? updatedAt;
  final List<String> issues;
  final int groupsFetched;
  final bool allStagesComplete;
  final int expectedMatchCount;
  const FhrFeed(this.matches, this.updatedAt, this.issues,
      this.groupsFetched, this.allStagesComplete, this.expectedMatchCount);

  factory FhrFeed.fromApi(Map<String, dynamic> json) {
    if (json['ok'] != true || json['matches'] is! List) {
      throw FormatException('ФХР: неверный ответ LIVE-сервера: ${json['error'] ?? 'без списка матчей'}');
    }
    final records = <String, Match>{};
    for (final e in json['matches'] as List) {
      if (e is! Map) continue;
      final m = Match.fromApi(Map<String, dynamic>.from(e));
      if (m.home.isEmpty || m.away.isEmpty || m.date.isEmpty || m.home == m.away) continue;
      records[m.key] = m;
    }
    final stages = json['groups'] is List ? json['groups'] as List : [];
    final issues = <String>[];
    for (final group in stages) {
      if (group is! Map) continue;
      final name = group['name']?.toString() ?? '';
      final count = group['matchesCount'];
      final error = group['error'];
      if (error != null) issues.add('$name: $error');
      final upper=name.toUpperCase().replaceAll('Ё','Е');
      final expected = upper.startsWith('ГРУППА ') && RegExp(r'-(I|II|III)$').hasMatch(upper) ? 10 :
        (upper.contains('СТЫКОВ') || upper.startsWith('ПЛЕЙ-ОФФ')) ? 5 : 0;
      if (expected > 0 && count is num && count.toInt()!=expected) {
        issues.add('$name: опубликовано $count из $expected ожидаемых матчей');
      }
    }
    final fetched = (json['groupsFetched'] as num?)?.toInt() ?? 0;
    // First two qualification tours contain eight 5-team groups and two
    // five-game crossover sections. Later sections appear only when FHR publishes them.
    if (stages.isNotEmpty && fetched < stages.length) {
      issues.add('Не загружены некоторые опубликованные разделы ФХР');
    }
    if (stages.length >= 10 && records.length < 90) {
      issues.add('Получено ${records.length} из ожидаемых 90 матчей двух первых туров');
    }
    final byDate = records.values.toList()
      ..sort((a,b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.timeMsk.compareTo(a.timeMsk);
      });
    return FhrFeed(byDate, DateTime.tryParse(json['fetchedAt']?.toString() ?? ''),
        issues, fetched, issues.isEmpty && stages.length >= 10, 90);
  }
  Map<String, dynamic> toCache() => {
    'ok': true,
    'matches': matches.map((m)=>m.toJson()).toList(),
    'groupsFetched': groupsFetched,
    'fetchedAt': updatedAt?.toIso8601String(),
    'groups': [],
  };
}

/// Retain published fixtures when the provider reports an incomplete response.
/// Incoming matches always win; the old snapshot is only a fallback for gaps.
/// On a complete response the feed is authoritative, including removals.
List<Match> reconcileCalendar(List<Match> previous,List<Match> incoming,
    {required bool partial}){
  if(!partial)return List<Match>.from(incoming);
  final indexed=<String,Match>{
    for(final match in previous)match.key:match,
    for(final match in incoming)match.key:match,
  };
  return indexed.values.toList();
}

class TeamInfo {
  final int id;
  final String name, city, fullName, url;
  final String? logo;
  const TeamInfo(this.id,this.name,this.city,this.fullName,this.url,this.logo);
  factory TeamInfo.fromApi(Map<String,dynamic> data) => TeamInfo(
    (data['id'] as num).toInt(),
    data['name']?.toString()??'',
    data['city']?.toString()??'',
    data['fullName']?.toString()??'',
    data['url']?.toString()??'',
    data['logo']?.toString(),
  );
}

class PlayerInfo {
  final String number,name,position,url;
  final String? photo;
  const PlayerInfo(this.number,this.name,this.position,this.url,this.photo);
  factory PlayerInfo.fromApi(Map<String,dynamic> data) => PlayerInfo(
    data['number']?.toString()??'',
    data['name']?.toString()??'',
    data['position']?.toString()??'',
    data['url']?.toString()??'',
    data['photo']?.toString(),
  );
}

class TeamRoster {
  final TeamInfo team;
  final List<PlayerInfo> players;
  const TeamRoster(this.team,this.players);
}

double? _statsNum(dynamic source) {
  if(source is num)return source.toDouble();
  if(source==null)return null;
  return double.tryParse(source.toString().replaceAll(',','.'));
}

class SeasonPlayerStat {
  final int id;
  final String name,number,position,team,city,kind,profile;
  final String? photo,teamLogo;
  final int? gp,goals,assists,points,plusMinus,pim,ppg,shg;
  final int? wins,losses,saves,shotsAgainst,goalsAgainst,shutouts;
  final double? pointsPerGame,savePercentage,gaa;
  final String? timeOnIce;
  const SeasonPlayerStat({
    required this.id,required this.name,required this.number,
    required this.position,required this.team,required this.city,
    required this.kind,required this.profile,this.photo,this.teamLogo,
    this.gp,this.goals,this.assists,this.points,this.plusMinus,this.pim,
    this.ppg,this.shg,this.pointsPerGame,this.wins,this.losses,
    this.saves,this.shotsAgainst,this.savePercentage,this.gaa,
    this.goalsAgainst,this.shutouts,this.timeOnIce,
  });

  factory SeasonPlayerStat.fromApi(Map<String,dynamic> json,{required bool goalie}){
    int? number(String key){
      final value=json[key];
      return value is num?value.toInt():int.tryParse(value?.toString()??'');
    }
    return SeasonPlayerStat(
      id:number('id')??0,name:json['name']?.toString()??'',
      number:json['number']?.toString()??'',
      position:json['position']?.toString()??(goalie?'Вратарь':''),
      team:json['team']?.toString()??'',city:json['city']?.toString()??'',
      kind:goalie?'goalie':'skater',profile:json['profile']?.toString()??'',
      photo:json['photo']?.toString(),teamLogo:json['teamLogo']?.toString(),
      gp:number('gp'),goals:number('goals'),assists:number('assists'),
      points:number('points'),plusMinus:number('plusMinus'),
      pim:number('pim'),ppg:number('powerplayGoals'),
      shg:number('shorthandedGoals'),
      pointsPerGame:_statsNum(json['pointsPerGame']),
      wins:number('wins'),losses:number('losses'),saves:number('saves'),
      shotsAgainst:number('shotsAgainst'),savePercentage:_statsNum(json['savePercentage']),
      gaa:_statsNum(json['gaa']),goalsAgainst:number('goalsAgainst'),
      shutouts:number('shutouts'),timeOnIce:json['timeOnIce']?.toString()
    );
  }
  bool get isGoalie=>kind=='goalie';
  String get teamFullName=>city.isEmpty?team:'$team $city';
}

class OfficialStatsFeed {
  final String group;
  final List<String> groups;
  final DateTime? fetchedAt;
  final List<SeasonPlayerStat> skaters,goalies;
  final bool complete;
  const OfficialStatsFeed({required this.group,required this.groups,
    required this.skaters,required this.goalies,required this.complete,this.fetchedAt});
  factory OfficialStatsFeed.fromApi(Map<String,dynamic> json){
    if(json['ok']!=true||json['skaters'] is! List||json['goalies'] is! List||
      json['complete']!=true) {
      throw const FormatException('Полная статистика игроков ФХР сейчас недоступна');
    }
    final skaters=(json['skaters'] as List).whereType<Map>()
      .map((x)=>SeasonPlayerStat.fromApi(Map<String,dynamic>.from(x),goalie:false)).toList();
    final goalies=(json['goalies'] as List).whereType<Map>()
      .map((x)=>SeasonPlayerStat.fromApi(Map<String,dynamic>.from(x),goalie:true)).toList();
    final expectedSkaters=(json['skaterCount'] as num?)?.toInt();
    final expectedGoalies=(json['goalieCount'] as num?)?.toInt();
    if((expectedSkaters!=null&&expectedSkaters!=skaters.length)||
      (expectedGoalies!=null&&expectedGoalies!=goalies.length)){
      throw const FormatException('В ответе ФХР отсутствуют некоторые игроки');
    }
    return OfficialStatsFeed(
      group:json['group']?.toString()??'Общая статистика',
      groups:(json['availableGroups'] is List)
        ?(json['availableGroups'] as List).map((e)=>e.toString()).toList()
        :const ['Общая статистика'],
      skaters:skaters,goalies:goalies,complete:true,
      fetchedAt:DateTime.tryParse(json['fetchedAt']?.toString()??''),
    );
  }
}

class FhrApiClient {
  final http.Client client;
  FhrApiClient(this.client);
  Future<Map<String, dynamic>> _get(String path) async {
    try {
    final response = await client.get(Uri.parse('$fhrApiBase$path'),
      headers: {'Accept':'application/json'})
      .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw Exception('LIVE-сервер: HTTP ${response.statusCode}');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map) throw const FormatException('Ответ сервера не JSON-объект');
    final result=Map<String,dynamic>.from(data);
    if(result['ok']==true && path!='/api/v1/live')await FeedCache.write(path,result);
    return result;
    }catch(e){Diagnostics.record(path,e);rethrow;}
  }
  Future<List<TeamInfo>> teams() async {
    final data=await _get('/api/v1/teams');
    if(data['ok']!=true || data['teams'] is! List) throw const FormatException('Нет списка команд ФХР');
    return (data['teams'] as List).whereType<Map>()
      .map((item)=>TeamInfo.fromApi(Map<String,dynamic>.from(item)))
      .where((t)=>t.fullName.isNotEmpty && t.id>0).toList();
  }
  Future<TeamRoster> roster(int teamId) async {
    final data=await _get('/api/v1/teams/$teamId');
    if(data['ok']!=true || data['team'] is! Map || data['players'] is! List) {
      throw const FormatException('Состав команды на ФХР пока недоступен');
    }
    final team=TeamInfo.fromApi(Map<String,dynamic>.from(data['team'] as Map));
    final players=(data['players'] as List).whereType<Map>()
      .map((item)=>PlayerInfo.fromApi(Map<String,dynamic>.from(item))).toList();
    return TeamRoster(team,players);
  }

  Future<OfficialStatsFeed> statistics({String? group}) async {
    final normalized=group?.trim()??'';
    final suffix=normalized.isEmpty?'':'?group=${Uri.encodeQueryComponent(normalized)}';
    return OfficialStatsFeed.fromApi(await _get('/api/v1/stats$suffix'));
  }
  Future<FhrFeed> calendar() async => FhrFeed.fromApi(await _get('/api/v1/matches'));
  Future<List<Map<String, dynamic>>> liveCheck() async {
    final data = await _get('/api/v1/live');
    if (data['ok'] != true) throw Exception('Проверка LIVE ФХР недоступна');
    final raw = data['checkedMatches'];
    if (raw is! List) return [];
    return raw.whereType<Map>().where((e)=>e['ok']==true)
      .map((e)=>Map<String,dynamic>.from(e)).toList();
  }
  Future<Map<String,dynamic>> detail(int gameId) async =>
      _get('/api/v1/matches/$gameId');
}

class Rank {
  final String team;
  int gp=0, pts=0, w=0, rw=0, gf=0, ga=0, otLosses=0;
  bool provisionalTie=false;
  Rank(this.team);
  int get diff=>gf-ga;
}

/// Regulation FHR 2026/27, Articles 14, 17 and 18.
/// Points: 2 per win, 1 per OT/SO defeat, 0 per regulation defeat.
/// A final/tournament-stage table can be computed independently by setting
/// includeFinals=true and passing only the relevant final-round fixtures.
List<Rank> ranking(List<Match> matches,{
  DateTime? utcNow,
  bool includeFinals=false,
  Iterable<String> participants=const <String>[],
}) {
  final when=utcNow??DateTime.now().toUtc();
  final table=<String,Rank>{};
  final played=<Match>[];
  final seen=<String>{};
  for (final team in participants) {
    if(team.isNotEmpty)table.putIfAbsent(team,()=>Rank(team));
  }
  for(final m in matches){
    if(!seen.add(m.key))continue;
    if(!m.isQualifier && !(includeFinals&&m.isFinalStage))continue;
    table.putIfAbsent(m.home,()=>Rank(m.home));
    table.putIfAbsent(m.away,()=>Rank(m.away));
    if(!m.isResultAt(when))continue;
    final g=m.goals;
    if(g==null||g[0]==g[1])continue;
    final home=table[m.home]!,away=table[m.away]!;
    home.gp++;away.gp++;
    home.gf+=g[0];home.ga+=g[1];
    away.gf+=g[1];away.ga+=g[0];
    final winner=g[0]>g[1]?home:away,loser=g[0]>g[1]?away:home;
    winner.w++;winner.pts+=2;
    if(m.overtime){loser.otLosses++;loser.pts++;}else{winner.rw++;}
    played.add(m);
  }
  final buckets=<int,List<Rank>>{};
  for(final team in table.values){
    buckets.putIfAbsent(team.pts,()=>[]).add(team);
  }
  final result=<Rank>[];
  for(final points in (buckets.keys.toList()..sort((a,b)=>b.compareTo(a)))){
    result.addAll(_regulationTieBreak(buckets[points]!,played));
  }
  return result;
}

List<Rank> _regulationTieBreak(List<Rank> teams,List<Match> games){
  if(teams.length<2)return teams;
  final tied=teams.map((e)=>e.team).toSet();
  final meetings=games.where((m)=>tied.contains(m.home)&&tied.contains(m.away)).toList();
  final pairs=<String>{};
  for(final m in meetings){
    final ordered=[m.home,m.away]..sort();
    pairs.add(ordered.join('|'));
  }
  final required=teams.length*(teams.length-1)~/2;
  // Article 17: head-to-head criteria only when the relevant opponents
  // have played each other. For incomplete mini-leagues, use the
  // global fallback; ties remain explicitly provisional.
  final complete=required>0&&pairs.length==required;
  final criteria=complete?<int>[1,2,3,4,5,6]:<int>[5,3,6];
  for(final criterion in criteria){
    final groups=<int,List<Rank>>{};
    for(final rank in teams){
      groups.putIfAbsent(_rankCriterion(rank,criterion,meetings),()=>[]).add(rank);
    }
    if(groups.length<=1)continue;
    final result=<Rank>[];
    for(final key in (groups.keys.toList()..sort((a,b)=>b.compareTo(a)))){
      // A new mini-league must restart criteria at the beginning.
      result.addAll(_regulationTieBreak(groups[key]!,games));
    }
    if(!complete){for(final rank in result){rank.provisionalTie=true;}}
    return result;
  }
  // No extra alphabetical tie breaker exists in the FHR regulation.
  // Stable alphabetical display with a visible "not settled" marker.
  for(final rank in teams){rank.provisionalTie=true;}
  return teams.toList()..sort((a,b)=>a.team.compareTo(b.team));
}

int _rankCriterion(Rank rank,int criterion,List<Match> meetings) {
  switch(criterion){
    case 1:
      var points=0;
      for(final m in meetings){
        if(m.home!=rank.team&&m.away!=rank.team)continue;
        final goals=m.goals;
        if(goals==null)continue;
        final winner=m.home==rank.team?goals[0]>goals[1]:goals[1]>goals[0];
        points+=winner?2:(m.overtime?1:0);
      }
      return points;
    case 2:
      var difference=0;
      for(final m in meetings){
        final goals=m.goals;
        if(goals==null)continue;
        if(m.home==rank.team)difference+=goals[0]-goals[1];
        if(m.away==rank.team)difference+=goals[1]-goals[0];
      }
      return difference;
    case 3:return rank.diff;
    case 4:return rank.w;
    case 5:return rank.rw;
    case 6:return rank.gf;
    default:return 0;
  }
}

