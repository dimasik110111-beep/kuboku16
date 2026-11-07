import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cup_data.dart';
import 'scenario.dart';
import 'tournament.dart';
import 'ui_kit.dart';
import 'app_services.dart';

class ScenarioPage extends StatefulWidget {
  final List<Match> matches;final List<String> teams;
  const ScenarioPage({super.key,required this.matches,required this.teams});
  @override State<ScenarioPage> createState()=>_ScenarioPageState();
}
class _ScenarioPageState extends State<ScenarioPage>{
  final Map<String,ScenarioScore> scores={};String? team;bool ready=false;
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
  @override Widget build(BuildContext context){
    final simulated=applyScenario(widget.matches,scores);
    final cup=CupTournament(simulated.matches,teams:widget.teams);
    final table=cup.table();final original=CupTournament(widget.matches,teams:widget.teams).table();
    final originalPlaces={for(var i=0;i<original.length;i++)original[i].team:i+1};
    final originalPoints={for(final r in original)r.team:r.pts};
    final all=scenarioFixtures(widget.matches);
    final fixtures=all.where((m)=>team==null||m.home==team||m.away==team).toList();
    final names=table.map((r)=>r.team).toList()..sort();
    return Scaffold(appBar:AppBar(title:const Text('Если сыграют так…'),actions:[IconButton(tooltip:'Сбросить сценарий',onPressed:!ready||scores.isEmpty?null:()async{
      final confirm=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Сбросить предположения?'),content:const Text('Реальные результаты ФХР останутся без изменений.'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Отмена')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Сбросить'))]));
      if(confirm==true&&mounted){setState(scores.clear);await save();}
    },icon:const Icon(Icons.restart_alt))]),body:SafeArea(child:!ready?const LoadingCards():ListView(children:[
      CupCard(padding:const EdgeInsets.all(18),color:CupUi.raised,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('СЦЕНАРИЙ · ${simulated.applied} результатов',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:18)),const SizedBox(height:8),
        const Text('Задай счёт будущих опубликованных матчей. Таблица пересчитается только здесь. Это предположение, не прогноз и не данные ФХР.'),const SizedBox(height:8),
        Text('Выбрано ${simulated.applied} из ${all.length} доступных игр. Квалификация: ${cup.qualifyingFixtureCount} из 140 матчей опубликовано.'),
        if(cup.qualifyingFixtureCount<140)const Text('Часть расписания ещё отсутствует: окончательный состав финалов определить нельзя.'),
      ])),
      CupSection(title:'ТАБЛИЦА СЦЕНАРИЯ',subtitle:cup.qualificationComplete?'Все матчи квалификации учтены в сценарии':'Промежуточная таблица · первые 8 мест выделены'),
      CupCard(padding:const EdgeInsets.symmetric(vertical:8),child:Column(children:[
        for(var i=0;i<table.length;i++)Material(color:i<8?CupUi.green.withValues(alpha:.07):Colors.transparent,child:ListTile(dense:true,leading:Text('${i+1}',style:TextStyle(fontWeight:FontWeight.w900,color:i<8?CupUi.green:CupUi.muted)),title:Text(table[i].team),subtitle:Text('${table[i].gp} игр · ${table[i].gf}:${table[i].ga} шайб${table[i].provisionalTie?' · порядок при равенстве предварительный':''}'),trailing:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${table[i].pts} О',style:const TextStyle(fontWeight:FontWeight.bold)),Text('${table[i].pts-(originalPoints[table[i].team]??0)>=0?'+':''}${table[i].pts-(originalPoints[table[i].team]??0)} О · ${(originalPlaces[table[i].team]??i+1)-(i+1)>=0?'+':''}${(originalPlaces[table[i].team]??i+1)-(i+1)} мест',style:const TextStyle(fontSize:10))]))),
      ])),
      CupSection(title:'ЗАДАТЬ РЕЗУЛЬТАТЫ',subtitle:'Завершённые и текущие LIVE-матчи защищены от изменения'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:DropdownButton<String>(isExpanded:true,value:team??'',items:[const DropdownMenuItem(value:'',child:Text('Все команды')),for(final name in names)DropdownMenuItem(value:name,child:Text(name,overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState(()=>team=v==null||v.isEmpty?null:v))),
      if(fixtures.isEmpty)const CupMessage(title:'Нет доступных матчей',message:'Будущие пары появятся после публикации ФХР. Выбери другую команду или обнови календарь.'),
      for(final m in fixtures)CupCard(child:ListTile(onTap:()=>edit(m),title:Text('${m.home} — ${m.away}',style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700)),subtitle:Text('${m.dayLabel} · ${m.stage}'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text(scores[m.key]==null?'Задать':'${scores[m.key]!.home}:${scores[m.key]!.away}${scores[m.key]!.overtime?' ОТ':''}'),if(scores[m.key]!=null)IconButton(tooltip:'Убрать результат',onPressed:(){setState(()=>scores.remove(m.key));save();},icon:const Icon(Icons.close,size:18))]))),
      const SizedBox(height:24),
    ])));
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
