import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cup_data.dart';
import 'insights.dart';
import 'team_pages.dart';
import 'ui_kit.dart';
import 'app_services.dart';

const myTeamPreference='junior_my_team_id';
Match? nextTeamMatch(List<Match> games,String team,{DateTime? utcNow}){
  final now=utcNow??DateTime.now().toUtc();
  final rows=teamFixtures(games,team).where((m)=>!m.isResultAt(now)).toList();
  final live=rows.where((m)=>m.isLive).toList();
  if(live.isNotEmpty)return live.first;
  final today=now.add(const Duration(hours:3)).toIso8601String().substring(0,10);
  rows.removeWhere((m)=>m.date.compareTo(today)<0);
  rows.sort((a,b)=>'${a.date} ${a.timeMsk}'.compareTo('${b.date} ${b.timeMsk}'));
  return rows.isEmpty?null:rows.first;
}
class MyTeamCard extends StatefulWidget{
  final List<TeamInfo> teams;final List<Match> matches;
  final ValueChanged<TeamInfo> onTeam;final ValueChanged<Match> onMatch;
  const MyTeamCard({super.key,required this.teams,required this.matches,required this.onTeam,required this.onMatch});
  @override State<MyTeamCard> createState()=>_MyTeamCardState();
}
class _MyTeamCardState extends State<MyTeamCard>{
  int? selectedId;bool loaded=false;
  @override void initState(){super.initState();restore();}
  Future<void> restore()async{
    try{final prefs=await SharedPreferences.getInstance();if(mounted)setState((){selectedId=prefs.getInt(myTeamPreference);loaded=true;});}
    catch(e){Diagnostics.record('my team restore',e);if(mounted)setState(()=>loaded=true);}
  }
  Future<void> select()async{
    if(widget.teams.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Сначала загрузи список команд.')));return;}
    final chosen=await showModalBottomSheet<int>(context:context,isScrollControlled:true,useSafeArea:true,builder:(context)=>TeamPicker(teams:widget.teams,selectedId:selectedId));
    if(chosen==null||!mounted)return;
    try{
      final prefs=await SharedPreferences.getInstance();
      if(chosen<0){await prefs.remove(myTeamPreference);}else{await prefs.setInt(myTeamPreference,chosen);}
      if(mounted)setState(()=>selectedId=chosen<0?null:chosen);
    }catch(e){Diagnostics.record('my team save',e);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Не удалось сохранить команду. Попробуй ещё раз.')));}
  }
  @override Widget build(BuildContext context){
    TeamInfo? selected;for(final t in widget.teams){if(t.id==selectedId){selected=t;break;}}
    final club=selected;
    if(!loaded)return const SizedBox.shrink();
    if(club==null)return CupCard(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('МОЯ КОМАНДА',style:TextStyle(color:CupUi.red,fontWeight:FontWeight.w800,letterSpacing:1)),const SizedBox(height:8),
      Text(selectedId==null?'Твой Кубок — на первом экране':'Жду данные выбранной команды',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),const SizedBox(height:8),
      const Text('Ближайшая игра, место в таблице и быстрый переход к составу.'),const SizedBox(height:12),
      FilledButton.icon(onPressed:select,icon:const Icon(Icons.shield_outlined),label:Text(selectedId==null?'Выбрать мою команду':'Выбрать другую команду')),
    ]));
    final next=nextTeamMatch(widget.matches,club.fullName);
    final table=ranking(widget.matches,participants:widget.teams.map((t)=>t.fullName));
    final index=table.indexWhere((r)=>sameClub(r.team,club.fullName));
    final rank=index<0?null:table[index];
    return CupCard(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text('МОЯ КОМАНДА',style:TextStyle(color:CupUi.red,fontWeight:FontWeight.w800,letterSpacing:1))),TextButton(onPressed:select,child:const Text('Сменить'))]),
      InkWell(onTap:()=>widget.onTeam(club),child:Row(children:[fhrTeamLogo(club.logo,size:56),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(club.name,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900)),Text(club.city,style:TextStyle(color:CupUi.muted))])),const Icon(Icons.chevron_right)])),
      const SizedBox(height:18),
      if(rank!=null)Wrap(spacing:8,runSpacing:8,children:[CupTag(text:'${index+1} МЕСТО${rank.provisionalTie?'*':''}',color:CupUi.green,filled:true),CupTag(text:'${rank.pts} ОЧКОВ',color:CupUi.soft),CupTag(text:'${rank.gp} ИГР',color:CupUi.soft)]),
      const SizedBox(height:14),
      if(rank?.provisionalTie??false)const Text('* Порядок при равенстве очков предварительный.',style:TextStyle(fontSize:11)),
      if(next==null)const Text('Ближайшая игра ещё не опубликована.')else InkWell(onTap:()=>widget.onMatch(next),child:Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(next.isLive?'СЕЙЧАС НА ЛЬДУ':'БЛИЖАЙШАЯ ИГРА',style:TextStyle(color:next.isLive?CupUi.green:CupUi.muted,fontWeight:FontWeight.w700,fontSize:11)),const SizedBox(height:7),
        Text('${next.home} — ${next.away}',style:const TextStyle(fontWeight:FontWeight.w700)),
        Text('${next.dayLabel} · ${next.timeMsk.isEmpty?'Время уточняется':'${next.timeMsk} МСК'}${next.isLive&&next.hasScore?' · ${next.score}':''}'),
      ]))),
      TextButton.icon(onPressed:()=>widget.onTeam(club),icon:const Icon(Icons.groups_outlined),label:const Text('Состав и профиль команды')),
    ]));
  }
}
class TeamPicker extends StatefulWidget{
  final List<TeamInfo> teams;final int? selectedId;
  const TeamPicker({super.key,required this.teams,this.selectedId});
  @override State<TeamPicker> createState()=>_TeamPickerState();
}
class _TeamPickerState extends State<TeamPicker>{
  String query='';
  @override Widget build(BuildContext context){
    final list=widget.teams.where((t)=>clubKey(t.fullName).contains(clubKey(query))).toList();
    return Padding(padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(context).bottom),child:SizedBox(height:MediaQuery.sizeOf(context).height*.75,child:Column(children:[
      const SizedBox(height:16),const Text('Выбери свою команду',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
      Padding(padding:const EdgeInsets.all(16),child:TextField(autofocus:false,onChanged:(q)=>setState(()=>query=q),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Команда или город'))),
      if(widget.selectedId!=null)TextButton(onPressed:()=>Navigator.pop(context,-1),child:const Text('Убрать мою команду')),
      Expanded(child:ListView.builder(itemCount:list.length,itemBuilder:(_,i)=>ListTile(leading:fhrTeamLogo(list[i].logo,size:40),title:Text(list[i].name),subtitle:Text(list[i].city),trailing:list[i].id==widget.selectedId?const Icon(Icons.check_circle):null,onTap:()=>Navigator.pop(context,list[i].id)))),
    ])));
  }
}
