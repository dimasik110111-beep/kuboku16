import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'cup_data.dart';
import 'ui_kit.dart';

Widget fhrTeamLogo(String? url,{double size=32}) {
  final uri=url==null?null:Uri.tryParse(url);
  final valid=uri!=null&&uri.scheme=='https'&&uri.host=='img.fhr.ru'&&uri.path.startsWith('/teams/');
  return SizedBox(width:size,height:size,
    child:valid
      ? Image.network(url!,fit:BoxFit.contain,
        errorBuilder:(_,__,___)=>Icon(Icons.shield_outlined,color:CupUi.muted))
      : Icon(Icons.shield_outlined,color:CupUi.muted));
}

Widget fhrPlayerPhoto(String? url,{double size=54}){
  final uri=url==null?null:Uri.tryParse(url);
  final valid=uri!=null&&uri.scheme=='https'&&uri.host=='img.fhr.ru'&&uri.path.startsWith('/players/');
  return ClipRRect(borderRadius:BorderRadius.circular(9),
    child:Container(width:size,height:size,color:CupUi.raised,
      child:valid?Image.network(url!,fit:BoxFit.cover,
        errorBuilder:(_,__,___)=>Icon(Icons.person_outline,color:CupUi.muted)):
        Icon(Icons.person_outline,color:CupUi.muted)));
}

Future<void> fhrOpen(String url) async{
  final uri=Uri.tryParse(url);
  if(uri==null||uri.scheme!='https'||uri.host!='junior.fhr.ru')return;
  await launchUrl(uri,mode:LaunchMode.externalApplication);
}

class TeamRosterPage extends StatefulWidget {
  final TeamInfo team;
  const TeamRosterPage({super.key,required this.team});
  @override State<TeamRosterPage> createState()=>_TeamRosterPageState();
}

class _TeamRosterPageState extends State<TeamRosterPage> {
  final FhrApiClient api=FhrApiClient(http.Client());
  late Future<TeamRoster> future;
  String query='';
  @override void initState(){super.initState();future=api.roster(widget.team.id);}
  @override void dispose(){api.client.close();super.dispose();}
  Future<void> refresh() async{
    setState(()=>future=api.roster(widget.team.id));
    try{await future;}catch(_){/* Error is rendered by FutureBuilder. */}
  }

