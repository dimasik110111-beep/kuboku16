import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cup_data.dart';
import 'player_statistics.dart';
import 'match_lineups.dart';
import 'insights.dart';
import 'app_services.dart';
import 'ui_kit.dart';
import 'match_center.dart';

class PlayerComparisonPage extends StatefulWidget{
  final CupStatistics data;
  final CupPlayerStats? initial;
  const PlayerComparisonPage({super.key,required this.data,this.initial});
  @override State<PlayerComparisonPage> createState()=>_PlayerComparisonPageState();
}
class _PlayerComparisonPageState extends State<PlayerComparisonPage>{
  CupPlayerStats? first,second;bool goalies=false;
  @override void initState(){super.initState();
    goalies=widget.initial?.goalie??false;
    final list=goalies?widget.data.goalies:widget.data.skaters;
    for(final player in list){if(player.id==widget.initial?.id&&player.fullClub==widget.initial?.fullClub){first=player;break;}}
  }
  List<CupPlayerStats> get players=>goalies?widget.data.goalies:widget.data.skaters;
  Future<void> choose(bool left)async{
    final p=await showSearch<CupPlayerStats?>(context:context,delegate:_PlayerSearch(players));
    if(p!=null&&mounted)setState((){if(left){first=p;}else{second=p;}});
  }
  @override Widget build(BuildContext context){
    final a=first,b=second;
    final rows=<List<String>>[];
    if(a!=null&&b!=null){
      rows.add(['Матчи','${a.games}','${b.games}']);
      if(goalies){rows.addAll([['Победы','${a.wins}','${b.wins}'],['Отражено',a.savePercentText,b.savePercentText],['КН',a.gaaText,b.gaaText],['Сейвы','${a.saves}','${b.saves}']]);}
      else{rows.addAll([['Голы','${a.goals}','${b.goals}'],['Передачи','${a.assists}','${b.assists}'],['Очки','${a.points}','${b.points}'],['Очки за игру',a.games==0?'—':(a.points/a.games).toStringAsFixed(2),b.games==0?'—':(b.points/b.games).toStringAsFixed(2)],['Штраф','${a.pim}','${b.pim}']]);}
    }
    return Scaffold(appBar:AppBar(title:const Text('Сравнение игроков')),body:SafeArea(child:ListView(children:[
      CupSection(title:widget.data.group,subtitle:'Одинаковый этап для обоих игроков'),
      SwitchListTile(title:const Text('Вратари'),value:goalies,onChanged:(v)=>setState((){goalies=v;first=null;second=null;})),
      CupCard(child:Column(children:[ListTile(title:Text(a?.name??'Выбрать первого игрока'),subtitle:Text(a?.fullClub??'Поиск по фамилии или команде'),trailing:const Icon(Icons.search),onTap:()=>choose(true)),ListTile(title:Text(b?.name??'Выбрать второго игрока'),subtitle:Text(b?.fullClub??'Поиск по фамилии или команде'),trailing:const Icon(Icons.search),onTap:()=>choose(false))])),
      if(rows.isNotEmpty)CupCard(padding:const EdgeInsets.all(16),child:Table(columnWidths:const {0:FlexColumnWidth(2),1:FlexColumnWidth(),2:FlexColumnWidth()},children:[for(final row in rows)TableRow(children:[for(final cell in row)Padding(padding:const EdgeInsets.symmetric(vertical:12,horizontal:4),child:Text(cell,style:const TextStyle(fontWeight:FontWeight.w700)))])])),
      if(a!=null&&b!=null)Padding(padding:const EdgeInsets.all(16),child:FilledButton.icon(onPressed:()=>shareCard(context,'${a.name} / ${b.name}',rows.take(5).map((r)=>'${r[0]}: ${r[1]} / ${r[2]}').toList()),icon:const Icon(Icons.ios_share),label:const Text('Поделиться сравнением'))),
    ])));
  }
}
class _PlayerSearch extends SearchDelegate<CupPlayerStats?>{
  final List<CupPlayerStats> players;
  _PlayerSearch(this.players):super(searchFieldLabel:'Фамилия или команда');
  @override List<Widget> buildActions(BuildContext context)=>[IconButton(onPressed:()=>query='',icon:const Icon(Icons.clear))];
  @override Widget buildLeading(BuildContext context)=>IconButton(onPressed:()=>close(context,null),icon:const Icon(Icons.arrow_back));
  @override Widget buildResults(BuildContext context)=>buildSuggestions(context);
  @override Widget buildSuggestions(BuildContext context){final q=clubKey(query);final rows=players.where((p)=>clubKey('${p.name} ${p.team} ${p.city}').contains(q)).toList();return ListView.builder(itemCount:rows.length,itemBuilder:(_,i)=>ListTile(title:Text(rows[i].name),subtitle:Text(rows[i].fullClub),onTap:()=>close(context,rows[i])));}
}

