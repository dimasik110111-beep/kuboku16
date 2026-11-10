import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cup_data.dart';
import 'tournament.dart';
import 'command_engine.dart';
import 'gold_odds.dart';
import 'personal_hq.dart';
import 'scenario_page.dart';
import 'team_pages.dart';
import 'ui_kit.dart';
import 'app_services.dart';

class CommandCenterPage extends StatefulWidget {
  final List<Match> matches;
  final List<TeamInfo> clubs;
  final ValueChanged<String> onTeam;
  final ValueChanged<Match> onMatch;
  final String? initialTeam;
  const CommandCenterPage({super.key,required this.matches,required this.clubs,
    required this.onTeam,required this.onMatch,this.initialTeam});
  @override State<CommandCenterPage> createState()=>_CommandCenterPageState();
}
class _CommandCenterPageState extends State<CommandCenterPage>
    with WidgetsBindingObserver{
  final api=FhrApiClient(http.Client());
  Timer? timer;
  late List<Match> games;
  late RaceEngine _engine;
  String _feedSignature='';
  bool _simulationStale=false;
  bool fetching=false,simulating=false;
  String? syncError,focus;
  int screen=0,samples=500,historicalIndex=-1;
  String? expandedMatch;
  SimulationReport? report;
  DateTime? updated;
  static const tabs=['LIVE RACE','ПРОГНОЗЫ','ПУТЬ К ФИНАЛУ',
    'МАШИНА ВРЕМЕНИ','ВЛИЯНИЕ МАТЧЕЙ','МОЁ','GOLD ODDS'];
  static const tabIcons=[
    Icons.leaderboard_rounded,Icons.auto_graph_rounded,
    Icons.account_tree_rounded,Icons.history_toggle_off_rounded,
    Icons.hub_rounded,Icons.person_rounded,Icons.auto_awesome_rounded,
  ];
  @override void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    games=widget.matches;
    _engine=RaceEngine(games,_participants(games));
    _feedSignature=_signature(games);
    focus=widget.initialTeam;
    refresh();
    timer=Timer.periodic(const Duration(seconds:25),(_){
      if(mounted&&ModalRoute.of(context)?.isCurrent==true)refresh();
    });
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed)refresh();
  }
  @override void dispose(){
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    api.client.close();
    super.dispose();
  }
  List<String> _participants(List<Match> matches){
    final names=<String>{
      ...widget.clubs.map((c)=>c.fullName).where((s)=>s.isNotEmpty),
      ...matches.where((m)=>m.isQualifier).expand((m)=>[m.home,m.away])
        .where((s)=>s.isNotEmpty),
    }.toList()..sort();
    return names;
  }
  String _signature(List<Match> source){
    final fixtures=[...source]..sort((a,b)=>a.key.compareTo(b.key));
    return fixtures.map((m)=>'${m.key}:${m.status}:${m.score}:${m.scoreNote}').join(';');
  }
  List<String> get teamNames=>_engine.teams;
  RaceEngine get engine=>_engine;
  String? get chosen=>teamNames.contains(focus)?focus:
    teamNames.isEmpty?null:teamNames.first;
  String? logo(String name){
    for(final t in widget.clubs){
      if(t.fullName==name||t.name==name)return t.logo;
    }
    return null;
  }
  Future<void> refresh()async{
    if(fetching)return;
    if(mounted)setState(()=>fetching=true);
    try{
      final feed=await api.calendar();
      final rows={for(final m in feed.matches)m.key:m};
      try{
        final details=await api.liveCheck();
        for(final detail in details){
          final id=detail['gameId']?.toString();
          if(id!=null&&rows.containsKey(id))rows[id]=rows[id]!.withDetail(detail);
        }
      }catch(e){Diagnostics.record('command live details',e);}
      if(!mounted)return;
      final partial=feed.issues.isNotEmpty||
        (rows.isEmpty&&games.isNotEmpty);
      final nextGames=reconcileCalendar(games,rows.values.toList(),partial:partial);
      final nextSignature=_signature(nextGames);
      setState((){
        if(nextSignature!=_feedSignature){
          games=nextGames;
          _feedSignature=nextSignature;
          _engine=RaceEngine(games,_participants(games));
          _simulationStale=report!=null;
        }
        updated=feed.updatedAt;
        syncError=feed.issues.isEmpty?null:'Часть данных ФХР не загружена';
      });
    }catch(e){
      Diagnostics.record('command live feed',e);
      if(mounted)setState(()=>syncError='Нет соединения с ФХР; показаны последние доступные данные');
    }finally{if(mounted)setState(()=>fetching=false);}
  }
  Future<void> simulate()async{
    if(simulating||teamNames.isEmpty)return;
    final signatureAtStart=_feedSignature;
    setState(()=>simulating=true);
    try{
      final input=SimulationInput(List<Match>.from(games),List<String>.from(teamNames),
        samples,20261107+samples,DateTime.now().toUtc());
      final value=await compute(simulateCup,input);
      if(mounted)setState((){
        report=value;
        _simulationStale=signatureAtStart!=_feedSignature;
      });
    }catch(e){
      Diagnostics.record('simulation',e);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Симуляция не завершена. Попробуй меньше прогонов.')));
    }finally{if(mounted)setState(()=>simulating=false);}
  }
  void select(int index){
    setState(()=>screen=index);
  }
  Widget _tag(String text,{Color? color})=>
    CupTag(text:text,color:color??CupUi.ice,filled:true);
  Widget _teamSelector()=>CupCard(padding:const EdgeInsets.fromLTRB(15,4,15,4),
    child:Row(children:[
      Icon(Icons.travel_explore_rounded,color:CupUi.ice,size:21),
      const SizedBox(width:11),
      Expanded(child:DropdownButtonHideUnderline(child:DropdownButton<String>(
        isExpanded:true,value:chosen,
        hint:const Text('Выбрать команду'),
        items:[for(final name in teamNames)DropdownMenuItem(
          value:name,child:Text(name,overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontSize:12)))],
        onChanged:(name)=>setState(()=>focus=name),
      ))),
      if(chosen!=null)IconButton(tooltip:'Профиль клуба',
        icon:Icon(Icons.open_in_new_rounded,color:CupUi.ice,size:20),
        onPressed:()=>widget.onTeam(chosen!)),
    ]));
  Widget _hero(RaceEngine r){
    final table=r.standings;
    final completed=r.confirmed;
    final live=games.where((m)=>m.isLive).length;
    return CupArena(padding:const EdgeInsets.all(22),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Icon(Icons.radar_rounded,color:CupUi.ice,size:22),
          const SizedBox(width:10),
          const Expanded(child:Text('JUNIOR / COMMAND CENTER',
            style:TextStyle(color:CupUi.ice,fontSize:10,
              fontWeight:FontWeight.w900,letterSpacing:1))),
          _tag(live>0?'● $live LIVE':'LIVE DATA',
            color:live>0?CupUi.green:CupUi.ice),
        ]),
        const SizedBox(height:20),
        const Text('КУБОК ПОД\nКОНТРОЛЕМ.',
          style:TextStyle(color:Colors.white,fontSize:31,
            fontWeight:FontWeight.w900,letterSpacing:-1.2,height:1.06)),
        const SizedBox(height:12),
        Text('${table.length} команд · $completed завершённых матчей квалификации',
          style:TextStyle(color:CupUi.soft,fontSize:11,fontWeight:FontWeight.w800)),
        const SizedBox(height:12),
        ClipRRect(borderRadius:BorderRadius.circular(9),
          child:LinearProgressIndicator(
            minHeight:7,value:(completed/expectedQualifyingGames).clamp(0.0,1.0),
            backgroundColor:Colors.white.withValues(alpha:.13),
            valueColor:const AlwaysStoppedAnimation<Color>(CupUi.ice))),
        const SizedBox(height:11),
        Row(children:[
          Icon(Icons.sync_rounded,color:CupUi.ice,size:14),
          const SizedBox(width:6),
          Expanded(child:Text(
            updated==null?'Синхронизация ФХР':
            'Синхронизировано: ${updated!.toUtc().toIso8601String().substring(0,16)} UTC',
            style:TextStyle(color:CupUi.muted,fontSize:9))),
          if(fetching)const SizedBox(width:13,height:13,
            child:CircularProgressIndicator(strokeWidth:2)),
        ]),
      ]));
  }
  Widget _race(RaceEngine r){
    final official=r.standings;
    final liveCount=games.where((m)=>m.isQualifier&&m.isLive&&m.goals!=null).length;
    final table=liveCount>0?r.cup.liveTable():official;
    final officialPosition={for(var i=0;i<official.length;i++)official[i].team:i+1};
    final focusTeam=chosen;
    final useful=focusTeam==null?<HelpfulOutcome>[]:
      r.helpfulOutcomes(focusTeam,limit:6);
    return Column(children:[
      CupSection(title:'ГОНКА ЗА ЗОЛОТО',subtitle:liveCount>0
        ?'Промежуточная таблица обновляется по текущему счёту'
        :'Официальная таблица по подтверждённым результатам'),
      if(liveCount>0)Padding(padding:const EdgeInsets.symmetric(horizontal:13),
        child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
          decoration:BoxDecoration(color:CupUi.green.withValues(alpha:.10),
            border:Border.all(color:CupUi.green.withValues(alpha:.28)),
            borderRadius:BorderRadius.circular(13)),
          child:Row(children:[Icon(Icons.sensors_rounded,color:CupUi.green,size:17),
            const SizedBox(width:8),Expanded(child:Text(
              'LIVE · $liveCount ${liveCount==1?'матч':'матча'} учтено предварительно. Очки и места могут измениться до финальной сирены.',
              style:TextStyle(color:CupUi.soft,fontSize:9,height:1.35))),
          ]))),
      CupCard(padding:EdgeInsets.zero,child:Column(children:[
        for(var i=0;i<table.length;i++)...[
          if(i==8)Container(padding:const EdgeInsets.symmetric(vertical:11),
            color:CupUi.yellow.withValues(alpha:.11),
            child:Row(children:[
              Expanded(child:Container(height:1,color:CupUi.yellow.withValues(alpha:.4))),
              Padding(padding:const EdgeInsets.symmetric(horizontal:10),
                child:Text('ГРАНИЦА ТОП-8',style:TextStyle(
                  color:CupUi.yellow,fontSize:10,fontWeight:FontWeight.w900))),
              Expanded(child:Container(height:1,color:CupUi.yellow.withValues(alpha:.4))),
            ])),
          InkWell(onTap:()=>setState(()=>focus=table[i].team),
            child:AnimatedContainer(
              duration:const Duration(milliseconds:250),
              decoration:BoxDecoration(color:chosen==table[i].team
                ?CupUi.red.withValues(alpha:.17)
                :i<8?CupUi.green.withValues(alpha:.035):Colors.transparent),
              padding:const EdgeInsets.symmetric(horizontal:13,vertical:11),
              child:Row(children:[
                SizedBox(width:27,child:Text('${i+1}',
                  style:TextStyle(color:i<8?CupUi.green:CupUi.muted,
                    fontSize:11,fontWeight:FontWeight.w900))),
                fhrTeamLogo(logo(table[i].team),size:26),
                const SizedBox(width:9),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(table[i].team,maxLines:1,overflow:TextOverflow.ellipsis,
                    style:TextStyle(color:CupUi.white,fontSize:11,fontWeight:FontWeight.w800)),
                  Text('${table[i].gp} И · ${table[i].gf}:${table[i].ga} · гр. ${r.projectedGroups[table[i].team]??'—'}',
                    style:TextStyle(color:CupUi.muted,fontSize:9)),
                ])),
                SizedBox(width:31,child:Text(
                  liveCount>0&&officialPosition.containsKey(table[i].team)&&officialPosition[table[i].team]!=i+1
                    ?'${officialPosition[table[i].team]!>i+1?'↑':'↓'}${(officialPosition[table[i].team]!-i-1).abs()}'
                    :liveCount==0&&(r.positionChanges[table[i].team]??0)!=0
                      ?'${r.positionChanges[table[i].team]!>0?'↑':'↓'}${r.positionChanges[table[i].team]!.abs()}'
                      :'—',
                  textAlign:TextAlign.center,
                  style:TextStyle(color:liveCount>0
                    ?(officialPosition[table[i].team]??i+1)>=i+1?CupUi.green:CupUi.red
                    :(r.positionChanges[table[i].team]??0)>=0
                    ?CupUi.green:CupUi.red,fontSize:10,fontWeight:FontWeight.w900))),
                SizedBox(width:35,child:Text('${table[i].pts}',
                  textAlign:TextAlign.right,style:TextStyle(
                    color:CupUi.white,fontSize:16,fontWeight:FontWeight.w900))),
              ]))),
          if(i<table.length-1)CupDiv(indent:45),
        ],
      ])),
      const SizedBox(height:6),
      _teamSelector(),
      CupSection(title:'ЧТО НУЖНО МОЕЙ КОМАНДЕ?',
        subtitle:'Расклады по ещё не сыгранным опубликованным матчам'),
      CupCard(padding:const EdgeInsets.all(15),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(focusTeam??'Выбери клуб',style:TextStyle(
            color:CupUi.white,fontSize:15,fontWeight:FontWeight.w900)),
          const SizedBox(height:9),
          Text('Исследуем, какой исход каждой отдельной игры улучшает позицию клуба. '
            'Это не минимально необходимые результаты и не гарантия прохода.',
            style:TextStyle(color:CupUi.soft,fontSize:10,height:1.5)),
          if(useful.isEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:12),
            child:Text('Подходящие опубликованные матчи пока не найдены.',
              style:TextStyle(color:CupUi.muted,fontSize:11))),
          for(final item in useful)Padding(
            padding:const EdgeInsets.only(top:11),
            child:Row(children:[
              Icon(Icons.bolt_rounded,color:CupUi.yellow,size:17),
              const SizedBox(width:8),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('${item.match.home} — ${item.match.away}',
                  maxLines:1,overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:CupUi.white,fontSize:10,fontWeight:FontWeight.w800)),
                const SizedBox(height:3),
                Text(item.usefulResult,style:TextStyle(
                  color:CupUi.green,fontSize:10)),
              ])),
              Text('${item.bestPlace}–${item.worstPlace}',
                style:TextStyle(color:CupUi.ice,fontSize:12,fontWeight:FontWeight.w900)),
            ])),
          const SizedBox(height:13),
          SizedBox(width:double.infinity,child:FilledButton.icon(
            onPressed:focusTeam==null?null:()=>_openPredictions(focusTeam),
            icon:const Icon(Icons.auto_graph_rounded),
            label:const Text('ПОСТРОИТЬ МОЙ СЦЕНАРИЙ'))),
        ])),
    ]);
  }
  void _openPredictions(String? selected)=>Navigator.push(context,
    MaterialPageRoute(builder:(_)=>ScenarioPage(matches:games,
      teams:teamNames,initialTeam:selected,
      teamLogos:{for(final t in widget.clubs)t.fullName:t.logo})));

  Widget _simulations(RaceEngine r){
    final rows=r.standings;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      CupSection(title:'PREDICTION ENGINE 2.0',
        subtitle:'Вероятностная модель с автоматическими развилками туров'),
      CupArena(padding:const EdgeInsets.all(19),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Icon(Icons.psychology_alt_rounded,color:CupUi.ice,size:23),
            const SizedBox(width:9),
            const Expanded(child:Text('МОНТЕ-КАРЛО',style:TextStyle(
              color:Colors.white,fontSize:14,fontWeight:FontWeight.w900))),
            _tag('ON DEVICE'),
          ]),
          const SizedBox(height:15),
          Text('Каждый прогон моделирует возможные победы, овертаймы и '
            'следующий рассев по правилам Кубка. Текущие результаты ФХР не меняются.',
            style:TextStyle(color:CupUi.soft,fontSize:11,height:1.55)),
          const SizedBox(height:15),
          Wrap(spacing:7,runSpacing:7,children:[
            for(final count in [100,500,1500])ChoiceChip(
              label:Text('$count прогонов'),
              selected:samples==count,
              onSelected:simulating?null:(_)=>setState(()=>samples=count),
            ),
          ]),
          const SizedBox(height:13),
          SizedBox(width:double.infinity,child:FilledButton.icon(
            onPressed:simulating?null:simulate,
            icon:simulating?const SizedBox(width:17,height:17,
              child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):
              const Icon(Icons.play_arrow_rounded),
            label:Text(simulating?'СЧИТАЮ СЦЕНАРИИ':'ЗАПУСТИТЬ СИМУЛЯЦИЮ'))),
          if(report!=null)...[
            const SizedBox(height:13),
            Text('${report!.iterations} прогонов · до ${report!.predictedPerRun} смоделированных игр в прогоне',
              style:TextStyle(color:CupUi.ice,fontSize:10)),
          ],
        ])),
      if(report==null)const CupMessage(
        title:'Симуляция не запускалась',
        message:'Выбери количество прогонов и нажми запуск. Результат будет рассчитан на устройстве.'),
      if(report!=null)...[
        if(_simulationStale)CupCard(padding:const EdgeInsets.all(13),
          child:Row(children:[
            Icon(Icons.info_outline_rounded,color:CupUi.yellow,size:20),
            const SizedBox(width:10),
            Expanded(child:Text('Данные ФХР изменились после расчёта. '
              'Это сохранённый прогноз; запусти симуляцию заново.',
              style:TextStyle(color:CupUi.soft,fontSize:11,height:1.4))),
          ])),
        CupSection(title:'МОДЕЛЬНЫЕ ШАНСЫ НА ТОП-8',
          subtitle:'Доля прогонов, в которых клуб закончил в первой восьмёрке'),
        CupCard(padding:const EdgeInsets.all(13),child:Column(children:[
          for(final rank in rows)Padding(
            padding:const EdgeInsets.symmetric(vertical:9),
            child:Column(children:[
              Row(children:[
                SizedBox(width:24,child:Text('${rows.indexOf(rank)+1}',
                  style:TextStyle(color:CupUi.muted,fontSize:10))),
                Expanded(child:Text(rank.team,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:CupUi.white,fontWeight:FontWeight.w800,fontSize:11))),
                Text('${((report!.topEight[rank.team]??0)*100).toStringAsFixed(1)}%',
                  style:TextStyle(color:CupUi.ice,fontSize:12,fontWeight:FontWeight.w900)),
              ]),
              const SizedBox(height:7),
              ClipRRect(borderRadius:BorderRadius.circular(6),
                child:LinearProgressIndicator(
                  value:report!.topEight[rank.team]??0,minHeight:6,
                  backgroundColor:CupUi.raised,
                  valueColor:AlwaysStoppedAnimation<Color>(
                    (report!.topEight[rank.team]??0)>.5?CupUi.green:CupUi.red))),
            ])),
        ])),
        _teamSelector(),
        if(chosen!=null)CupArena(padding:const EdgeInsets.all(17),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Icon(Icons.sports_score_rounded,color:CupUi.ice,size:21),
              const SizedBox(width:9),
              Expanded(child:Text(chosen!,maxLines:2,
                overflow:TextOverflow.ellipsis,style:const TextStyle(
                  color:Colors.white,fontSize:13,fontWeight:FontWeight.w900))),
              CupTag(text:'МОЙ ПРОГНОЗ',color:CupUi.ice,filled:true),
            ]),
            const SizedBox(height:14),
            Row(children:[
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('МОДЕЛЬНЫЙ ТОП-8',style:TextStyle(
                  color:Color(0xFFCDD8ED),fontSize:9,fontWeight:FontWeight.w900)),
                const SizedBox(height:7),
                Text('${((report!.topEight[chosen!]??0)*100).toStringAsFixed(1)}%',
                  style:const TextStyle(color:Colors.white,
                    fontSize:33,fontWeight:FontWeight.w900)),
              ])),
              Container(width:1,height:56,color:Colors.white.withValues(alpha:.18)),
              const SizedBox(width:15),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('СРЕДНЕЕ МЕСТО',style:TextStyle(
                  color:Color(0xFFCDD8ED),fontSize:9,fontWeight:FontWeight.w900)),
                const SizedBox(height:7),
                Text((report!.averagePlace[chosen!]??0).toStringAsFixed(1),
                  style:const TextStyle(color:Colors.white,
                    fontSize:33,fontWeight:FontWeight.w900)),
              ])),
            ]),
            const SizedBox(height:11),
            Text('Не рейтинг ФХР. Оценка модели по ${report!.iterations} сценариям.',
              style:TextStyle(color:CupUi.soft,fontSize:10,height:1.4)),
          ])),
        if(chosen!=null)CupCard(padding:const EdgeInsets.all(15),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('ГРУППА III ТУРА · $chosen',style:TextStyle(
              color:CupUi.white,fontSize:12,fontWeight:FontWeight.w900)),
            const SizedBox(height:14),
            for(final name in ['А','Б','В','Г'])Padding(
              padding:const EdgeInsets.only(bottom:11),child:Row(children:[
                SizedBox(width:73,child:Text('ГРУППА $name',style:TextStyle(
                  color:CupUi.soft,fontSize:9,fontWeight:FontWeight.w800))),
                Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(5),
                  child:LinearProgressIndicator(minHeight:8,
                    backgroundColor:CupUi.raised,
                    value:(report!.thirdGroups[chosen!]?[name]??0),
                    valueColor:const AlwaysStoppedAnimation<Color>(CupUi.ice)))),
                const SizedBox(width:8),
                Text('${((report!.thirdGroups[chosen!]?[name]??0)*100).toStringAsFixed(0)}%',
                  style:TextStyle(color:CupUi.white,fontSize:10)),
              ])),
          ])),
        CupCard(padding:const EdgeInsets.all(15),
          child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Icon(Icons.info_outline,color:CupUi.yellow,size:18),
            const SizedBox(width:10),
            Expanded(child:Text(report!.warning,style:TextStyle(
              color:CupUi.soft,fontSize:10,height:1.5))),
          ])),
      ],
    ]);
  }

  Widget _road(RaceEngine r){
    final name=chosen;
    final matches=games;
    if(name==null)return const CupMessage(title:'Выбери команду',message:'Загружаю участников ФХР.');
    final current=r.standings.indexWhere((row)=>row.team==name);
    final projectedGroup=r.projectedGroups[name];
    final completed=r.cup.qualificationComplete;
    final labels=['I ТУР','II ТУР','III ТУР','ФИНАЛ'];
    final stages=[CupTour.first,CupTour.second,CupTour.third];
    return Column(children:[
      CupSection(title:'ROAD TO GOLD',
        subtitle:'Маршрут команды на основе официальных и прогнозных этапов'),
      _teamSelector(),
      CupArena(padding:const EdgeInsets.all(21),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('THE JOURNEY',style:TextStyle(color:CupUi.ice,
            fontWeight:FontWeight.w900,fontSize:11,letterSpacing:1.6)),
          const SizedBox(height:16),
          Text(name,style:const TextStyle(color:Colors.white,
            fontWeight:FontWeight.w900,fontSize:25,height:1.1)),
          const SizedBox(height:9),
          Text(current<0?'В общей таблице пока нет места':
            'СЕЙЧАС: ${current+1}-Е МЕСТО · ${r.standings[current].pts} ОЧКОВ',
            style:TextStyle(color:CupUi.soft,fontSize:11)),
          const SizedBox(height:12),
          Text('ПРОЕКЦИЯ ГРУППЫ III: ${projectedGroup??'—'}',
            style:TextStyle(color:CupUi.ice,fontSize:11,fontWeight:FontWeight.w900)),
        ])),
      for(var i=0;i<labels.length;i++)...[
        CupCard(padding:const EdgeInsets.all(16),child:Row(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Container(width:43,height:43,alignment:Alignment.center,
            decoration:BoxDecoration(
              color:i==3?CupUi.yellow.withValues(alpha:.15):CupUi.redMuted,
              borderRadius:BorderRadius.circular(13)),
            child:Icon(i==3?Icons.emoji_events_rounded:Icons.sports_hockey_rounded,
              color:i==3?CupUi.yellow:CupUi.ice)),
          const SizedBox(width:13),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(labels[i],style:TextStyle(color:CupUi.white,
              fontSize:13,fontWeight:FontWeight.w900)),
            const SizedBox(height:6),
            if(i<3)...[
              Builder(builder:(_){
                final stage=stages[i];
                final fixtures=matches.where((m)=>tourOf(m.stage)==stage&&
                  (m.home==name||m.away==name)).toList();
                final done=fixtures.where((m)=>m.finished).length;
                final group=fixtures.where((m)=>!m.isCrossover).map((m)=>m.stage).toSet();
                return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('${group.isEmpty?(stage==CupTour.third&&projectedGroup!=null?'ПРОГНОЗ: ГРУППА $projectedGroup':'Группа не опубликована'):group.join(' / ')}',
                    style:TextStyle(color:CupUi.soft,fontSize:10)),
                  const SizedBox(height:7),
                  Text('$done / ${fixtures.length} опубликованных матчей завершено',
                    style:TextStyle(color:CupUi.muted,fontSize:10)),
                  for(final game in fixtures.take(2))Padding(
                    padding:const EdgeInsets.only(top:8),
                    child:InkWell(onTap:()=>widget.onMatch(game),
                      child:Text('${game.home} — ${game.away}    ${game.hasScore?game.score:'→'}',
                        maxLines:2,style:TextStyle(color:CupUi.ice,fontSize:10)))),
                ]);
              }),
            ]else Text(!completed
              ?'Квалификация ещё идёт. Итоговые участники финалов не определены.'
              :current>=0&&current<8?'Текущая зона Золотого финала':
                'Текущая зона Серебряного финала',
                style:TextStyle(color:CupUi.soft,fontSize:11,height:1.5)),
          ])),
          ])),
        if(i<3)Padding(padding:const EdgeInsets.symmetric(vertical:2),
          child:Icon(Icons.south_rounded,color:CupUi.ice,size:24)),
      ],
      CupCard(padding:const EdgeInsets.all(13),child:Text(
        'Третий тур и финал до официальной публикации показаны как расчётный маршрут. '
        'Несуществующие пары и даты не выдаются за календарь ФХР.',
        style:TextStyle(color:CupUi.muted,fontSize:10,height:1.6))),
    ]);
  }
  Widget _history(RaceEngine r){
    final dates=r.historyDates;
    if(dates.isEmpty)return const CupMessage(
      title:'История пока не доступна',
      message:'Нужны подтверждённые датированные результаты ФХР.');
    final idx=historicalIndex<0?dates.length-1:
      historicalIndex.clamp(0,dates.length-1);
    final date=dates[idx];
    final table=r.standingsAt(date);
    final groups=r.seedingAt(date);
    return Column(children:[
      CupSection(title:'TIME MACHINE',
        subtitle:'Прокрути историю текущего Кубка по сыгранным дням'),
      CupArena(padding:const EdgeInsets.all(19),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Icon(Icons.history_toggle_off_rounded,color:CupUi.ice,size:22),
            const SizedBox(width:10),
            const Expanded(child:Text('МАШИНА ВРЕМЕНИ',
              style:TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w900))),
          ]),
          const SizedBox(height:18),
          Text(date,style:const TextStyle(color:Colors.white,
            fontWeight:FontWeight.w900,fontSize:27)),
          const SizedBox(height:8),
          Text('Игровой день ${idx+1} из ${dates.length}',
            style:TextStyle(color:CupUi.soft,fontSize:11)),
          const SizedBox(height:12),
          if(dates.length>1)Slider(
            value:idx.toDouble(),min:0,max:(dates.length-1).toDouble(),
            divisions:dates.length-1,
            onChanged:(value)=>setState(()=>historicalIndex=value.round())),
          Row(children:[
            TextButton(onPressed:idx==0?null:()=>setState(()=>historicalIndex=idx-1),
              child:const Text('НАЗАД')),
            const Spacer(),
            TextButton(onPressed:idx==dates.length-1?null:
              ()=>setState(()=>historicalIndex=idx+1),
              child:const Text('ВПЕРЁД')),
          ]),
        ])),
      CupSection(title:'ТАБЛИЦА НА $date',
        subtitle:'Только матчи, подтверждённые ФХР к текущему моменту'),
      CupCard(padding:EdgeInsets.zero,child:Column(children:[
        for(var i=0;i<table.length;i++)...[
          if(i==8)Padding(padding:const EdgeInsets.all(8),
            child:Text('ТОП-8',style:TextStyle(color:CupUi.yellow,fontSize:10))),
          Padding(padding:const EdgeInsets.symmetric(horizontal:13,vertical:9),
            child:Row(children:[
              SizedBox(width:25,child:Text('${i+1}',style:TextStyle(
                color:i<8?CupUi.green:CupUi.muted,fontWeight:FontWeight.w900))),
              Expanded(child:Text(table[i].team,maxLines:1,
                overflow:TextOverflow.ellipsis,style:TextStyle(
                  color:CupUi.white,fontSize:11,fontWeight:FontWeight.w800))),
              Text('${table[i].pts} О',style:TextStyle(
                color:CupUi.ice,fontSize:12,fontWeight:FontWeight.w900)),
            ])),
          if(i<table.length-1)CupDiv(indent:20),
        ],
      ])),
      CupSection(title:'РАССЕВ НА ЭТУ ДАТУ',
        subtitle:'Ретроспективная проектная схема, не историческая жеребьёвка'),
      for(var i=0;i<groups.length;i++)CupCard(padding:const EdgeInsets.all(14),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('ГРУППА ${['А','Б','В','Г'][i]}',
            style:TextStyle(color:CupUi.ice,fontSize:12,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          Text(groups[i].join(' • '),style:TextStyle(
            color:CupUi.soft,fontSize:11,height:1.5)),
        ])),
    ]);
  }
  Widget _impact(RaceEngine r){
    final games=r.mostImportant(focus:chosen,limit:15);
    return Column(children:[
      CupSection(title:'MATCH IMPACT',
        subtitle:'Какие матчи могут сильнее всего изменить общую таблицу'),
      CupArena(padding:const EdgeInsets.all(19),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(Icons.hub_rounded,color:CupUi.ice,size:25),
          const SizedBox(height:13),
          const Text('КАЖДАЯ ШАЙБА\nМЕНЯЕТ РАСКЛАД',
            style:TextStyle(color:Colors.white,
              fontSize:25,fontWeight:FontWeight.w900,height:1.05)),
          const SizedBox(height:13),
          Text('Сравниваются гипотетические победы 3:1 и 1:3. '
            'Влияние оценивается по изменению мест и зоны топ-8; '
            'это показатель сценарного разброса, а не вероятность.',
            style:TextStyle(color:CupUi.soft,fontSize:11,height:1.6)),
        ])),
      _teamSelector(),
      if(games.isEmpty)const CupMessage(title:'Влияние пока не рассчитывается',
        message:'В календаре нет незавершённых опубликованных матчей квалификации.'),
      for(final data in games)CupCard(padding:EdgeInsets.zero,child:Column(children:[
        InkWell(onTap:()=>setState(()=>expandedMatch=
          expandedMatch==data.match.key?null:data.match.key),
          child:Padding(padding:const EdgeInsets.all(14),
            child:Row(children:[
              Container(width:39,height:39,alignment:Alignment.center,
                decoration:BoxDecoration(color:CupUi.redMuted,
                  borderRadius:BorderRadius.circular(13)),
                child:Text('${data.weight}',style:TextStyle(
                  color:CupUi.ice,fontWeight:FontWeight.w900,fontSize:13))),
              const SizedBox(width:10),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('${data.match.home} — ${data.match.away}',
                  maxLines:2,overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:CupUi.white,fontWeight:FontWeight.w900,fontSize:11)),
                const SizedBox(height:5),
                Text('${data.cutoffSwitches} смен зоны топ-8 · ${data.movedTeams} изменённых мест',
                  style:TextStyle(color:CupUi.muted,fontSize:9)),
              ])),
              Icon(expandedMatch==data.match.key?Icons.expand_less:
                Icons.expand_more,color:CupUi.soft),
            ]))),
        if(expandedMatch==data.match.key)Padding(
          padding:const EdgeInsets.fromLTRB(14,0,14,14),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Container(height:1,color:CupUi.stroke),
            const SizedBox(height:12),
            _outcomeRow(r,data.match,true),
            const SizedBox(height:8),
            _outcomeRow(r,data.match,false),
            const SizedBox(height:10),
            OutlinedButton.icon(
              onPressed:()=>widget.onMatch(data.match),
              icon:const Icon(Icons.open_in_new_rounded,size:16),
              label:const Text('ОТКРЫТЬ МАТЧ')),
          ])),
      ])),
    ]);
  }
  Widget _outcomeRow(RaceEngine r,Match match,bool home){
    final table=r.hypothetical(match,home?3:1,home?1:3);
    final name=chosen;
    final position=name==null?-1:table.indexWhere((x)=>x.team==name);
    return Row(children:[
      Icon(home?Icons.home_rounded:Icons.flight_takeoff_rounded,
        color:home?CupUi.green:CupUi.yellow,size:16),
      const SizedBox(width:8),
      Expanded(child:Text('Победа ${home?match.home:match.away}',
        maxLines:1,overflow:TextOverflow.ellipsis,
        style:TextStyle(color:CupUi.soft,fontSize:10))),
      Text(position<0?'—':'${position+1}-Е МЕСТО',
        style:TextStyle(color:CupUi.ice,fontSize:10,fontWeight:FontWeight.w900)),
    ]);
  }
  @override Widget build(BuildContext context){
    final r=engine;
    return Scaffold(backgroundColor:CupUi.background,
      appBar:AppBar(title:const Text('COMMAND CENTER'),
        actions:[IconButton(tooltip:'Обновить ФХР',
          onPressed:fetching?null:refresh,
          icon:fetching?const SizedBox(width:18,height:18,
            child:CircularProgressIndicator(strokeWidth:2)):
            const Icon(Icons.refresh_rounded))]),
      body:Column(children:[
        CupArena(margin:const EdgeInsets.fromLTRB(12,10,12,7),
          padding:const EdgeInsets.fromLTRB(16,14,16,15),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              const Text('АНАЛИТИЧЕСКИЙ ПУЛЬТ',style:TextStyle(color:Color(0xFFB8D6DC),
                fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1)),
              const Spacer(),
              Text('${(screen+1).toString().padLeft(2,'0')} / 07',
                style:const TextStyle(color:CupUi.signal,fontFamily:'ArenaCondensed',
                  fontSize:10,fontWeight:FontWeight.w900)),
            ]),
            const SizedBox(height:9),
            Row(children:[
              Icon(tabIcons[screen],color:CupUi.signal,size:24),
              const SizedBox(width:9),
              Expanded(child:Text(screen==6?'GOLD ODDS PRO':tabs[screen],
                style:const TextStyle(color:Colors.white,fontFamily:'ArenaCondensed',
                  fontSize:25,fontWeight:FontWeight.w700,letterSpacing:.3))),
            ]),
          ])),
        SizedBox(height:58,child:ListView(scrollDirection:Axis.horizontal,
          padding:const EdgeInsets.symmetric(horizontal:12),children:[
          for(var i=0;i<tabs.length;i++)Padding(
            padding:const EdgeInsets.only(right:7),child:Semantics(
              button:true,selected:screen==i,label:tabs[i],
              child:InkWell(key:ValueKey('command-tab-$i'),
                onTap:()=>select(i),borderRadius:BorderRadius.circular(6),
                child:AnimatedContainer(duration:const Duration(milliseconds:180),
                  width:i==6?146:119,padding:const EdgeInsets.symmetric(horizontal:10),
                  decoration:BoxDecoration(
                    color:screen==i?CupUi.featureAccents[i].withValues(alpha:.18):CupUi.surface,
                    border:Border.all(color:screen==i?CupUi.featureAccents[i]:CupUi.stroke,
                      width:screen==i?1.5:1),
                    borderRadius:BorderRadius.circular(6)),
                  child:Row(children:[
                    Icon(tabIcons[i],size:18,color:CupUi.featureAccents[i]),
                    const SizedBox(width:7),
                    Expanded(child:Text(i==6?'GOLD ODDS PRO':tabs[i],maxLines:2,
                      style:TextStyle(color:screen==i?CupUi.white:CupUi.soft,
                        fontSize:9,fontWeight:FontWeight.w900))),
                  ]))),
            )),
        ])),
        if(syncError!=null)Padding(padding:const EdgeInsets.fromLTRB(13,4,13,9),
          child:Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:9),
            decoration:BoxDecoration(color:CupUi.yellow.withValues(alpha:.10),
              borderRadius:BorderRadius.circular(12)),
            child:Row(children:[
              Icon(Icons.wifi_off_rounded,color:CupUi.yellow,size:17),
              const SizedBox(width:9),
              Expanded(child:Text(syncError!,style:TextStyle(color:CupUi.yellow,fontSize:10))),
              TextButton(onPressed:fetching?null:refresh,
                child:const Text('ПОВТОРИТЬ',style:TextStyle(fontSize:9))),
            ]))),
        Expanded(child:screen==5
          ?PersonalHqPanel(matches:games,clubs:widget.clubs,
            onTeam:widget.onTeam,onMatch:widget.onMatch)
          :RefreshIndicator(onRefresh:refresh,child:ListView(
            key:ValueKey('command-section-$screen'),
            children:[
              if(screen==6)_goldOdds(),
              if(screen==0)_hero(r),
              if(screen==0)_race(r),
              if(screen==1)_simulations(r),
              if(screen==2)_road(r),
              if(screen==3)_history(r),
              if(screen==4)_impact(r),
              const SizedBox(height:28),
            ]))),
      ]),
    );
  }

  Widget _goldOdds(){
    final now=DateTime.now().toUtc();
    final fixtures=games.where((m)=>m.isQualifier&&!m.isLive&&
      !m.isResultAt(now)).toList()
      ..sort((a,b)=>'${a.date} ${a.timeMsk}'.compareTo('${b.date} ${b.timeMsk}'));
    return Column(children:[
      CupSection(title:'GOLD ODDS PRO',
        subtitle:'Вероятность исхода по подтверждённым матчам ФХР'),
      CupArena(padding:const EdgeInsets.all(20),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Container(width:44,height:44,decoration:BoxDecoration(
              color:CupUi.yellow.withValues(alpha:.14),
              borderRadius:BorderRadius.circular(15)),
              child:Icon(Icons.auto_awesome_rounded,color:CupUi.yellow)),
            const SizedBox(width:12),
            const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
              children:[Text('GOLD ODDS PRO',style:TextStyle(color:Colors.white,
                fontSize:15,fontWeight:FontWeight.w900)),
                SizedBox(height:4),Text('Модель исходов и ожидаемых голов',
                  style:TextStyle(color:Color(0xFFD1DFF6),fontSize:10))])),
          ]),
          const SizedBox(height:16),
          Text('Модель использует только подтверждённые результаты квалификации. '
            'Маленькая выборка сглаживается к среднему турнира; при равном счёте '
            'в основное время вероятность делится по разнице ожидаемых голов.',
            style:TextStyle(color:CupUi.soft,fontSize:10,height:1.55)),
        ])),
      if(report==null)CupCard(padding:const EdgeInsets.all(14),child:Row(children:[
        Expanded(child:Text('Посчитай положение команд и шансы на топ-8 во всех оставшихся сценариях.',
          style:TextStyle(color:CupUi.soft,fontSize:10,height:1.4))),
        const SizedBox(width:8),FilledButton(
          onPressed:simulating?null:simulate,
          child:Text(simulating?'СЧИТАЮ':'РАССЧИТАТЬ',style:const TextStyle(fontSize:9))),
      ])),
      if(report!=null)...[
        CupSection(title:'ШАНСЫ НА ИТОГОВЫЙ ТОП-8',
          subtitle:'Монте-Карло · ${report!.iterations} сценариев${_simulationStale?' · данные обновились':''}'),
        CupCard(padding:const EdgeInsets.all(13),child:Column(children:[
            for(final row in (teamNames.toList()
            ..sort((a,b)=>(report!.topEight[b]??0).compareTo(report!.topEight[a]??0))))
            Builder(builder:(context){
              final top=report!.topEight[row]??0;
              final places=report!.placeDistribution[row]??const <int,double>{};
              final champ=places[1]??0;
              final avg=report!.averagePlace[row]??0;
              return Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[
                Expanded(flex:5,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(row,maxLines:1,overflow:TextOverflow.ellipsis,
                    style:TextStyle(color:CupUi.white,fontSize:10,fontWeight:FontWeight.w800)),
                  const SizedBox(height:5),ClipRRect(borderRadius:BorderRadius.circular(5),
                    child:LinearProgressIndicator(value:top,minHeight:5,
                      backgroundColor:CupUi.raised,
                      valueColor:AlwaysStoppedAnimation<Color>(top>=.5?CupUi.green:CupUi.ice))),
                ])),
                const SizedBox(width:10),
                Expanded(flex:2,child:Text('${(top*100).toStringAsFixed(0)}% ТОП-8',
                  textAlign:TextAlign.right,style:TextStyle(color:CupUi.ice,fontSize:9,fontWeight:FontWeight.w900))),
                const SizedBox(width:8),
                Expanded(flex:2,child:Text('${(champ*100).toStringAsFixed(0)}% · ${(avg).toStringAsFixed(1)} м.',
                  textAlign:TextAlign.right,style:TextStyle(color:CupUi.gold,fontSize:8,fontWeight:FontWeight.w800))),
              ]));
            }),
        ])),
        if(chosen!=null)CupCard(padding:const EdgeInsets.all(13),child:Row(children:[
          Icon(Icons.route_rounded,color:CupUi.violet,size:18),
          const SizedBox(width:8),Expanded(child:Text('III тур: ${chosen!} чаще попадает в группу ${report!.thirdGroups[chosen!] == null?'—':((report!.thirdGroups[chosen!]!.entries.toList()..sort((a,b)=>b.value.compareTo(a.value))).first.key)}',
            style:TextStyle(color:CupUi.soft,fontSize:10))),
        ])),
      ],
      if(fixtures.isEmpty)const CupMessage(title:'Нет предстоящих матчей',
        message:'Когда ФХР опубликует новые игры, здесь появятся расчёты вероятностей.'),
      for(final match in fixtures.take(40))_oddsCard(match),
      CupCard(padding:const EdgeInsets.all(14),child:Row(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(Icons.info_outline_rounded,color:CupUi.yellow,size:18),
          const SizedBox(width:9),
          Expanded(child:Text('Это статистическая оценка, а не официальный прогноз ФХР. '
            'Доля матчей для каждой команды и число учтённых игр показаны отдельно.',
            style:TextStyle(color:CupUi.muted,fontSize:9,height:1.5))),
        ])),
    ]);
  }

  Widget _oddsCard(Match match){
    final odds=GoldOdds.forMatch(games,match);
    final home=(odds.homeWin*100).round(),away=100-home;
    return CupCard(padding:const EdgeInsets.all(15),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Expanded(child:Text('${match.home}  —  ${match.away}',
            maxLines:2,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:CupUi.white,fontSize:11,fontWeight:FontWeight.w900))),
          const SizedBox(width:8),
          Text('${match.dayLabel} · ${match.timeMsk}',
            style:TextStyle(color:CupUi.muted,fontSize:9)),
        ]),
        const SizedBox(height:13),
        Row(children:[
          Text('$home%',style:TextStyle(color:CupUi.ice,fontSize:22,fontWeight:FontWeight.w900)),
          const SizedBox(width:6),
          Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(8),
            child:SizedBox(height:9,child:Row(children:[
              Expanded(flex:home,child:Container(color:CupUi.ice)),
              Expanded(flex:away,child:Container(color:CupUi.yellow)),
            ])))),
          const SizedBox(width:6),
          Text('$away%',style:TextStyle(color:CupUi.yellow,fontSize:22,fontWeight:FontWeight.w900)),
        ]),
        const SizedBox(height:6),
        Row(children:[
          Expanded(child:Text(match.home,maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:CupUi.soft,fontSize:9))),
          Text('ПОБЕДА',style:TextStyle(color:CupUi.muted,fontSize:8,
            fontWeight:FontWeight.w900,letterSpacing:.7)),
          Expanded(child:Text(match.away,textAlign:TextAlign.right,maxLines:1,
            overflow:TextOverflow.ellipsis,style:TextStyle(color:CupUi.soft,fontSize:9))),
        ]),
        const SizedBox(height:12),
        Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:9),
          decoration:BoxDecoration(color:CupUi.raised,borderRadius:BorderRadius.circular(13)),
          child:Row(children:[
            Expanded(child:_oddsMetric('ОЖИД. ГОЛЫ','${odds.homeGoals.toStringAsFixed(1)} : ${odds.awayGoals.toStringAsFixed(1)}')),
            Expanded(child:_oddsMetric('ВЫБОРКА','${odds.homeGames} / ${odds.awayGames} игр')),
            Expanded(child:_oddsMetric('СЧЁТ · ОСН. ВРЕМЯ',odds.mostLikelyScore)),
          ])),
        Align(alignment:Alignment.centerRight,child:TextButton.icon(
          onPressed:()=>widget.onMatch(match),
          icon:const Icon(Icons.insights_rounded,size:15),
          label:const Text('MATCH CENTER ULTRA',style:TextStyle(fontSize:9)),
        )),
      ]));
  }
  Widget _oddsMetric(String label,String value)=>Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:TextStyle(color:CupUi.dim,fontSize:7,fontWeight:FontWeight.w900)),
      const SizedBox(height:4),Text(value,maxLines:1,overflow:TextOverflow.ellipsis,
        style:TextStyle(color:CupUi.white,fontSize:9,fontWeight:FontWeight.w800)),
    ]);
}
