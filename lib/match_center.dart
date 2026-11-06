import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'cup_data.dart';
import 'match_lineups.dart';
import 'team_pages.dart';
import 'ui_kit.dart';

class MatchCenterPage extends StatefulWidget {
  final Match match;
  final TeamInfo? homeTeam;
  final TeamInfo? awayTeam;
  const MatchCenterPage({super.key,required this.match,this.homeTeam,this.awayTeam});
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
  int eventFilter=0;
  @override void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    match=widget.match;
    homeTeam=widget.homeTeam;
    awayTeam=widget.awayTeam;
    refresh();
    timer=Timer.periodic(const Duration(seconds:20),(_)=>refresh());
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed)refresh();
  }
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
      if(mounted)setState(()=>error='Не удалось проверить матч: $e');
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
    final live=match.isLive;
    final lineups=GameLineups.fromDetail(data);
    final label=data?['statusText']?.toString();
    final status=label!=null&&label.isNotEmpty?label:
      live?'LIVE':match.finished?'Матч завершён':'По расписанию';
    return CupCard(
      margin:const EdgeInsets.fromLTRB(12,6,12,10),padding:const EdgeInsets.fromLTRB(12,19,12,20),
      child:Column(children:[
        Text(match.stage.toUpperCase(),textAlign:TextAlign.center,
          style:const TextStyle(color:CupUi.muted,fontWeight:FontWeight.w700,fontSize:11,letterSpacing:.7)),
        const SizedBox(height:7),
        Text('${match.dayLabel}   •   ${match.timeMsk} МСК',
          style:const TextStyle(color:CupUi.muted,fontSize:11)),
        const SizedBox(height:15),
        CupTag(text:status.toUpperCase(),color:live?CupUi.green:(match.finished?CupUi.soft:CupUi.yellow),filled:true),
        const SizedBox(height:19),
        Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
          Expanded(child:_heroTeam(match.home,homeTeam?.logo??lineups.side('home')?.logo)),
          Container(constraints:const BoxConstraints(minWidth:108),alignment:Alignment.center,
            child:Column(children:[
              Text(match.score.isEmpty?'–  :  –':match.score.replaceAll(':',' : '),
                style:TextStyle(color:live?CupUi.green:CupUi.white,
                  fontSize:31,fontWeight:FontWeight.w900,letterSpacing:-1.5)),
              if(match.scoreNote.isNotEmpty)Text(match.scoreNote,
                style:const TextStyle(color:CupUi.yellow,fontSize:11)),
            ])),
          Expanded(child:_heroTeam(match.away,awayTeam?.logo??lineups.side('away')?.logo)),
        ]),
        if(live&&data?['period']!=null)...[
          const SizedBox(height:15),
          Text('Период ${data?['period']} · ${data?['clock']??''}',
            style:const TextStyle(color:CupUi.green,fontWeight:FontWeight.w700,fontSize:13)),
        ],
      ]));
  }
  Widget _heroTeam(String name,String? logo)=>Column(children:[
    fhrTeamLogo(logo,size:58),
    const SizedBox(height:10),
    Text(name,maxLines:3,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,
      style:const TextStyle(color:CupUi.white,fontWeight:FontWeight.w700,height:1.15,fontSize:12)),
  ]);

  Widget _periodRow(){
    final scores=data?['periodScores'];
    final list=scores is List?scores:[];
    if(list.isEmpty)return const SizedBox.shrink();
    return CupCard(
      margin:const EdgeInsets.fromLTRB(12,0,12,4),
      child:Padding(padding:const EdgeInsets.symmetric(vertical:14,horizontal:10),
        child:Row(children:[
          const SizedBox(width:58,child:Text('ПЕРИОДЫ',style:TextStyle(color:CupUi.dim,fontSize:9,fontWeight:FontWeight.w800))),
          for(var i=0;i<list.length;i++)Expanded(child:Column(children:[
            Text(i==3?'ОТ':'${i+1}-Й',style:const TextStyle(color:CupUi.muted,fontSize:10,fontWeight:FontWeight.w700)),
            const SizedBox(height:6),
            Text('${list[i] is Map?list[i]['home']:'–'}:${list[i] is Map?list[i]['away']:'–'}',
              style:const TextStyle(color:CupUi.white,fontSize:14,fontWeight:FontWeight.w800)),
          ])),
        ])),
    );
  }

  Widget _tabs()=>Container(
    margin:const EdgeInsets.only(top:8),decoration:const BoxDecoration(
      color:CupUi.background,border:Border(bottom:BorderSide(color:CupUi.stroke))),
    child:Row(children:[
      for(var i=0;i<4;i++)Expanded(child:InkWell(
        onTap:(){
          setState(()=>tab=i);
        },
        child:Container(
          padding:const EdgeInsets.symmetric(vertical:16),
          decoration:BoxDecoration(border:Border(bottom:BorderSide(
            color:tab==i?CupUi.red:Colors.transparent,width:2.5))),
          child:Text(const ['ОБЗОР','СОБЫТИЯ','СОСТАВЫ','СТАТИСТИКА'][i],
            textAlign:TextAlign.center,maxLines:1,
            style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,
              color:tab==i?CupUi.white:CupUi.muted,letterSpacing:.1))),
      )),
    ]),
  );

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
    return Container(margin:const EdgeInsets.fromLTRB(12,0,12,7),
      padding:const EdgeInsets.symmetric(horizontal:11,vertical:13),
      decoration:BoxDecoration(color:CupUi.surface,borderRadius:BorderRadius.circular(12),
        border:Border.all(color:CupUi.stroke,width:.7)),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        SizedBox(width:43,child:Column(children:[
          Text(time.isEmpty?'–':time,style:const TextStyle(color:CupUi.white,fontWeight:FontWeight.w800,fontSize:11)),
          const SizedBox(height:8),
          Container(width:29,height:29,decoration:BoxDecoration(color:accent.withValues(alpha:.12),
            shape:BoxShape.circle),
            child:Icon(isGoal?Icons.sports_hockey:isPenalty?Icons.timer_outlined:
              isKeeper?Icons.shield_outlined:Icons.flag_outlined,size:16,color:accent)),
        ])),
        const SizedBox(width:9),
        if(photo!=null&&photo.startsWith('https://img.fhr.ru/players/'))...[
          fhrPlayerPhoto(photo,size:39),const SizedBox(width:9),
        ],
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Text(title.toUpperCase(),style:TextStyle(color:accent,fontSize:10,
              fontWeight:FontWeight.w800,letterSpacing:.4)),
            if(isPenalty&&penaltyMinutes.isNotEmpty)...[
              const SizedBox(width:6),
              CupTag(text:penaltyMinutes,color:CupUi.yellow,filled:true),
            ],
            if(score.isNotEmpty)...[const Spacer(),
              Text(score,style:const TextStyle(color:CupUi.white,fontSize:13,fontWeight:FontWeight.w800))],
          ]),
          const SizedBox(height:5),
          if(name.isNotEmpty)Text(name,style:const TextStyle(color:CupUi.white,fontSize:13,fontWeight:FontWeight.w700)),
          if(reason.isNotEmpty)Padding(padding:const EdgeInsets.only(top:4),
            child:Text(isGoal?'Передачи: $reason':reason,
              maxLines:compact?2:4,overflow:TextOverflow.ellipsis,
              style:const TextStyle(color:CupUi.muted,fontSize:11,height:1.35))),
          if(str(e,'team').isNotEmpty)Padding(padding:const EdgeInsets.only(top:5),
            child:Text(str(e,'team'),maxLines:1,overflow:TextOverflow.ellipsis,
              style:const TextStyle(color:CupUi.dim,fontSize:10))),
        ])),
      ]));
  }

  Widget _introInfo()=>CupCard(
    child:Column(children:[
      _infoRow(Icons.stadium_outlined,'Арена',match.arena.isEmpty?'Не указана':match.arena),
      const CupDiv(indent:16),
      _infoRow(Icons.calendar_today_outlined,'Дата',match.dayLabel),
      const CupDiv(indent:16),
      _infoRow(Icons.update_rounded,'Обновление','Автоматически каждые 20 секунд'),
    ]));
  Widget _infoRow(IconData icon,String key,String value)=>Padding(
    padding:const EdgeInsets.symmetric(horizontal:14,vertical:13),
    child:Row(children:[
      Icon(icon,size:16,color:CupUi.muted),const SizedBox(width:10),
      SizedBox(width:88,child:Text(key,style:const TextStyle(color:CupUi.muted,fontSize:11))),
      Expanded(child:Text(value,textAlign:TextAlign.right,
        style:const TextStyle(color:CupUi.white,fontSize:11,fontWeight:FontWeight.w600))),
    ]));

  Widget _overview(){
    final goals=events.where((e)=>str(e,'type')=='GOAL').toList();
    final penalties=events.where((e)=>str(e,'type')=='PENALTY').toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      _periodRow(),
      const CupSection(title:'ГОЛЫ И ПЕРЕДАЧИ',subtitle:'По официальному протоколу ФХР'),
      if(goals.isEmpty)const CupMessage(title:'Шайбы пока не опубликованы',
        message:'Список голов появится после публикации событий ФХР.',icon:Icons.sports_hockey),
      for(final goal in goals)_goalEntry(goal),
      if(penalties.isNotEmpty)...[
        CupSection(title:'УДАЛЕНИЯ',subtitle:'${penalties.length} записей'),
        for(final penalty in penalties.take(3))_goalEntry(penalty,compact:true),
        if(penalties.length>3)Padding(padding:const EdgeInsets.symmetric(horizontal:12),
          child:TextButton(onPressed:()=>setState(()=>tab=1),child:const Text('ВСЕ СОБЫТИЯ МАТЧА'))),
      ],
      if(data!=null)...[
        const CupSection(title:'ЗАЯВКИ КОМАНД'),
        CupCard(padding:const EdgeInsets.all(14),
          child:InkWell(onTap:()=>setState(()=>tab=2),
            child:Row(children:[
              const Icon(Icons.groups_2_outlined,color:CupUi.red,size:22),
              const SizedBox(width:11),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(GameLineups.fromDetail(data).available
                  ?'Подтверждённые заявки ФХР':'Заявки ФХР пока не подтверждены',
                  style:const TextStyle(color:CupUi.white,fontWeight:FontWeight.w800,fontSize:12)),
                const SizedBox(height:4),
                const Text('Игроки, тренеры, капитаны и статистика',
                  style:TextStyle(color:CupUi.muted,fontSize:11)),
              ])),
              const Icon(Icons.chevron_right_rounded,color:CupUi.soft),
            ]))),
      ],
      const CupSection(title:'ИНФОРМАЦИЯ О МАТЧЕ'),
      _introInfo(),const SizedBox(height:26),
    ]);
  }

  Widget _eventList(){
    if(data==null)return const CupMessage(
      title:'Загружаю протокол',message:'Запрашиваю события матча ФХР.');
    if(events.isEmpty)return const CupMessage(
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
      const CupSection(title:'ХРОНОЛОГИЯ МАТЧА',
        subtitle:'Голы, передачи, штрафы, вратари и тайм-ауты'),
      SingleChildScrollView(scrollDirection:Axis.horizontal,
        padding:const EdgeInsets.fromLTRB(12,1,12,14),
        child:Row(children:[
          for(var i=0;i<4;i++)Padding(
            padding:const EdgeInsets.only(right:7),
            child:InkWell(
              onTap:()=>setState(()=>eventFilter=i),
              borderRadius:BorderRadius.circular(9),
              child:Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:10),
                decoration:BoxDecoration(
                  color:i==eventFilter?CupUi.red:CupUi.surface,
                  borderRadius:BorderRadius.circular(9),
                  border:Border.all(color:i==eventFilter?CupUi.red:CupUi.stroke)),
                child:Text(const ['ВСЕ','ГОЛЫ','УДАЛЕНИЯ','ВРАТАРИ'][i],
                  style:TextStyle(color:i==eventFilter?CupUi.white:CupUi.muted,
                    fontSize:10,fontWeight:FontWeight.w800))),
            )),
        ])),
      if(visible.isEmpty)const CupMessage(title:'Нет событий в категории',
        message:'Попробуй другой фильтр хронологии.'),
      ...out,
      const SizedBox(height:20),
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
    return Padding(padding:const EdgeInsets.fromLTRB(16,12,16,12),child:Column(children:[
      Row(children:[
        SizedBox(width:35,child:Text('$left',style:const TextStyle(color:CupUi.white,fontWeight:FontWeight.w800,fontSize:13))),
        Expanded(child:Text(title,textAlign:TextAlign.center,
          style:const TextStyle(color:CupUi.muted,fontWeight:FontWeight.w700,fontSize:11))),
        SizedBox(width:35,child:Text('$right',textAlign:TextAlign.right,
          style:const TextStyle(color:CupUi.white,fontWeight:FontWeight.w800,fontSize:13))),
      ]),
      const SizedBox(height:8),
      ClipRRect(borderRadius:BorderRadius.circular(4),child:Row(children:[
        Expanded(flex:(frac*100).round().clamp(1,99),child:Container(height:6,color:CupUi.red)),
        Expanded(flex:100-(frac*100).round().clamp(1,99),child:Container(height:6,color:const Color(0xFF6798D6))),
      ])),
    ]));
  }

  Widget _statistics(){
    if(data==null)return const CupMessage(title:'Статистика загружается',
      message:'Показатели будут отображены только после получения протокола.');
    final goals=events.where((e)=>str(e,'type')=='GOAL').toList();
    final penalties=events.where((e)=>str(e,'type')=='PENALTY').toList();
    final periods=data?['periodScores'] is List ? data!['periodScores'] as List : [];
    final lineups=GameLineups.fromDetail(data);
    int count(List<Map<String,dynamic>> values,String side)=>
      values.where((e)=>str(e,'side')==side).length;
    return Column(children:[
      const CupSection(title:'СЧЁТ ПО ПЕРИОДАМ'),
      _periodRow(),
      if(events.isNotEmpty)...[
        const CupSection(title:'СОБЫТИЯ ИГРЫ',subtitle:'Подсчитано из официального протокола ФХР'),
        CupCard(padding:const EdgeInsets.symmetric(vertical:6),
          child:Column(children:[
            _compareBar('ГОЛЫ',count(goals,'home'),count(goals,'away')),
            const CupDiv(indent:16),
            _compareBar('УДАЛЕНИЯ',count(penalties,'home'),count(penalties,'away')),
          ])),
      ],
      if(periods.isEmpty&&events.isEmpty)const CupMessage(
        title:'Детальная статистика не опубликована',
        message:'ФХР пока не предоставляет числовые показатели для этого матча.'),
      if(lineups.available)MatchScorersPanel(lineups:lineups,home:match.home,away:match.away),
      const CupSection(title:'ДРУГИЕ ПОКАЗАТЕЛИ'),
      const CupCard(padding:EdgeInsets.all(16),
        child:Text('Броски, вбрасывания и другие показатели появятся, когда ФХР предоставит проверенные данные. Мы не подменяем их расчётами.',
          style:TextStyle(color:CupUi.muted,height:1.5,fontSize:12))),
      const SizedBox(height:20),
    ]);
  }

  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:CupUi.background,
    appBar:AppBar(
      backgroundColor:CupUi.background,
      title:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('КУБОК РОССИИ',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900,color:CupUi.white)),
        Text('МАТЧ-ЦЕНТР · U16',style:TextStyle(fontSize:10,color:CupUi.muted,letterSpacing:1.1)),
      ]),
      actions:[
        IconButton(onPressed:loading?null:refresh,icon:loading
          ?const SizedBox(height:18,width:18,child:CircularProgressIndicator(strokeWidth:2))
          :const Icon(Icons.refresh_rounded,color:CupUi.soft)),
        IconButton(onPressed:openOfficial,tooltip:'Источник ФХР',
          icon:const Icon(Icons.open_in_new_rounded,color:CupUi.soft,size:20)),
      ],
    ),
    body:RefreshIndicator(onRefresh:refresh,child:ListView(children:[
      _hero(),
      if(error!=null)Padding(padding:const EdgeInsets.symmetric(horizontal:17,vertical:6),
        child:Text(error!,style:const TextStyle(color:CupUi.yellow,fontSize:11))),
      _tabs(),
      if(tab==0)_overview(),
      if(tab==1)_eventList(),
      if(tab==2)_lineup(),
      if(tab==3)_statistics(),
      Padding(padding:const EdgeInsets.fromLTRB(18,12,18,30),
        child:Row(children:[
          const Icon(Icons.verified_outlined,color:CupUi.dim,size:16),
          const SizedBox(width:7),
          const Expanded(child:Text('Официальный источник: ФХР Джуниор',
            style:TextStyle(color:CupUi.dim,fontSize:11))),
          TextButton(onPressed:openOfficial,child:const Text('ФХР')),
        ])),
    ])),
  );
}
