import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'cup_data.dart';
import 'match_center.dart';
import 'team_pages.dart';
import 'ui_kit.dart';

const fhrCupLogo='https://img.fhr.ru/tournaments/b6/ef/25008909.webp';

class JuniorApp extends StatelessWidget {
  const JuniorApp({super.key});
  @override
  Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:'JUNIOR U16 · Кубок России',
    theme:ThemeData(
      useMaterial3:true,brightness:Brightness.dark,
      scaffoldBackgroundColor:CupUi.background,
      colorScheme:ColorScheme.fromSeed(seedColor:CupUi.red,brightness:Brightness.dark),
      splashFactory:InkRipple.splashFactory,
      appBarTheme:const AppBarTheme(backgroundColor:CupUi.background,
        foregroundColor:CupUi.white,surfaceTintColor:Colors.transparent),
      dividerColor:CupUi.stroke,
      textTheme:const TextTheme(
        bodyMedium:TextStyle(color:CupUi.white),
        bodySmall:TextStyle(color:CupUi.muted)),
    ),
    home:const ScoresHome(),
  );
}

class ScoresHome extends StatefulWidget{
  const ScoresHome({super.key});
  @override State<ScoresHome> createState()=>_ScoresHomeState();
}

class _ScoresHomeState extends State<ScoresHome> with WidgetsBindingObserver{
  final api=FhrApiClient(http.Client());
  Timer? timer;
  int tab=0,filter=0;
  bool loading=false,loadingTeams=false,cached=false,dateFilter=false;
  DateTime date=DateTime.now().toUtc().add(const Duration(hours:3));
  DateTime? updatedAt;
  String? error,teamError;
  String search='';
  String? selectedGroup;
  List<Match> games=[];
  List<TeamInfo> clubs=[];
  Set<String> favorites={};
  static const filters=['ВСЕ','LIVE','РЕЗУЛЬТАТЫ','РАСПИСАНИЕ'];
  static const sections=[
    (Icons.home_outlined,Icons.home_rounded,'Главная'),
    (Icons.sports_hockey_outlined,Icons.sports_hockey,'Матчи'),
    (Icons.leaderboard_outlined,Icons.leaderboard_rounded,'Таблица'),
    (Icons.shield_outlined,Icons.shield_rounded,'Команды'),
    (Icons.star_border_rounded,Icons.star_rounded,'Избранное'),
  ];
  @override void initState(){
    super.initState();WidgetsBinding.instance.addObserver(this);
    _loadLocal().then((_){refresh();loadClubs();});
    timer=Timer.periodic(const Duration(seconds:25),(_)=>refresh());
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed){refresh();loadClubs();}
  }
  @override void dispose(){
    timer?.cancel();WidgetsBinding.instance.removeObserver(this);api.client.close();super.dispose();
  }

  Future<void> _loadLocal() async {
    try{
      final p=await SharedPreferences.getInstance();
      final f=p.getStringList('junior_favorites')??[];
      final content=p.getString('junior_u16_calendar_v9');
      if(!mounted)return;
      if(content!=null){
        final obj=jsonDecode(content);
        if(obj is Map) {
          final feed=FhrFeed.fromApi(Map<String,dynamic>.from(obj));
          setState((){games=feed.matches;updatedAt=feed.updatedAt;cached=true;favorites=f.toSet();});
          return;
        }
      }
      setState(()=>favorites=f.toSet());
    }catch(_){/* Unsupported/corrupt saved state must not block network fetch. */}
  }

  Future<void> refresh() async {
    if(loading)return;
    if(mounted)setState(()=>loading=true);
    try{
      final feed=await api.calendar();
      final indexed=<String,Match>{for(final m in feed.matches)m.key:m};
      try{
        final details=await api.liveCheck();
        for(final e in details){
          final id=e['gameId']?.toString();
          if(id==null||indexed[id]==null)continue;
          indexed[id]=indexed[id]!.withDetail(e);
        }
      }catch(_){/* LIVE is unverified when detail fetch fails, never infer it. */}
      final rows=indexed.values.toList()
        ..sort((a,b){final d=b.date.compareTo(a.date);
          return d!=0?d:b.timeMsk.compareTo(a.timeMsk);});
      if(!mounted)return;
      setState((){
        games=rows;updatedAt=feed.updatedAt;cached=false;error=feed.issues.isEmpty?null:
          'Данные ФХР частичные: ${feed.issues.first}';
      });
      final p=await SharedPreferences.getInstance();
      await p.setString('junior_u16_calendar_v9',jsonEncode(feed.toCache()));
    }catch(e){
      if(mounted)setState(()=>error='Нет обновления ФХР: $e');
    }finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> loadClubs() async {
    if(loadingTeams||clubs.length>=20)return;
    if(mounted)setState(()=>loadingTeams=true);
    try{
      final data=await api.teams();
      if(!mounted)return;
      setState((){
        clubs=data;teamError=data.length<20?'Список ФХР неполный: ${data.length} клубов':null;
      });
    }catch(e){if(mounted)setState(()=>teamError='Команды ФХР недоступны: $e');}
    finally{if(mounted)setState(()=>loadingTeams=false);}
  }

  String normalize(String s)=>s.toUpperCase().replaceAll('Ё','Е')
    .replaceAll(RegExp(r'\s+'),' ').trim();
  TeamInfo? findClub(String team){
    final key=normalize(team);
    for(final t in clubs){
      if(normalize(t.fullName)==key||normalize(t.name)==key)return t;
    }
    return null;
  }
  void openMatch(Match m)=>Navigator.of(context).push(MaterialPageRoute(
    builder:(_)=>MatchCenterPage(match:m,homeTeam:findClub(m.home),awayTeam:findClub(m.away))));
  void openClub(TeamInfo t)=>Navigator.of(context).push(MaterialPageRoute(
    builder:(_)=>TeamRosterPage(team:t)));
  Future<void> toggleFavorite(Match m) async {
    setState((){
      if(favorites.contains(m.key)){favorites.remove(m.key);}else{favorites.add(m.key);}
    });
    final p=await SharedPreferences.getInstance();
    await p.setStringList('junior_favorites',favorites.toList());
  }

  String shortDate(DateTime d)=>'${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}';
  String weekday(DateTime d)=>const ['ПН','ВТ','СР','ЧТ','ПТ','СБ','ВС'][d.weekday-1];
  String refreshTime(){
    if(updatedAt==null)return 'Ожидание ФХР';
    final t=updatedAt!.toUtc().add(const Duration(hours:3));
    return 'ФХР · ${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')} МСК';
  }

  Widget _header()=>SafeArea(bottom:false,child:Container(
    padding:const EdgeInsets.fromLTRB(15,10,7,10),
    decoration:const BoxDecoration(color:CupUi.background,
      border:Border(bottom:BorderSide(color:CupUi.stroke,width:.8))),
    child:Row(children:[
      ClipRRect(borderRadius:BorderRadius.circular(9),
        child:Container(color:CupUi.raised,width:40,height:40,
          child:Image.network(fhrCupLogo,fit:BoxFit.contain,errorBuilder:(_,__,___)=>
            const Icon(Icons.sports_hockey,color:CupUi.red)))),
      const SizedBox(width:11),
      const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('JUNIOR U16',style:TextStyle(color:CupUi.white,letterSpacing:.65,
          fontWeight:FontWeight.w900,fontSize:20,height:1.05)),
        SizedBox(height:4),
        Text('КУБОК РОССИИ · 2026/27',style:TextStyle(color:CupUi.muted,
          fontWeight:FontWeight.w700,letterSpacing:.45,fontSize:9)),
      ])),
      if(games.any((m)=>m.isLive))const Padding(padding:EdgeInsets.only(right:6),
        child:CupTag(text:'LIVE',color:CupUi.green,filled:true)),
      IconButton(onPressed:loading?null:refresh,tooltip:'Обновить ФХР',
        icon:loading?const SizedBox(height:19,width:19,
          child:CircularProgressIndicator(strokeWidth:2)):
          const Icon(Icons.refresh_rounded,color:CupUi.soft)),
    ]),
  ));

  Widget _syncBar()=>Container(
    color:CupUi.surface,padding:const EdgeInsets.symmetric(horizontal:16,vertical:9),
    child:Row(children:[
      Container(width:6,height:6,decoration:BoxDecoration(shape:BoxShape.circle,
        color:cached?CupUi.yellow:(error==null?CupUi.green:CupUi.yellow))),
      const SizedBox(width:7),
      Expanded(child:Text(cached?'КЭШ · последнее сохранение':refreshTime(),
        style:const TextStyle(color:CupUi.muted,fontSize:10,fontWeight:FontWeight.w600))),
      Text('${games.length} матчей · ${clubs.length} клубов',
        style:const TextStyle(color:CupUi.muted,fontSize:10)),
    ]),
  );

  Widget _nav()=>SafeArea(top:false,child:Container(
    height:67,decoration:const BoxDecoration(color:CupUi.surface,
      border:Border(top:BorderSide(color:CupUi.stroke,width:.7))),
    child:Row(children:[
      for(var i=0;i<sections.length;i++)Expanded(child:InkWell(
        onTap:()=>setState((){tab=i;filter=0;dateFilter=false;search='';}),
        child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Icon(i==tab?sections[i].$2:sections[i].$1,size:22,
            color:i==tab?CupUi.red:CupUi.muted),
          const SizedBox(height:4),
          Text(sections[i].$3,style:TextStyle(color:i==tab?CupUi.white:CupUi.muted,
            fontSize:10,fontWeight:i==tab?FontWeight.w800:FontWeight.w600)),
        ]))),
    ]),
  ));

  Widget _filterChip(String text,bool active,VoidCallback tap)=>InkWell(
    onTap:tap,borderRadius:BorderRadius.circular(8),
    child:AnimatedContainer(duration:const Duration(milliseconds:150),
      margin:const EdgeInsets.only(right:8),
      padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
      decoration:BoxDecoration(
        color:active?CupUi.red:CupUi.surface,
        borderRadius:BorderRadius.circular(8),
        border:Border.all(color:active?CupUi.red:CupUi.stroke)),
      child:Text(text,style:TextStyle(fontSize:10,letterSpacing:.3,
        color:active?CupUi.white:CupUi.muted,fontWeight:FontWeight.w800))),
  );

  Widget _dateSelector(){
    final now=DateTime.now().toUtc().add(const Duration(hours:3));
    return Container(color:CupUi.background,
      child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(13,10,10,10),
          child:Row(children:[
            const Icon(Icons.calendar_month_outlined,color:CupUi.muted,size:18),
            const SizedBox(width:8),
            Expanded(child:Text(dateFilter?'ВЫБРАННАЯ ДАТА: ${shortDate(date)}':'ВЫБЕРИ ДЕНЬ МАТЧА',
              style:const TextStyle(color:CupUi.soft,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:.5))),
            InkWell(onTap:()=>setState(()=>dateFilter=false),
              child:Padding(padding:const EdgeInsets.all(6),
                child:Text('ВСЕ ДАТЫ',style:TextStyle(color:dateFilter?CupUi.red:CupUi.muted,
                  fontSize:10,fontWeight:FontWeight.w800)))),
            const SizedBox(width:4),
            IconButton(icon:const Icon(Icons.calendar_today_rounded,size:17,color:CupUi.soft),
              onPressed:()async{
                final selected=await showDatePicker(context:context,
                  firstDate:DateTime(2026,8,1),lastDate:DateTime(2027,12,31),
                  initialDate:date.isBefore(DateTime(2026,8,1))?DateTime(2026,9,10):date);
                if(selected!=null&&mounted)setState((){date=selected;dateFilter=true;});
              }),
          ])),
        SizedBox(height:57,child:ListView.builder(
          padding:const EdgeInsets.symmetric(horizontal:9),scrollDirection:Axis.horizontal,
          itemCount:11,itemBuilder:(context,i){
            final current=now.add(Duration(days:i-5));
            final active=dateFilter&&current.year==date.year&&current.month==date.month&&current.day==date.day;
            return InkWell(onTap:()=>setState((){date=current;dateFilter=true;}),
              borderRadius:BorderRadius.circular(8),
              child:Container(width:59,margin:const EdgeInsets.symmetric(horizontal:2),
                decoration:BoxDecoration(color:active?CupUi.raised:Colors.transparent,
                  borderRadius:BorderRadius.circular(8),
                  border:Border(bottom:BorderSide(width:2.5,
                    color:active?CupUi.red:Colors.transparent))),
                child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                  Text(i==5?'СЕГОДНЯ':weekday(current),
                    style:TextStyle(fontSize:i==5?9:10,color:active?CupUi.red:CupUi.muted,
                      fontWeight:FontWeight.w800)),
                  const SizedBox(height:5),
                  Text(shortDate(current),style:TextStyle(color:active?CupUi.white:CupUi.soft,
                    fontSize:11,fontWeight:FontWeight.w800)),
                ])),
            );
          },
        )),
        const SizedBox(height:5),
      ]));
  }

  List<Match> filtered({bool onlyFavorites=false}){
    return games.where((m){
      if(onlyFavorites&&!favorites.contains(m.key))return false;
      if(filter==1&&!m.isLive)return false;
      if(filter==2&&!m.finished)return false;
      if(filter==3&&(m.finished||m.isLive))return false;
      if(dateFilter){
        final parsed=m.matchDate;
        if(parsed==null||parsed.year!=date.year||parsed.month!=date.month||parsed.day!=date.day)return false;
      }
      return true;
    }).toList();
  }

  Widget _matchLine(Match game){
    final h=findClub(game.home),a=findClub(game.away);
    final goals=game.goals;
    final live=game.isLive;
    final played=game.finished;
    return InkWell(onTap:()=>openMatch(game),
      child:Padding(padding:const EdgeInsets.fromLTRB(12,10,6,10),
        child:Row(children:[
          SizedBox(width:50,child:Column(children:[
            Text(live?'LIVE':played?'КОН.':game.timeMsk.isNotEmpty?game.timeMsk:'–',
              style:TextStyle(fontWeight:FontWeight.w800,fontSize:10,
                color:live?CupUi.green:(played?CupUi.muted:CupUi.yellow))),
            const SizedBox(height:6),
            Text(game.dayLabel,style:const TextStyle(color:CupUi.dim,fontSize:10)),
          ])),
          Container(height:42,width:2,color:live?CupUi.green:(played?CupUi.stroke:CupUi.yellow)),
          const SizedBox(width:10),
          Expanded(child:Column(children:[
            _teamLine(game.home,h?.logo),
            const SizedBox(height:10),
            _teamLine(game.away,a?.logo),
          ])),
          SizedBox(width:34,child:Column(children:[
            Text(goals==null?'–':'${goals[0]}',style:TextStyle(color:played||live?CupUi.white:CupUi.soft,
              fontWeight:FontWeight.w900,fontSize:16)),
            const SizedBox(height:10),
            Text(goals==null?'–':'${goals[1]}',style:TextStyle(color:played||live?CupUi.white:CupUi.soft,
              fontWeight:FontWeight.w900,fontSize:16)),
          ])),
          IconButton(
            onPressed:()=>toggleFavorite(game),
            tooltip:'Избранное',
            icon:Icon(favorites.contains(game.key)?Icons.star_rounded:Icons.star_border_rounded,
              color:favorites.contains(game.key)?CupUi.yellow:CupUi.dim,size:21)),
        ])));
  }
  Widget _teamLine(String name,String? logo)=>Row(children:[
    fhrTeamLogo(logo,size:23),const SizedBox(width:9),
    Expanded(child:Text(name,maxLines:1,overflow:TextOverflow.ellipsis,
      style:const TextStyle(color:CupUi.white,fontSize:12,fontWeight:FontWeight.w700))),
  ]);

  Widget _leagueBlock(String label,List<Match> list)=>CupCard(
    margin:const EdgeInsets.fromLTRB(12,5,12,6),
    child:Column(children:[
      Container(color:CupUi.raised,
        padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),
        child:Row(children:[
          Container(width:27,height:27,decoration:BoxDecoration(color:CupUi.redMuted,
            borderRadius:BorderRadius.circular(8)),
            child:const Icon(Icons.sports_hockey,size:17,color:CupUi.red)),
          const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('РОССИЯ · КУБОК U16',style:TextStyle(color:CupUi.muted,fontSize:9,letterSpacing:.5)),
            const SizedBox(height:3),
            Text(label.toUpperCase(),style:const TextStyle(color:CupUi.white,fontSize:11,fontWeight:FontWeight.w800)),
          ])),
          CupTag(text:'${list.length}',color:CupUi.soft),
        ])),
      for(var i=0;i<list.length;i++)...[
        _matchLine(list[i]),
        if(i+1<list.length)const CupDiv(indent:15),
      ],
    ]),
  );

  Widget _filters()=>SingleChildScrollView(scrollDirection:Axis.horizontal,
    padding:const EdgeInsets.fromLTRB(13,8,8,10),
    child:Row(children:[
      for(var i=0;i<filters.length;i++)_filterChip(filters[i],filter==i,()=>setState(()=>filter=i)),
    ]));

  List<Widget> _gamesGrouped(List<Match> visible,{int? limit}){
    final selected=limit==null?visible:visible.take(limit).toList();
    final groups=<String,List<Match>>{};
    for(final m in selected){groups.putIfAbsent(m.stage,()=>[]).add(m);}
    return [for(final group in groups.entries)_leagueBlock(group.key,group.value)];
  }

  Widget _homePage(){
    final recent=filtered();
    final live=games.where((m)=>m.isLive).toList();
    return RefreshIndicator(onRefresh:refresh,child:ListView(children:[
      const Padding(padding:EdgeInsets.fromLTRB(16,20,16,4),
        child:Text('КУБОК РОССИИ U16',style:TextStyle(
          color:CupUi.white,fontSize:22,fontWeight:FontWeight.w900,letterSpacing:-.5))),
      const Padding(padding:EdgeInsets.fromLTRB(16,0,16,15),
        child:Text('Сезон 2026/27  ·  результаты ФХР Джуниор',
          style:TextStyle(color:CupUi.muted,fontSize:12))),
      Row(children:[
        Expanded(child:_metric('20','КОМАНД',Icons.shield_outlined)),
        Expanded(child:_metric('${games.length}','МАТЧЕЙ',Icons.sports_hockey_outlined)),
        Expanded(child:_metric('${live.length}','LIVE',Icons.radio_button_checked)),
      ]),
      if(error!=null)Padding(padding:const EdgeInsets.fromLTRB(15,5,15,10),
        child:Text(error!,style:const TextStyle(color:CupUi.yellow,fontSize:11))),
      if(live.isNotEmpty)...[
        const CupSection(title:'ПРЯМО СЕЙЧАС'),
        for(final block in _gamesGrouped(live))block,
      ],
      const CupSection(title:'МАТЧИ КУБКА',subtitle:'Выбери дату или открой результат'),
      _dateSelector(),_filters(),
      if(recent.isEmpty)CupMessage(
        icon:Icons.sports_hockey,title:'Пока нет матчей',
        message:games.isEmpty?'Запрашиваю результаты с ФХР. Потяни вниз, чтобы обновить.':
        'На выбранную дату или для этого фильтра игр нет.',
        retry:refresh),
      for(final block in _gamesGrouped(recent,limit:22))block,
      if(recent.length>22)Padding(padding:const EdgeInsets.fromLTRB(12,6,12,20),
        child:FilledButton.tonal(onPressed:()=>setState(()=>tab=1),
          child:const Text('ПОКАЗАТЬ ВСЕ МАТЧИ'))),
      const SizedBox(height:20),
    ]));
  }

  Widget _metric(String value,String label,IconData icon)=>CupCard(
    margin:const EdgeInsets.fromLTRB(4,0,4,8),
    padding:const EdgeInsets.symmetric(vertical:12,horizontal:7),
    child:Column(children:[
      Icon(icon,color:CupUi.red,size:18),const SizedBox(height:7),
      Text(value,style:const TextStyle(color:CupUi.white,fontSize:21,fontWeight:FontWeight.w900)),
      const SizedBox(height:3),
      Text(label,style:const TextStyle(color:CupUi.muted,fontSize:9,fontWeight:FontWeight.w800)),
    ]));

  Widget _matchesPage()=>RefreshIndicator(onRefresh:refresh,child:ListView(children:[
    const CupSection(title:'ВСЕ МАТЧИ',subtitle:'Календарь Кубка России U16'),
    _dateSelector(),_filters(),
    if(filtered().isEmpty)CupMessage(icon:Icons.calendar_month_outlined,title:'Ничего не найдено',
      message:'Выбери другую дату или другой тип матчей.',retry:refresh),
    for(final block in _gamesGrouped(filtered()))block,
    const SizedBox(height:24),
  ]));

  List<String> get stageNames {
    final set=games.map((e)=>e.stage).where((s)=>s.startsWith('Группа ')).toSet().toList();
    set.sort((a,b){final x=a.split('-').last,y=b.split('-').last;
      final c=(x=='I'?1:x=='II'?2:3).compareTo(y=='I'?1:y=='II'?2:3);
      return c==0?a.compareTo(b):c;});
    return set;
  }
  Widget _standingPage(){
    final group=selectedGroup!=null&&stageNames.contains(selectedGroup)?selectedGroup:null;
    final played=group==null?games:games.where((e)=>e.stage==group).toList();
    final standings=ranking(played);
    return RefreshIndicator(onRefresh:refresh,child:ListView(children:[
      const CupSection(title:'ТУРНИРНЫЕ ТАБЛИЦЫ',subtitle:'Общая таблица и отдельные группы'),
      SingleChildScrollView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.fromLTRB(12,2,12,12),
        child:Row(children:[
          _filterChip('ОБЩАЯ',group==null,()=>setState(()=>selectedGroup=null)),
          for(final s in stageNames)_filterChip(s.replaceFirst('Группа ','ГР. '),group==s,
            ()=>setState(()=>selectedGroup=s)),
        ])),
      CupCard(margin:const EdgeInsets.fromLTRB(12,3,12,14),padding:const EdgeInsets.all(12),
        color:CupUi.raised,child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Icon(Icons.info_outline_rounded,size:18,color:CupUi.yellow),const SizedBox(width:9),
          Expanded(child:Text(group==null
            ? 'Общий рейтинг предварительный до завершения всех квалификационных туров. Стыковые матчи учитываются.'
            : 'В таблице $group учитываются только матчи этой группы. Стыковки относятся к общему рейтингу.',
            style:const TextStyle(color:CupUi.soft,fontSize:11,height:1.5))),
        ])),
      CupCard(padding:const EdgeInsets.only(top:2,bottom:2),
        child:Column(children:[
          Container(color:CupUi.raised,padding:const EdgeInsets.symmetric(horizontal:11,vertical:13),
            child:Row(children:[
              const SizedBox(width:23,child:Text('#',style:TextStyle(color:CupUi.muted,fontSize:10))),
              const Expanded(child:Text('КОМАНДА',style:TextStyle(color:CupUi.muted,fontSize:10,fontWeight:FontWeight.w800))),
              for(final label in ['И','РШ','О'])SizedBox(width:label=='РШ'?44:29,
                child:Text(label,textAlign:TextAlign.center,
                  style:const TextStyle(color:CupUi.muted,fontSize:10,fontWeight:FontWeight.w800))),
            ])),
          for(var i=0;i<standings.length;i++)...[
            InkWell(onTap:(){
              final c=findClub(standings[i].team);
              if(c!=null)openClub(c);
            },child:Padding(padding:const EdgeInsets.symmetric(horizontal:9,vertical:11),
              child:Row(children:[
                Container(width:23,alignment:Alignment.centerLeft,
                  child:Text('${i+1}',style:TextStyle(color:i<8&&group==null?CupUi.green:CupUi.muted,
                    fontSize:11,fontWeight:FontWeight.w800))),
                fhrTeamLogo(findClub(standings[i].team)?.logo,size:22),
                const SizedBox(width:7),
                Expanded(child:Text(standings[i].team,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:CupUi.white,fontSize:11,fontWeight:FontWeight.w700))),
                SizedBox(width:29,child:Text('${standings[i].gp}',textAlign:TextAlign.center,
                  style:const TextStyle(color:CupUi.soft,fontSize:11))),
                SizedBox(width:44,child:Text('${standings[i].diff}',textAlign:TextAlign.center,
                  style:const TextStyle(color:CupUi.muted,fontSize:11))),
                SizedBox(width:29,child:Text('${standings[i].pts}',textAlign:TextAlign.center,
                  style:const TextStyle(color:CupUi.white,fontSize:13,fontWeight:FontWeight.w900))),
              ]))),
            if(i+1<standings.length)const CupDiv(indent:10),
          ],
        ])),
      if(standings.isEmpty)const CupMessage(title:'Нет опубликованных игр',
        message:'Таблица появится, когда ФХР опубликует расписание и результаты.'),
      const Padding(padding:EdgeInsets.fromLTRB(18,11,18,30),
        child:Text('Порядок команд при сложных равенствах очков требует сверки с официальным регламентом и ФХР.',
          style:TextStyle(fontSize:11,color:CupUi.muted,height:1.4))),
    ]));
  }

  Widget _teamPage(){
    final list=clubs.where((x)=>x.fullName.toLowerCase().contains(search.toLowerCase())).toList();
    return RefreshIndicator(onRefresh:loadClubs,child:ListView(children:[
      CupSection(title:'УЧАСТНИКИ',subtitle:'${clubs.length} клубов с официальными составами ФХР'),
      Padding(padding:const EdgeInsets.fromLTRB(12,0,12,12),
        child:TextField(onChanged:(v)=>setState(()=>search=v),
          style:const TextStyle(fontSize:13),
          decoration:InputDecoration(
            prefixIcon:const Icon(Icons.search,color:CupUi.muted),
            hintText:'Найти команду',hintStyle:const TextStyle(color:CupUi.dim),
            filled:true,fillColor:CupUi.surface,
            contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:11),
            enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(11),
              borderSide:const BorderSide(color:CupUi.stroke)),
            focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(11),
              borderSide:const BorderSide(color:CupUi.red))))),
      if(loadingTeams&&clubs.isEmpty)const Padding(padding:EdgeInsets.all(28),
        child:Center(child:CircularProgressIndicator())),
      if(teamError!=null)Padding(padding:const EdgeInsets.all(15),
        child:Text(teamError!,style:const TextStyle(color:CupUi.yellow,fontSize:11))),
      CupCard(padding:const EdgeInsets.symmetric(vertical:4),child:Column(children:[
        for(var i=0;i<list.length;i++)...[
          InkWell(onTap:()=>openClub(list[i]),
            child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:11),
              child:Row(children:[
                fhrTeamLogo(list[i].logo,size:40),const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(list[i].name,style:const TextStyle(color:CupUi.white,
                    fontSize:13,fontWeight:FontWeight.w800)),
                  const SizedBox(height:3),
                  Text(list[i].city,style:const TextStyle(color:CupUi.muted,fontSize:11)),
                ])),
                const Icon(Icons.chevron_right_rounded,color:CupUi.dim,size:19),
              ]))),
          if(i+1<list.length)const CupDiv(indent:60),
        ],
      ])),
      if(clubs.isEmpty&&!loadingTeams)CupMessage(title:'Команды не загружены',
        message:'Данные клуба и фото игроков берутся только из ФХР Джуниор.',retry:loadClubs),
      const SizedBox(height:24),
    ]));
  }

  Widget _favoritesPage(){
    final list=games.where((e)=>favorites.contains(e.key)).toList();
    return RefreshIndicator(onRefresh:refresh,child:ListView(children:[
      CupSection(title:'ИЗБРАННЫЕ МАТЧИ',subtitle:'${list.length} сохранено на этом устройстве'),
      if(list.isEmpty)const CupMessage(
        icon:Icons.star_border_rounded,title:'Избранное пока пусто',
        message:'Нажимай на звёздочку возле матча. Он появится здесь и останется после перезапуска.'),
      for(final block in _gamesGrouped(list))block,
      const SizedBox(height:20),
    ]));
  }

  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:CupUi.background,
    body:Column(children:[
      _header(),_syncBar(),
      Expanded(child:IndexedStack(index:tab,children:[
        _homePage(),_matchesPage(),_standingPage(),_teamPage(),_favoritesPage(),
      ])),
    ]),
    bottomNavigationBar:_nav(),
  );
}
