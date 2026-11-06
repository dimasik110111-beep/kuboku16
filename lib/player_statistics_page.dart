import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'player_statistics.dart';
import 'team_pages.dart';
import 'ui_kit.dart';

class PlayerStatisticsPage extends StatefulWidget{
  final http.Client? client;
  const PlayerStatisticsPage({super.key,this.client});
  @override State<PlayerStatisticsPage> createState()=>_PlayerStatisticsPageState();
}
class _PlayerStatisticsPageState extends State<PlayerStatisticsPage>{
  late final CupStatisticsClient api=CupStatisticsClient(widget.client??http.Client());
  Future<CupStatistics>? pending;
  CupStatistics? latest;
  String? group,team;
  String search='';
  bool goalies=false;
  PlayerStatSort sort=PlayerStatSort.points;
  bool loading=false;
  @override void initState(){super.initState();load();}
  @override void dispose(){
    if(widget.client==null)api.client.close();
    super.dispose();
  }
  Future<void> load()async{
    if(loading)return;
    loading=true;
    final future=api.fetch(group:group);
    setState(()=>pending=future);
    try {
      final data=await future;
      if(mounted)setState((){
        latest=data;
        if(team!=null&&!data.teams.contains(team))team=null;
      });
    }catch(_){/* FutureBuilder provides the correct error state. */}
    finally{loading=false;}
  }
  String mskUpdate(DateTime? time){
    if(time==null)return 'ФХР · время не указано';
    final local=time.toUtc().add(Duration(hours:3));
    return 'ФХР · ${local.day.toString().padLeft(2,'0')}.${local.month.toString().padLeft(2,'0')} · ${local.hour.toString().padLeft(2,'0')}:${local.minute.toString().padLeft(2,'0')} МСК';
  }
  Widget sectionButton(String label,bool active,VoidCallback onTap){
    return InkWell(onTap:onTap,borderRadius:BorderRadius.circular(9),
      child:AnimatedContainer(
        duration:Duration(milliseconds:160),padding:EdgeInsets.symmetric(horizontal:13,vertical:12),
        decoration:BoxDecoration(color:active?CupUi.red:CupUi.raised,borderRadius:BorderRadius.circular(9)),
        child:Text(label,maxLines:1,style:TextStyle(color:active?CupUi.white:CupUi.soft,
          fontWeight:FontWeight.w900,fontSize:10,letterSpacing:.15)),
      ));
  }
  Widget filterWrap(String title,Widget child)=>CupCard(
    margin:EdgeInsets.fromLTRB(12,3,12,5),padding:EdgeInsets.fromLTRB(12,8,12,8),
    child:Row(children:[
      SizedBox(width:72,child:Text(title,style:TextStyle(color:CupUi.muted,fontSize:10,fontWeight:FontWeight.w800))),
      Expanded(child:child),
    ]));
  Widget groupFilter(CupStatistics source)=>filterWrap('ЭТАП',
    DropdownButtonHideUnderline(child:DropdownButton<String>(
      isExpanded:true,dropdownColor:CupUi.surface,
      value:group??'',style:TextStyle(color:CupUi.white,fontSize:11,fontWeight:FontWeight.w700),
      items:[
        DropdownMenuItem(value:'',child:Text('ВЕСЬ ТУРНИР',overflow:TextOverflow.ellipsis)),
        for(final group in source.availableGroups.where((e)=>e!='Общая статистика'))
          DropdownMenuItem(value:group,child:Text(group,maxLines:1,overflow:TextOverflow.ellipsis)),
      ],
      onChanged:(next) {
        if(next==null)return;
        setState((){
          group=next.isEmpty?null:next;
          team=null;
        });
        load();
      },
    )));
  Widget teamFilter(CupStatistics source)=>filterWrap('КОМАНДА',
    DropdownButtonHideUnderline(child:DropdownButton<String>(
      isExpanded:true,dropdownColor:CupUi.surface,
      value:team??'',style:TextStyle(color:CupUi.white,fontSize:11,fontWeight:FontWeight.w700),
      items:[
        DropdownMenuItem(value:'',child:Text('ВСЕ КОМАНДЫ',overflow:TextOverflow.ellipsis)),
        for(final club in source.teams)
          DropdownMenuItem(value:club,child:Text(club,overflow:TextOverflow.ellipsis,maxLines:1)),
      ],
      onChanged:(value)=>setState(()=>team=value==null||value.isEmpty?null:value),
    )));

  List<PlayerStatSort> get filters=>goalies
    ?const [PlayerStatSort.savesPercentage,PlayerStatSort.gaa,PlayerStatSort.wins,PlayerStatSort.saves]
    :const [PlayerStatSort.points,PlayerStatSort.goals,PlayerStatSort.assists,
      PlayerStatSort.plusMinus,PlayerStatSort.pim,PlayerStatSort.pointsPerGame];

