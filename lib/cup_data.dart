import 'dart:convert';
import 'package:http/http.dart' as http;

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
      item['group']?.toString().trim() ?? 'Этап не определён',
      item['arena']?.toString().trim() ?? '',
      timeMsk: item['timeMsk']?.toString() ?? '',
      scoreNote: item['scoreNote']?.toString() ?? '',
      status: item['status']?.toString() ?? 'UNKNOWN',
      gameId: id is num ? id.toInt() : int.tryParse(id?.toString() ?? ''),
      matchUrl: item['matchUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date, 'home': home, 'away': away, 'stage': stage, 'arena': arena,
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
    return day.isBefore(mskDay);
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
    return RegExp(r'\bГРУППА\s+[^ ]+-(I|II|III)\b').hasMatch(s) ||
      s.contains('СТЫКОВ') || s.contains('ПЛЕЙ-ОФФ');
  }
  String get key => gameId?.toString() ?? '$stage|$date|$home|$away';
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
      final expected = name.startsWith('Группа') ? 10 :
          (name.contains('Плей-офф') || name.contains('Стыков')) ? 5 : 0;
      if (expected > 0 && count != expected) issues.add('$name: ${count ?? '?'} / $expected матчей');
    }
    final fetched = (json['groupsFetched'] as num?)?.toInt() ?? 0;
    if (fetched < 10) issues.add('Загружено только $fetched из 10 разделов первых двух туров');
    if (records.length < 90) issues.add('Получено ${records.length} из 90 матчей двух первых туров');
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

class FhrApiClient {
  final http.Client client;
  FhrApiClient(this.client);
  Future<Map<String, dynamic>> _get(String path) async {
    final response = await client.get(Uri.parse('$fhrApiBase$path'),
      headers: {'Accept':'application/json'})
      .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw Exception('LIVE-сервер: HTTP ${response.statusCode}');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map) throw const FormatException('Ответ сервера не JSON-объект');
    return Map<String, dynamic>.from(data);
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
  int gp = 0, pts = 0, w = 0, rw = 0, gf = 0, ga = 0;
  Rank(this.team);
  int get diff => gf-ga;
}

List<Rank> ranking(List<Match> matches, {DateTime? utcNow}) {
  final when = utcNow ?? DateTime.now().toUtc();
  final table = <String,Rank>{};
  final played = <Match>[];
  // Seed every published qualifier participant, including future fixtures.
  for (final m in matches) {
    if (!m.isQualifier) continue;
    table.putIfAbsent(m.home,()=>Rank(m.home));
    table.putIfAbsent(m.away,()=>Rank(m.away));
    if (!m.isResultAt(when)) continue;
    final g = m.goals;
    if (g == null || g[0] == g[1]) continue;
    played.add(m);
    final a = table[m.home]!, b=table[m.away]!;
    a.gp++; b.gp++;
    a.gf+=g[0];a.ga+=g[1];b.gf+=g[1];b.ga+=g[0];
    final win = g[0]>g[1]?a:b, lose=g[0]>g[1]?b:a;
    win.pts+=2; win.w++;
    if(m.overtime){lose.pts++;}else{win.rw++;}
  }
  final byPoints=<int,List<Rank>>{};
  for(final team in table.values) {
    byPoints.putIfAbsent(team.pts,()=>[]).add(team);
  }
  final ranks=<Rank>[];
  for(final pts in (byPoints.keys.toList()..sort((a,b)=>b.compareTo(a)))) {
    ranks.addAll(_breakTies(byPoints[pts]!, played));
  }
  return ranks;
}

List<Rank> _breakTies(List<Rank> group,List<Match> games) {
  if (group.length<2) return group;
  final names=group.map((t)=>t.team).toSet();
  final meetings=games.where((m)=>names.contains(m.home)&&names.contains(m.away)).toList();
  final pairs = <String>{};
  for (final m in meetings) {
    final teams=[m.home,m.away]..sort();
    pairs.add(teams.join('|'));
  }
  final completeMeetings=pairs.length==group.length*(group.length-1)~/2;
  final criteria=completeMeetings?<int>[1,2,3,4,5,6]:<int>[5,3,6];
  for (final criterion in criteria) {
    final buckets=<int,List<Rank>>{};
    for (final team in group) {
      buckets.putIfAbsent(_criterion(team,criterion,meetings),()=>[]).add(team);
    }
    if (buckets.length==1) continue;
    final out=<Rank>[];
    for (final k in (buckets.keys.toList()..sort((a,b)=>b.compareTo(a)))) {
      out.addAll(_breakTies(buckets[k]!,games));
    }
    return out;
  }
  // Official criteria cannot separate these teams; alphabetic order is provisional.
  return group.toList()..sort((a,b)=>a.team.compareTo(b.team));
}

int _criterion(Rank team,int criterion,List<Match> meetings) {
  switch(criterion) {
    case 1:
      var points=0;
      for(final m in meetings) {
        if(m.home!=team.team && m.away!=team.team) continue;
        final g=m.goals!;
        final win=(m.home==team.team?g[0]>g[1]:g[1]>g[0]);
        points+=win?2:(m.overtime?1:0);
      }
      return points;
    case 2:
      var diff=0;
      for(final m in meetings) {
        final g=m.goals!;
        if(m.home==team.team)diff+=g[0]-g[1];
        if(m.away==team.team)diff+=g[1]-g[0];
      }
      return diff;
    case 3:return team.diff;
    case 4:return team.w;
    case 5:return team.rw;
    case 6:return team.gf;
    default: return 0;
  }
}