  Widget _header(int count)=>Container(
    margin:EdgeInsets.fromLTRB(12,8,12,12),
    padding:EdgeInsets.fromLTRB(14,25,14,24),
    decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
      colors:CupUi.heroGradient),borderRadius:BorderRadius.circular(30),
      border:Border.all(color:CupUi.ice.withValues(alpha:.18))),
    child:Column(children:[
      Container(width:94,height:94,padding:EdgeInsets.all(10),
        decoration:BoxDecoration(color:CupUi.raised,borderRadius:BorderRadius.circular(22)),
        child:fhrTeamLogo(widget.team.logo,size:74)),
      SizedBox(height:14),
      Text(widget.team.name,textAlign:TextAlign.center,
        style:TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:Colors.white,letterSpacing:-.8)),
      SizedBox(height:5),
      Text(widget.team.city,style:TextStyle(fontSize:12,color:CupUi.soft)),
      SizedBox(height:17),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        CupTag(text:'U16 · 2026/27',color:CupUi.soft,filled:true),
        SizedBox(width:7),
        CupTag(text:'$count ИГРОКОВ',color:CupUi.green,filled:true),
      ]),
    ]),
  );

  List<PlayerInfo> _filter(List<PlayerInfo> players){
    if(query.isEmpty)return players;
    final q=query.toLowerCase();
    return players.where((e)=>e.name.toLowerCase().contains(q)||
      e.number.toLowerCase().contains(q)).toList();
  }
  Widget _rosterGroup(String title,List<PlayerInfo> players){
    if(players.isEmpty)return SizedBox.shrink();
    players.sort((a,b){
      final n=int.tryParse(a.number),m=int.tryParse(b.number);
      if(n!=null&&m!=null)return n.compareTo(m);
      return a.name.compareTo(b.name);
    });
    return Column(children:[
      CupSection(title:title,subtitle:'${players.length} игроков'),
      CupCard(padding:EdgeInsets.symmetric(vertical:2),
        child:Column(children:[
          for(var i=0;i<players.length;i++)...[
            InkWell(onTap:()=>Navigator.of(context).push(MaterialPageRoute(
              builder:(_)=>PlayerCardPage(player:players[i],team:widget.team))),
              child:Padding(padding:EdgeInsets.symmetric(horizontal:11,vertical:9),
                child:Row(children:[
                  fhrPlayerPhoto(players[i].photo,size:44),
                  SizedBox(width:10),
                  SizedBox(width:33,child:Text('#${players[i].number}',
                    style:TextStyle(fontSize:13,fontWeight:FontWeight.w900,color:CupUi.red))),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(players[i].name,maxLines:2,overflow:TextOverflow.ellipsis,
                      style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:CupUi.white)),
                    SizedBox(height:4),
                    Text(players[i].position,style:TextStyle(fontSize:11,color:CupUi.muted)),
                  ])),
                  Icon(Icons.chevron_right,color:CupUi.dim,size:18),
                ]))),
            if(i+1<players.length)CupDiv(indent:58),
          ],
        ]),
      ),
    ]);
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:CupUi.background,
    appBar:AppBar(title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('КОМАНДА',style:TextStyle(color:CupUi.white,fontWeight:FontWeight.w900,fontSize:15)),
      Text('КУБОК РОССИИ · U16',style:TextStyle(color:CupUi.muted,fontSize:10,letterSpacing:.5)),
    ]),actions:[
      IconButton(onPressed:refresh,icon:Icon(Icons.refresh_rounded)),
      IconButton(onPressed:()=>fhrOpen(widget.team.url),
        icon:Icon(Icons.open_in_new_rounded,size:20)),
    ]),
    body:FutureBuilder<TeamRoster>(future:future,builder:(context,snapshot){
      if(snapshot.connectionState!=ConnectionState.done){
        return CupMessage(icon:Icons.hourglass_top,title:'Загружаю состав',
          message:'Получаю имена и фотографии игроков с ФХР Джуниор.');
      }
      if(snapshot.hasError){
        return CupMessage(icon:Icons.cloud_off_outlined,title:'Состав временно недоступен',
          message:'ФХР не ответила: ${snapshot.error}',retry:refresh);
      }
      final roster=snapshot.data!;
      final all=_filter(roster.players);
      final goalies=all.where((x)=>x.position.toLowerCase().contains('вратарь')).toList();
      final defenders=all.where((x)=>x.position.toLowerCase().contains('защитник')).toList();
      final forwards=all.where((x)=>x.position.toLowerCase().contains('нападающий')).toList();
      final others=all.where((x)=>!goalies.contains(x)&&!defenders.contains(x)&&!forwards.contains(x)).toList();
      return RefreshIndicator(onRefresh:refresh,child:ListView(children:[
        _header(roster.players.length),
        CupSection(title:'СОСТАВ КОМАНДЫ',subtitle:'Реестр игроков ФХР Джуниор'),
        Padding(padding:EdgeInsets.symmetric(horizontal:12),child:TextField(
          onChanged:(v)=>setState(()=>query=v),
          style:TextStyle(color:CupUi.white,fontSize:13),
          decoration:InputDecoration(
            prefixIcon:Icon(Icons.search,color:CupUi.muted,size:20),
            hintText:'Игрок или номер',hintStyle:TextStyle(color:CupUi.dim,fontSize:12),
            filled:true,fillColor:CupUi.surface,
            contentPadding:EdgeInsets.symmetric(vertical:11,horizontal:13),
            border:OutlineInputBorder(borderSide:BorderSide(color:CupUi.stroke),
              borderRadius:BorderRadius.circular(11)),
            enabledBorder:OutlineInputBorder(borderSide:BorderSide(color:CupUi.stroke),
              borderRadius:BorderRadius.circular(11)),
            focusedBorder:OutlineInputBorder(borderSide:BorderSide(color:CupUi.red),
              borderRadius:BorderRadius.circular(11)),
          ))),
        _rosterGroup('ВРАТАРИ',goalies),_rosterGroup('ЗАЩИТНИКИ',defenders),
        _rosterGroup('НАПАДАЮЩИЕ',forwards),_rosterGroup('ДРУГИЕ',others),
        if(all.isEmpty)CupMessage(title:'Игрок не найден',
          message:'Попробуй другую фамилию или игровой номер.'),
        Padding(padding:EdgeInsets.fromLTRB(17,12,17,27),
          child:Text('Официальный состав ФХР. Заявка на конкретный матч может отличаться.',
            style:TextStyle(color:CupUi.muted,fontSize:11,height:1.4))),
      ]));
    }),
  );
}

