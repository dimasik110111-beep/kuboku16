import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'cup_data.dart';
import 'match_center.dart';
import 'team_pages.dart';
import 'ui_kit.dart';
import 'tournament_page.dart';
import 'player_statistics_page.dart';
import 'team_hub.dart';
import 'app_services.dart';
import 'scenario_page.dart';
import 'command_center_page.dart';

const fhrCupLogo='https://img.fhr.ru/tournaments/b6/ef/25008909.webp';

class JuniorApp extends StatefulWidget {
  const JuniorApp({super.key});
  @override State<JuniorApp> createState()=>_JuniorAppState();
}
class _JuniorAppState extends State<JuniorApp>{
  bool light=true;
  @override void initState(){
    super.initState();
    CupUi.light=true;
    SharedPreferences.getInstance().then((p){
      if(mounted){
        setState((){
          light=p.getBool('junior_u16_reference_theme_migrated')==true
            ?(p.getBool('junior_u16_light_theme')??true):true;
          CupUi.light=light;
        });
        if(p.getBool('junior_u16_reference_theme_migrated')!=true){
          p.setBool('junior_u16_light_theme',true);
          p.setBool('junior_u16_reference_theme_migrated',true);
        }
      }
    });
  }
  void switchTheme(){
    setState((){light=!light;CupUi.light=light;});
    SharedPreferences.getInstance().then((p)=>p.setBool('junior_u16_light_theme',light));
  }
  @override Widget build(BuildContext context){
    CupUi.light=light;
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:CupUi.navy,statusBarIconBrightness:Brightness.light,
      systemNavigationBarColor:Colors.white,systemNavigationBarIconBrightness:Brightness.dark));
    final brightness=light?Brightness.light:Brightness.dark;
    return MaterialApp(
      debugShowCheckedModeBanner:false,title:'JUNIOR U16 · Кубок России',
      themeAnimationDuration:const Duration(milliseconds:480),
      themeAnimationCurve:Curves.easeInOutCubic,
      theme:ThemeData(
        useMaterial3:true,brightness:brightness,fontFamily:'ArenaSans',
        scaffoldBackgroundColor:CupUi.background,
        colorScheme:ColorScheme.fromSeed(seedColor:CupUi.red,brightness:brightness).copyWith(
          primary:CupUi.red,onPrimary:Colors.white,
          secondary:CupUi.ice,surface:CupUi.surface,
          onSurface:CupUi.white,error:const Color(0xFFFF8274)),
        appBarTheme:AppBarTheme(backgroundColor:CupUi.navy,
          foregroundColor:Colors.white,surfaceTintColor:Colors.transparent,
          centerTitle:false,toolbarHeight:62,
          titleTextStyle:const TextStyle(fontFamily:'ArenaCondensed',color:Colors.white,fontSize:22,fontWeight:FontWeight.w700,letterSpacing:.6)),
        dividerColor:CupUi.stroke,
        splashColor:CupUi.ice.withValues(alpha:.08),
        highlightColor:CupUi.ice.withValues(alpha:.05),
        textTheme:ThemeData(brightness:brightness).textTheme.apply(
          fontFamily:'ArenaSans',bodyColor:CupUi.white,displayColor:CupUi.white),
        inputDecorationTheme:InputDecorationTheme(
          filled:true,fillColor:CupUi.raised,
          hintStyle:TextStyle(color:CupUi.dim,fontSize:13),
          labelStyle:TextStyle(color:CupUi.muted,fontSize:13),
          contentPadding:const EdgeInsets.symmetric(horizontal:15,vertical:14),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(13),
            borderSide:BorderSide(color:CupUi.stroke)),
          enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(13),
            borderSide:BorderSide(color:CupUi.stroke)),
          focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(13),
            borderSide:BorderSide(color:CupUi.red,width:1.5))),
        cardTheme:CardThemeData(color:CupUi.surface,elevation:0,
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15),
            side:BorderSide(color:CupUi.stroke))),
        dialogTheme:DialogThemeData(
          backgroundColor:CupUi.surface,surfaceTintColor:Colors.transparent,
          elevation:0,alignment:Alignment.center,
          titleTextStyle:TextStyle(fontFamily:'ArenaCondensed',color:CupUi.white,
            fontSize:24,fontWeight:FontWeight.w700,letterSpacing:.3),
          contentTextStyle:TextStyle(fontFamily:'ArenaSans',color:CupUi.soft,
            fontSize:12,height:1.5),
          actionsPadding:const EdgeInsets.fromLTRB(18,4,18,16),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20))),
        bottomSheetTheme:BottomSheetThemeData(
          backgroundColor:CupUi.surface,surfaceTintColor:Colors.transparent,
          modalBackgroundColor:CupUi.surface,elevation:0,
          shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(
            top:Radius.circular(22))),
          showDragHandle:true,dragHandleColor:CupUi.muted,
          dragHandleSize:const Size(38,4)),
        snackBarTheme:SnackBarThemeData(backgroundColor:CupUi.raised,
          contentTextStyle:TextStyle(color:CupUi.white,fontSize:12,fontWeight:FontWeight.w700),
          behavior:SnackBarBehavior.floating,
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13))),
        progressIndicatorTheme:ProgressIndicatorThemeData(color:CupUi.red,
          linearTrackColor:CupUi.stroke,circularTrackColor:CupUi.stroke),
        pageTransitionsTheme:const PageTransitionsTheme(builders:{
          TargetPlatform.android:FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS:FadeUpwardsPageTransitionsBuilder(),
        }),
        tabBarTheme:TabBarThemeData(labelColor:CupUi.white,unselectedLabelColor:CupUi.muted,
          indicatorColor:CupUi.red,dividerColor:CupUi.stroke,
          labelStyle:const TextStyle(fontSize:12,fontWeight:FontWeight.w800),
          indicatorSize:TabBarIndicatorSize.label),
        filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(
          backgroundColor:CupUi.red,foregroundColor:Colors.white,
          textStyle:const TextStyle(fontWeight:FontWeight.w800),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(7)),
          padding:const EdgeInsets.symmetric(horizontal:18,vertical:13))),
        textButtonTheme:TextButtonThemeData(style:TextButton.styleFrom(
          foregroundColor:CupUi.red,
          textStyle:const TextStyle(fontFamily:'ArenaSans',fontWeight:FontWeight.w900,
            fontSize:11,letterSpacing:.2),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
          padding:const EdgeInsets.symmetric(horizontal:13,vertical:11))),
        outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(
          foregroundColor:CupUi.white,side:BorderSide(color:CupUi.stroke),
          textStyle:const TextStyle(fontWeight:FontWeight.w800),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(7)),
          padding:const EdgeInsets.symmetric(horizontal:18,vertical:12))),
        iconButtonTheme:IconButtonThemeData(style:IconButton.styleFrom(
          foregroundColor:CupUi.soft,highlightColor:CupUi.ice.withValues(alpha:.12))),
      ),
      home:ScoresHome(light:light,onSwitchTheme:switchTheme),
    );
  }
}
class ScoresHome extends StatefulWidget{
  final bool light;
  final VoidCallback onSwitchTheme;
  const ScoresHome({super.key,required this.light,required this.onSwitchTheme});
  @override State<ScoresHome> createState()=>_ScoresHomeState();
}