class PlayerAppearance {
  final Match match;final GamePlayerStats? stats;
  const PlayerAppearance(this.match,this.stats);
}
class AppearanceHistory {
  final List<PlayerAppearance> rows;final int unavailable;
  const AppearanceHistory(this.rows,this.unavailable);
}
bool isSamePlayer(GamePlayer candidate,CupPlayerStats player){
  final profile=candidate.url;
  if(profile!=null&&profile.isNotEmpty){
    final ids=RegExp(r'\d+').allMatches(Uri.tryParse(profile)?.path??'').map((m)=>m.group(0));
    return ids.contains('${player.id}');
  }
  // No ambiguous surname-only matching.
  return clubKey(candidate.name)==clubKey(player.name)&&candidate.number==player.number;
}
class RecentPlayerGames extends StatefulWidget{
  final CupPlayerStats player;
  const RecentPlayerGames({super.key,required this.player});
  @override State<RecentPlayerGames> createState()=>_RecentPlayerGamesState();
}
class _RecentPlayerGamesState extends State<RecentPlayerGames>{
  final client=http.Client();late Future<AppearanceHistory> future;
  @override void initState(){super.initState();future=load();}
  @override void dispose(){client.close();super.dispose();}
  Future<AppearanceHistory> load()async{
    final api=FhrApiClient(client);final feed=await api.calendar();
    // Walk newest protocols until five verified appearances are found.
    // Partial/missing protocols remain explicitly reported to the user.
    final p=widget.player;
    final fixtures=feed.matches.where((m)=>m.finished&&m.gameId!=null).toList()
      ..sort((a,b)=>'${b.date} ${b.timeMsk}'.compareTo('${a.date} ${a.timeMsk}'));
    final rows=<PlayerAppearance>[];var missing=0;
    for(final m in fixtures){
      if(!mounted)break;
      final clubs=[m.home,m.away];
      if(!clubs.any((c)=>sameClub(c,'${p.team} ${p.city}')||sameClub(c,p.team)))continue;
      try{
        final detail=await api.detail(m.gameId!);final lineups=GameLineups.fromDetail(detail);
        if(!lineups.available||lineups.partial){missing++;continue;}
        final found=lineups.allPlayers.where((c)=>isSamePlayer(c,p));
        if(found.length==1)rows.add(PlayerAppearance(m,found.first.stats));
        if(rows.length==5)break;
      }catch(e){missing++;Diagnostics.record('player history',e);}
    }
    return AppearanceHistory(rows,missing);
  }
  @override Widget build(BuildContext context)=>FutureBuilder<AppearanceHistory>(future:future,builder:(context,s){
    if(s.hasError)return CupMessage(title:'История не загрузилась',message:'Проверь соединение с интернетом.',retry:()=>setState(()=>future=load()));
    if(!s.hasData)return const Padding(padding:EdgeInsets.all(20),child:Column(children:[LinearProgressIndicator(),SizedBox(height:12),Text('Проверяю последние заявки ФХР…')]));
    final data=s.data!;
    return Column(children:[
      CupSection(title:'ПОСЛЕДНИЕ 5 МАТЧЕЙ',subtitle:'Подтверждённые заявки · текущая команда'),
      if(data.unavailable>0)Padding(padding:const EdgeInsets.all(16),child:Text('${data.unavailable} протоколов недоступно или неполно: история может содержать пропуски.')),
      if(data.rows.isEmpty)const CupMessage(title:'Нет подтверждённых заявок',message:'ФХР ещё не опубликовала подходящие полные протоколы.'),
      for(final row in data.rows)CupCard(child:ListTile(
        onTap:()=>Navigator.push(context,MaterialPageRoute(
          builder:(_)=>MatchCenterPage(match:row.match))),
        leading:Icon(Icons.play_circle_outline_rounded,color:CupUi.ice),
        title:Text('${row.match.home} — ${row.match.away}',
          style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800)),
        subtitle:Text('${row.match.dayLabel} · ${row.match.score}\nГ ${row.stats?.goals??'—'} · П ${row.stats?.assists??'—'} · О ${row.stats?.points??'—'} · Штр ${row.stats?.penaltyMinutes??'—'}'),
        trailing:Icon(Icons.chevron_right_rounded,color:CupUi.muted))),
      const Padding(padding:EdgeInsets.all(16),child:Text('«—» означает, что показатель не опубликован. Попадание в заявку само по себе не подтверждает выход на лёд.')),
    ]);
  });
}
