import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cup_data.dart';
import 'player_statistics.dart';
import 'player_statistics_page.dart';
import 'team_pages.dart';
import 'match_center.dart';
import 'insights.dart';
import 'app_services.dart';
import 'ui_kit.dart';

class TeamHubPage extends StatefulWidget {
  final TeamInfo team;final List<Match> matches;final List<TeamInfo> teams;
  const TeamHubPage({super.key,required this.team,required this.matches,required this.teams});
  @override State<TeamHubPage> createState()=>_TeamHubPageState();
}
class _TeamHubPageState extends State<TeamHubPage>{
  final client=http.Client();late Future<CupStatistics> stats;String? opponent;
  @override void initState(){super.initState();stats=CupStatisticsClient(client).fetch();}
  @override void dispose(){client.close();super.dispose();}
  void open(Match m)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>MatchCenterPage(match:m)));
  Widget fixture(Match m)=>ListTile(onTap:()=>open(m),title:Text('${m.home} — ${m.away}',style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600)),subtitle:Text('${m.dayLabel} · ${m.timeMsk} · ${m.stage}'),trailing:Text(m.hasScore?m.score:'—',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:18)));
  @override Widget build(BuildContext context){
    final fixtures=teamFixtures(widget.matches,widget.team.fullName);
    final played=fixtures.where((m)=>m.finished).toList();
    final upcoming=fixtures.where((m)=>!m.finished).toList().reversed.toList();
    final table=ranking(widget.matches,participants:widget.teams.map((t)=>t.fullName));
    final ranks=table.where((r)=>sameClub(r.team,widget.team.fullName));
    final rank=ranks.isEmpty?null:ranks.first;
    final bounds=rank==null?null:QualificationBounds.forTeam(table,rank);
    final h2h=opponent==null?<Match>[]:meetings(widget.matches,widget.team.fullName,opponent!).where((m)=>m.finished).toList();
    int wins=0,gf=0,ga=0;
    for(final m in h2h){final g=m.goals!;final home=sameClub(m.home,widget.team.fullName);gf+=g[home?0:1];ga+=g[home?1:0];if(g[home?0:1]>g[home?1:0])wins++;}
    return DefaultTabController(length:4,child:Scaffold(appBar:AppBar(title:Text(widget.team.name),actions:[
      IconButton(tooltip:'Поделиться',icon:const Icon(Icons.ios_share),onPressed:()=>shareCard(context,widget.team.fullName,[if(rank!=null)'${rank.pts} очков · ${rank.gp} игр','${played.length} завершённых матчей','Кубок России U16'])),
    ],bottom:const TabBar(isScrollable:true,tabs:[Tab(text:'Обзор'),Tab(text:'Матчи'),Tab(text:'Личные встречи'),Tab(text:'Расклады')])),body:SafeArea(child:TabBarView(children:[
      ListView(key:const PageStorageKey('team-overview'),children:[
        CupCard(padding:const EdgeInsets.all(24),child:Column(children:[fhrTeamLogo(widget.team.logo,size:80),const SizedBox(height:14),Text(widget.team.fullName,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800),textAlign:TextAlign.center),const SizedBox(height:16),FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>TeamRosterPage(team:widget.team))),icon:const Icon(Icons.groups_outlined),label:const Text('Состав команды'))])),
        CupSection(title:'ПОСЛЕДНИЕ МАТЧИ'),for(final m in played.take(5))fixture(m),
        CupSection(title:'ЛИДЕРЫ КОМАНДЫ'),
        FutureBuilder<CupStatistics>(future:stats,builder:(context,s){
          if(s.hasError)return CupMessage(title:'Лидеры не загружены',message:'Проверь интернет и повтори загрузку.',retry:()=>setState(()=>stats=CupStatisticsClient(client).fetch()));
          if(!s.hasData)return const Padding(padding:EdgeInsets.all(20),child:LinearProgressIndicator());
          final leaders=sortCupPlayers(s.data!.skaters.where((p)=>sameClub('${p.team} ${p.city}',widget.team.fullName)||sameClub(p.team,widget.team.name)),PlayerStatSort.points).take(5);
          return Column(children:[for(final p in leaders)ListTile(title:Text(p.name),subtitle:Text('${p.goals} + ${p.assists} · ${p.games} игр'),trailing:Text('${p.points} О'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CupPlayerProfilePage(player:p))))]);
        }),const SizedBox(height:24),
      ]),
      ListView(key:const PageStorageKey('team-matches'),children:[CupSection(title:'РАСПИСАНИЕ'),if(upcoming.isEmpty)const CupMessage(title:'Новых матчей пока нет',message:'Расписание появится после публикации ФХР.'),for(final m in upcoming)fixture(m),CupSection(title:'РЕЗУЛЬТАТЫ'),for(final m in played)fixture(m)]),
      ListView(children:[CupSection(title:'ЛИЧНЫЕ ВСТРЕЧИ',subtitle:'Все опубликованные этапы этого Кубка'),Padding(padding:const EdgeInsets.all(16),child:DropdownButton<String>(isExpanded:true,value:opponent,hint:const Text('Выбери соперника'),items:[for(final t in widget.teams.where((t)=>t.id!=widget.team.id))DropdownMenuItem(value:t.fullName,child:Text(t.fullName,overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState(()=>opponent=v))),if(opponent!=null)...[CupCard(padding:const EdgeInsets.all(20),child:Text('${h2h.length} матчей · Победы $wins : ${h2h.length-wins}\nШайбы $gf : $ga',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w700))),for(final m in h2h)fixture(m),if(h2h.isEmpty)const CupMessage(title:'Встреч пока нет',message:'Завершённые матчи этих команд не опубликованы.')]],),
      ListView(children:[CupSection(title:'ПУТЬ В ЗОЛОТОЙ ФИНАЛ',subtitle:'Первые 8 мест общей квалификации'),if(rank!=null&&bounds!=null)...[
        CupCard(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Сейчас: ${table.indexOf(rank)+1}-е место',style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),Text('${rank.pts} очков · осталось ${bounds.remaining} из 14 игр'),const SizedBox(height:14),Text('Диапазон очков: ${bounds.minPoints}–${bounds.maxPoints}'),Text('Границы места по очкам: ${bounds.bestBound}–${bounds.worstBound}'),const SizedBox(height:14),Text(table.length!=20?'Список участников неполный: вывод о проходе пока недоступен.':bounds.worstBound<=8?'Место в восьмёрке обеспечено по очкам.':bounds.bestBound>8?'Войти в восьмёрку по очкам уже невозможно.':'Борьба за восьмёрку продолжается: результат зависит от своих матчей и соперников.'),if(table.length>=8)Text('Текущая граница восьмёрки: ${table[7].pts} очков. Это не итоговый проходной балл.') ])),
        const Padding(padding:EdgeInsets.all(18),child:Text('Границы консервативные: учитывают максимум 2 очка за победу и оставшиеся игры каждого клуба. Не все места внутри диапазона обязательно достижимы. При равенстве очков действуют дополнительные критерии ФХР; будущий рассев и ещё не опубликованные пары здесь не угадываются.')),
      ]else const CupMessage(title:'Недостаточно данных',message:'Нужна таблица квалификации. Потяни календарь на главной вниз для обновления.')]),
    ]))));
  }
}