  String statValue(CupPlayerStats p,PlayerStatSort s){
    switch(s){
      case PlayerStatSort.points:return '${p.points}';
      case PlayerStatSort.goals:return '${p.goals}';
      case PlayerStatSort.assists:return '${p.assists}';
      case PlayerStatSort.plusMinus:return p.plusMinus>0?'+${p.plusMinus}':'${p.plusMinus}';
      case PlayerStatSort.pim:return '${p.pim}';
      case PlayerStatSort.pointsPerGame:return p.pointsPerGame?.toStringAsFixed(2)??'—';
      case PlayerStatSort.savesPercentage:return p.savePercentText;
      case PlayerStatSort.gaa:return p.gaaText;
      case PlayerStatSort.wins:return '${p.wins}';
      case PlayerStatSort.saves:return '${p.saves}';
    }
  }
  List<CupPlayerStats> filtered(CupStatistics data){
    final q=search.toLowerCase().trim();
    final rows=(goalies?data.goalies:data.skaters).where((p){
      if(team!=null&&p.fullClub!=team)return false;
      return q.isEmpty||p.name.toLowerCase().contains(q)||
        p.team.toLowerCase().contains(q)||p.number.contains(q);
    });
    return sortCupPlayers(rows,sort);
  }
  Widget _playerRow(CupPlayerStats player,int index)=>InkWell(
    onTap:()=>Navigator.of(context).push(MaterialPageRoute(
      builder:(_)=>CupPlayerProfilePage(player:player))),
    child:Padding(padding:EdgeInsets.symmetric(horizontal:11,vertical:9),
      child:Row(children:[
        SizedBox(width:26,child:Text('${index+1}',style:TextStyle(
          fontWeight:FontWeight.w900,fontSize:12,
          color:index<3?CupUi.red:CupUi.muted))),
        fhrPlayerPhoto(player.photo,size:43),SizedBox(width:9),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(player.name,maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:CupUi.white,fontSize:12,fontWeight:FontWeight.w800)),
          SizedBox(height:4),
          Row(children:[
            fhrTeamLogo(player.teamLogo,size:17),SizedBox(width:5),
            Expanded(child:Text(player.fullClub,maxLines:1,overflow:TextOverflow.ellipsis,
              style:TextStyle(color:CupUi.muted,fontSize:10))),
          ]),
          SizedBox(height:3),
          Text('№${player.number} · ${player.games} игр',
            style:TextStyle(color:CupUi.dim,fontSize:10)),
        ])),
        SizedBox(width:5),
        Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
          Text(statValue(player,sort),style:TextStyle(
            color:CupUi.white,fontSize:16,fontWeight:FontWeight.w900)),
          SizedBox(height:4),
          Text(labelForSort(sort),textAlign:TextAlign.right,
            style:TextStyle(color:CupUi.muted,fontSize:8,fontWeight:FontWeight.w800)),
        ]),
        Icon(Icons.chevron_right_rounded,color:CupUi.dim,size:17),
      ])));

  Widget _podium(List<CupPlayerStats> rows) {
    if(rows.length<3)return SizedBox.shrink();
    return CupCard(
      margin:EdgeInsets.fromLTRB(12,8,12,8),
      padding:EdgeInsets.symmetric(horizontal:8,vertical:15),
      child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
        for(final i in [1,0,2]) Expanded(child:InkWell(
          onTap:()=>Navigator.of(context).push(MaterialPageRoute(
            builder:(_)=>CupPlayerProfilePage(player:rows[i]))),
          child:Column(children:[
            Text('${i+1} МЕСТО',style:TextStyle(color:i==0?CupUi.yellow:CupUi.muted,
              fontSize:9,fontWeight:FontWeight.w900)),
            SizedBox(height:10),
            Container(
              padding:EdgeInsets.all(3),
              decoration:BoxDecoration(border:Border.all(
                color:i==0?CupUi.yellow:CupUi.stroke,width:1.5),
                borderRadius:BorderRadius.circular(12)),
              child:fhrPlayerPhoto(rows[i].photo,size:i==0?75:58)),
            SizedBox(height:8),
            Text(rows[i].name,maxLines:2,overflow:TextOverflow.ellipsis,
              textAlign:TextAlign.center,
              style:TextStyle(color:CupUi.white,fontSize:10,fontWeight:FontWeight.w800)),
            SizedBox(height:5),
            Text(statValue(rows[i],sort),style:TextStyle(
              color:i==0?CupUi.yellow:CupUi.white,fontSize:22,fontWeight:FontWeight.w900)),
            Text(rows[i].team,maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,
              style:TextStyle(color:CupUi.muted,fontSize:9)),
          ]))
        ),
      ]),
    );
  }

  Widget _content(CupStatistics data){
    final rows=filtered(data);
    return ListView(children:[
      CupSection(title:'СТАТИСТИКА ИГРОКОВ',
        subtitle:'Кубок России U16 · 2026/27 · официальный источник ФХР'),
      CupCard(
        margin:EdgeInsets.fromLTRB(12,1,12,10),
        padding:EdgeInsets.symmetric(vertical:13,horizontal:14),
        child:Row(children:[
          Icon(Icons.bar_chart_rounded,color:CupUi.red,size:23),
          SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${data.skaters.length} полевых · ${data.goalies.length} вратарей',
              style:TextStyle(color:CupUi.white,fontSize:13,fontWeight:FontWeight.w900)),
            SizedBox(height:4),
            Text(mskUpdate(data.updatedAt),
              style:TextStyle(color:CupUi.muted,fontSize:10)),
          ])),
          CupTag(text:'ФХР',color:CupUi.green,filled:true),
        ])),
      Padding(padding:EdgeInsets.fromLTRB(12,0,12,9),
        child:Row(children:[
          Expanded(child:sectionButton('ПОЛЕВЫЕ',!goalies,()=>setState((){goalies=false;sort=PlayerStatSort.points;}))),
          SizedBox(width:8),
          Expanded(child:sectionButton('ВРАТАРИ',goalies,()=>setState((){goalies=true;sort=PlayerStatSort.savesPercentage;}))),
        ])),
      groupFilter(data),teamFilter(data),
      Padding(padding:EdgeInsets.fromLTRB(12,5,12,12),
        child:TextField(
          onChanged:(value)=>setState(()=>search=value),
          style:TextStyle(color:CupUi.white,fontSize:12),
          decoration:InputDecoration(
            prefixIcon:Icon(Icons.search_rounded,color:CupUi.muted,size:20),
            hintText:'Поиск по фамилии, клубу или номеру',
            hintStyle:TextStyle(color:CupUi.dim,fontSize:11),
            filled:true,fillColor:CupUi.surface,
            border:OutlineInputBorder(borderSide:BorderSide(color:CupUi.stroke),
              borderRadius:BorderRadius.circular(11)),
            enabledBorder:OutlineInputBorder(borderSide:BorderSide(color:CupUi.stroke),
              borderRadius:BorderRadius.circular(11)),
          ))),
      CupSection(title:'РЕЙТИНГ',subtitle:'Сортировка по выбранному показателю'),
      SizedBox(height:43,child:ListView(scrollDirection:Axis.horizontal,
        padding:EdgeInsets.symmetric(horizontal:12),
        children:[
          for(final metric in filters)Padding(padding:EdgeInsets.only(right:7),
            child:sectionButton(labelForSort(metric),sort==metric,
              ()=>setState(()=>sort=metric))),
        ])),
      if(goalies)Padding(padding:EdgeInsets.fromLTRB(17,10,17,3),
        child:Text('Отбитые броски показаны в процентах (1,00 у ФХР = 100%). '
          'Рейтинг учитывает все опубликованные результаты, включая малое число бросков.',
          style:TextStyle(color:CupUi.muted,fontSize:10,height:1.4))),
      _podium(rows),
      CupSection(title:'ВСЕ ИГРОКИ · ${rows.length}',
        subtitle:'Рейтинги обновляются по публикациям ФХР'),
      if(rows.isEmpty)CupMessage(title:'Ничего не найдено',
        message:'Выбери другой этап, команду или поисковый запрос.'),
      if(rows.isNotEmpty)CupCard(
        margin:EdgeInsets.fromLTRB(12,0,12,18),
        padding:EdgeInsets.symmetric(vertical:4),
        child:ListView.separated(
          shrinkWrap:true,physics:NeverScrollableScrollPhysics(),
          itemCount:rows.length,
          separatorBuilder:(_,__)=>CupDiv(indent:39),
          itemBuilder:(_,i)=>_playerRow(rows[i],i),
        )),
      Padding(padding:EdgeInsets.fromLTRB(17,2,17,22),
        child:Text('Рейтинг включает игроков, имеющих запись в официальной статистике ФХР. '
          'Игроки без опубликованной статистики доступны в общих составах команд. '
          'При отсутствии данных показатель не вычисляется самостоятельно.',
          style:TextStyle(color:CupUi.muted,fontSize:11,height:1.5))),
    ]);
  }
  @override Widget build(BuildContext context){
    return FutureBuilder<CupStatistics>(future:pending,builder:(context,snapshot){
      if(snapshot.connectionState!=ConnectionState.done && latest==null){
        return CupMessage(icon:Icons.hourglass_top_rounded,
          title:'Загружаю всю статистику ФХР',
          message:'Получаю официальные таблицы полевых игроков и вратарей.');
      }
      if(snapshot.hasError && latest==null){
        return CupMessage(icon:Icons.cloud_off_outlined,
          title:'Статистика ФХР временно недоступна',
          message:'Не удалось получить полные таблицы. ${snapshot.error}',
          retry:load);
      }
      final data=snapshot.hasData?snapshot.data!:latest;
      if(data==null)return SizedBox.shrink();
      return RefreshIndicator(onRefresh:load,child:_content(data));
    });
  }
}