class PlayerCardPage extends StatelessWidget {
  final PlayerInfo player;
  final TeamInfo team;
  const PlayerCardPage({super.key,required this.player,required this.team});
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:CupUi.background,
    appBar:AppBar(title:Text('ПРОФИЛЬ ИГРОКА',
      style:TextStyle(color:CupUi.white,fontSize:15,fontWeight:FontWeight.w900))),
    body:ListView(children:[
      CupCard(margin:EdgeInsets.fromLTRB(12,12,12,10),
        padding:EdgeInsets.fromLTRB(16,25,16,25),
        child:Column(children:[
          Container(padding:EdgeInsets.all(4),
            decoration:BoxDecoration(border:Border.all(color:CupUi.stroke),
              borderRadius:BorderRadius.circular(17)),
            child:fhrPlayerPhoto(player.photo,size:146)),
          SizedBox(height:19),
          Text(player.name,textAlign:TextAlign.center,
            style:TextStyle(color:CupUi.white,fontSize:21,fontWeight:FontWeight.w900,height:1.2)),
          SizedBox(height:11),
          CupTag(text:'№ ${player.number}  ·  ${player.position.toUpperCase()}',
            color:CupUi.red,filled:true),
          SizedBox(height:20),
          CupDiv(),
          SizedBox(height:15),
          Row(mainAxisAlignment:MainAxisAlignment.center,children:[
            fhrTeamLogo(team.logo,size:32),SizedBox(width:10),
            Flexible(child:Text(team.fullName,style:TextStyle(
              color:CupUi.soft,fontSize:12,fontWeight:FontWeight.w700))),
          ]),
        ]),
      ),
      CupSection(title:'ДАННЫЕ ИГРОКА'),
      CupCard(padding:EdgeInsets.symmetric(horizontal:15,vertical:16),
        child:Column(children:[
          Row(children:[
            Expanded(child:Text('Команда',style:TextStyle(color:CupUi.muted,fontSize:12))),
            Flexible(child:Text(team.name,textAlign:TextAlign.right,
              style:TextStyle(color:CupUi.white,fontSize:12,fontWeight:FontWeight.w700))),
          ]),
          SizedBox(height:13),CupDiv(),SizedBox(height:13),
          Row(children:[
            Expanded(child:Text('Амплуа',style:TextStyle(color:CupUi.muted,fontSize:12))),
            Text(player.position,style:TextStyle(color:CupUi.white,fontSize:12,fontWeight:FontWeight.w700)),
          ]),
        ])),
      Padding(padding:EdgeInsets.fromLTRB(18,10,18,10),
        child:Text('Фото и сведения получены из официального профиля ФХР Джуниор.',
          style:TextStyle(color:CupUi.muted,fontSize:11))),
      Padding(padding:EdgeInsets.symmetric(horizontal:12),child:FilledButton.icon(
        onPressed:()=>fhrOpen(player.url),icon:Icon(Icons.open_in_new_rounded,size:18),
        label:Text('ПРОФИЛЬ НА ФХР'))),
      SizedBox(height:30),
    ]),
  );
}
