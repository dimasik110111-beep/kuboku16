import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cup_data.dart';

const navy = Color(0xff11141b);
const panel = Color(0xff1b202b);
const red = Color(0xffef4c60);
const muted = Color(0xffa1a9b8);
const calendarUrl = fhrCalendarUrl;
const tournamentUrl = 'https://junior.fhr.ru/tournaments/kubokrossii-25008909/';
void main() => runApp(const JuniorApp());

const bg2 = Color(0xff151921);
const stroke = Color(0xff2a303b);
const amber = Color(0xffffc75e);
const gold = Color(0xffffd36f);

class JuniorApp extends StatelessWidget {
  const JuniorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'JUNIOR U16',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navy,
      colorScheme: ColorScheme.fromSeed(seedColor: red, brightness: Brightness.dark),
      dividerColor: stroke,
      appBarTheme: const AppBarTheme(backgroundColor: navy, surfaceTintColor: Colors.transparent),
    ),
    home: const HomeScreen(),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int tab = 0;
  int filter = 0;
  bool loading = false;
  bool searchMode = false;
  String search = '';
  DateTime? updated;
  DateTime selectedDate = DateTime.now();
  bool dateFilter = false;
  String? error;
  List<Match> matches = [];
  Timer? timer;
  final FhrApiClient api = FhrApiClient(http.Client());
  List<String> importIssues = [];
  bool allStagesComplete = false;
  int groupsFetched = 0;
  bool fromCache = false;
  String? liveError;
  List<String> get teams {
    final set=<String>{};
    for (final m in matches) {
      if (m.home.isNotEmpty) set.add(m.home);
      if (m.away.isNotEmpty) set.add(m.away);
    }
    return set.toList()..sort((a,b)=>a.compareTo(b));
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadCache().then((_) => refresh());
    timer = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
  }
  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    api.client.close();
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }
  Future<void> loadCache() async {
    try {
      final prefs=await SharedPreferences.getInstance();
      final raw=prefs.getString('junior_u16_calendar_v9');
      if(raw==null)return;
      final decoded=jsonDecode(raw);
      if(decoded is! Map)return;
      final feed=FhrFeed.fromApi(Map<String,dynamic>.from(decoded));
      if(!mounted)return;
      setState(() {
        matches=feed.matches;
        updated=feed.updatedAt;
        groupsFetched=feed.groupsFetched;
        importIssues=['Сохранённые данные: нет свежего подтверждения ФХР'];
        allStagesComplete=false;
        fromCache=true;
      });
    } catch (_) { /* corrupted cache must not crash the application */ }
  }
  Future<void> refresh() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final feed = await api.calendar();
      final byId=<String,Match>{for(final m in feed.matches)m.key:m};
      String? liveWarning;
      try {
        final checked=await api.liveCheck();
        for (final detail in checked) {
          final id=detail['gameId']?.toString();
          if(id==null)continue;
          final current=byId[id];
          if(current!=null)byId[id]=current.withDetail(detail);
        }
      } catch(e) {
        liveWarning='LIVE-статусы временно не проверены: $e';
      }
      final list=byId.values.toList()
        ..sort((a,b){
          final d=b.date.compareTo(a.date);
          return d!=0?d:b.timeMsk.compareTo(a.timeMsk);
        });
      if(!mounted)return;
      setState((){
        matches=list;
        updated=feed.updatedAt ?? DateTime.now().toUtc();
        groupsFetched=feed.groupsFetched;
        importIssues=feed.issues;
        allStagesComplete=feed.allStagesComplete;
        fromCache=false;
        liveError=liveWarning;
        error=null;
      });
      final prefs=await SharedPreferences.getInstance();
      await prefs.setString('junior_u16_calendar_v9',jsonEncode(feed.toCache()));
    }catch(e) {
      if(mounted)setState(()=>error='Не удалось обновить ФХР: $e');
    }finally {
      if(mounted)setState(()=>loading=false);
    }
  }
  Future<void> openFhr(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть сайт ФХР')),
      );
    }
  }
  String fmtTime(DateTime dt) => dt.hour.toString().padLeft(2, '0') + ':' + dt.minute.toString().padLeft(2, '0');
  String fmtDate(DateTime dt) => dt.day.toString().padLeft(2, '0') + '.' + dt.month.toString().padLeft(2, '0');
  String weekday(DateTime dt) => const ['ПН','ВТ','СР','ЧТ','ПТ','СБ','ВС'][dt.weekday-1];
  String groupName(Match match) {
    final s = match.stage.trim();
    return s.isEmpty || s.contains('не установлен') ? 'КУБОК РОССИИ U16' : s.toUpperCase();
  }
  bool isToday(Match m, DateTime dt) {
    final parsed=m.matchDate;
    return parsed!=null && parsed.year==dt.year && parsed.month==dt.month && parsed.day==dt.day;
  }
  List<Match> visibleMatches() {
    var list = matches.where((m) {
      if (filter == 1 && !m.finished) return false;
      if (filter == 2 && m.finished) return false;
      if (search.isNotEmpty &&
          !(m.home + ' ' + m.away + ' ' + m.stage).toLowerCase().contains(search.toLowerCase())) return false;
      if (dateFilter && !isToday(m, selectedDate)) return false;
      return true;
    }).toList();
    list.sort((a,b) => b.date.compareTo(a.date));
    return list;
  }
  Widget pageTitle(String text, {String? subtitle}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 19, 16, 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.4)),
      if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 5),
        child: Text(subtitle, style: const TextStyle(color: muted, fontSize: 12))),
    ]),
  );
  Widget pill(String label, bool active, VoidCallback tap, {IconData? icon}) => GestureDetector(
    onTap: tap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: active ? red : panel,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: active ? red : stroke),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: active ? Colors.white : muted), const SizedBox(width: 5)],
        Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: active ? Colors.white : muted)),
      ]),
    ),
  );
  Widget dateRibbon() {
    final base = DateTime.now().toUtc().add(const Duration(hours:3));
    return Container(color: bg2, padding: const EdgeInsets.fromLTRB(8, 9, 8, 10), child: Row(children: [
      IconButton(onPressed: () => setState(() {dateFilter=false; selectedDate=base;}), icon: const Icon(Icons.calendar_today_outlined, size: 20), tooltip:'Все даты'),
      Expanded(child: SizedBox(height: 58, child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 9,
        itemBuilder: (context,i) {
          final date = base.add(Duration(days:i-4));
          final selected = dateFilter && isSameDay(date, selectedDate);
          return GestureDetector(
            onTap: () => setState(() {selectedDate=date;dateFilter=true;}),
            child: Container(width: 54, margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(color:selected ? panel : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border(bottom:BorderSide(color: selected ? red : Colors.transparent,width:3))),
              child: Column(mainAxisAlignment:MainAxisAlignment.center, children:[
                Text(i==4?'СЕГОДНЯ':weekday(date),style:TextStyle(fontSize:i==4?9:10,color:selected?red:muted,fontWeight:FontWeight.bold)),
                const SizedBox(height:6),
                Text(fmtDate(date),style:TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:selected?Colors.white:muted)),
              ]),
            ),
          );
        },
      ))),
    ]));
  }
  bool isSameDay(DateTime a, DateTime b) => a.year==b.year && a.month==b.month && a.day==b.day;
  Widget syncStatus() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 9),
    decoration: const BoxDecoration(border:Border(bottom:BorderSide(color:stroke))),
    child: Row(children:[
      Container(width:7,height:7,decoration:BoxDecoration(color:loading?amber:(error==null?const Color(0xff58ca90):muted),shape:BoxShape.circle)),
      const SizedBox(width:8),
      Expanded(child:Text(updated==null?'Ожидание ФХР Джуниор':
        '${fromCache?'КЭШ · ':'ФХР · '}${matches.length} игр · ${groupsFetched}/10 групп · ${fmtTime(updated!.toUtc().add(const Duration(hours:3)))} МСК',
        maxLines:1,overflow:TextOverflow.ellipsis,
        style: const TextStyle(fontSize:11,color:muted))),
      if(loading)const SizedBox(width:13,height:13,child:CircularProgressIndicator(strokeWidth:2)),
      GestureDetector(onTap: refresh, child: const Icon(Icons.refresh_rounded,size:19,color:muted)),
    ]),
  );
  Widget matchRow(Match m) => InkWell(
    onTap: () => openMatch(m),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal:15,vertical:12),
      decoration: const BoxDecoration(border:Border(bottom:BorderSide(color:stroke,width:.6))),
      child: Row(children:[
        SizedBox(width:49,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(m.isLive?'LIVE':m.finished?'КОН.':m.timeMsk.isNotEmpty?m.timeMsk:m.dayLabel,
            style: TextStyle(color:m.isLive?red:(m.finished?muted:amber),fontSize:10,fontWeight:FontWeight.w700)),
          const SizedBox(height:6),
          Icon(m.isLive?Icons.radio_button_checked:(m.finished?Icons.check_circle_outline:Icons.schedule_outlined),
            size:15,color:m.isLive?red:muted),
        ])),
        Container(width:2,height:34,color:m.isLive?red:(m.finished?stroke:amber.withValues(alpha:.65))),
        const SizedBox(width:10),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(m.home,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600)),
          const SizedBox(height:9),
          Text(m.away,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600)),
        ])),
        SizedBox(width:53,child:Column(children:[
          Text(m.score.isNotEmpty?m.score:'–',
            maxLines:1,textAlign:TextAlign.center,
            style:TextStyle(fontWeight:FontWeight.w800,fontSize:16,color:m.isLive?red:(m.finished?Colors.white:muted))),
          if(m.scoreNote.isNotEmpty)Text(m.scoreNote,style:const TextStyle(fontSize:9,color:amber)),
        ])),
        const Icon(Icons.chevron_right_rounded,size:18,color:muted),
      ]),
    ),
  );
  Widget leagueSection(String name,List<Match> group) => Container(
    margin:const EdgeInsets.fromLTRB(12,7,12,4),
    decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(12),border:Border.all(color:stroke)),
    clipBehavior:Clip.hardEdge,
    child:Column(children:[
      Container(color:bg2,padding:const EdgeInsets.symmetric(horizontal:13,vertical:13),
        child:Row(children:[
          Container(width:25,height:25,decoration:BoxDecoration(color:const Color(0xff303845),borderRadius:BorderRadius.circular(6)),
            child:const Icon(Icons.sports_hockey,size:16,color:red)),
          const SizedBox(width:9),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('РОССИЯ · U16',style:TextStyle(color:muted,fontSize:10,fontWeight:FontWeight.w600)),
            const SizedBox(height:3),
            Text(name,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800)),
          ])),
          Text(group.length.toString(),style:const TextStyle(color:muted,fontSize:12)),
        ]),
      ),
      for(final m in group)matchRow(m),
    ]),
  );
  Widget emptyState(String title, String desc, {VoidCallback? action}) => Padding(
    padding:const EdgeInsets.fromLTRB(25,48,25,22),
    child:Column(children:[
      Container(width:56,height:56,decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(15)),
        child:const Icon(Icons.sports_hockey,size:30,color:muted)),
      const SizedBox(height:14),
      Text(title,textAlign:TextAlign.center,style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      Text(desc,textAlign:TextAlign.center,style:const TextStyle(fontSize:12,color:muted,height:1.4)),
      if(action!=null)TextButton(onPressed:action,child:const Text('Открыть календарь ФХР')),
    ]),
  );
  Widget matchPage({bool dashboard=false}) {
    final list=visibleMatches();
    final groups=<String,List<Match>>{};
    for(final m in list){groups.putIfAbsent(groupName(m),()=>[]).add(m);}
    return RefreshIndicator(onRefresh:refresh,child:CustomScrollView(slivers:[
      SliverToBoxAdapter(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(dashboard)pageTitle('Хоккей · Кубок России',subtitle:'Сезон 2026/27  •  Юноши до 16 лет'),
        if(!dashboard)pageTitle('Матчи',subtitle:'Официальный календарь ФХР Джуниор'),
        dateRibbon(),
        Padding(padding:const EdgeInsets.fromLTRB(12,13,12,7),child:Row(children:[
          pill('ВСЕ',filter==0,()=>setState(()=>filter=0)),
          const SizedBox(width:7),
          pill('РЕЗУЛЬТАТЫ',filter==1,()=>setState(()=>filter=1)),
          const SizedBox(width:7),
          pill('ПРЕДСТОЯЩИЕ',filter==2,()=>setState(()=>filter=2)),
        ])),
        if(dateFilter)Padding(padding:const EdgeInsets.fromLTRB(12,2,12,4),
          child:TextButton.icon(onPressed:()=>setState(()=>dateFilter=false),
            icon:const Icon(Icons.close,size:15),label:const Text('Показать все даты'))),
        if(error!=null)Padding(padding:const EdgeInsets.all(12),
          child:Text(error!,style:const TextStyle(color:amber,fontSize:12))),
        if(!allStagesComplete && importIssues.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:5),
          child:Text('Проверка данных: ${importIssues.first}',style:const TextStyle(fontSize:11,color:amber))),
        if(liveError!=null && dashboard)Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:5),
          child:Text(liveError!,style:const TextStyle(fontSize:11,color:muted))),
        if(dashboard && matches.any((m)=>m.isLive))
          leagueSection('ПОДТВЕРЖДЁННЫЕ LIVE',matches.where((m)=>m.isLive).toList()),
        if(list.isEmpty)emptyState('Матчи пока не отображаются',
          'ФХР не опубликовала доступные данные или выбранная дата не содержит матчей. Приложение не подставляет вымышленные счета.',
          action:()=>openFhr(calendarUrl)),
        for(final e in groups.entries)leagueSection(e.key,e.value),
        Padding(padding:const EdgeInsets.all(18),child:Center(child:TextButton.icon(
          onPressed:()=>openFhr(calendarUrl),icon:const Icon(Icons.open_in_new,size:17),
          label:const Text('Официальный календарь ФХР')))),
        const SizedBox(height:20),
      ])),
    ]));
  }
  void openMatch(Match m) {
    Navigator.of(context).push(MaterialPageRoute(
      builder:(_)=>FhrMatchDetails(initial:m)));
  }

  Widget rankingPage() {
    final ranks=ranking(matches);
    return RefreshIndicator(onRefresh:refresh,child:ListView(children:[
      pageTitle('Турнирная таблица',subtitle:'20 участников · квалификация'),
      Container(margin:const EdgeInsets.fromLTRB(12,0,12,14),padding:const EdgeInsets.all(13),
        decoration:BoxDecoration(color:const Color(0xff352d27),borderRadius:BorderRadius.circular(10)),
        child:Row(children:[const Icon(Icons.info_outline,size:18,color:amber),const SizedBox(width:10),
          Expanded(child:Text(allStagesComplete
            ? 'Таблица предварительная: учитывает опубликованные результаты всех 10 разделов ФХР. Тай-брейки по регламенту.'
            : 'Предварительно: полнота данных не подтверждена (${groupsFetched}/10 разделов).',
            style:const TextStyle(color:amber,fontSize:11,height:1.4)))])),
      Container(margin:const EdgeInsets.symmetric(horizontal:12),padding:const EdgeInsets.symmetric(horizontal:12,vertical:12),
        color:bg2,child:const Row(children:[
          SizedBox(width:27,child:Text('#',style:TextStyle(color:muted,fontSize:11))),
          Expanded(child:Text('КОМАНДА',style:TextStyle(color:muted,fontSize:11))),
          SizedBox(width:29,child:Text('И',textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:11))),
          SizedBox(width:36,child:Text('РШ',textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:11))),
          SizedBox(width:34,child:Text('О',textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:11))),
        ])),
      if(ranks.isEmpty)emptyState('Таблица ещё не подтверждена',
        'Для итогового рейтинга необходимо получить результаты всех групп и стыковых матчей.',
        action:()=>openFhr(tournamentUrl)),
      for(var i=0;i<ranks.length;i++)Container(
        margin:const EdgeInsets.symmetric(horizontal:12),
        padding:const EdgeInsets.symmetric(horizontal:12,vertical:13),
        decoration:BoxDecoration(color:i.isEven?panel:bg2,border:const Border(bottom:BorderSide(color:stroke,width:.5))),
        child:Row(children:[
          Container(width:27,alignment:Alignment.centerLeft,
            child:Text((i+1).toString(),style:TextStyle(color:i<8?gold:muted,fontWeight:FontWeight.bold,fontSize:12))),
          Expanded(child:Text(ranks[i].team,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12))),
          SizedBox(width:29,child:Text(ranks[i].gp.toString(),textAlign:TextAlign.center,style:const TextStyle(fontSize:12))),
          SizedBox(width:36,child:Text(ranks[i].diff.toString(),textAlign:TextAlign.center,style:const TextStyle(fontSize:12,color:muted))),
          SizedBox(width:34,child:Text(ranks[i].pts.toString(),textAlign:TextAlign.center,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900))),
        ])),
      const SizedBox(height:12),
      TextButton(onPressed:()=>openFhr(tournamentUrl),child:const Text('Проверить таблицу на ФХР')),
    ]));
  }
  Widget teamPage() {
    final names=teams.where((t)=>t.toLowerCase().contains(search.toLowerCase())).toList();
    return ListView(children:[
      pageTitle('Команды',subtitle:'Участники Кубка России U16'),
      Padding(padding:const EdgeInsets.fromLTRB(12,0,12,12),child:TextField(
        onChanged:(v)=>setState(()=>search=v),
        decoration:InputDecoration(prefixIcon:const Icon(Icons.search,color:muted),
          hintText:'Поиск команды',filled:true,fillColor:panel,
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(11),borderSide:BorderSide.none)))),
      for(final name in names)Container(
        margin:const EdgeInsets.fromLTRB(12,0,12,3),
        color:panel,child:ListTile(
          leading:Container(width:36,height:36,decoration:BoxDecoration(color:bg2,borderRadius:BorderRadius.circular(8)),
            child:const Icon(Icons.shield_outlined,color:red,size:21)),
          title:Text(name,style:const TextStyle(fontSize:13,fontWeight:FontWeight.bold)),
          trailing:const Icon(Icons.chevron_right,color:muted,size:20),
          onTap:()=>openTeam(name),
        )),
      const SizedBox(height:20),
    ]);
  }
  void openTeam(String name) => Navigator.of(context).push(MaterialPageRoute(
    builder:(ctx)=>Scaffold(
      appBar:AppBar(title:Text(name)),
      body:ListView(children:[
        Container(color:panel,padding:const EdgeInsets.all(28),child:Column(children:[
          const Icon(Icons.shield_outlined,size:64,color:red),
          const SizedBox(height:12),Text(name,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w800)),
          const Text('Кубок России U16 · 2026/27',style:TextStyle(fontSize:12,color:muted)),
        ])),
        Padding(padding:const EdgeInsets.fromLTRB(16,20,16,8),child:Text('Матчи',style:Theme.of(ctx).textTheme.titleLarge)),
        for(final m in matches.where((x)=>x.home==name||x.away==name))matchRow(m),
        if(!matches.any((x)=>x.home==name||x.away==name))
          emptyState('Нет загруженных матчей','Сведения о клубе и календарь можно проверить на сайте ФХР.',
            action:()=>openFhr(tournamentUrl)),
      ]),
    )));
  Widget statsPage()=>ListView(children:[
    pageTitle('Статистика',subtitle:'Голы, передачи, бомбардиры и вратари'),
    Container(margin:const EdgeInsets.all(12),padding:const EdgeInsets.all(20),
      decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(12)),
      child:Column(children:[
        const Icon(Icons.query_stats_rounded,size:44,color:red),
        const SizedBox(height:14),
        const Text('Официальная статистика ФХР',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
        const SizedBox(height:9),
        const Text('Результаты игроков пока не импортированы. Мы не показываем выдуманные показатели.',
          textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:12,height:1.5)),
        const SizedBox(height:18),
        SizedBox(width:double.infinity,child:FilledButton(
          onPressed:()=>openFhr(tournamentUrl+'stats/'),child:const Text('Открыть статистику ФХР'))),
      ])),
  ]);
  Widget header() => Container(
    decoration:const BoxDecoration(color:navy,border:Border(bottom:BorderSide(color:stroke))),
    child:SafeArea(bottom:false,child:Padding(
      padding:const EdgeInsets.fromLTRB(16,9,9,10),child:Row(children:[
        Container(width:35,height:35,decoration:BoxDecoration(color:red,borderRadius:BorderRadius.circular(8)),
          child:const Icon(Icons.sports_hockey_rounded,size:24,color:Colors.white)),
        const SizedBox(width:11),
        const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('JUNIOR U16',style:TextStyle(fontSize:18,letterSpacing:1,fontWeight:FontWeight.w900)),
          Text('КУБОК РОССИИ  2026/27',style:TextStyle(fontSize:9,color:muted,letterSpacing:1.1)),
        ])),
        IconButton(onPressed:()=>openFhr(calendarUrl),icon:const Icon(Icons.open_in_new_rounded,size:20)),
        IconButton(onPressed:refresh,icon:loading?
          const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))
          :const Icon(Icons.refresh_rounded,size:23)),
      ]),
    )),
  );
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(children:[
        header(),
        syncStatus(),
        Expanded(child:IndexedStack(index:tab,children:[
          matchPage(dashboard:true),matchPage(),rankingPage(),teamPage(),statsPage(),
        ])),
      ]),
      bottomNavigationBar:Container(
        decoration:const BoxDecoration(border:Border(top:BorderSide(color:stroke))),
        child:NavigationBar(
          height:67,
          selectedIndex:tab,
          labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected:(i)=>setState(() {tab=i;search='';dateFilter=false;filter=0;}),
          backgroundColor:bg2,
          indicatorColor:red.withValues(alpha:.2),
          destinations:const [
            NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home,color:red),label:'Главная'),
            NavigationDestination(icon:Icon(Icons.sports_hockey_outlined),selectedIcon:Icon(Icons.sports_hockey,color:red),label:'Матчи'),
            NavigationDestination(icon:Icon(Icons.leaderboard_outlined),selectedIcon:Icon(Icons.leaderboard,color:red),label:'Таблица'),
            NavigationDestination(icon:Icon(Icons.shield_outlined),selectedIcon:Icon(Icons.shield,color:red),label:'Команды'),
            NavigationDestination(icon:Icon(Icons.bar_chart_rounded),selectedIcon:Icon(Icons.bar_chart,color:red),label:'Статы'),
          ],
        ),
      ),
    );
  }
}