class _ScoresHomeState extends State<ScoresHome> with WidgetsBindingObserver{
  final api=FhrApiClient(http.Client());
  Timer? timer;
  bool foreground=true;
  final visited=<int>{0};
  int tab=0,filter=0;
  final dateScroll=ScrollController();
  bool loading=false,loadingTeams=false,cached=false,dateFilter=false;
  DateTime date=DateTime.now().toUtc().add(Duration(hours:3));
  DateTime? updatedAt;
  String? error,teamError;
  String search='';
  List<Match> games=[];
  List<TeamInfo> clubs=[];
  Set<String> favorites={};
  static const filters=['ВСЕ','LIVE','РЕЗУЛЬТАТЫ','РАСПИСАНИЕ'];
  @override void initState(){
    super.initState();WidgetsBinding.instance.addObserver(this);
    _loadLocal().then((_){refresh();loadClubs();});
    _startPolling();
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    foreground=state==AppLifecycleState.resumed;
    timer?.cancel();
    if(foreground){refresh();loadClubs();_startPolling();}
  }
  void _startPolling(){
    timer?.cancel();
    timer=Timer.periodic(const Duration(seconds:25),(_){
      if(foreground && (ModalRoute.of(context)?.isCurrent??true))refresh();
    });
  }
  void selectTab(int value){
    setState((){tab=value;visited.add(value);});
    SharedPreferences.getInstance().then((p)=>p.setInt('junior_tab',value));
  }
  @override void dispose(){
    timer?.cancel();dateScroll.dispose();WidgetsBinding.instance.removeObserver(this);api.client.close();super.dispose();
  }

