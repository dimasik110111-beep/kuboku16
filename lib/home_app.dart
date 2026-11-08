import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
import 'my_team.dart';
import 'scenario_page.dart';
import 'command_center_page.dart';

const fhrCupLogo='https://img.fhr.ru/tournaments/b6/ef/25008909.webp';

class JuniorApp extends StatefulWidget {
  const JuniorApp({super.key});
  @override State<JuniorApp> createState()=>_JuniorAppState();
}
class _JuniorAppState extends State<JuniorApp>{
  bool light=false;
  @override void initState(){
    super.initState();
    CupUi.light=false;
    SharedPreferences.getInstance().then((p){
      if(mounted){
        setState((){
          light=p.getBool('junior_u16_light_theme')??false;
          CupUi.light=light;
        });
      }
    });
  }
  void switchTheme(){
    setState((){light=!light;CupUi.light=light;});
    SharedPreferences.getInstance().then((p)=>p.setBool('junior_u16_light_theme',light));
  }
  @override Widget build(BuildContext context){
    CupUi.light=light;
    final brightness=light?Brightness.light:Brightness.dark;
    return MaterialApp(
      debugShowCheckedModeBanner:false,title:'JUNIOR U16 · Кубок России',
      themeAnimationDuration:const Duration(milliseconds:480),
      themeAnimationCurve:Curves.easeInOutCubic,
      theme:ThemeData(
        useMaterial3:true,brightness:brightness,fontFamily:'Manrope',
        scaffoldBackgroundColor:CupUi.background,
        colorScheme:ColorScheme.fromSeed(seedColor:CupUi.red,brightness:brightness).copyWith(
          primary:CupUi.red,secondary:CupUi.ice,surface:CupUi.surface,
          onSurface:CupUi.white,error:const Color(0xFFFF6978)),
        appBarTheme:AppBarTheme(backgroundColor:CupUi.background,
          foregroundColor:CupUi.white,surfaceTintColor:Colors.transparent,
          centerTitle:false,toolbarHeight:62,
          titleTextStyle:TextStyle(fontFamily:'Manrope',color:CupUi.white,fontSize:17,fontWeight:FontWeight.w800,letterSpacing:-.3)),
        dividerColor:CupUi.stroke,
        splashColor:CupUi.ice.withValues(alpha:.08),
        highlightColor:CupUi.ice.withValues(alpha:.05),
        textTheme:ThemeData(brightness:brightness).textTheme.apply(
          fontFamily:'Manrope',bodyColor:CupUi.white,displayColor:CupUi.white),
        inputDecorationTheme:InputDecorationTheme(
          filled:true,fillColor:CupUi.raised,
          hintStyle:TextStyle(color:CupUi.dim,fontSize:13),
          labelStyle:TextStyle(color:CupUi.muted,fontSize:13),
          contentPadding:const EdgeInsets.symmetric(horizontal:15,vertical:14),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),
            borderSide:BorderSide(color:CupUi.stroke)),
          enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),
            borderSide:BorderSide(color:CupUi.stroke)),
          focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),
            borderSide:BorderSide(color:CupUi.red,width:1.5))),
        cardTheme:CardThemeData(color:CupUi.surface,elevation:0,
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20),
            side:BorderSide(color:CupUi.stroke))),
        dialogTheme:DialogThemeData(
          backgroundColor:CupUi.surface,surfaceTintColor:Colors.transparent,
          elevation:0,alignment:Alignment.center,
          titleTextStyle:TextStyle(fontFamily:'Manrope',color:CupUi.white,
            fontSize:17,fontWeight:FontWeight.w900,letterSpacing:-.25),
          contentTextStyle:TextStyle(fontFamily:'Manrope',color:CupUi.soft,
            fontSize:12,height:1.5),
          actionsPadding:const EdgeInsets.fromLTRB(18,4,18,16),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(25),
            side:BorderSide(color:CupUi.ice.withValues(alpha:.20)))),
        bottomSheetTheme:BottomSheetThemeData(
          backgroundColor:CupUi.surface,surfaceTintColor:Colors.transparent,
          modalBackgroundColor:CupUi.surface,elevation:0,
          shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(
            top:Radius.circular(26))),
          showDragHandle:true,dragHandleColor:CupUi.muted,
          dragHandleSize:const Size(38,4)),
        snackBarTheme:SnackBarThemeData(backgroundColor:CupUi.raised,
          contentTextStyle:TextStyle(color:CupUi.white,fontSize:12,fontWeight:FontWeight.w700),
          behavior:SnackBarBehavior.floating,
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),
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
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
          padding:const EdgeInsets.symmetric(horizontal:18,vertical:13))),
        textButtonTheme:TextButtonThemeData(style:TextButton.styleFrom(
          foregroundColor:CupUi.red,
          textStyle:const TextStyle(fontFamily:'Manrope',fontWeight:FontWeight.w900,
            fontSize:11,letterSpacing:.2),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
          padding:const EdgeInsets.symmetric(horizontal:13,vertical:11))),
        outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(
          foregroundColor:CupUi.white,side:BorderSide(color:CupUi.stroke),
          textStyle:const TextStyle(fontWeight:FontWeight.w800),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
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
  bool loading=false,loadingTeams=false,cached=false,dateFilter=false;
  DateTime date=DateTime.now().toUtc().add(Duration(hours:3));
  DateTime? updatedAt;
  String? error,teamError;
  String search='';
  List<Match> games=[];
  List<TeamInfo> clubs=[];
  Set<String> favorites={};
  static const filters=['ВСЕ','LIVE','РЕЗУЛЬТАТЫ','РАСПИСАНИЕ'];
  static const sections=[
    (Icons.home_outlined,Icons.home_rounded,'Главная'),
    (Icons.sports_hockey_outlined,Icons.sports_hockey,'Матчи'),
    (Icons.leaderboard_outlined,Icons.leaderboard_rounded,'Турнир'),
    (Icons.bar_chart_outlined,Icons.bar_chart_rounded,'Игроки'),
    (Icons.shield_outlined,Icons.shield_rounded,'Команды'),
    (Icons.star_border_rounded,Icons.star_rounded,'Избранное'),
  ];
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
    timer?.cancel();WidgetsBinding.instance.removeObserver(this);api.client.close();super.dispose();
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

  Widget _header()=>SafeArea(bottom:false,child:Container(
    padding:const EdgeInsets.fromLTRB(15,10,10,10),
    decoration:BoxDecoration(
      color:CupUi.background,
      border:Border(bottom:BorderSide(color:CupUi.stroke.withValues(alpha:.7)))),
    child:Row(children:[
      Container(width:43,height:43,padding:const EdgeInsets.all(5),
        decoration:BoxDecoration(
          gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
            colors:[CupUi.red.withValues(alpha:.55),CupUi.raised]),
          borderRadius:BorderRadius.circular(15),
          border:Border.all(color:CupUi.ice.withValues(alpha:.22)),
          boxShadow:[BoxShadow(color:CupUi.red.withValues(alpha:.20),blurRadius:18)]),
        child:Image.network(fhrCupLogo,fit:BoxFit.contain,
          errorBuilder:(_,__,___)=>Icon(Icons.sports_hockey,color:CupUi.ice))),
      const SizedBox(width:11),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('JUNIOR U16',maxLines:1,overflow:TextOverflow.ellipsis,
          style:TextStyle(color:CupUi.white,letterSpacing:-.55,
            fontWeight:FontWeight.w900,fontSize:19,height:1)),
        const SizedBox(height:6),
        Row(children:[
          Container(width:6,height:6,decoration:BoxDecoration(
            color:error==null?CupUi.green:CupUi.yellow,shape:BoxShape.circle,
            boxShadow:[BoxShadow(color:(error==null?CupUi.green:CupUi.yellow).withValues(alpha:.4),blurRadius:8)])),
          const SizedBox(width:6),
          Flexible(child:Text('ARENA 2.0  /  КУБОК РОССИИ 2026·27',
            maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:CupUi.muted,
              fontWeight:FontWeight.w900,letterSpacing:.85,fontSize:8))),
        ]),
      ])),
      if(games.any((m)=>m.isLive))Padding(padding:const EdgeInsets.only(right:3),
        child:CupTag(text:'LIVE',color:CupUi.green,filled:true)),
      _headerAction(icon:widget.light?Icons.dark_mode_outlined:Icons.light_mode_outlined,
        tooltip:widget.light?'Тёмная тема':'Светлая тема',onTap:widget.onSwitchTheme),
      PopupMenuButton<String>(
        tooltip:'Ещё',icon:Icon(Icons.more_horiz_rounded,color:CupUi.soft,size:23),
        color:CupUi.surface,
        onSelected:(value){
          if(value=='settings')Navigator.push(context,MaterialPageRoute(builder:(_)=>const AppSettingsPage()));
          if(value=='refresh')refresh();
        },
        itemBuilder:(_)=>[
          const PopupMenuItem(value:'settings',child:Row(children:[
            Icon(Icons.tune_rounded),SizedBox(width:12),Text('Настройки')])),
          PopupMenuItem(value:'refresh',child:Row(children:[
            loading?const SizedBox(width:24,height:24,child:CircularProgressIndicator(strokeWidth:2)):
              const Icon(Icons.refresh_rounded),const SizedBox(width:12),const Text('Обновить ФХР')])),
        ]),
    ]),
  ));
  Widget _headerAction({required IconData icon,required String tooltip,VoidCallback? onTap})=>
    IconButton(tooltip:tooltip,onPressed:onTap,visualDensity:VisualDensity.compact,
      constraints:const BoxConstraints.tightFor(width:34,height:34),padding:EdgeInsets.zero,
      style:IconButton.styleFrom(backgroundColor:CupUi.surface,foregroundColor:CupUi.soft,
        side:BorderSide(color:CupUi.stroke),shape:RoundedRectangleBorder(
          borderRadius:BorderRadius.circular(12))),
      icon:Icon(icon,size:18));

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
    margin:const EdgeInsets.fromLTRB(11,2,11,7),
    padding:const EdgeInsets.symmetric(horizontal:3,vertical:5),
    decoration:BoxDecoration(
      gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
        colors:[CupUi.raised,CupUi.surface]),
      borderRadius:BorderRadius.circular(26),
      border:Border.all(color:CupUi.stroke),
      boxShadow:[
        BoxShadow(color:Colors.black.withValues(alpha:.42),blurRadius:32,
          offset:const Offset(0,10)),
        BoxShadow(color:CupUi.red.withValues(alpha:.10),blurRadius:24),
      ]),
    child:Row(children:[
      for(var i=0;i<sections.length;i++)Expanded(child:Semantics(
        button:true,selected:tab==i,label:sections[i].$3,
        child:InkWell(
          onTap:()=>selectTab(i),
          borderRadius:BorderRadius.circular(20),
          child:AnimatedContainer(
            duration:const Duration(milliseconds:290),curve:Curves.easeOutCubic,
            margin:const EdgeInsets.symmetric(horizontal:1,vertical:1),
            padding:const EdgeInsets.symmetric(vertical:8),
            decoration:BoxDecoration(
              gradient:i==tab?LinearGradient(
                begin:Alignment.topLeft,end:Alignment.bottomRight,
                colors:[CupUi.red,CupUi.red.withValues(alpha:.73)]):null,
              borderRadius:BorderRadius.circular(19),
              boxShadow:i==tab?[BoxShadow(color:CupUi.red.withValues(alpha:.25),
                blurRadius:16,offset:const Offset(0,3))]:null),
            child:Column(mainAxisSize:MainAxisSize.min,children:[
              AnimatedSwitcher(
                duration:const Duration(milliseconds:250),
                transitionBuilder:(child,anim)=>ScaleTransition(
                  scale:Tween<double>(begin:.72,end:1).animate(anim),
                  child:FadeTransition(opacity:anim,child:child)),
                child:Icon(i==tab?sections[i].$2:sections[i].$1,
                  key:ValueKey('${i}-${i==tab}'),size:22,
                  color:i==tab?Colors.white:CupUi.muted)),
              const SizedBox(height:4),
              Text(sections[i].$3,maxLines:1,overflow:TextOverflow.ellipsis,
                style:TextStyle(color:i==tab?Colors.white:CupUi.muted,
                  fontSize:8,fontWeight:i==tab?FontWeight.w900:FontWeight.w700)),
            ]),
          )))),
    ]),
  ));

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
    final now=DateTime.now().toUtc().add(Duration(hours:3));
    return Container(color:CupUi.background,
      child:Column(children:[
        Padding(padding:EdgeInsets.fromLTRB(13,10,10,10),
          child:Row(children:[
            Icon(Icons.calendar_month_outlined,color:CupUi.muted,size:18),
            SizedBox(width:8),
            Expanded(child:Text(dateFilter?'ВЫБРАННАЯ ДАТА: ${shortDate(date)}':'ВЫБЕРИ ДЕНЬ МАТЧА',
              style:TextStyle(color:CupUi.soft,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:.5))),
            InkWell(onTap:()=>setState(()=>dateFilter=false),
              child:Padding(padding:EdgeInsets.all(6),
                child:Text('ВСЕ ДАТЫ',style:TextStyle(color:dateFilter?CupUi.red:CupUi.muted,
                  fontSize:10,fontWeight:FontWeight.w800)))),
            SizedBox(width:4),
            IconButton(icon:Icon(Icons.calendar_today_rounded,size:17,color:CupUi.soft),
              onPressed:()async{
                final selected=await showDatePicker(context:context,
                  firstDate:DateTime(2026,8,1),lastDate:DateTime(2027,12,31),
                  initialDate:date.isBefore(DateTime(2026,8,1))?DateTime(2026,9,10):date);
                if(selected!=null&&mounted)setState((){date=selected;dateFilter=true;});
              }),
          ])),
        SizedBox(height:57,child:ListView.builder(
          padding:EdgeInsets.symmetric(horizontal:9),scrollDirection:Axis.horizontal,
          itemCount:11,itemBuilder:(context,i){
            final current=now.add(Duration(days:i-5));
            final active=dateFilter&&current.year==date.year&&current.month==date.month&&current.day==date.day;
            return InkWell(onTap:()=>setState((){date=current;dateFilter=true;}),
              borderRadius:BorderRadius.circular(8),
              child:Container(width:59,margin:EdgeInsets.symmetric(horizontal:2),
                decoration:BoxDecoration(
                  gradient:active?LinearGradient(begin:Alignment.topLeft,
                    end:Alignment.bottomRight,colors:[
                      CupUi.red.withValues(alpha:.95),CupUi.red.withValues(alpha:.48)]):null,
                  color:active?null:CupUi.surface,
                  borderRadius:BorderRadius.circular(15),
                  border:Border.all(color:active
                    ?CupUi.ice.withValues(alpha:.45)
                    :CupUi.stroke.withValues(alpha:.55))),
                child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                  Text(i==5?'СЕГОДНЯ':weekday(current),
                    style:TextStyle(fontSize:i==5?9:10,color:active?Colors.white:CupUi.muted,
                      fontWeight:FontWeight.w800)),
                  SizedBox(height:5),
                  Text(shortDate(current),style:TextStyle(color:active?Colors.white:CupUi.soft,
                    fontSize:11,fontWeight:FontWeight.w800)),
                ])),
            );
          },
        )),
        SizedBox(height:5),
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
      child:Padding(padding:EdgeInsets.fromLTRB(12,11,7,11),
        child:Row(children:[
          SizedBox(width:49,child:Column(children:[
            Row(mainAxisAlignment:MainAxisAlignment.center,children:[
              if(live)...[const CupLivePulse(),const SizedBox(width:3)],
            Text(live?'LIVE':played?'КОН.':game.timeMsk.isNotEmpty?game.timeMsk:'–',
              style:TextStyle(fontWeight:FontWeight.w900,fontSize:11,
                color:live?CupUi.green:(played?CupUi.muted:CupUi.yellow)))]),
            SizedBox(height:6),
            Text(game.dayLabel,style:TextStyle(color:CupUi.dim,fontSize:10)),
          ])),
          Container(height:43,width:3,decoration:BoxDecoration(
            color:live?CupUi.green:(played?CupUi.stroke:CupUi.yellow),
            borderRadius:BorderRadius.circular(4))),
          SizedBox(width:10),
          Expanded(child:Column(children:[
            _teamLine(game.home,h?.logo),
            SizedBox(height:9),
            _teamLine(game.away,a?.logo),
          ])),
          Container(width:43,padding:const EdgeInsets.symmetric(vertical:5),
            decoration:BoxDecoration(color:live?CupUi.green.withValues(alpha:.12):CupUi.raised,
              borderRadius:BorderRadius.circular(11),border:Border.all(
                color:live?CupUi.green.withValues(alpha:.38):CupUi.stroke)),
            child:Column(children:[
              _animatedGoal(goals==null?'–':'${goals[0]}',played||live),
              const SizedBox(height:5),Container(height:1,width:19,color:CupUi.stroke),const SizedBox(height:5),
              _animatedGoal(goals==null?'–':'${goals[1]}',played||live),
            ])),
          IconButton(
            onPressed:()=>toggleFavorite(game),
            tooltip:'Избранное',
            icon:Icon(favorites.contains(game.key)?Icons.star_rounded:Icons.star_border_rounded,
              color:favorites.contains(game.key)?CupUi.yellow:CupUi.dim,size:21)),
        ])));
  }
  Widget _animatedGoal(String value,bool active)=>AnimatedSwitcher(
    duration:const Duration(milliseconds:360),switchInCurve:Curves.easeOutCubic,
    transitionBuilder:(child,animation)=>FadeTransition(opacity:animation,
      child:SlideTransition(position:Tween<Offset>(begin:const Offset(0,.25),end:Offset.zero).animate(animation),child:child)),
    child:Text(value,key:ValueKey(value),style:TextStyle(color:active?CupUi.white:CupUi.soft,
      fontWeight:FontWeight.w900,fontSize:17,height:1)));
  Widget _teamLine(String name,String? logo)=>Row(children:[
    fhrTeamLogo(logo,size:25),SizedBox(width:9),
    Expanded(child:Text(name,maxLines:1,overflow:TextOverflow.ellipsis,
      style:TextStyle(color:CupUi.white,fontSize:12,fontWeight:FontWeight.w800))),
  ]);

  Widget _leagueBlock(String label,List<Match> list)=>CupCard(
    margin:EdgeInsets.fromLTRB(12,5,12,6),
    child:Column(children:[
      Container(
        decoration:BoxDecoration(gradient:LinearGradient(
          begin:Alignment.topLeft,end:Alignment.bottomRight,
          colors:[CupUi.raised,CupUi.surface])),
        padding:EdgeInsets.symmetric(horizontal:13,vertical:13),
        child:Row(children:[
          Container(width:27,height:27,decoration:BoxDecoration(color:CupUi.redMuted,
            borderRadius:BorderRadius.circular(8)),
            child:Icon(Icons.sports_hockey,size:17,color:CupUi.red)),
          SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('РОССИЯ · КУБОК U16',style:TextStyle(color:CupUi.muted,fontSize:9,letterSpacing:.5)),
            SizedBox(height:3),
            Text(label.toUpperCase(),style:TextStyle(color:CupUi.white,fontSize:11,fontWeight:FontWeight.w800)),
          ])),
          CupTag(text:'${list.length}',color:CupUi.soft),
        ])),
      for(var i=0;i<list.length;i++)...[
        _matchLine(list[i]),
        if(i+1<list.length)CupDiv(indent:15),
      ],
    ]),
  );

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

  Widget _homeHero(){
    final completed=games.where((m)=>m.finished).length;
    final progress=games.isEmpty?0.0:completed/games.length;
    final live=games.where((m)=>m.isLive).length;
    return CupArena(
      margin:const EdgeInsets.fromLTRB(12,14,12,10),
      padding:const EdgeInsets.fromLTRB(22,23,22,24),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(width:32,height:32,decoration:BoxDecoration(
            color:Colors.white.withValues(alpha:.10),
            borderRadius:BorderRadius.circular(11),
            border:Border.all(color:Colors.white.withValues(alpha:.12))),
            child:const Icon(Icons.sports_hockey_rounded,color:CupUi.ice,size:19)),
          const SizedBox(width:10),
          const Expanded(child:Text('JUNIOR  /  TOURNAMENT',
            style:TextStyle(color:CupUi.ice,fontSize:10,
              letterSpacing:1.3,fontWeight:FontWeight.w900))),
          CupTag(text:live>0?'● LIVE':'SEASON 26/27',
            color:live>0?CupUi.green:CupUi.ice,filled:true),
        ]),
        const SizedBox(height:27),
        const Text('КУБОК',style:TextStyle(fontSize:43,height:.93,
          letterSpacing:-2.1,fontWeight:FontWeight.w900,color:Colors.white)),
        const Text('РОССИИ',style:TextStyle(fontSize:43,height:1,
          letterSpacing:-2.1,fontWeight:FontWeight.w900,color:Colors.white)),
        const SizedBox(height:12),
        Text('U16  •  20 КОМАНД  •  СЕЗОН 2026/27',
          style:TextStyle(color:CupUi.soft,fontSize:10,fontWeight:FontWeight.w800,
            letterSpacing:.5)),
        const SizedBox(height:25),
        Container(padding:const EdgeInsets.all(13),
          decoration:BoxDecoration(color:Colors.white.withValues(alpha:.07),
            borderRadius:BorderRadius.circular(18),
            border:Border.all(color:Colors.white.withValues(alpha:.1))),
          child:Column(children:[
            Row(children:[
              Text('ТУРНИР В ДВИЖЕНИИ',
                style:TextStyle(color:CupUi.soft,fontSize:9,
                  letterSpacing:.8,fontWeight:FontWeight.w900)),
              const Spacer(),
              Text('${(progress*100).round()}%',style:const TextStyle(
                color:Colors.white,fontSize:15,fontWeight:FontWeight.w900)),
            ]),
            const SizedBox(height:9),
            ClipRRect(borderRadius:BorderRadius.circular(10),
              child:LinearProgressIndicator(value:progress,minHeight:5,
                backgroundColor:Colors.white.withValues(alpha:.13),
                valueColor:const AlwaysStoppedAnimation<Color>(CupUi.ice))),
            const SizedBox(height:9),
            Row(children:[
              Text('${completed} завершено',style:TextStyle(color:CupUi.muted,fontSize:10)),
              const Spacer(),
              Text('${games.length} в календаре',
                style:TextStyle(color:CupUi.muted,fontSize:10)),
            ]),
          ])),
        const SizedBox(height:17),
        Row(children:[
          Expanded(child:FilledButton.icon(
            onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ScenarioPage(
              matches:games,teams:clubs.map((t)=>t.fullName).toList(),
              teamLogos:{for(final t in clubs)t.fullName:t.logo}))),
            style:FilledButton.styleFrom(
              backgroundColor:Colors.white,
              foregroundColor:const Color(0xFF13234A),
              padding:const EdgeInsets.symmetric(horizontal:5,vertical:12)),
            icon:const Icon(Icons.auto_awesome_rounded,size:17),
            label:const Text('ПРЕДИКТЫ',
              style:TextStyle(fontWeight:FontWeight.w900,fontSize:10)))),
          const SizedBox(width:9),
          Expanded(child:OutlinedButton.icon(
            onPressed:()=>selectTab(2),
            style:OutlinedButton.styleFrom(
              foregroundColor:Colors.white,
              side:BorderSide(color:Colors.white.withValues(alpha:.3)),
              padding:const EdgeInsets.symmetric(horizontal:5,vertical:12)),
            icon:const Icon(Icons.leaderboard_rounded,size:17),
            label:const Text('ТАБЛИЦА',
              style:TextStyle(fontWeight:FontWeight.w900,fontSize:10)))),
        ]),
      ]),
    );
  }

  Widget _homePage(){
    final recent=filtered();
    final live=games.where((m)=>m.isLive).toList();
    return RefreshIndicator(onRefresh:refresh,child:ListView(key:const PageStorageKey('home'),children:[
      CupReveal(child:_homeHero()),
      CupArena(margin:const EdgeInsets.fromLTRB(12,4,12,11),
        padding:EdgeInsets.zero,child:Material(color:Colors.transparent,
          child:InkWell(onTap:openCommandCenter,
            borderRadius:BorderRadius.circular(22),
            child:Padding(padding:const EdgeInsets.fromLTRB(18,18,17,19),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  Icon(Icons.radar_rounded,color:CupUi.ice,size:24),
                  const SizedBox(width:10),
                  const Expanded(child:Text('COMMAND CENTER',style:TextStyle(
                    color:Colors.white,fontSize:13,fontWeight:FontWeight.w900,
                    letterSpacing:1))),
                  CupTag(text:'v29',color:CupUi.gold,filled:true),
                ]),
                const SizedBox(height:14),
                const Text('АРЕНА КУБКА.\nПОЛНЫЙ КОНТРОЛЬ.',
                  style:TextStyle(color:Colors.white,fontSize:21,
                    fontWeight:FontWeight.w900,height:1.1)),
                const SizedBox(height:11),
                Text('Прогнозы · Рассев · Аналитика · Мои команды',
                  style:TextStyle(color:CupUi.soft,fontSize:11)),
                const SizedBox(height:16),
                Row(children:[
                  Expanded(child:Container(height:1,
                    color:CupUi.ice.withValues(alpha:.35))),
                  const SizedBox(width:13),
                  const Text('ОТКРЫТЬ АНАЛИТИКУ',style:TextStyle(
                    color:Colors.white,fontSize:10,fontWeight:FontWeight.w900)),
                  const SizedBox(width:7),
               