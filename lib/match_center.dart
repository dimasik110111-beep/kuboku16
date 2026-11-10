import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'cup_data.dart';
import 'match_lineups.dart';
import 'team_pages.dart';
import 'ui_kit.dart';
import 'app_services.dart';
import 'gold_odds.dart';

class MatchCenterPage extends StatefulWidget {
  final Match match;
  final TeamInfo? homeTeam;
  final TeamInfo? awayTeam;
  final List<Match> matches;
  const MatchCenterPage({super.key,required this.match,this.homeTeam,this.awayTeam,
    this.matches=const []});
  @override
  State<MatchCenterPage> createState()=>_MatchCenterPageState();
}

class _MatchCenterPageState extends State<MatchCenterPage> with WidgetsBindingObserver {
  late final FhrApiClient api=FhrApiClient(http.Client());
  Timer? timer;
  late Match match;
  Map<String,dynamic>? data;
  String? error;
  bool loading=false;
  int tab=0;
  TeamInfo? homeTeam,awayTeam;
  int eventFilter=0;int storyPeriod=0;
  @override void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    match=widget.match;
    homeTeam=widget.homeTeam;
    awayTeam=widget.awayTeam;
    refresh();
    startPolling();
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    timer?.cancel();
    if(state==AppLifecycleState.resumed){refresh();startPolling();}
  }
  void startPolling(){timer?.cancel();timer=Timer.periodic(const Duration(seconds:20),(_){if(!match.finished&&(ModalRoute.of(context)?.isCurrent??true))refresh();});}
  @override void dispose(){
    timer?.cancel();WidgetsBinding.instance.removeObserver(this);api.client.close();super.dispose();
  }

  Future<void> refresh() async {
    if(loading||match.gameId==null)return;
    setState(()=>loading=true);
    try{
      final raw=await api.detail(match.gameId!);
      if(!mounted)return;
      if(raw['ok']!=true)throw Exception('ФХР не прислал протокол');
      setState((){data=raw;match=widget.match.withDetail(raw);error=null;});
    }catch(e){
      Diagnostics.record('match',e);
      if(mounted)setState(()=>error='Не удалось обновить протокол. Проверь интернет.');
    }finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> openOfficial() async {
    final link='https://junior.fhr.ru/games/${match.gameId}/';
    await launchUrl(Uri.parse(link),mode:LaunchMode.externalApplication);
  }

  List<Map<String,dynamic>> get events {
    final raw=data?['timeline'];
    if(raw is! List)return [];
    return raw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
  }
  String str(Map<String,dynamic> map,String key)=>map[key]?.toString()??'';
  String? periodLabel(int? period) {
    switch(period){
      case 1:return '1-Й ПЕРИОД';
      case 2:return '2-Й ПЕРИОД';
      case 3:return '3-Й ПЕРИОД';
      case 4:return 'ОВЕРТАЙМ';
    }
    return null;
  }

  Widget _hero() {
    final lineups=GameLineups.fromDetail(data);
    final raw=data?['statusText']?.toString();
    final status=raw!=null&&raw.isNotEmpty?raw:
      match.isLive?'ПРЯМО СЕЙЧАС':match.finished?'МАТЧ ЗАВЕРШЁН':'СКОРО';
    return CupArena(margin:const EdgeInsets.fromLTRB(12,12,12,9),
      padding:const EdgeInsets.fromLTRB(15,17,15,20),child:Column(children:[
      Row(children:[
        const Icon(Icons.sports_hockey_rounded,color:CupUi.signal,size:17),
        const SizedBox(width:7),
        Expanded(child:Text(match.stage.toUpperCase(),maxLines:1,
          overflow:TextOverflow.ellipsis,style:const TextStyle(
            color:Color(0xFFB8D6DC),fontSize:10,fontWeight:FontWeight.w800))),
        Container(width:8,height:8,decoration:BoxDecoration(
          color:match.isLive?CupUi.signal:Colors.white54,shape:BoxShape.circle)),
      ]),
      const SizedBox(height:21),
      Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
        Expanded(child:_heroTeam(match.home,
          homeTeam?.logo??lineups.side('home')?.logo)),
        SizedBox(width:122,child:Column(children:[
          Text('${match.dayLabel}  ·  ${match.timeMsk} МСК',
            style:const TextStyle(color:Color(0xFFB8D6DC),fontSize:9,
              fontWeight:FontWeight.w700)),
          const SizedBox(height:8),
          Text(match.hasScore?match.score.replaceAll(':',' : '):'– : –',
            key:ValueKey(match.score),style:const TextStyle(color:Colors.white,
              fontFamily:'ArenaCondensed',fontSize:41,fontWeight:FontWeight.w700,height:1)),
          const SizedBox(height:7),
          Text(status,textAlign:TextAlign.center,style:const TextStyle(
            color:CupUi.signal,fontSize:9,fontWeight:FontWeight.w900,
            letterSpacing:.5)),
          if(match.scoreNote.isNotEmpty)Text(match.scoreNote,
            style:const TextStyle(color:Colors.white70,fontSize:10)),
        ])),
        Expanded(child:_heroTeam(match.away,
          awayTeam?.logo??lineups.side('away')?.logo)),
      ]),
    ]));
  }
  Widget _heroTeam(String name,String? logo)=>Column(children:[
    Container(width:56,height:56,alignment:Alignment.center,
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(13)),
      child:fhrTeamLogo(logo,size:44)),
    const SizedBox(height:9),
    Text(name,maxLines:2,overflow:TextOverflow.ellipsis,
      textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,
        fontWeight:FontWeight.w800,height:1.15,fontSize:11)),
  ]);

  Widget _periodRow(){
    final scores=data?['periodScores'];
    final list=scores is List?scores:[];
    if(list.isEmpty)return SizedBox.shrink();
    return CupCard(
      margin:EdgeInsets.fromLTRB(12,0,12,4),
      child:Padding(padding:EdgeInsets.symmetric(vertical:14,horizontal:10),
        child:Row(children:[
          SizedBox(width:58,child:Text('ПЕРИОДЫ',style:TextStyle(color:CupUi.dim,fontSize:9,fontWeight:FontWeight.w800))),
          for(var i=0;i<list.length;i++)Expanded(child:Column(children:[
            Text(i==3?'ОТ':'${i+1}-Й',style:TextStyle(color:CupUi.muted,fontSize:10,fontWeight:FontWeight.w700)),
            SizedBox(height:6),
            Text('${list[i] is Map?list[i]['home']:'–'}:${list[i] is Map?list[i]['away']:'–'}',
              style:TextStyle(color:CupUi.white,fontSize:14,fontWeight:FontWeight.w800)),
          ])),
        ])),
    );
  }

  Widget _tabs()=>Container(color:CupUi.surface,
    height:51,child:Row(children:[
      for(var i=0;i<4;i++)Expanded(child:InkWell(
        onTap:()=>setState(()=>tab=i),child:Container(
          alignment:Alignment.center,
          decoration:BoxDecoration(border:Border(bottom:BorderSide(
            color:tab==i?CupUi.red:Colors.transparent,width:3))),
          child:Text(const ['ОБЗОР','СОБЫТИЯ','СОСТАВЫ','СТАТИСТИКА'][i],
            textAlign:TextAlign.center,maxLines:1,
            style:TextStyle(fontSize:9,fontWeight:FontWeight.w900,
              color:tab==i?CupUi.red:CupUi.muted))))),
    ]));

  Widget _matchStory(){
    final all=events.where((e)=>str(e,'type')=='GOAL').toList();
    final series=<List<int>>[[0,0]];
    for(final event in all){
      final raw=str(event,'score');
      if(!RegExp(r'^[0-9]+:[0-9]+$').hasMatch(raw))continue;
      series.add(raw.split(':').map(int.parse).toList());
    }
    final selected=all.where((e)=>storyPeriod==0||
      e['period']?.toString()=='$storyPeriod').toList();
    return Column(children:[
      CupSection(title:'MATCH STORY',
        subtitle:'Счёт и хронология из официальных событий ФХР'),
      CupCard(padding:const EdgeInsets.all(16),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Icon(Icons.auto_stories_rounded,color:CupUi.ice,size:21),
          const SizedBox(width:10),
          const Expanded(child:Text('ИСТОРИЯ МАТЧА',
            style:TextStyle(fontWeight:FontWeight.w900,fontSize:12))),
          CupTag(text:'${all.length} ГОЛОВ',color:CupUi.green,filled:true),
        ]),
        const SizedBox(height:12),
        if(series.length>1)...[
          SizedBox(height:93,width:double.infinity,
            child:CustomPaint(painter:_ScoreJourneyPainter(series))),
          const SizedBox(height:7),
          Text('Разница шайб по опубликованным голам. '
            'При неполном протоколе линия может быть неполной.',
            style:TextStyle(color:CupUi.muted,fontSize:10,height:1.4)),
          const SizedBox(height:12),
        ],
        SingleChildScrollView(scrollDirection:Axis.horizontal,
          child:Row(children:[
            for(var p=0;p<5;p++)Padding(padding:const EdgeInsets.only(right:6),
              child:ChoiceChip(
                label:Text(p==0?'ВСЁ':p==4?'ОТ':'$p ПЕРИОД',
                  style:const TextStyle(fontSize:9)),
                selected:storyPeriod==p,
                onSelected:(_)=>setState(()=>storyPeriod=p))),
          ])),
        const SizedBox(height:11),
        if(selected.isEmpty)Text('Голы на этом отрезке не опубликованы.',
          style:TextStyle(color:CupUi.muted,fontSize:11)),
        for(final goal in selected)InkWell(
          onTap:()=>setState((){tab=1;eventFilter=1;}),
          child:Padding(padding:const EdgeInsets.symmetric(vertical:10),
            child:Row(children:[
              Icon(Icons.sports_hockey_rounded,color:CupUi.green,size:20),
              const SizedBox(width:10),
              SizedBox(width:48,child:Text(str(goal,'elapsed'),
                style:TextStyle(color:CupUi.ice,fontSize:10))),
              Expanded(child:Text(str(goal,'player').isEmpty?
                'Гол · ${str(goal,'team')}':str(goal,'player'),
                maxLines:2,style:TextStyle(
                  color:CupUi.white,fontSize:11,fontWeight:FontWeight.w800))),
              Text(str(goal,'score'),style:TextStyle(
                color:CupUi.ice,fontSize:13,fontWeight:FontWeight.w900)),
              Icon(Icons.chevron_right_rounded,color:CupUi.muted,size:16),
            ]))),
      ])),
    ]);
  }

  Widget _matchPulse(){
    final goals=events.where((e)=>str(e,'type')=='GOAL').toList();
    final penalties=events.where((e)=>str(e,'type')=='PENALTY').toList();
    final hasVerified=data!=null;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      CupSection(title:'ПУЛЬС МАТЧА',
        subtitle:'Только события, подтверждённые протоколом ФХР'),
      CupCard(padding:const EdgeInsets.all(17),
        child:Column(children:[
          Row(children:[
            Expanded(child:_pulseMetric('${goals.length}','ГОЛЫ В ПРОТОКОЛЕ',
              Icons.sports_hockey_rounded,CupUi.green)),
            Container(height:40,width:1,color:CupUi.stroke),
            Expanded(child:_pulseMetric('${penalties.length}','УДАЛЕНИЯ',
              Icons.timer_outlined,CupUi.yellow)),
          ]),
          const SizedBox(height:17),
          Container(height:1,color:CupUi.stroke),
          const SizedBox(height:15),
          if(goals.isNotEmpty)SingleChildScrollView(
            scrollDirection:Axis.horizontal,
            child:Row(children:[
              for(final e in goals)Padding(padding:const EdgeInsets.only(right:9),
                child:Container(padding:const EdgeInsets.symmetric(
                  horizontal:12,vertical:10),
                  decoration:BoxDecoration(color:CupUi.green.withValues(alpha:.10),
                    borderRadius:BorderRadius.circular(13),
                    border:Border.all(color:CupUi.green.withValues(alpha:.24))),
                  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(str(e,'elapsed').isEmpty?'ГОЛ':str(e,'elapsed'),
                      style:TextStyle(color:CupUi.green,fontWeight:FontWeight.w900,
                        fontSize:12)),
                    const SizedBox(height:4),
                    SizedBox(width:105,child:Text(str(e,'player').isEmpty
                      ?str(e,'team'):str(e,'player'),
                      maxLines:1,overflow:TextOverflow.ellipsis,
                      style:TextStyle(color:CupUi.white,fontSize:10,
                        fontWeight:FontWeight.w800))),
                    if(str(e,'score').isNotEmpty)Text(str(e,'score'),
                      style:TextStyle(color:CupUi.soft,fontSize:10)),
                  ]))),
            ]))
          else Text(hasVerified
            ?'События голов пока не опубликованы в протоколе.'
            :'Загружаем события матча с ФХР…',
            style:TextStyle(color:CupUi.muted,fontSize:11)),
          const SizedBox(height:12),
          SizedBox(width:double.infinity,child:OutlinedButton.icon(
            onPressed:()=>setState(()=>tab=1),
            icon:const Icon(Icons.list_alt_rounded,size:16),
            label:const Text('ОТКРЫТЬ ВСЮ ХРОНОЛОГИЮ'))),
        ])),
      if(homeTeam!=null||awayTeam!=null)CupCard(
        padding:const EdgeInsets.all(13),
        child:Column(children:[
          Text('ЗАЯВКИ И СОСТАВЫ',style:TextStyle(color:CupUi.soft,
            fontWeight:FontWeight.w900,fontSize:10)),
          const SizedBox(height:9),
          Row(children:[
            if(homeTeam!=null)Expanded(child:OutlinedButton(
              onPressed:()=>Navigator.push(context,MaterialPageRoute(
                builder:(_)=>TeamRosterPage(team:homeTeam!))),
              child:Text(match.home,maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontSize:9)))),
            const SizedBox(width:8),
            if(awayTeam!=null)Expanded(child:OutlinedButton(
              onPressed:()=>Navigator.push(context,MaterialPageRoute(
                builder:(_)=>TeamRosterPage(team:awayTeam!))),
              child:Text(match.away,maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontSize:9)))),
          ]),
        ])),
    ]);
  }
  Widget _pulseMetric(String value,String name,IconData icon,Color color)=>
    Column(children:[
      Icon(icon,size:20,color:color),
      const SizedBox(height:7),
      Text(value,style:TextStyle(color:CupUi.white,fontSize:28,
        fontWeight:FontWeight.w900)),
      const SizedBox(height:6),
      Text(name,textAlign:TextAlign.center,
        style:TextStyle(color:CupUi.muted,fontSize:9,fontWeight:FontWeight.w900)),
    ]);

  Widget _goalEntry(Map<String,dynamic> e,{bool compact=false}){
    final type=str(e,'type');
    final isGoal=type=='GOAL';
    final isPenalty=type=='PENALTY';
    final isKeeper=type=='GOALKEEPER';
    final accent=isGoal?CupUi.green:isPenalty?CupUi.yellow:
      isKeeper?const Color(0xFF72A8E7):CupUi.muted;
    final title=isGoal?'Гол':isPenalty?'Удаление':
      type=='TIMEOUT'?'Тайм-аут':isKeeper?'Вратарь':'Событие';
    final name=str(e,'player');
    final time=str(e,'elapsed');
    final reason=str(e,'description');
    final score=str(e,'score');
    final penaltyMinutes=str(e,'penaltyMinutes');
    final photo=e['playerPhoto']?.toString();
    return Container(margin:EdgeInsets.fromLTRB(12,0,12,8),
      padding:EdgeInsets.symmetric(horizontal:12,vertical:15),
      decoration:BoxDecoration(color:CupUi.surface,borderRadius:BorderRadius.circular(19),
        border:Border.all(color:accent.withValues(alpha:.30),width:.8)),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        SizedBox(width:43,child:Column(children:[
          Text(time.isEmpty?'–':time,style:TextStyle(color:CupUi.white,fontWeight:FontWeight.w800,fontSize:11)),
          SizedBox(height:8),
          Container(width:29,height:29,decoration:BoxDecoration(color:accent.withValues(alpha:.12),
            shape:BoxShape.circle),
            child:Icon(isGoal?Icons.sports_hockey:isPenalty?Icons.timer_outlined:
              isKeeper?Icons.shield_outlined:Icons.flag_outlined,size:16,color:accent)),
        ])),
        SizedBox(width:9),
        if(photo!=null&&photo.startsWith('https://img.fhr.ru/players/'))...[
          fhrPlayerPhoto(photo,size:39),SizedBox(width:9),
        ],
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Text(title.toUpperCase(),style:TextStyle(color:accent,fontSize:10,
              fontWeight:FontWeight.w800,letterSpacing:.4)),
            if(isPenalty&&penaltyMinutes.isNotEmpty)...[
              SizedBox(width:6),
              CupTag(text:penaltyMinutes,color:CupUi.yellow,filled:true),
            ],
            if(score.isNotEmpty)...[Spacer(),
              Text(score,style:TextStyle(color:CupUi.white,fontSize:13,fontWeight:FontWeight.w800))],
          ]),
          SizedBox(height:5),
          if(name.isNotEmpty)Text(name,style:TextStyle(color:CupUi.white,fontSize:13,fontWeight:FontWeight.w700)),
          if(reason.isNotEmpty)Padding(padding:EdgeInsets.only(top:4),
            child:Text(isGoal?'Передачи: $reason':reason,
              maxLines:compact?2:4,overflow:TextOverflow.ellipsis,
              style:TextStyle(color:CupUi.muted,fontSize:11,height:1.35))),
          if(str(e,'team').isNotEmpty)Padding(padding:EdgeInsets.only(top:5),
            child:Text(str(e,'team'),maxLines:1,overflow:TextOverflow.ellipsis,
              style:TextStyle(color:CupUi.dim,fontSize:10))),
        ])),
      ]));
  }

  Widget _introInfo()=>CupCard(
    child:Column(children:[
      _infoRow(Icons.stadium_outlined,'Арена',match.arena.isEmpty?'Не указана':match.arena),
      CupDiv(indent:16),
      _infoRow(Icons.calendar_today_outlined,'Дата',match.dayLabel),
      CupDiv(indent:16),
      _infoRow(Icons.update_rounded,'Обновление','Автоматически каждые 20 секунд'),
    ]));
  Widget _infoRow(IconData icon,String key,String value)=>Padding(
    padding:EdgeInsets.symmetric(horizontal:14,vertical:13),
    child:Row(children:[
      Icon(icon,size:16,color:CupUi.muted),SizedBox(width:10),
      SizedBox(width:88,child:Text(key,style:TextStyle(color:CupUi.muted,fontSize:11))),
      Expanded(child:Text(value,textAlign:TextAlign.right,
        style:TextStyle(color:CupUi.white,fontSize:11,fontWeight:FontWeight.w600))),
    ]));

  Widget _overview(){
    final goals=events.where((e)=>str(e,'type')=='GOAL').toList();
    final penalties=events.where((e)=>str(e,'type')=='PENALTY').toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      if(!match.finished&&!match.isLive&&match.isQualifier&&widget.matches.isNotEmpty)
        _preGameModel(),
      _periodRow(),
      _matchStory(),
      _matchPulse(),
      if(GameLineups.fromDetail(data).allPlayers.any((p)=>p.position=='GOALIE'))
        _keeperOverview(GameLineups.fromDetail(data)),
      CupSection(title:'ГОЛЫ И ПЕРЕДАЧИ',subtitle:'По официальному протоколу ФХР'),
      if(goals.isEmpty)CupMessage(title:'Шайбы пока не опубликованы',
        message:'Список голов появится после публикации событий ФХР.',icon:Icons.sports_hockey),
      for(final goal in goals)_goalEntry(goal),
      if(penalties.isNotEmpty)...[
        CupSection(title:'УДАЛЕНИЯ',subtitle:'${penalties.length} записей'),
        for(final penalty in penalties.take(3))_goalEntry(penalty,compact:true),
        if(penalties.length>3)Padding(padding:EdgeInsets.symmetric(horizontal:12),
          child:TextButton(onPressed:()=>setState(()=>tab=1),child:Text('ВСЕ СОБЫТИЯ МАТЧА'))),
      ],
      if(data!=null)...[
        CupSection(title:'ЗАЯВКИ КОМАНД'),
        CupCard(padding:EdgeInsets.all(14),
          child:InkWell(onTap:()=>setState(()=>tab=2),
            child:Row(children:[
              Icon(Icons.groups_2_outlined,color:CupUi.red,size:22),
              SizedBox(width:11),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(GameLineups.fromDetail(data).available
                  ?'Подтверждённые заявки ФХР':'Заявки ФХР пока не подтверждены',
                  style:TextStyle(color:CupUi.white,fontWeight:FontWeight.w800,fontSize:12)),
                SizedBox(height:4),
                Text('Игроки, тренеры, капитаны и статистика',
                  style:TextStyle(color:CupUi.muted,fontSize:11)),
              ])),
              Icon(Icons.chevron_right_rounded,color:CupUi.soft),
            ]))),
      ],
      CupSection(title:'ИНФОРМАЦИЯ О МАТЧЕ'),
      _introInfo(),SizedBox(height:26),
    ]);
  }

  Widget _preGameModel(){
    final model=GoldOdds.forMatch(widget.matches,match);
    final home=(model.homeWin*100).round(),away=100-home;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      CupSection(title:'GOLD ODDS PRO',
        subtitle:'Оценка перед матчем на данных завершённых игр ФХР'),
      CupCard(padding:const EdgeInsets.all(16),child:Column(children:[
        Row(children:[
          Expanded(child:_modelSide(match.home,home,CupUi.ice,homeTeam?.logo)),
          Padding(padding:const EdgeInsets.symmetric(horizontal:8),
            child:Text('VS',style:TextStyle(color:CupUi.dim,fontSize:9,
              fontWeight:FontWeight.w900,letterSpacing:1))),
          Expanded(child:_modelSide(match.away,away,CupUi.yellow,awayTeam?.logo)),
        ]),
        const SizedBox(height:14),
        ClipRRect(borderRadius:BorderRadius.circular(7),child:Row(children:[
          Expanded(flex:home,child:Container(height:7,color:CupUi.ice)),
          Expanded(flex:away,child:Container(height:7,color:CupUi.yellow)),
        ])),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child:_modelFoot('ОЖИДАЕМЫЕ ГОЛЫ',
            '${model.homeGoals.toStringAsFixed(1)} : ${model.awayGoals.toStringAsFixed(1)}')),
          Expanded(child:_modelFoot('СЧЁТ · ОСН. ВРЕМЯ',model.mostLikelyScore)),
          Expanded(child:_modelFoot('МАТЧЕЙ В БАЗЕ','${model.totalGames}')),
        ]),
        const SizedBox(height:12),
        Align(alignment:Alignment.centerLeft,child:Text(
          'Оценка основана на голах за и против с поправкой на малую выборку. '
          'Это модель приложения, не официальный прогноз ФХР.',
          style:TextStyle(color:CupUi.muted,fontSize:9,height:1.45))),
      ])),
    ]);
  }
  Widget _modelSide(String team,int chance,Color color,String? logo)=>Column(
    children:[
      fhrTeamLogo(logo,size:40),
      const SizedBox(height:7),
      Text('$chance%',style:TextStyle(color:color,fontSize:22,fontWeight:FontWeight.w900)),
      Text(team,maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,
        style:TextStyle(color:CupUi.soft,fontSize:9,fontWeight:FontWeight.w700)),
    ]);
  Widget _modelFoot(String label,String value)=>Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:TextStyle(color:CupUi.dim,fontSize:7,fontWeight:FontWeight.w900)),
      const SizedBox(height:4),Text(value,style:TextStyle(color:CupUi.white,
        fontSize:10,fontWeight:FontWeight.w900)),
    ]);

  Widget _eventList(){
    if(data==null)return CupMessage(
      title:'Загружаю протокол',message:'Запрашиваю события матча ФХР.');
    final lineups=GameLineups.fromDetail(data);
    if(events.isEmpty&&lineups.allPlayers.isEmpty)return CupMessage(
      title:'События не опубликованы',
      message:'На странице ФХР пока нет подтверждённого протокола. Проверь позже.');
    final filterTypes=<String>['','GOAL','PENALTY','GOALKEEPER'];
    final visible=events.where((e)=>eventFilter==0||str(e,'type')==filterTypes[eventFilter]).toList();
    final out=<Widget>[];
    int? prevPeriod;
    for(final e in visible){
      final p=e['period'] is num?(e['period'] as num).toInt():null;
      if(p!=prevPeriod){
        final label=periodLabel(p);
        if(label!=null)out.add(CupSection(title:label,
          subtitle:'Время матча — по официальному протоколу ФХР'));
        prevPeriod=p;
      }
      out.add(_goalEntry(e));
    }
    return Column(children:[
      CupSection(title:'ХРОНОЛОГИЯ МАТЧА',
        subtitle:'Голы, передачи, штрафы, вратари и тайм-ауты'),
      SingleChildScrollView(scrollDirection:Axis.horizontal,
        padding:EdgeInsets.fromLTRB(12,1,12,14),
        child:Row(children:[
          for(var i=0;i<4;i++)Padding(
            padding:EdgeInsets.only(right:7),
            child:InkWell(
              onTap:()=>setState(()=>eventFilter=i),
              borderRadius:BorderRadius.circular(9),
              child:Container(padding:EdgeInsets.symmetric(horizontal:13,vertical:10),
                decoration:BoxDecoration(
                  color:i==eventFilter?CupUi.red:CupUi.surface,
                  borderRadius:BorderRadius.circular(9),
                  border:Border.all(color:i==eventFilter?CupUi.red:CupUi.stroke)),
                child:Text(const ['ВСЕ','ГОЛЫ','УДАЛЕНИЯ','ВРАТАРИ'][i],
                  style:TextStyle(color:i==eventFilter?CupUi.white:CupUi.muted,
                    fontSize:10,fontWeight:FontWeight.w800))),
            )),
        ])),
      if(visible.isEmpty)CupMessage(title:'Нет событий в категории',
        message:'Попробуй другой фильтр хронологии.'),
      if(eventFilter==3)_keeperOverview(lineups),
      ...out,
      SizedBox(height:20),
    ]);
  }

  Widget _keeperOverview(GameLineups lineups){
    Widget side(String key,String name,Color accent){
      final keepers=lineups.side(key)?.players.where((p)=>p.position=='GOALIE').toList()
        ??<GamePlayer>[];
      return Expanded(child:Container(
        padding:const EdgeInsets.all(14),
        decoration:BoxDecoration(color:accent.withValues(alpha:.08),
          border:Border.all(color:accent.withValues(alpha:.35)),
          borderRadius:BorderRadius.circular(8)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(name,maxLines:2,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:accent,fontSize:10,fontWeight:FontWeight.w900)),
          const SizedBox(height:10),
          if(keepers.isEmpty)Text('Вратарь не указан в заявке ФХР',
            style:TextStyle(color:CupUi.muted,fontSize:11,height:1.3)),
          for(final keeper in keepers)Padding(
            padding:const EdgeInsets.only(bottom:6),
            child:Text('№${keeper.number}  ${keeper.name}',
              style:TextStyle(color:CupUi.white,fontSize:12,fontWeight:FontWeight.w800))),
        ])));
    }
    return Column(children:[
      const CupSection(title:'ВРАТАРИ ОБЕИХ КОМАНД',
        subtitle:'По заявкам на этот матч · данные ФХР'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Row(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          side('home',match.home,CupUi.ice),const SizedBox(width:8),
          side('away',match.away,CupUi.orange),
        ])),
      const SizedBox(height:8),
    ]);
  }

  Widget _lineup(){
    if(data==null)return CupMessage(
      icon:Icons.description_outlined,
      title:'Проверяю заявку на матч',
      message:error??'Получаю официальный список игроков, тренеров и статистику из карточки этой встречи на ФХР.',
      retry:refresh);
    final lineups=GameLineups.fromDetail(data);
    return MatchLineupPanel(
      lineups:lineups,
      home:match.home,away:match.away,
      homeLogo:homeTeam?.logo??lineups.side('home')?.logo,
      awayLogo:awayTeam?.logo??lineups.side('away')?.logo,
    );
  }

  Widget _compareBar(String title,int left,int right){
    final sum=left+right;
    final frac=sum>0?left/sum:.5;
    return Padding(padding:EdgeInsets.fromLTRB(16,12,16,12),child:Column(children:[
      Row(children:[
        SizedBox(width:35,child:Text('$left',style:TextStyle(color:CupUi.white,fontWeight:FontWeight.w800,fontSize:13))),
        Expanded(child:Text(title,textAlign:TextAlign.center,
          style:TextStyle(color:CupUi.muted,fontWeight:FontWeight.w700,fontSize:11))),
        SizedBox(width:35,child:Text('$right',textAlign:TextAlign.right,
          style:TextStyle(color:CupUi.white,fontWeight:FontWeight.w800,fontSize:13))),
      ]),
      SizedBox(height:8),
      ClipRRect(borderRadius:BorderRadius.circular(4),child:Row(children:[
        Expanded(flex:(frac*100).round().clamp(1,99),child:Container(height:6,color:CupUi.red)),
        Expanded(flex:100-(frac*100).round().clamp(1,99),child:Container(height:6,color:const Color(0xFF6798D6))),
      ])),
    ]));
  }

  Widget _statistics(){
    if(data==null)return CupMessage(title:'Статистика загружается',
      message:'Показатели будут отображены только после получения протокола.');
    final goals=events.where((e)=>str(e,'type')=='GOAL').toList();
    final penalties=events.where((e)=>str(e,'type')=='PENALTY').toList();
    final periods=data?['periodScores'] is List ? data!['periodScores'] as List : [];
    final lineups=GameLineups.fromDetail(data);
    int count(List<Map<String,dynamic>> values,String side)=>
      values.where((e)=>str(e,'side')==side).length;
    return Column(children:[
      CupSection(title:'СЧЁТ ПО ПЕРИОДАМ'),
      _periodRow(),
      if(events.isNotEmpty)...[
        CupSection(title:'СОБЫТИЯ ИГРЫ',subtitle:'Подсчитано из официального протокола ФХР'),
        CupCard(padding:EdgeInsets.symmetric(vertical:6),
          child:Column(children:[
            _compareBar('ГОЛЫ',count(goals,'home'),count(goals,'away')),
            CupDiv(indent:16),
            _compareBar('УДАЛЕНИЯ',count(penalties,'home'),count(penalties,'away')),
          ])),
      ],
      if(periods.isEmpty&&events.isEmpty)CupMessage(
        title:'Детальная статистика не опубликована',
        message:'ФХР пока не предоставляет числовые показатели для этого матча.'),
      if(lineups.available)MatchScorersPanel(lineups:lineups,home:match.home,away:match.away),
      CupSection(title:'ДРУГИЕ ПОКАЗАТЕЛИ'),
      CupCard(padding:EdgeInsets.all(16),
        child:Text('Броски, вбрасывания и другие показатели появятся, когда ФХР предоставит проверенные данные. Мы не подменяем их расчётами.',
          style:TextStyle(color:CupUi.muted,height:1.5,fontSize:12))),
      SizedBox(height:20),
    ]);
  }

  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:CupUi.background,
    appBar:AppBar(
      backgroundColor:CupUi.navy,
      title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('МАТЧ-ЦЕНТР',style:TextStyle(fontFamily:'ArenaCondensed',fontSize:22,fontWeight:FontWeight.w700,color:Colors.white)),
        Text('КУБОК РОССИИ · ПРОТОКОЛ',style:TextStyle(fontSize:9,color:Colors.white70,letterSpacing:.8)),
      ]),
      actions:[
        IconButton(tooltip:'Поделиться',icon:const Icon(Icons.ios_share),onPressed:()=>shareCard(context,'${match.home} — ${match.away}',[match.hasScore?match.score:'Матч впереди','${match.dayLabel} · ${match.timeMsk}',match.stage])),
        IconButton(onPressed:loading?null:refresh,icon:loading
          ?SizedBox(height:18,width:18,child:CircularProgressIndicator(strokeWidth:2))
          :Icon(Icons.refresh_rounded,color:CupUi.soft)),
        IconButton(onPressed:openOfficial,tooltip:'Источник ФХР',
          icon:Icon(Icons.open_in_new_rounded,color:CupUi.soft,size:20)),
      ],
    ),
    body:RefreshIndicator(onRefresh:refresh,child:ListView(children:[
      _hero(),
      if(error!=null)Padding(padding:EdgeInsets.symmetric(horizontal:17,vertical:6),
        child:Text(error!,style:TextStyle(color:CupUi.yellow,fontSize:11))),
      _tabs(),
      if(tab==0)_overview(),
      if(tab==1)_eventList(),
      if(tab==2)_lineup(),
      if(tab==3)_statistics(),
      Padding(padding:EdgeInsets.fromLTRB(18,12,18,30),
        child:Row(children:[
          Icon(Icons.verified_outlined,color:CupUi.dim,size:16),
          SizedBox(width:7),
          Expanded(child:Text('Официальный источник: ФХР Джуниор',
            style:TextStyle(color:CupUi.dim,fontSize:11))),
          TextButton(onPressed:openOfficial,child:Text('ФХР')),
        ])),
    ])),
  );
}