  Future<void> _loadLocal() async {
    try{
      final p=await SharedPreferences.getInstance();
      final f=p.getStringList('junior_favorites')??[];
      final savedTab=(p.getInt('junior_tab')??0).clamp(0,5);
      final savedClubs=await FeedCache.read('/api/v1/teams');
      if(!mounted)return;
      setState((){tab=savedTab;visited.add(tab);
        if(savedClubs?['teams'] is List)clubs=(savedClubs!['teams'] as List).whereType<Map>().map((t)=>TeamInfo.fromApi(Map<String,dynamic>.from(t))).toList();
      });
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
      final partial=feed.issues.isNotEmpty||
        (indexed.isEmpty&&games.isNotEmpty);
      final rows=reconcileCalendar(games,indexed.values.toList(),partial:partial)
        ..sort((a,b){final d=b.date.compareTo(a.date);
          return d!=0?d:b.timeMsk.compareTo(a.timeMsk);});
      if(!mounted)return;
      setState((){
        games=rows;updatedAt=feed.updatedAt;cached=false;error=feed.issues.isEmpty?null:
          'Данные ФХР частичные: ${feed.issues.first}';
      });
      final p=await SharedPreferences.getInstance();
      await p.setString('junior_u16_calendar_v9',jsonEncode(FhrFeed(rows,feed.updatedAt,feed.issues,feed.groupsFetched,feed.allStagesComplete,feed.expectedMatchCount).toCache()));
    }catch(e){
      Diagnostics.record('calendar',e);
      if(mounted)setState((){cached=games.isNotEmpty;error='Не удалось обновить данные. Проверь интернет и повтори.';});
    }finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> loadClubs() async {
    if(loadingTeams)return;
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
  void openCommandCenter()=>Navigator.of(context).push(MaterialPageRoute(
    builder:(_)=>CommandCenterPage(matches:games,clubs:clubs,
      onTeam:(name){final club=findClub(name);if(club!=null)openClub(club);},
      onMatch:openMatch)));
  void openMatch(Match m)=>Navigator.of(context).push(MaterialPageRoute(
    builder:(_)=>MatchCenterPage(match:m,homeTeam:findClub(m.home),awayTeam:findClub(m.away),matches:games)));
  void openClub(TeamInfo t)=>Navigator.of(context).push(MaterialPageRoute(
    builder:(_)=>TeamHubPage(team:t,matches:games,teams:clubs)));
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
    final t=updatedAt!.toUtc().add(Duration(hours:3));
    return 'ФХР · ${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')} МСК';
  }

  Widget _header()=>Container(color:CupUi.navy,child:SafeArea(bottom:false,
    child:Padding(padding:const EdgeInsets.fromLTRB(17,13,9,13),child:Row(children:[
      Container(width:39,height:39,alignment:Alignment.center,
        decoration:BoxDecoration(color:CupUi.signal,borderRadius:BorderRadius.circular(11)),
        child:const Text('16',style:TextStyle(color:CupUi.navy,
          fontFamily:'ArenaCondensed',fontSize:25,fontWeight:FontWeight.w700))),
      const SizedBox(width:10),
      const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('JUNIOR',style:TextStyle(color:Colors.white,
          fontFamily:'ArenaCondensed',fontSize:24,fontWeight:FontWeight.w700,height:1)),
        SizedBox(height:3),
        Text('КУБОК РОССИИ  /  26·27',maxLines:1,overflow:TextOverflow.ellipsis,
          style:TextStyle(color:Color(0xFFACCCD2),fontSize:8,fontWeight:FontWeight.w800)),
      ])),
      IconButton(tooltip:'Прогнозы',onPressed:()=>Navigator.push(context,
        MaterialPageRoute(builder:(_)=>ScenarioPage(matches:games,
          teams:clubs.map((t)=>t.fullName).toList(),
          teamLogos:{for(final t in clubs)t.fullName:t.logo}))),
        icon:const Icon(Icons.auto_graph_rounded,color:Colors.white)),
      IconButton(tooltip:'Команды',onPressed:()=>selectTab(4),
        icon:const Icon(Icons.search_rounded,color:Colors.white)),
      PopupMenuButton<String>(tooltip:'Разделы',icon:const Icon(Icons.more_vert,
        color:Colors.white),color:CupUi.surface,onSelected:(value){
          if(value=='players')selectTab(3);
          if(value=='teams')selectTab(4);
          if(value=='command')openCommandCenter();
          if(value=='settings')Navigator.push(context,MaterialPageRoute(builder:(_)=>const AppSettingsPage()));
          if(value=='theme')widget.onSwitchTheme();
          if(value=='refresh')refresh();
        },itemBuilder:(_)=>const [
          PopupMenuItem(value:'players',child:Text('Игроки')),
          PopupMenuItem(value:'teams',child:Text('Команды')),
          PopupMenuItem(value:'command',child:Text('Command Center')),
          PopupMenuItem(value:'theme',child:Text('Сменить тему')),
          PopupMenuItem(value:'settings',child:Text('Настройки')),
          PopupMenuItem(value:'refresh',child:Text('Обновить ФХР')),
        ]),
    ]))));
  Widget _syncBar()=>Container(
    padding:const EdgeInsets.fromLTRB(16,9,16,10),
    decoration:BoxDecoration(color:CupUi.surface,
      border:Border(bottom:BorderSide(color:CupUi.stroke.withValues(alpha:.5)))),
    child:Row(children:[
      if(loading)SizedBox(width:10,height:10,child:CircularProgressIndicator(
        strokeWidth:1.7,color:CupUi.ice))
      else Container(width:7,height:7,decoration:BoxDecoration(shape:BoxShape.circle,
        color:cached?CupUi.yellow:(error==null?CupUi.green:CupUi.yellow))),
      const SizedBox(width:8),
      Expanded(child:Text(cached?'КЭШ · ${refreshTime()}':refreshTime(),
        maxLines:1,overflow:TextOverflow.ellipsis,
        style:TextStyle(color:CupUi.soft,fontSize:10,fontWeight:FontWeight.w700))),
      Container(width:1,height:13,color:CupUi.stroke),
      const SizedBox(width:9),
      Text('${games.length} ИГР  /  ${clubs.length} КЛУБОВ',
        style:TextStyle(color:CupUi.muted,fontSize:9,fontWeight:FontWeight.w900,
          letterSpacing:.25)),
    ]),
  );

  Widget _nav()=>SafeArea(top:false,child:Container(
    padding:const EdgeInsets.fromLTRB(6,7,6,4),
    decoration:const BoxDecoration(color:CupUi.navy,
      borderRadius:BorderRadius.vertical(top:Radius.circular(18))),
    child:Row(children:[
      _bottomItem('Матчи',Icons.sports_hockey_rounded,tab==0,(){
        setState((){filter=0;dateFilter=false;});selectTab(0);
      }),
      _bottomItem('LIVE',Icons.sensors_rounded,tab==1&&filter==1,(){
        setState((){filter=1;dateFilter=false;});selectTab(1);
      }),
      _bottomItem('Избранное',Icons.star_outline_rounded,tab==5,()=>selectTab(5)),
      _bottomItem('Турниры',Icons.emoji_events_outlined,tab==2,()=>selectTab(2)),
    ])));
  Widget _bottomItem(String label,IconData icon,bool selected,VoidCallback tap)=>
    Expanded(child:InkWell(onTap:tap,borderRadius:BorderRadius.circular(12),child:Padding(
      padding:const EdgeInsets.symmetric(vertical:5),child:Column(
        mainAxisSize:MainAxisSize.min,children:[
        Container(width:46,height:34,alignment:Alignment.center,
          decoration:BoxDecoration(color:selected?CupUi.signal:Colors.transparent,
            borderRadius:BorderRadius.circular(11)),
          child:Icon(icon,size:21,color:selected?CupUi.navy:const Color(0xFFA5C0C8))),
        const SizedBox(height:2),
        Text(label,maxLines:1,overflow:TextOverflow.ellipsis,
          style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,
            color:selected?CupUi.signal:const Color(0xFFA5C0C8))),
      ]))));

  Widget _filterChip(String text,bool active,VoidCallback tap)=>InkWell(
    onTap:tap,borderRadius:BorderRadius.circular(99),
    child:AnimatedContainer(duration:Duration(milliseconds:150),
      margin:EdgeInsets.only(right:8),
      padding:EdgeInsets.symmetric(horizontal:15,vertical:10),
      decoration:BoxDecoration(
        color:active?CupUi.red:CupUi.surface,
        borderRadius:BorderRadius.circular(99),
        border:Border.all(color:active?CupUi.red:CupUi.stroke)),
      child:Text(text,style:TextStyle(fontSize:10,letterSpacing:.3,
        color:active?Colors.white:CupUi.muted,fontWeight:FontWeight.w800))),
  );

  Widget _dateSelector(){
    final now=DateTime.now().toUtc().add(const Duration(hours:3));
    return Container(height:68,color:CupUi.surface,child:Row(children:[
      Expanded(child:ListView.builder(scrollDirection:Axis.horizontal,
        controller:dateScroll,itemCount:14,itemBuilder:(context,i){
        if(i==0)return InkWell(onTap:()=>setState(()=>dateFilter=false),
          child:Container(width:65,alignment:Alignment.center,
            margin:const EdgeInsets.symmetric(vertical:7,horizontal:2),
            decoration:BoxDecoration(color:!dateFilter?CupUi.redMuted:Colors.transparent,
              borderRadius:BorderRadius.circular(9)),
            child:Text('ВСЕ\nДАТЫ',textAlign:TextAlign.center,
              style:TextStyle(color:!dateFilter?CupUi.red:CupUi.muted,
                fontWeight:FontWeight.w900,fontSize:10))));
        final day=now.add(Duration(days:i-7));
        final active=dateFilter&&date.year==day.year&&
          date.month==day.month&&date.day==day.day;
        final today=i==7;
        return InkWell(onTap:()=>setState((){date=day;dateFilter=true;}),
          child:Container(width:65,alignment:Alignment.center,
            margin:const EdgeInsets.symmetric(vertical:7,horizontal:2),
            decoration:BoxDecoration(color:active?CupUi.navy:Colors.transparent,
              borderRadius:BorderRadius.circular(9)),
            child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
              Text(today?'СЕГОДНЯ':weekday(day),maxLines:1,
                style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,
                  color:active?CupUi.signal:CupUi.muted)),
              const SizedBox(height:4),
              Text('${shortDate(day)}.',style:TextStyle(color:active?Colors.white:CupUi.muted,
                fontSize:11,fontWeight:FontWeight.w700)),
            ])));
      })),
      IconButton(tooltip:'Выбрать дату',icon:Icon(Icons.calendar_month_outlined,
        color:CupUi.white,size:21),onPressed:()async{
        final selected=await showDatePicker(context:context,
          firstDate:DateTime(2026,8,1),lastDate:DateTime(2027,12,31),
          initialDate:date.isBefore(DateTime(2026,8,1))?DateTime(2026,9,10):date);
        if(selected!=null&&mounted)setState((){date=selected;dateFilter=true;});
      }),
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
    return InkWell(onTap:()=>openMatch(game),child:Container(
      margin:const EdgeInsets.fromLTRB(12,3,12,3),
      padding:const EdgeInsets.fromLTRB(10,10,13,10),
      decoration:BoxDecoration(color:CupUi.surface,
        borderRadius:BorderRadius.circular(13),
        border:Border.all(color:game.isLive?CupUi.red.withValues(alpha:.55):CupUi.stroke)),
      child:Row(children:[
        SizedBox(width:36,child:IconButton(tooltip:'Избранное',
          padding:EdgeInsets.zero,onPressed:()=>toggleFavorite(game),
          icon:Icon(favorites.contains(game.key)?Icons.star_rounded:
            Icons.star_border_rounded,size:25,
            color:favorites.contains(game.key)?CupUi.gold:CupUi.dim))),
        const SizedBox(width:7),
        Expanded(child:Column(children:[
          _matchTeamRow(game.home,h?.logo,goals?[0],game.finished||game.isLive),
          const SizedBox(height:6),
          _matchTeamRow(game.away,a?.logo,goals?[1],game.finished||game.isLive),
          const SizedBox(height:8),
          Row(children:[
            Text(game.isLive?'● LIVE':game.finished?'● ЗАВЕРШЁН':'○ ПО РАСПИСАНИЮ',
              style:TextStyle(color:game.isLive?CupUi.red:CupUi.muted,
                fontSize:9,fontWeight:FontWeight.w800)),
            const Spacer(),
            Text('${game.dayLabel}  ·  ${game.timeMsk}',
              style:TextStyle(color:CupUi.muted,fontSize:10,fontWeight:FontWeight.w700)),
          ]),
        ])),
      ])));
  }
  Widget _matchTeamRow(String name,String? logo,int? goals,bool scored)=>Row(children:[
    fhrTeamLogo(logo,size:22),const SizedBox(width:9),
    Expanded(child:Text(name,maxLines:1,overflow:TextOverflow.ellipsis,
      style:TextStyle(color:CupUi.white,fontSize:13,fontWeight:FontWeight.w700))),
    if(scored)Text('${goals??'–'}',style:TextStyle(
      color:CupUi.white,fontSize:15,fontWeight:FontWeight.w900,
      fontFamily:'monospace')),
  ]);

  Widget _leagueBlock(String label,List<Match> list)=>Column(children:[
    Container(color:CupUi.raised,padding:const EdgeInsets.fromLTRB(18,9,15,9),
      child:Row(children:[
        Container(width:26,height:26,alignment:Alignment.center,
          decoration:BoxDecoration(color:CupUi.navy,borderRadius:BorderRadius.circular(7)),
          child:const Icon(Icons.sports_hockey_rounded,color:CupUi.signal,size:17)),
        const SizedBox(width:9),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('КУБОК РОССИИ · U16',style:TextStyle(
            color:CupUi.muted,fontSize:9,fontWeight:FontWeight.w800)),
          Text(label,style:TextStyle(color:CupUi.white,
            fontFamily:'ArenaCondensed',fontSize:17,fontWeight:FontWeight.w700)),
        ])),
        Text('${list.length}',style:TextStyle(color:CupUi.white,
          fontSize:11,fontWeight:FontWeight.w800)),
      ])),
    for(final m in list)_matchLine(m),
  ]);

  Widget _filters()=>SingleChildScrollView(scrollDirection:Axis.horizontal,
    padding:EdgeInsets.fromLTRB(13,8,8,10),
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
    final now=DateTime.now().toUtc().add(const Duration(hours:3));
    final today=games.where((m){final d=m.matchDate;
      return d!=null&&d.year==now.year&&d.month==now.month&&d.day==now.day;
    }).toList();
    final live=today.where((m)=>m.isLive).length;
    final complete=today.where((m)=>m.finished).length;
    return RefreshIndicator(onRefresh:refresh,child:ListView(
      key:const PageStorageKey('home'),children:[
      CupArena(margin:const EdgeInsets.fromLTRB(12,12,12,8),
        padding:const EdgeInsets.fromLTRB(18,16,18,17),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            const Expanded(child:Text('КУБОК РОССИИ',style:TextStyle(
              fontFamily:'ArenaCondensed',color:Colors.white,fontSize:27,
              fontWeight:FontWeight.w700,letterSpacing:.5))),
            Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
              decoration:BoxDecoration(color:CupUi.signal,
                borderRadius:BorderRadius.circular(6)),
              child:const Text('U16  /  26·27',style:TextStyle(
                color:CupUi.navy,fontSize:10,fontWeight:FontWeight.w900))),
          ]),
          const SizedBox(height:5),
          const Text('ЛЕДОВАЯ СВОДКА  ·  ОБНОВЛЯЕТСЯ С ФХР',
            style:TextStyle(color:Color(0xFFAACCD2),fontSize:9,
              fontWeight:FontWeight.w700,letterSpacing:.8)),
          const SizedBox(height:16),
          Row(children:[
            _pulseMetric('$live','LIVE',CupUi.signal),
            const SizedBox(width:23),
            _pulseMetric('$complete','ЗАВЕРШЕНО',Colors.white),
            const SizedBox(width:23),
            _pulseMetric('${today.length}','СЕГОДНЯ',Colors.white),
          ]),
          const SizedBox(height:15),
          Row(children:[
            Expanded(child:_pulseLink('ТАБЛИЦА LIVE',Icons.leaderboard_outlined,openCommandCenter)),
            const SizedBox(width:8),
            Expanded(child:_pulseLink('ПРЕДИКТЫ',Icons.auto_graph_rounded,()=>Navigator.push(context,
              MaterialPageRoute(builder:(_)=>ScenarioPage(matches:games,
                teams:clubs.map((t)=>t.fullName).toList(),
                teamLogos:{for(final t in clubs)t.fullName:t.logo}))))),
          ]),
        ])),
      CupSection(title:'МАТЧИ',subtitle:dateFilter?'Выбранный день · ${shortDate(date)}':'Все опубликованные игры'),
      if(recent.isEmpty)CupMessage(icon:Icons.sports_hockey,
        title:games.isEmpty?'Загружаю матчи':'Матчей за этот день нет',
        message:'Выбери другую дату или нажми «Все даты».',retry:refresh),
      for(final block in _gamesGrouped(recent,limit:40))block,
      if(recent.length>40)TextButton(onPressed:()=>selectTab(1),
        child:const Text('ПОКАЗАТЬ ВСЕ МАТЧИ')),
      const SizedBox(height:20),
    ]));
  }

  Widget _pulseMetric(String value,String label,Color color)=>Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(value,style:TextStyle(color:color,fontFamily:'ArenaCondensed',
        fontSize:25,fontWeight:FontWeight.w700,height:1)),
      const SizedBox(height:3),
      Text(label,style:const TextStyle(color:Color(0xFFAACCD2),
        fontSize:9,fontWeight:FontWeight.w800)),
    ]);
  Widget _pulseLink(String label,IconData icon,VoidCallback tap)=>InkWell(
    onTap:tap,borderRadius:BorderRadius.circular(8),child:Container(
      padding:const EdgeInsets.symmetric(horizontal:9,vertical:10),
      decoration:BoxDecoration(border:Border.all(color:Colors.white24),
        borderRadius:BorderRadius.circular(8)),
      child:Row(children:[
        Icon(icon,color:CupUi.signal,size:17),const SizedBox(width:6),
        Expanded(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,
          style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w800))),
      ])));

  Widget _matchesPage()=>RefreshIndicator(onRefresh:refresh,child:ListView(key:const PageStorageKey('matches'),children:[
    CupSection(title:'ВСЕ МАТЧИ',subtitle:'Календарь Кубка России U16'),
    _filters(),
    if(filtered().isEmpty)CupMessage(icon:Icons.calendar_month_outlined,title:'Ничего не найдено',
      message:'Выбери другую дату или другой тип матчей.',retry:refresh),
    for(final block in _gamesGrouped(filtered()))block,
    SizedBox(height:24),
  ]));

  Widget _standingPage()=>TournamentPage(
    matches:games,
    teams:clubs.map((team)=>team.fullName),
    teamLogo:(name)=>findClub(name)?.logo,
    onTeam:(name){
      final club=findClub(name);
      if(club!=null)openClub(club);
    },
    onMatch:openMatch,
  );

  Widget _teamPage(){
    final list=clubs.where((x)=>x.fullName.toLowerCase().contains(search.toLowerCase())).toList();
    return RefreshIndicator(onRefresh:loadClubs,child:ListView(children:[
      CupSection(title:'УЧАСТНИКИ',subtitle:'${clubs.length} клубов с официальными составами ФХР'),
      Padding(padding:EdgeInsets.fromLTRB(12,0,12,12),
        child:TextField(onChanged:(v)=>setState(()=>search=v),
          style:TextStyle(fontSize:13),
          decoration:InputDecoration(
            prefixIcon:Icon(Icons.search,color:CupUi.muted),
            hintText:'Найти команду',hintStyle:TextStyle(color:CupUi.dim),
            filled:true,fillColor:CupUi.surface,
            contentPadding:EdgeInsets.symmetric(horizontal:13,vertical:11),
            enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(11),
              borderSide:BorderSide(color:CupUi.stroke)),
            focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(11),
              borderSide:BorderSide(color:CupUi.red))))),
      if(loadingTeams&&clubs.isEmpty)Padding(padding:EdgeInsets.all(28),
        child:Center(child:CircularProgressIndicator())),
      if(teamError!=null)Padding(padding:EdgeInsets.all(15),
        child:Text(teamError!,style:TextStyle(color:CupUi.yellow,fontSize:11))),
      CupCard(padding:EdgeInsets.symmetric(vertical:4),child:Column(children:[
        for(var i=0;i<list.length;i++)...[
          InkWell(onTap:()=>openClub(list[i]),
            child:Padding(padding:EdgeInsets.symmetric(horizontal:12,vertical:11),
              child:Row(children:[
                fhrTeamLogo(list[i].logo,size:40),SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(list[i].name,style:TextStyle(color:CupUi.white,
                    fontSize:13,fontWeight:FontWeight.w800)),
                  SizedBox(height:3),
                  Text(list[i].city,style:TextStyle(color:CupUi.muted,fontSize:11)),
                ])),
                Icon(Icons.chevron_right_rounded,color:CupUi.dim,size:19),
              ]))),
          if(i+1<list.length)CupDiv(indent:60),
        ],
      ])),
      if(clubs.isEmpty&&!loadingTeams)CupMessage(title:'Команды не загружены',
        message:'Данные клуба и фото игроков берутся только из ФХР Джуниор.',retry:loadClubs),
      SizedBox(height:24),
    ]));
  }

  Widget _favoritesPage(){
    final list=games.where((e)=>favorites.contains(e.key)).toList();
    return RefreshIndicator(onRefresh:refresh,child:ListView(children:[
      CupSection(title:'ИЗБРАННЫЕ МАТЧИ',subtitle:'${list.length} сохранено на этом устройстве'),
      if(list.isEmpty)CupMessage(
        icon:Icons.star_border_rounded,title:'Избранное пока пусто',
        message:'Нажимай на звёздочку возле матча. Он появится здесь и останется после перезапуска.'),
      for(final block in _gamesGrouped(list))block,
      SizedBox(height:20),
    ]));
  }

  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:CupUi.background,
    body:Column(children:[
      _header(),
      if(tab==0||tab==1)_dateSelector(),
      _syncBar(),
      if(error!=null)MaterialBanner(content:Text(error!,style:const TextStyle(fontSize:12)),actions:[TextButton(onPressed:loading?null:refresh,child:const Text('Повторить'))]),
      Expanded(child:IndexedStack(index:tab,children:[
        games.isEmpty&&loading?const LoadingCards():_homePage(),
        visited.contains(1)?_matchesPage():const SizedBox.shrink(),
        visited.contains(2)?_standingPage():const SizedBox.shrink(),
        visited.contains(3)?const PlayerStatisticsPage():const SizedBox.shrink(),
        visited.contains(4)?_teamPage():const SizedBox.shrink(),
        visited.contains(5)?_favoritesPage():const SizedBox.shrink(),
      ])),
    ]),
    bottomNavigationBar:_nav(),
  );
}