class FhrMatchDetails extends StatefulWidget {
  final Match initial;
  const FhrMatchDetails({super.key,required this.initial});
  @override
  State<FhrMatchDetails> createState()=>_FhrMatchDetailsState();
}

class _FhrMatchDetailsState extends State<FhrMatchDetails> {
  final FhrApiClient api=FhrApiClient(http.Client());
  Timer? ticker;
  late Match match;
  Map<String,dynamic>? detail;
  String? error;
  bool loading=false;
  @override
  void initState() {
    super.initState();
    match=widget.initial;
    update();
    ticker=Timer.periodic(const Duration(seconds:20),(_)=>update());
  }
  @override
  void dispose() {ticker?.cancel();api.client.close();super.dispose();}
  Future<void> update() async {
    if(loading || widget.initial.gameId==null)return;
    setState(()=>loading=true);
    try {
      final d=await api.detail(widget.initial.gameId!);
      if(!mounted)return;
      if(d['ok']!=true)throw Exception('ФХР не вернул протокол');
      setState((){
        detail=d;
        match=widget.initial.withDetail(d);
        error=null;
      });
    }catch(e){if(mounted)setState(()=>error='Протокол ФХР недоступен: $e');}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> openOfficial() async {
    final url=match.matchUrl ?? calendarUrl;
    final uri=Uri.tryParse(url);
    if(uri==null || uri.scheme!='https' || uri.host!='junior.fhr.ru')return;
    await launchUrl(uri,mode:LaunchMode.externalApplication);
  }
  String get statusLabel {
    final fromSite=detail?['statusText']?.toString();
    if(fromSite!=null && fromSite.isNotEmpty)return fromSite;
    if(match.isLive)return 'LIVE · ФХР';
    if(match.isFinalConfirmed)return 'МАТЧ ЗАВЕРШЁН · ФХР';
    if(match.finished)return 'РЕЗУЛЬТАТ ОПУБЛИКОВАН';
    return 'ПО РАСПИСАНИЮ';
  }
  @override
  Widget build(BuildContext context) {
    final periods=detail?['periodScores'] is List ? detail!['periodScores'] as List : [];
    final events=detail?['events'] is List ? detail!['events'] as List : [];
    return Scaffold(
      appBar:AppBar(title:const Text('Протокол матча'),actions:[
        IconButton(onPressed:update,icon:loading?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))
            :const Icon(Icons.refresh_rounded)),
        IconButton(onPressed:openOfficial,icon:const Icon(Icons.open_in_new_rounded)),
      ]),
      body:ListView(children:[
        Container(color:panel,padding:const EdgeInsets.fromLTRB(16,22,16,24),
          child:Column(children:[
            Text(match.stage.toUpperCase(),textAlign:TextAlign.center,
              style:const TextStyle(color:muted,fontSize:11,fontWeight:FontWeight.bold)),
            const SizedBox(height:8),
            Text('${match.dayLabel} · ${match.timeMsk} МСК',
              style:const TextStyle(color:muted,fontSize:12)),
            const SizedBox(height:25),
            Row(children:[
              Expanded(child:Text(match.home,textAlign:TextAlign.center,
                style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15))),
              SizedBox(width:95,child:Column(children:[
                Text(match.score.isNotEmpty?match.score:'– : –',
                  style:TextStyle(fontSize:27,fontWeight:FontWeight.w900,color:match.isLive?red:Colors.white)),
                if(match.scoreNote.isNotEmpty)Text(match.scoreNote,style:const TextStyle(fontSize:11,color:amber)),
              ])),
              Expanded(child:Text(match.away,textAlign:TextAlign.center,
                style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15))),
            ]),
            const SizedBox(height:18),
            Text(statusLabel,textAlign:TextAlign.center,
              style:TextStyle(fontWeight:FontWeight.w800,fontSize:12,color:match.isLive?red:amber)),
            if(match.isLive && detail?['period']!=null)Padding(padding:const EdgeInsets.only(top:8),
              child:Text('Период ${detail!['period']}  ·  ${detail?['clock'] ?? ''}',
                style:const TextStyle(fontSize:13,color:muted))),
          ])),
        if(error!=null)Padding(padding:const EdgeInsets.all(14),
          child:Text(error!,style:const TextStyle(color:amber,fontSize:12))),
        if(match.arena.isNotEmpty)ListTile(leading:const Icon(Icons.stadium_outlined,color:muted),
          title:const Text('Арена'),subtitle:Text(match.arena)),
        if(periods.isNotEmpty)...[
          const Padding(padding:EdgeInsets.fromLTRB(16,19,16,12),
            child:Text('По периодам',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800))),
          Container(color:panel,child:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,
            children:[
              for(var i=0;i<periods.length;i++)Padding(padding:const EdgeInsets.all(12),
                child:Column(children:[
                  Text('${i+1}-й',style:const TextStyle(color:muted,fontSize:11)),
                  Text('${periods[i] is Map ? periods[i]['home'] : '?'}:${periods[i] is Map ? periods[i]['away'] : '?'}',
                    style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
                ])),
            ])),
        ],
        const Padding(padding:EdgeInsets.fromLTRB(16,19,16,12),
          child:Text('События игры',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800))),
        if(events.isEmpty)const Padding(padding:EdgeInsets.fromLTRB(16,0,16,16),
          child:Text('ФХР пока не передал распознаваемую ленту событий.',
            style:TextStyle(color:muted,fontSize:12))),
        for(final e in events.take(100))
          if(e is Map)ListTile(
            dense:true,
            leading:const Icon(Icons.sports_hockey_outlined,size:18,color:red),
            title:Text(e['description']?.toString() ?? '',style:const TextStyle(fontSize:12)),
            subtitle:Text(e['score']?.toString() ?? '',style:const TextStyle(fontSize:11,color:muted)),
          ),
        Padding(padding:const EdgeInsets.all(16),child:FilledButton.icon(
          onPressed:openOfficial,icon:const Icon(Icons.open_in_new),
          label:const Text('Официальная карточка на ФХР'))),
        const Padding(padding:EdgeInsets.fromLTRB(16,0,16,22),
          child:Text('Данные протокола показываются по мере публикации ФХР. Автоматическая проверка при открытом экране каждые 20 секунд.',
            style:TextStyle(color:muted,fontSize:11))),
      ]),
    );
  }
}