class _ScoreJourneyPainter extends CustomPainter {
  final List<List<int>> points;
  const _ScoreJourneyPainter(this.points);
  @override void paint(Canvas canvas,Size size){
    if(points.length<2)return;
    final baseline=size.height/2;
    const gap=14.0;
    canvas.drawLine(Offset(gap,baseline),Offset(size.width-gap,baseline),
      Paint()..color=const Color(0xFF687C9D)..strokeWidth=.7);
    final maximum=points.map((p)=>(p[0]-p[1]).abs())
      .fold<int>(1,(a,b)=>a>b?a:b);
    final delta=(size.width-2*gap)/(points.length-1);
    final path=Path();
    for(var i=0;i<points.length;i++){
      final score=points[i],lead=score[0]-score[1];
      final position=Offset(gap+i*delta,baseline-lead/maximum*(baseline-gap));
      if(i==0){path.moveTo(position.dx,position.dy);}
      else{path.lineTo(position.dx,position.dy);}
    }
    canvas.drawPath(path,Paint()..color=const Color(0xFF79E8FF)
      ..strokeWidth=3..strokeCap=StrokeCap.round..style=PaintingStyle.stroke);
    for(var i=0;i<points.length;i++){
      final lead=points[i][0]-points[i][1];
      final position=Offset(gap+i*delta,baseline-lead/maximum*(baseline-gap));
      canvas.drawCircle(position,3.5,Paint()
        ..color=lead>=0?const Color(0xFF79E8FF):const Color(0xFFFFD47A));
    }
  }
  @override bool shouldRepaint(covariant _ScoreJourneyPainter old)=>
    points.toString()!=old.points.toString();
}
