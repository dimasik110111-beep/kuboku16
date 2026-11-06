import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:url_launcher/url_launcher.dart';

const navy = Color(0xff11141b);
const panel = Color(0xff1b202b);
const red = Color(0xffef4c60);
const muted = Color(0xffa1a9b8);
const calendarUrl = 'https://junior.fhr.ru/tournaments/kubokrossii-25008909/calendar/';
const tournamentUrl = 'https://junior.fhr.ru/tournaments/kubokrossii-25008909/';

void main() => runApp(const JuniorApp());

class Match {
  final String date, home, away, score, stage, arena;
  const Match(this.date, this.home, this.away, this.score, this.stage, this.arena);
  bool get finished => RegExp(r'^\d+\s*:\s*\d+').hasMatch(score);
  List<int>? get goals {
    final found = RegExp(r'(\d+)\s*:\s*(\d+)').firstMatch(score);
    if (!finished || found == null) return null;
    return [int.parse(found[1]!), int.parse(found[2]!)];
  }
  bool get overtime => score.toLowerCase().contains('от') || score.toLowerCase().contains('бул');
  String get key => '$stage|$date|$home|$away';
}

class Rank {
  final String team;
  int gp=0, pts=0, w=0, rw=0, gf=0, ga=0;
  Rank(this.team);
  int get diff => gf-ga;
}

List<Rank> ranking(List<Match> matches) {
  final table=<String,Rank>{};
  for(final m in matches) {
    final stage=m.stage.toUpperCase();
    if(stage.contains('ЗОЛОТОЙ ФИНАЛ') || stage.contains('СЕРЕБРЯНЫЙ ФИНАЛ')) continue;
    if(!(RegExp(r'-(I|II|III)\b').hasMatch(stage) || stage.contains('СТЫК') || stage.contains('ПЛЕЙ-ОФФ'))) continue;
    final g=m.goals;
    if(g==null || g[0]==g[1]) continue;
    final a=table.putIfAbsent(m.home,()=>Rank(m.home));
    final b=table.putIfAbsent(m.away,()=>Rank(m.away));
    a.gp++;b.gp++;a.gf+=g[0];a.ga+=g[1];b.gf+=g[1];b.ga+=g[0];
    final win=g[0]>g[1]?a:b, lose=g[0]>g[1]?b:a;
    win.pts+=2;win.w++;if(m.overtime){lose.pts++;}else{win.rw++;}
  }
  final standings=table.values.toList();
  standings.sort((a,b){
    for(final d in [b.pts-a.pts,b.rw-a.rw,b.diff-a.diff,b.gf-a.gf]) {if(d!=0)return d;}
    return a.team.compareTo(b.team);
  });
  return standings;
}

Future<List<Match>> fetchVisibleMatches() async {
  final response=await http.get(Uri.parse(calendarUrl),headers:{'User-Agent':'Mozilla/5.0 JUNIOR-U16'},).timeout(const Duration(seconds:20));
  if(response.statusCode!=200) throw Exception('ФХР: HTTP ${response.statusCode}');
  final doc=html.parse(response.body);
  final output=<Match>[];
  for(final table in doc.querySelectorAll('table')) {
    final heads=table.querySelectorAll('th').map((x)=>x.text.trim().toLowerCase()).join(' ');
    if(!heads.contains('команда') || !heads.contains('сч'))continue;
    final stage=table.parent?.querySelector('h2,h3,h4')?.text.trim() ?? 'Раздел ФХР (этап не установлен)';
    for(final tr in table.querySelectorAll('tr')){
      final cells=tr.querySelectorAll('td').map((e)=>e.text.replaceAll(RegExp(r'\s+'),' ').trim()).toList();
      if(cells.length<5)continue;
      final date=cells.length>1?cells[1]:'';
      final home=cells.length>2?cells[2]:'';
      final away=cells.length>3?cells[3]:'';
      final score=cells.length>4?cells[4]:'';
      if(home.isEmpty || away.isEmpty || date.isEmpty)continue;
      output.add(Match(date,home,away,score,stage,cells.length>5?cells[5]:''));
    }
  }
  return {for(final m in output)m.key:m}.values.toList();
}

