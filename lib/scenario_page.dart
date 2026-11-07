import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cup_data.dart';
import 'scenario.dart';
import 'tournament.dart';
import 'ui_kit.dart';
import 'app_services.dart';
import 'team_pages.dart';

class ScenarioPage extends StatefulWidget {
  final List<Match> matches;final List<String> teams;
  final Map<String,String?> teamLogos;
  const ScenarioPage({super.key,required this.matches,required this.teams,this.teamLogos=const {}});
  @override State<ScenarioPage> createState()=>_ScenarioPageState();
}
class _ScenarioPageState extends State<ScenarioPage>{
  final Map<String,ScenarioScore> scores={};final Map<String,bool> stageOpen={};
  String? team;bool ready=false,fullTable=false;int filter=0;
  static const filters=['ВСЕ','ОСТАЛОСЬ','СТЫКИ','III ТУР'];
  @override void initState(){super.initState();restore();}
  Future<void> restore()async{
    try{
      final raw=(await SharedPreferences.getInstance()).getString('junior_scenario_2026_27');
      final parsed=raw==null?null:jsonDecode(raw);
      if(!mounted)return;
      final eligible=scenarioFixtures(widget.matches).map((m)=>m.key).toSet();
      if(parsed is Map){for(final e in parsed.entries){final score=ScenarioScore.parse(e.value);if(score!=null&&eligible.contains(e.key))scores[e.key.toString()]=score;}}
    }catch(e){Diagnostics.record('scenario restore',e);}
    if(mounted)setState(()=>ready=true);
  }
  Future<void> save()async{
    final encoded=jsonEncode(scores.map((key,value)=>MapEntry(key,value.toJson())));
    try{await (await SharedPreferences.getInstance()).setString('junior_scenario_2026_27',encoded);}
    catch(e){Diagnostics.record('scenario save',e);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Сценарий работает, но сохранить его не удалось.')));}
  }
  Future<void> edit(Match match)async{
    final result=await showDialog<ScenarioScore>(context:context,builder:(_)=>ScenarioScoreDialog(match:match,initial:scores[match.key]));
    if(result!=null&&mounted){setState(()=>scores[match.key]=result);await save();}
  }
  Future<void> reset()async{
    final yes=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:const Text('Сбросить предикты?'),
      content:const Text('Твои предположения удалятся. Результаты ФХР останутся без изменений.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Отмена')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Сбросить'))]));
    if(yes==true&&mounted){setState(scores.clear);await save();}
  }
  bool _matchesFilter(Match m)=>filter==1
    ?m.gameId==null||m.gameId!>0
    :filter==2?m.isCrossover
    :filter==3?tourOf(m.stage)==CupTour.third:true;
  int _stageOrder(Match m){
    final tour=tourOf(m.stage);
    if(tour==CupTour.first)return 0;
    if(tour==CupTour.second)return m.isCrossover?2:1;
    if(tour==CupTour.third)return m.isCrossover?4:3;
    return 5;
  }
  Widget _hero(int available,int shifts)=>Container(
    margin:const EdgeInsets.fromLTRB(13,12,13,7),clipBehavior:Clip.antiAlias,
    decoration:BoxDecoration(
      gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:CupUi.heroGradient),
      borderRadius:BorderRadius.circular(26),border:Border.all(color:CupUi.ice.withValues(alpha:.16)),
      boxShadow:[BoxShadow(color:CupUi.red.withValues(alpha:.09),blurRadius:25,offset:const Offset(0,10))]),
    child:Stack(children:[
      Positioned(right:-36,top:-48,child:Container(width:165,height:165,
        decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:CupUi.ice.withValues(alpha:.07),width:25)))),
      Padding(padding:const EdgeInsets.fromLTRB(17,15,17,15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(width:31,height:31,decoration:BoxDecoration(color:CupUi.red.withValues(alpha:.2),borderRadius:BorderRadius.circular(11)),
            child:const Icon(Icons.auto_awesome_rounded,color:CupUi.red,size:17)),
          const SizedBox(width:8),Text('JUNIOR U16 · СИМУЛЯТОР',
            style:TextStyle(color:CupUi.ice,fontSize:9,letterSpacing:.75,fontWeight:FontWeight.w900)),
          const Spacer(),IconButton(tooltip:'Сбросить предикты',onPressed:!ready||scores.isEmpty?null:reset,
            visualDensity:VisualDensity.compact,icon:const Icon(Icons.restart_alt_rounded)),
        ]),
        const SizedBox(height:10),
        const Text('Сценарий\nКубка России',style:TextStyle(color:Colors.white,fontSize:25,
          height:1.03,letterSpacing:-.5,fontWeight:FontWeight.w900)),
        const SizedBox(height:7),
        Text('Задавай счёт — таблица и будущая сетка перестроятся автоматически.',
          style:TextStyle(color:CupUi.soft,fontSize:11,height:1.4)),
        const SizedBox(height:16),
        Row(children:[
          _heroMetric('${scores.length}','ВВЕДЕНО',Icons.edit_note_rounded),
          _heroMetric('$available','МАТЧЕЙ',Icons.sports_hockey_rounded),
          _heroMetric('$shifts','СДВИГОВ',Icons.swap_vert_rounded),
        ]),
        const SizedBox(height:13),
        Row(children:[Icon(Icons.cloud_done_outlined,color:CupUi.green,size:14),const SizedBox(width:6),
          Expanded(child:Text('Предикты сохраняются на устройстве',style:TextStyle(color:CupUi.muted,fontSize:9,fontWeight:FontWeight.w600))),
          CupTag(text:'ФХР · 2026/27',color:CupUi.soft),
        ]),
      ])),
    ]));
  Widget _heroMetric(String value,String label,IconData icon)=>Expanded(child:Row(children:[
    Icon(icon,color:CupUi.ice,size:18),const SizedBox(width:7),
    Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(value,style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w900,height:1)),
      const SizedBox(height:3),Text(label,style:TextStyle(color:CupUi.muted,fontSize:8,letterSpacing:.35,fontWeight:FontWeight.w800)),
    ]),
  ]));
  Widget _rankRow(Rank rank,int index,Map<String,int> oldPlaces,Map<String,int> oldPoints){
    final movement=(oldPlaces[rank.team]??index+1)-(index+1);
    final delta=rank.pts-(oldPoints[rank.team]??rank.pts);
    final top=index<8;
    return Container(color:top?CupUi.green.withValues(alpha:.035):Colors.transparent,
      padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),child:Row(children:[
        SizedBox(width:25,child:Text('${index+1}'.padLeft(2,'0'),style:TextStyle(
          color:top?CupUi.green:CupUi.muted,fontSize:10,fontWeight:FontWeight.w900))),
        fhrTeamLogo(widget.teamLogos[rank.team],size:25),const SizedBox(width:8),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(rank.team,maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:CupUi.white,fontSize:10,fontWeight:FontWeight.w800)),
          Text('${rank.gp} И · ${rank.gf}:${rank.ga}',style:TextStyle(color:CupUi.muted,fontSize:8)),
        ])),
        SizedBox(width:38,child:Center(child:movement==0?Text('—',style:TextStyle(color:CupUi.dim,fontSize:9)):
          Text('${movement>0?'↑':'↓'}${movement.abs()}',style:TextStyle(
            color:movement>0?CupUi.green:CupUi.red,fontSize:9,fontWeight:FontWeight.w900)))),
        SizedBox(width:42,child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
          Text('${rank.pts}',style:TextStyle(color:CupUi.white,fontSize:13,fontWeight:FontWeight.w900)),
          Text('${delta>=0?'+':''}$delta',style:TextStyle(color:delta>=0?CupUi.green:CupUi.red,fontSize:8)),
        ])),
      ]));
  }
  Widget _filterChip(int i)=>Padding(padding:const EdgeInsets.only(right:7),child:InkWell(
    onTap:()=>setState(()=>filter=i),borderRadius:BorderRadius.circular(99),
    child:AnimatedContainer(duration:const Duration(milliseconds:170),
      padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
      decoration:BoxDecoration(color:filter==i?CupUi.red:CupUi.surface,borderRadius:BorderRadius.circular(99),
        border:Border.all(color:filter==i?CupUi.red:CupUi.stroke)),
      child:Text(filters[i],style:TextStyle(color:filter==i?Colors.white:CupUi.muted,
        fontSize:9,letterSpacing:.35,fontWeight:FontWeight.w900)))));
  Widget _fixtureRow(Match m){
    final score=scores[m.key];final synthetic=m.gameId!=null&&m.gameId!<0;
    return InkWell(onTap:()=>edit(m),borderRadius:BorderRadius.circular(13),
      child:Padding(padding:const EdgeInsets.fromLTRB(10,9,9,9),child:Row(children:[
        Container(width:34,height:36,decoration:BoxDecoration(
          color:score==null?CupUi.raised:CupUi.redMuted,borderRadius:BorderRadius.circular(11)),
          child:Icon(score==null?Icons.add_rounded:Icons.edit_rounded,size:18,
            color:score==null?CupUi.ice:CupUi.red)),
        const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text(m.home,maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:CupUi.white))),
            fhrTeamLogo(widget.teamLogos[m.home],size:19)]),
          const SizedBox(height:5),
          Row(children:[Expanded(child:Text(m.away,maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:CupUi.white))),
            fhrTeamLogo(widget.teamLogos[m.away],size:19)]),
          const SizedBox(height:5),Text(synthetic?'РАСЧЁТНАЯ ПАРА · ДАТЫ НЕТ':'${m.dayLabel} · ${m.stage}',
            style:TextStyle(color:synthetic?CupUi.ice:CupUi.muted,fontSize:8,fontWeight:FontWeight.w700)),
        ])),const SizedBox(width:7),
        Container(constraints:const BoxConstraints(minWidth:50),padding:const EdgeInsets.symmetric(horizontal:6,vertical:9),
          decoration:BoxDecoration(color:score==null?CupUi.raised:CupUi.red.withValues(alpha:.13),
            borderRadius:BorderRadius.circular(10),border:Border.all(color:score==null?CupUi.stroke:CupUi.red.withValues(alpha:.2))),
          child:Text(score==null?'Задать':'${score.home}:${score.away}${score.overtime?' ОТ':''}',
            textAlign:TextAlign.center,style:TextStyle(color:score==null?CupUi.ice:CupUi.red,
              fontSize:score==null?9:11,fontWeight:FontWeight.w900))),
      ])));
  }
  Widget _stagePanel(String stage,List<Match> games,{required bool initiallyOpen}){
    final count=games.where((m)=>scores.containsKey(m.key)).length;
    final open=stageOpen.putIfAbsent(stage,()=>initiallyOpen);
    return CupCard(margin:const EdgeInsets.fromLTRB(13,4,13,7),padding:EdgeInsets.zero,
      child:Column(children:[
        InkWell(onTap:()=>setState(()=>stageOpen[stage]=!open),
          child:Padding(padding:const EdgeInsets.fromLTRB(12,11,11,10),child:Row(children:[
            Container(width:34,height:34,decoration:BoxDecoration(color:CupUi.raised,borderRadius:BorderRadius.circular(11)),
              child:Icon(stage.toUpperCase().contains('СТЫК')?Icons.compare_arrows_rounded:
                tourOf(stage)==CupTour.third?Icons.filter_3_rounded:Icons.sports_hockey_rounded,
                size:18,color:stage.toUpperCase().contains('СТЫК')?CupUi.yellow:CupUi.ice)),
            const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(stage.toUpperCase(),maxLines:1,overflow:TextOverflow.ellipsis,
                style:TextStyle(color:CupUi.white,fontSize:9,letterSpacing:.3,fontWeight:FontWeight.w900)),
              const SizedBox(height:3),Text('$count из ${games.length} предиктов задано',
                style:TextStyle(color:CupUi.muted,fontSize:8)),
            ])),
            SizedBox(width:42,child:ClipRRect(borderRadius:BorderRadius.circular(99),child:LinearProgressIndicator(
              value:games.isEmpty?0:count/games.length,minHeight:5,backgroundColor:CupUi.stroke,
              valueColor:AlwaysStoppedAnimation(count==games.length&&count>0?CupUi.green:CupUi.red)))),
            const SizedBox(width:5),Icon(open?Icons.expand_less:Icons.expand_more,color:CupUi.muted,size:19),
          ]))),
        if(open)...[
          Container(height:1,color:CupUi.stroke,margin:const EdgeInsets.symmetric(horizontal:11)),
          for(var i=0;i<games.length;i++)...[
            _fixtureRow(games[i]),
            if(i+1<games.length)Padding(padding:const EdgeInsets.only(left:53),
              child:Container(height:.7,color:CupUi.stroke)),
          ],
        ],
      ]));
  }
  @override Widget build(BuildContext context){
    final simulated=applyScenario(widget.matches,scores);
    final cup=CupTournament(simulated.matches,teams:widget.teams);
    final table=cup.table();final original=CupTournament(widget.matches,teams:widget.teams).table();
    final originalPlaces={for(var i=0;i<original.length;i++)original[i].team:i+1};
    final originalPoints={for(final r in original)r.team:r.pts};
    final all=scenarioFixtures(widget.matches,scores:scores);
    final fixtures=all.where((m)=>_matchesFilter(m)&&(team==null||m.home==team||m.away==team)).toList();
    final names=table.map((r)=>r.team).toList()..sort();
    final officialCup=CupTournament(widget.matches,teams:widget.teams);
    final groups=<String,List<Match>>{};
    for(final m in fixtures){groups.putIfAbsent(m.stage,()=>[]).add(m);}
    final stages=groups.keys.toList()..sort((a,b){
      final order=_stageOrder(groups[a]!.first).compareTo(_stageOrder(groups[b]!.first));
      return order==0?a.compareTo(b):order;
    });
    final moved=table.where((r){final p=originalPlaces[r.team];return p!=null&&p!=table.indexOf(r)+1;}).length;
    final limit=fullTable?table.length:table.length.clamp(0,6);
    return Scaffold(backgroundColor:CupUi.background,
      appBar:AppBar(title:const Text('ПРЕДИКТЫ'),
        actions:[IconButton(tooltip:'Сбросить',onPressed:!ready||scores.isEmpty?null:reset,icon:const Icon(Icons.restart_alt_rounded))]),
      body:SafeArea(child:!ready?const LoadingCards():ListView(children:[
        _hero(all.length,moved),
        CupSection(title:'ТУРНИРНАЯ ПРОЕКЦИЯ',subtitle:'Первые 8 мест — зона Золотого финала'),
        CupCard(margin:const EdgeInsets.fromLTRB(13,2,13,8),padding:EdgeInsets.zero,
          child:Column(children:[
            Padding(padding:const EdgeInsets.fromLTRB(14,13,14,11),child:Row(children:[
              Container(width:31,height:31,decoration:BoxDecoration(color:CupUi.redMuted,borderRadius:BorderRadius.circular(10)),
                child:const Icon(Icons.leaderboard_rounded,color:CupUi.red,size:17)),
              const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('ТАБЛИЦА СЦЕНАРИЯ',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900,letterSpacing:.4)),
                Text('Очки и движение относительно текущего места',style:TextStyle(fontSize:9,color:CupUi.muted)),
              ])),CupTag(text:'${table.length} КОМАНД',color:CupUi.ice,filled:true),
            ])),
            Container(height:1,color:CupUi.stroke),
            for(var i=0;i<limit;i++)...[
              _rankRow(table[i],i,originalPlaces,originalPoints),
              if(i==7)Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Row(children:[
                Expanded(child:Container(height:1,color:CupUi.stroke)),
                Padding(padding:const EdgeInsets.symmetric(horizontal:7),child:Text('ЗОЛОТО / СЕРЕБРО',
                  style:TextStyle(color:CupUi.yellow,fontSize:8,fontWeight:FontWeight.w900))),
                Expanded(child:Container(height:1,color:CupUi.stroke)),
              ])),
            ],
            if(table.length>6)TextButton.icon(onPressed:()=>setState(()=>fullTable=!fullTable),
              icon:Icon(fullTable?Icons.expand_less:Icons.expand_more,size:17),
              label:Text(fullTable?'Свернуть таблицу':'Показать всю таблицу'),
              style:TextButton.styleFrom(foregroundColor:CupUi.ice,textStyle:const TextStyle(fontSize:10,fontWeight:FontWeight.w800))),
          ])),
        Container(margin:const EdgeInsets.fromLTRB(13,4,13,7),padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(color:CupUi.raised,borderRadius:BorderRadius.circular(16),border:Border.all(color:CupUi.stroke)),
          child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Icon(Icons.info_outline_rounded,color:CupUi.ice,size:16),const SizedBox(width:8),
            Expanded(child:Text('III тур строится по змейке регламента. Стыки входят в общий зачёт, но не меняют места внутри группы. Расчётные пары — сценарий, не календарь ФХР.',
              style:TextStyle(color:CupUi.soft,fontSize:9,height:1.45))),
          ])),
        CupSection(title:'МАТЧИ ДЛЯ ВВОДА',subtitle:'${simulated.applied} предиктов · ${officialCup.qualifyingFixtureCount} матчей опубликовано ФХР'),
        SizedBox(height:42,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:13),
          children:[for(var i=0;i<filters.length;i++)_filterChip(i)])),
        Padding(padding:const EdgeInsets.fromLTRB(13,8,13,7),child:DropdownButtonFormField<String>(
          key:ValueKey(team??''),initialValue:team??'',isExpanded:true,
          decoration:InputDecoration(prefixIcon:Icon(Icons.filter_alt_outlined,color:CupUi.ice),
            contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:2)),
          items:[const DropdownMenuItem(value:'',child:Text('Все команды')),
            for(final name in names)DropdownMenuItem(value:name,child:Text(name,overflow:TextOverflow.ellipsis))],
          onChanged:(value)=>setState(()=>team=value==null||value.isEmpty?null:value))),
        if(stages.isEmpty)const CupMessage(title:'Матчей по фильтру нет',message:'Покажи все матчи или выбери другую команду.'),
        for(var i=0;i<stages.length;i++)_stagePanel(stages[i],groups[stages[i]]!,initiallyOpen:i==0),
        const SizedBox(height:24),
      ])),
    );
  }
}