class CupPlayerProfilePage extends StatelessWidget{
  final CupPlayerStats player;
  const CupPlayerProfilePage({super.key,required this.player});
  @override Widget build(BuildContext context){
    final stats=player.goalie
      ?<({String label,String value})>[
        (label:'МАТЧИ',value:'${player.games}'),(label:'ПОБЕДЫ',value:'${player.wins}'),
        (label:'ПОРАЖЕНИЯ',value:'${player.losses}'),(label:'% ОБ',value:player.savePercentText),
        (label:'КН',value:player.gaaText),(label:'БРОСКИ',value:'${player.shotsAgainst}'),
        (label:'СЕЙВЫ',value:'${player.saves}'),(label:'ПРОПУЩЕНО',value:'${player.goalsAgainst}'),
        (label:'СУХИЕ',value:'${player.shutouts}'),(label:'МИНУТЫ',value:player.timeOnIce),
      ]
      :<({String label,String value})>[
        (label:'МАТЧИ',value:'${player.games}'),(label:'ШАЙБЫ',value:'${player.goals}'),
        (label:'ПЕРЕДАЧИ',value:'${player.assists}'),(label:'ОЧКИ',value:'${player.points}'),
        (label:'+/-',value:'${player.plusMinus}'),(label:'ШТРАФ',value:'${player.pim}'),
        (label:'О/И',value:player.pointsPerGame?.toStringAsFixed(2)??'—'),
      ];
    final uri=Uri.tryParse(player.profile);
    final trusted=uri!=null && uri.scheme=='https' && uri.host=='junior.fhr.ru';
    return Scaffold(backgroundColor:CupUi.background,
      appBar:AppBar(title:Text('ИГРОК · КУБОК РОССИИ U16',
        style:TextStyle(color:CupUi.white,fontSize:14,fontWeight:FontWeight.w900))),
      body:ListView(children:[
        CupCard(margin:EdgeInsets.fromLTRB(12,10,12,8),
          padding:EdgeInsets.fromLTRB(15,22,15,20),
          child:Column(children:[
            fhrPlayerPhoto(player.photo,size:122),
            SizedBox(height:15),
            Text(player.name,textAlign:TextAlign.center,
              style:TextStyle(color:CupUi.white,fontSize:19,fontWeight:FontWeight.w900)),
            SizedBox(height:9),
            CupTag(text:'№${player.number} · ${player.position.toUpperCase()}',
              color:CupUi.red,filled:true),
            SizedBox(height:16),
            Row(mainAxisAlignment:MainAxisAlignment.center,children:[
              fhrTeamLogo(player.teamLogo,size:27),
              SizedBox(width:8),
              Flexible(child:Text(player.fullClub,
                style:TextStyle(color:CupUi.soft,fontWeight:FontWeight.w700,fontSize:12))),
            ]),
          ])),
        CupSection(title:'СТАТИСТИКА В ТУРНИРЕ',
          subtitle:'Сезон 2026/27 · данные ФХР'),
        CupCard(padding:EdgeInsets.all(12),
          child:GridView.builder(
            shrinkWrap:true,physics:NeverScrollableScrollPhysics(),
            itemCount:stats.length,
            gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:3,crossAxisSpacing:9,mainAxisSpacing:9,childAspectRatio:1.55),
            itemBuilder:(_,i)=>Container(
              decoration:BoxDecoration(color:CupUi.raised,borderRadius:BorderRadius.circular(10)),
              child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                Text(stats[i].value,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:CupUi.white,fontSize:17,fontWeight:FontWeight.w900)),
                SizedBox(height:4),
                Text(stats[i].label,maxLines:1,style:TextStyle(
                  color:CupUi.muted,fontSize:10,fontWeight:FontWeight.w700)),
              ]),
            ),
          )),
        if(trusted)Padding(padding:EdgeInsets.fromLTRB(12,13,12,2),
          child:FilledButton.icon(
            onPressed:()=>launchUrl(uri,mode:LaunchMode.externalApplication),
            icon:Icon(Icons.open_in_new_rounded,size:18),
            label:Text('ПРОФИЛЬ НА ФХР'))),
        Padding(padding:EdgeInsets.fromLTRB(15,10,15,26),
          child:Text('Сезонная статистика обновляется на основе официальных публикаций ФХР. '
            'Показатели вратарей могут зависеть от числа сыгранных минут и бросков.',
            style:TextStyle(color:CupUi.muted,fontSize:11,height:1.5))),
      ]),
    );
  }
}