class JuniorApp extends StatelessWidget{
  const JuniorApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'JUNIOR U16',
    theme:ThemeData(useMaterial3:true,brightness:Brightness.dark,scaffoldBackgroundColor:navy,
      colorScheme:ColorScheme.fromSeed(seedColor:red,brightness:Brightness.dark),
      appBarTheme:const AppBarTheme(backgroundColor:navy,surfaceTintColor:Colors.transparent)),
    home:const HomeScreen());
}

class HomeScreen extends StatefulWidget{
  const HomeScreen({super.key});
  @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver{
  int tab=0;
  bool loading=false;
  DateTime? updated;
  String? error;
  List<Match> matches=[];
  Timer? timer;
  static const teams=['ЦСКА','Северсталь','Нефтехимик','Армия СКА','Красная Машина Юниор',
    'Ак Барс','Спартак','Динамо СПб','Академия Михайлова','Динамо-Джуниверс',
    'Торпедо','Локомотив','Динамо Москва','МАХ','Авангард',
    'Крылья Советов','Сибирь','Лада','Трактор','Локомотив-2004'];
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);refresh();timer=Timer.periodic(const Duration(seconds:60),(_)=>refresh());}
  @override void dispose(){timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState s){if(s==AppLifecycleState.resumed)refresh();}
  Future<void> refresh() async{
    if(loading)return;
    setState(()=>loading=true);
    try{
      final latest=await fetchVisibleMatches();
      if(!mounted)return;
      setState((){matches=latest;updated=DateTime.now();error=latest.isEmpty?'Матчи не распознаны: проверьте официальный календарь.':null;});
    }catch(e){if(mounted)setState(()=>error='Не удалось получить данные ФХР: $e');}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> openFhr(String url) async {
    final uri=Uri.parse(url);
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication) && mounted){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Не удалось открыть ФХР')));
    }
  }
  @override Widget build(BuildContext context){
    return Scaffold(
      appBar:AppBar(title:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('JUNIOR U16',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:1.2)),
        Text('КУБОК РОССИИ · 2026/27',style:TextStyle(color:muted,fontSize:10)),
      ]),actions:[IconButton(onPressed:loading?null:refresh,icon:loading
        ?const SizedBox(height:18,width:18,child:CircularProgressIndicator(strokeWidth:2))
        :const Icon(Icons.refresh))]),
      body:Column(children:[
        if(error!=null)Container(width:double.infinity,color:const Color(0xff492832),padding:const EdgeInsets.all(10),
          child:Text(error!,style:const TextStyle(fontSize:12))),
        Container(color:panel,width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),
          child:Text(updated==null?'ФХР · ожидание обновления':
            'ФХР · обновлено ${updated!.hour.toString().padLeft(2,'0')}:${updated!.minute.toString().padLeft(2,'0')} · ${matches.length} строк',
            style:const TextStyle(fontSize:12,color:muted))),
        Expanded(child:RefreshIndicator(onRefresh:refresh,child:IndexedStack(index:tab,children:[
          screenMatches(matches.where((m)=>m.finished).toList(),title:'Последние результаты'),
          screenMatches(matches,title:'Матчи ФХР'),
          standingsScreen(),
          teamsScreen(),
          infoScreen(),
        ]))),
      ]),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),
        backgroundColor:panel,indicatorColor:red.withValues(alpha:0.18),
        destinations:const [
          NavigationDestination(icon:Icon(Icons.home_outlined),label:'Главная'),
          NavigationDestination(icon:Icon(Icons.calendar_month_outlined),label:'Матчи'),
          NavigationDestination(icon:Icon(Icons.format_list_numbered),label:'Таблица'),
          NavigationDestination(icon:Icon(Icons.shield_outlined),label:'Команды'),
          NavigationDestination(icon:Icon(Icons.query_stats),label:'Статистика'),
        ]),
    );
  }
  Widget wrap(Widget child)=>ListView(children:[Padding(padding:const EdgeInsets.all(14),child:child)]);
  Widget heading(String title)=>Padding(padding:const EdgeInsets.only(bottom:14),child:Text(title,
    style:const TextStyle(fontWeight:FontWeight.bold,fontSize:20)));
  Widget screenMatches(List<Match> list,{required String title}){
    return ListView(children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,18,16,8),child:heading(title)),
      if(list.isEmpty)const Padding(padding:EdgeInsets.all(18),child:Text('Пока нет проверенных результатов. Откройте календарь ФХР.',style:TextStyle(color:muted))),
      for(final m in list.take(150))Container(
        margin:const EdgeInsets.symmetric(horizontal:12,vertical:4),padding:const EdgeInsets.all(14),
        decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(12)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${m.date} · ${m.stage}',style:const TextStyle(color:muted,fontSize:11)),
          const SizedBox(height:10),
          Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(m.home,style:const TextStyle(fontWeight:FontWeight.w600)),
            const SizedBox(height:8),Text(m.away,style:const TextStyle(fontWeight:FontWeight.w600)),
          ])),Text(m.score.isEmpty?'—':m.score,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold))]),
          if(m.arena.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Text(m.arena,style:const TextStyle(color:muted,fontSize:11))),
        ])),
      TextButton(onPressed:()=>openFhr(calendarUrl),child:const Text('Полный календарь на ФХР Джуниор')),
    ]);
  }
  Widget standingsScreen(){
    final ranks=ranking(matches);
    return ListView(children:[
      Padding(padding:const EdgeInsets.all(16),child:heading('Общий рейтинг · предварительный')),
      const Padding(padding:EdgeInsets.fromLTRB(16,0,16,12),child:Text(
        'Внимание: прямой HTML-импорт не гарантирует получение всех групп и правильного этапа. Таблица НЕ является официальной. Для полного рейтинга нужен проверенный сервер синхронизации.',
        style:TextStyle(color:muted,fontSize:12))),
      for(var i=0;i<ranks.length;i++)Container(
        padding:const EdgeInsets.symmetric(horizontal:12,vertical:12),
        color:i.isEven?panel:navy,
        child:Row(children:[
          SizedBox(width:28,child:Text('${i+1}',style:const TextStyle(color:muted))),
          Expanded(child:Text(ranks[i].team,maxLines:1,overflow:TextOverflow.ellipsis)),
          SizedBox(width:25,child:Text('${ranks[i].gp}',textAlign:TextAlign.center)),
          SizedBox(width:35,child:Text('${ranks[i].diff}',textAlign:TextAlign.center,style:const TextStyle(color:muted))),
          SizedBox(width:35,child:Text('${ranks[i].pts}',textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.bold))),
        ])),
      if(ranks.isEmpty)const Padding(padding:EdgeInsets.all(16),child:Text('Достоверной общей таблицы пока нет.',style:TextStyle(color:muted))),
      TextButton(onPressed:()=>openFhr(tournamentUrl),child:const Text('Официальная таблица ФХР')),
    ]);
  }
  Widget teamsScreen()=>ListView(children:[
    Padding(padding:const EdgeInsets.all(16),child:heading('Участники · 20 команд')),
    for(final name in teams)ListTile(title:Text(name),leading:const Icon(Icons.shield_outlined,color:red),
      trailing:const Icon(Icons.chevron_right),onTap:()=>openFhr(tournamentUrl)),
  ]);
  Widget infoScreen()=>wrap(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    heading('Статистика ФХР'),
    const Text('Статистика игроков, вратарей и протоколы доступны на официальном сайте. '
      'Здесь нельзя показывать неподтверждённые голы, передачи или статусы LIVE.',style:TextStyle(color:muted)),
    const SizedBox(height:18),
    FilledButton(onPressed:()=>openFhr('${tournamentUrl}stats/'),child:const Text('Открыть статистику ФХР')),
    FilledButton.tonal(onPressed:()=>openFhr(calendarUrl),child:const Text('Открыть календарь ФХР')),
  ]));
}
