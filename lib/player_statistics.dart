import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cup_data.dart';
import 'app_services.dart';

double? _decimal(dynamic value) {
  if(value is num)return value.toDouble();
  if(value is! String)return null;
  return double.tryParse(value.replaceAll(',','.'));
}
int _whole(dynamic value)=>_decimal(value)?.toInt()??0;

class CupPlayerStats {
  final int id, games;
  final String name, number, position, team, city, photo, teamLogo, profile;
  final bool goalie;
  final int goals, assists, points, plusMinus, pim, wins, losses, saves, shotsAgainst, goalsAgainst, shutouts;
  final double? saveRatio, gaa, pointsPerGame;
  final String timeOnIce;
  const CupPlayerStats({
    required this.id,required this.games,required this.name,required this.number,
    required this.position,required this.team,required this.city,required this.photo,
    required this.teamLogo,required this.profile,required this.goalie,
    this.goals=0,this.assists=0,this.points=0,this.plusMinus=0,this.pim=0,
    this.wins=0,this.losses=0,this.saves=0,this.shotsAgainst=0,
    this.goalsAgainst=0,this.shutouts=0,this.saveRatio,this.gaa,
    this.pointsPerGame,this.timeOnIce='',
  });
  factory CupPlayerStats.fromApi(Map<String,dynamic> obj,{required bool goalie})=>CupPlayerStats(
    id:_whole(obj['id']),games:_whole(obj['gp']),
    name:obj['name']?.toString()??'',number:obj['number']?.toString()??'',
    position:obj['position']?.toString()??(goalie?'Вратарь':''),
    team:obj['team']?.toString()??'',city:obj['city']?.toString()??'',
    photo:obj['photo']?.toString()??'',teamLogo:obj['teamLogo']?.toString()??'',
    profile:obj['profile']?.toString()??'',goalie:goalie,
    goals:_whole(obj['goals']),assists:_whole(obj['assists']),points:_whole(obj['points']),
    plusMinus:_whole(obj['plusMinus']),pim:_whole(obj['pim']),
    wins:_whole(obj['wins']),losses:_whole(obj['losses']),saves:_whole(obj['saves']),
    shotsAgainst:_whole(obj['shotsAgainst']),goalsAgainst:_whole(obj['goalsAgainst']),
    shutouts:_whole(obj['shutouts']),saveRatio:_decimal(obj['savePercentage']),
    gaa:_decimal(obj['gaa']),pointsPerGame:_decimal(obj['pointsPerGame']),
    timeOnIce:obj['timeOnIce']?.toString()??'',
  );
  String get fullClub=>city.isEmpty?team:'$team · $city';
  String get savePercentText=>saveRatio==null?'—':'${(saveRatio!*100).toStringAsFixed(1)}%';
  String get gaaText=>gaa==null?'—':gaa!.toStringAsFixed(2);
}

enum PlayerStatSort {
  points,goals,assists,plusMinus,pim,pointsPerGame,
  savesPercentage,gaa,wins,saves,
}
String labelForSort(PlayerStatSort sort) {
  switch(sort){
    case PlayerStatSort.points:return 'БОМБАРДИРЫ';
    case PlayerStatSort.goals:return 'СНАЙПЕРЫ';
    case PlayerStatSort.assists:return 'АССИСТЕНТЫ';
    case PlayerStatSort.plusMinus:return '+/-';
    case PlayerStatSort.pim:return 'ШТРАФНЫЕ МИНУТЫ';
    case PlayerStatSort.pointsPerGame:return 'ОЧКИ ЗА МАТЧ';
    case PlayerStatSort.savesPercentage:return '% ОТРАЖЁННЫХ';
    case PlayerStatSort.gaa:return 'КН';
    case PlayerStatSort.wins:return 'ПОБЕДЫ';
    case PlayerStatSort.saves:return 'СЕЙВЫ';
  }
}