class ScenarioScoreDialog extends StatefulWidget {
  final Match match;final ScenarioScore? initial;
  const ScenarioScoreDialog({super.key,required this.match,this.initial});
  @override State<ScenarioScoreDialog> createState()=>_ScenarioScoreDialogState();
}
class _ScenarioScoreDialogState extends State<ScenarioScoreDialog>{
  late final home=TextEditingController(text:widget.initial?.home.toString()??'');
  late final away=TextEditingController(text:widget.initial?.away.toString()??'');
  late bool overtime=widget.initial?.overtime??false;String? error;
  @override void dispose(){home.dispose();away.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(
      title:const Text('Предположить результат'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text('${widget.match.home} — ${widget.match.away}',textAlign:TextAlign.center),const SizedBox(height:18),
        Row(children:[Expanded(child:TextField(key:const ValueKey('scenario-home-score'),controller:home,keyboardType:TextInputType.number,inputFormatters:[FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(2)],decoration:const InputDecoration(labelText:'Хозяева',border:OutlineInputBorder()))),const Padding(padding:EdgeInsets.all(12),child:Text(':')),Expanded(child:TextField(key:const ValueKey('scenario-away-score'),controller:away,keyboardType:TextInputType.number,inputFormatters:[FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(2)],decoration:const InputDecoration(labelText:'Гости',border:OutlineInputBorder())))]),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Овертайм / буллиты'),subtitle:const Text('Проигравшей команде — 1 очко'),value:overtime,onChanged:(v)=>setState(()=>overtime=v)),
        if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Отмена')),FilledButton(onPressed:(){
        final h=int.tryParse(home.text),a=int.tryParse(away.text);
        if(h==null||a==null){setState(()=>error='Укажи оба числа.');return;}
        final value=ScenarioScore(h,a,overtime:overtime);
        if(!value.valid){setState(()=>error=h==a?'Ничьи в хоккее нет.':overtime?'После ОТ или буллитов разница должна быть в одну шайбу.':'Счёт должен быть от 0 до 99.');return;}
        Navigator.pop(context,value);
      },child:const Text('Применить'))]);
}
