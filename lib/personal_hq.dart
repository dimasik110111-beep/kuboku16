import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'cup_data.dart';
import 'player_statistics.dart';
import 'player_statistics_page.dart';
import 'team_pages.dart';
import 'ui_kit.dart';
import 'follow_store.dart';
import 'insights.dart';
import 'app_services.dart';

/// Personal dashboard based on locally saved clubs, players and match stars.
/// Visible in-app only. No background push service is claimed.
class PersonalHqPanel extends StatefulWidget {
  final List<Match> matches;
  final List<TeamInfo> clubs;
  final ValueChanged<String> onTeam;
  final ValueChanged<Match> onMatch;
  const PersonalHqPanel({super.key,required this.matches,required this.clubs,
    required this.onTeam,required this.onMatch});
  @override State<PersonalHqPanel> createState()=>_PersonalHqPanelState();
}
class _PersonalHqPanelState extends State<PersonalHqPanel>{
  Set<String> teams={};
  Set<int> players={};
  Set<String> starredMatches={};
  int? myTeamId;
  CupStatistics? stats;
  final httpClient=http.Client();
  bool loading=true,fetching=false;
  @override void initState(){super.initState();restore();}
  @override void dispose(){httpClient.close();super.dispose();}
  Future<void> restore()async{
    try{
      final prefs=await SharedPreferences.getInstance();
      final clubs=await FollowStore.teams();
      final followed=await FollowStore.players();
      if(!mounted)return;
      setState((){
        teams=clubs;players=followed;
        starredMatches=(prefs.getStringList('junior_favorites')??[]).toSet();
        myTeamId=prefs.getInt('junior_my_team_id');loading=false;
      });
      await loadPlayers();
    }catch(e){
      Diagnostics.record('personal hq',e);
      if(mounted)setState(()=>loading=false);
    }
  }
  Future<void> loadPlayers()async{
    if(fetching)return;
    setState(()=>fetching=true);
    try{
      final data=await CupStatisticsClient(httpClient).fetch();
      if(mounted)setState(()=>stats=data);
    }catch(e){Diagnostics.record('personal player feed',e);}
    finally{if(mounted)setState(()=>fetching=false);}
  }
  Future<void> chooseTeam()async{
    final chosen=await showModalBottomSheet<TeamInfo>(context:context,
      isScrollControlled:true,useSafeArea:true,builder:(context)=>SafeArea(
        child:ListView(shrinkWrap:true,children:[
          const ListTile(title:Text('ДОБАВИТЬ КОМАНДУ')),
          for(final club in widget.clubs)ListTile(
            leading:fhrTeamLogo(club.logo,size:32),
            title:Text(club.fullName),
            trailing:teams.contains(club.fullName)
              ?Icon(Icons.check_circle,color:CupUi.green):null,
            onTap:()=>Navigator.pop(context,club)),
        ])));
    if(chosen==null||!mounted)return;
    await FollowStore.toggleTeam(chosen.fullName);
    final saved=await FollowStore.teams();
    if(mounted)setState(()=>teams=saved);
  }
  Future<void> removeTeam(String team)async{
    await FollowStore.toggleTeam(team);
    final updated=await FollowStore.teams();
    if(mounted)setState(()=>teams=updated);
  }
  Future<void> removePlayer(int id)async{
    await FollowStore.togglePlayer(id);
    final updated=await FollowStore.players();
    if(mounted)setState(()=>players=updated);
  }
  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator());
    final preferred=widget.clubs.where((t)=>t.id==myTeamId);
    final followed={...teams,if(preferred.isNotEmpty)preferred.first.fullName};
    final watched=[...widget.matches.where((m)=>followed.any((t)=>
      sameClub(m.home,t)||sameClub(m.away,t))||starredMatches.contains(m.key))]
      ..sort((a,b)=>'${b.date} ${b.timeMsk}'.compareTo('${a.date} ${a.timeMsk}'));
    final recent=watched.where((m)=>m.finished||m.isLive).take(7).toList();
    final next=watched.where((m)=>!m.finished&&!m.isLive).toList()
      ..sort((a,b)=>'${a.date} ${a.timeMsk}'.compareTo('${b.date} ${b.timeMsk}'));
    final allPlayers=[...?stats?.skaters,...?stats?.goalies];
    final starred=allPlayers.where((p)=>players.contains(p.id)).toList()
      ..sort((a,b)=>b.points.compareTo(a.points));
    return RefreshIndicator(onRefresh:()async{await restore();},
      child:ListView(key:const PageStorageKey('personal-hq'),children:[
        CupArena(padding:const EdgeInsets.all(22),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            const Icon(Icons.radar_rounded,color:CupUi.ice,size:23),
            const SizedBox(width:10),
            const Expanded(child:Text('PERSONAL HQ',style:TextStyle(
              color:Colors.white,fontWeight:FontWeight.w900,fontSize:13,
              letterSpacing:1))),
            CupTag(text:'НА УСТРОЙСТВЕ',color:CupUi.ice),
          ]),
          const SizedBox(height:22),
          const Text('ТВОЙ КУБОК.\nТВОИ ПРАВИЛА.',
            style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,
              fontSize:30,height:1.05,letterSpacing:-1)),
          const SizedBox(height:14),
          Text('${followed.length} команд · ${players.length} игроков · ${starredMatches.length} избранных матчей',
            style:TextStyle(color:CupUi.soft,fontWeight:FontWeight.w800,fontSize:11)),
          const SizedBox(height:15),
          Text('Лента обновляется при получении данных ФХР. Фоновые push-уведомления не включены.',
            style:TextStyle(color:CupUi.muted,fontSize:10,height:1.5)),
        ])),
        CupSection(title:'МОИ КОМАНДЫ',subtitle:'Добавь любую команду для личной ленты'),
        Padding(padding:const EdgeInsets.symmetric(horizontal:12),
          child:OutlinedButton.icon(onPressed:chooseTeam,
            icon:const Icon(Icons.add_circle_outline_rounded),
            label:const Text('ВЫБРАТЬ КОМАНДУ'))),
        for(final name in followed)CupCard(padding:const EdgeInsets.all(10),
          child:Row(children:[
            fhrTeamLogo(widget.clubs.where((c)=>c.fullName==name)
              .map((c)=>c.logo).firstOrNull,size:37),
            const SizedBox(width:9),
            Expanded(child:InkWell(onTap:()=>widget.onTeam(name),
              child:Padding(padding:const EdgeInsets.symmetric(vertical:9),
                child:Text(name,maxLines:2,style:TextStyle(
                  color:CupUi.white,fontSize:12,fontWeight:FontWeight.w800))))),
            if(teams.contains(name))IconButton(
              tooltip:'Перестать отслеживать',onPressed:()=>removeTeam(name),
              icon:Icon(Icons.close,color:CupUi.muted,size:20)),
          ])),
        CupSection(title:'МОИ ИГРОКИ',subtitle:'Добавляй игроков звёздочкой в их профилях'),
        if(fetching)const Padding(padding:EdgeInsets.all(13),
          child:LinearProgressIndicator()),
        if(players.isEmpty)const CupMessage(
          title:'Пока нет избранных игроков',
          message:'Открой статистику или профиль игрока и нажми звёздочку.'),
        if(players.isNotEmpty&&stats==null)CupMessage(
          title:'Данные игроков недоступны',
          message:'Отслеживаемые игроки сохранены. Повтори обновление статистики.',
          retry:loadPlayers),
        for(final p in starred)CupCard(padding:EdgeInsets.zero,
          child:ListTile(
            leading:fhrPlayerPhoto(p.photo,size:43),
            title:Text(p.name,style:TextStyle(color:CupUi.white,
              fontSize:12,fontWeight:FontWeight.w900)),
            subtitle:Text('${p.fullClub} · ${p.goalie?p.savePercentText:'${p.points} очков'}',
              maxLines:2,style:TextStyle(color:CupUi.muted,fontSize:10)),
            trailing:IconButton(tooltip:'Убрать',onPressed:()=>removePlayer(p.id),
              icon:Icon(Icons.star_rounded,color:CupUi.yellow)),
            onTap:()=>Navigator.push(context,MaterialPageRoute(
              builder:(_)=>CupPlayerProfilePage(player:p))),
          )),
        CupSection(title:'БЛИЖАЙШИЕ МАТЧИ',subtitle:'Команды и отмеченные встречи'),
        if(next.isEmpty)const CupMessage(title:'Нет предстоящих матчей',
          message:'Новые даты появятся после публикации ФХР.'),
        for(final m in next.take(5))_matchRow(m),
        CupSection(title:'ЛЕНТА РЕЗУЛЬТАТОВ',
          subtitle:'Реальные данные ФХР для выбранных команд'),
        if(recent.isEmpty)const CupMessage(title:'Пока нет результатов',
          message:'Отметь команду или матч для персональной ленты.'),
        for(final m in recent)_matchRow(m),
        const SizedBox(height:26),
      ]));
  }
  Widget _matchRow(Match m)=>CupCard(padding:EdgeInsets.zero,
    child:ListTile(
      onTap:()=>widget.onMatch(m),
      leading:Icon(m.isLive?Icons.radio_button_checked_rounded:
        m.finished?Icons.check_circle_outline_rounded:Icons.schedule_rounded,
        color:m.isLive?CupUi.green:CupUi.ice,size:21),
      title:Text('${m.home} — ${m.away}',maxLines:2,
        style:TextStyle(color:CupUi.white,fontSize:11,fontWeight:FontWeight.w800)),
      subtitle:Text('${m.dayLabel} · ${m.stage}',maxLines:1,
        style:TextStyle(color:CupUi.muted,fontSize:9)),
      trailing:Text(m.hasScore?m.score:'→',style:TextStyle(color:CupUi.white,
        fontWeight:FontWeight.w900,fontSize:16)),
    ));
}