num sortValue(CupPlayerStats p,PlayerStatSort mode) {
  switch(mode){
    case PlayerStatSort.points:return p.points;
    case PlayerStatSort.goals:return p.goals;
    case PlayerStatSort.assists:return p.assists;
    case PlayerStatSort.plusMinus:return p.plusMinus;
    case PlayerStatSort.pim:return p.pim;
    case PlayerStatSort.pointsPerGame:return p.pointsPerGame??-1;
    case PlayerStatSort.savesPercentage:return p.saveRatio??-1;
    case PlayerStatSort.gaa:return p.gaa??999999;
    case PlayerStatSort.wins:return p.wins;
    case PlayerStatSort.saves:return p.saves;
  }
}

List<CupPlayerStats> sortCupPlayers(Iterable<CupPlayerStats> input,PlayerStatSort mode){
  final rows=input.toList();
  rows.sort((a,b){
    final d=mode==PlayerStatSort.gaa
      ?sortValue(a,mode).compareTo(sortValue(b,mode))
      :sortValue(b,mode).compareTo(sortValue(a,mode));
    if(d!=0)return d;
    final games=b.games.compareTo(a.games);
    return games!=0?games:a.name.compareTo(b.name);
  });
  return rows;
}

class CupStatistics {
  final List<CupPlayerStats> skaters,goalies;
  final String group,sourceUrl;
  final DateTime? updatedAt;
  final List<String> availableGroups;
  final bool complete;
  const CupStatistics({required this.skaters,required this.goalies,required this.group,
    required this.sourceUrl,required this.updatedAt,required this.availableGroups,
    required this.complete});
  factory CupStatistics.fromApi(Map<String,dynamic> json) {
    if(json['ok']!=true||json['complete']!=true||
      json['skaters'] is! List||json['goalies'] is! List) {
      throw const FormatException('Официальная статистика ФХР неполная или недоступна');
    }
    final skaters=(json['skaters'] as List).whereType<Map>()
      .map((m)=>CupPlayerStats.fromApi(Map<String,dynamic>.from(m),goalie:false))
      .where((p)=>p.id>0&&p.name.isNotEmpty&&p.team.isNotEmpty).toList();
    final goalies=(json['goalies'] as List).whereType<Map>()
      .map((m)=>CupPlayerStats.fromApi(Map<String,dynamic>.from(m),goalie:true))
      .where((p)=>p.id>0&&p.name.isNotEmpty&&p.team.isNotEmpty).toList();
    final total=(json['skaterCount'] as num?)?.toInt();
    final keepers=(json['goalieCount'] as num?)?.toInt();
    if(total!=skaters.length||keepers!=goalies.length){
      throw const FormatException('Часть строк статистики ФХР не распознана');
    }
    return CupStatistics(
      skaters:skaters,goalies:goalies,
      group:json['group']?.toString()??'Общая статистика',
      sourceUrl:json['sourceUrl']?.toString()??'',
      updatedAt:DateTime.tryParse(json['fetchedAt']?.toString()??''),
      availableGroups:(json['availableGroups'] as List?)?.map((e)=>e.toString()).toList()??
        const ['Общая статистика'],complete:true,
    );
  }
  int get playersCount=>skaters.length+goalies.length;
  List<String> get teams{
    final set=<String>{for(final p in [...skaters,...goalies])p.fullClub};
    return set.toList()..sort((a,b)=>a.compareTo(b));
  }
}

class CupStatisticsClient {
  final http.Client client;
  CupStatisticsClient(this.client);
  Future<CupStatistics?> cached({String? group})async{
    final raw=await FeedCache.read('stats:${group??''}');
    if(raw==null)return null;
    try{return CupStatistics.fromApi(raw);}catch(e){Diagnostics.record('stats cache',e);return null;}
  }
  Future<CupStatistics> fetch({String? group})async{
    final uri=Uri.parse('$fhrApiBase/api/v1/stats').replace(
      queryParameters:group==null||group.isEmpty?null:{'group':group});
    final response=await client.get(uri,headers:{'Accept':'application/json'})
      .timeout(const Duration(seconds:35));
    if(response.statusCode!=200)throw Exception('Статистика ФХР: HTTP ${response.statusCode}');
    final raw=jsonDecode(utf8.decode(response.bodyBytes));
    if(raw is! Map)throw const FormatException('Статистика ФХР вернула неверный формат');
    final obj=Map<String,dynamic>.from(raw);
    final result=CupStatistics.fromApi(obj);
    await FeedCache.write('stats:${group??''}',obj);
    return result;
  }
}

