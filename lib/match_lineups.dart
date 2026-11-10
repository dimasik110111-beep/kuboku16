import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'team_pages.dart';
import 'ui_kit.dart';

int? _num(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString()??'');

class GamePlayerStats {
  final int? goals,assists,points,penaltyMinutes;
  const GamePlayerStats({this.goals,this.assists,this.points,this.penaltyMinutes});
  factory GamePlayerStats.fromApi(Map<String,dynamic> value) => GamePlayerStats(
    goals:_num(value['goals']),assists:_num(value['assists']),
    points:_num(value['points']),penaltyMinutes:_num(value['penaltyMinutes']),
  );
  bool get published => [goals,assists,points,penaltyMinutes].any((x)=>x!=null);
}

class GamePlayer {
  final String name,number,position,assignment;
  final String? captainRole,photo,url;
  final GamePlayerStats? stats;
  const GamePlayer({
    required this.name,required this.number,required this.position,
    this.assignment='',this.captainRole,this.photo,this.url,this.stats,
  });
  factory GamePlayer.fromApi(Map<String,dynamic> value)=>GamePlayer(
    name:value['name']?.toString()??'',
    number:value['number']?.toString()??'',
    position:_position(value['position']),
    assignment:value['assignment']?.toString()??'',
    captainRole:value['captainRole']?.toString(),
    photo:value['photo']?.toString(),
    url:value['url']?.toString(),
    stats:value['stats'] is Map
      ?GamePlayerStats.fromApi(Map<String,dynamic>.from(value['stats'] as Map)):null,
  );
  static String _position(dynamic raw){
    final value=raw?.toString().trim().toUpperCase().replaceAll('Ё','Е')??'';
    if(const {'GOALIE','GOALTENDER','GK','G','ВРАТАРЬ','ВР'}.contains(value))return 'GOALIE';
    if(const {'DEFENDER','DEFENCE','D','ЗАЩИТНИК','ЗАЩ'}.contains(value))return 'DEFENDER';
    if(const {'FORWARD','F','НАПАДАЮЩИЙ','НАПАДАЮЩАЯ','НАП'}.contains(value))return 'FORWARD';
    return value;
  }
  String get positionLabel {
    switch(position) {
      case 'GOALIE':return 'Вратарь';
      case 'DEFENDER':return 'Защитник';
      case 'FORWARD':return 'Нападающий';
      default:return 'Игрок';
    }
  }
}

class GameStaff {
  final String name,position;
  final String? photo;
  const GameStaff({required this.name,required this.position,this.photo});
  factory GameStaff.fromApi(Map<String,dynamic> value)=>GameStaff(
    name:value['name']?.toString()??'',
    position:value['position']?.toString()??'',
    photo:value['photo']?.toString(),
  );
}

class GameSide {
  final String side;
  final String? logo;
  final bool verified;
  final List<GamePlayer> players;
  final List<GameStaff> staff;
  const GameSide({required this.side,required this.players,required this.staff,this.logo,this.verified=false});
  factory GameSide.fromApi(Map<String,dynamic> value,{String fallbackSide=''})=>GameSide(
    side:const {'home':'home','away':'away'}[value['side']?.toString().toLowerCase()]??fallbackSide,
    logo:value['logo']?.toString(),
    verified:value['verified']==true,
    players:value['players'] is List
      ?(value['players'] as List).whereType<Map>().map((x)=>GamePlayer.fromApi(Map<String,dynamic>.from(x)))
        .where((x)=>x.name.isNotEmpty).toList():[],
    staff:value['staff'] is List
      ?(value['staff'] as List).whereType<Map>().map((x)=>GameStaff.fromApi(Map<String,dynamic>.from(x)))
        .where((x)=>x.name.isNotEmpty).toList():[],
  );
  int get goalies=>players.where((x)=>x.position=='GOALIE').length;
  int get skaters=>players.where((x)=>x.position!='GOALIE').length;
}

class GameLineups {
  final bool available,partial;
  final List<GameSide> teams;
  const GameLineups({required this.available,required this.partial,required this.teams});
  factory GameLineups.fromDetail(Map<String,dynamic>? data){
    final value=data?['matchLineups'];
    if(value is! Map)return GameLineups(available:false,partial:false,teams:[]);
    final obj=Map<String,dynamic>.from(value);
    final teams=obj['teams'] is List ?(obj['teams'] as List).whereType<Map>()
      .toList().asMap().entries.map((e)=>GameSide.fromApi(
        Map<String,dynamic>.from(e.value),fallbackSide:e.key==0?'home':'away'))
      .toList():<GameSide>[];
    return GameLineups(available:obj['available']==true&&teams.length==2,
      partial:obj['partial']==true,teams:teams);
  }
  GameSide? side(String side){
    for(final t in teams)if(t.side==side)return t;
    return null;
  }
  List<GamePlayer> get allPlayers=>[for(final team in teams)...team.players];
}

class MatchLineupPanel extends StatefulWidget {
  final GameLineups lineups;
  final String home,away;
  final String? homeLogo,awayLogo;
  const MatchLineupPanel({super.key,required this.lineups,required this.home,required this.away,
    this.homeLogo,this.awayLogo});
  @override
  State<MatchLineupPanel> createState()=>_MatchLineupPanelState();
}
class _MatchLineupPanelState extends State<MatchLineupPanel>{
  int selected=0;
  @override
  Widget build(BuildContext context) {
    final lineup=widget.lineups;
    if(!lineup.available && lineup.teams.isEmpty){
      return CupMessage(icon:Icons.description_outlined,
        title:'Заявка ещё не опубликована',
        message:'ФХР пока не предоставила составы именно этой встречи. Общие составы клубов не подставляются вместо заявки.');
    }
    final team=lineup.side(selected==0?'home':'away');
    final teamName=selected==0?widget.home:widget.away;
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      CupSection(title:'ЗАЯВКА НА МАТЧ',subtitle:'Источник: официальный протокол ФХР Джуниор'),
      Padding(padding:EdgeInsets.symmetric(horizontal:12),
        child:Row(children:[
          if(lineup.available)CupTag(text:'ПОДТВЕРЖДЕНО ФХР',color:CupUi.green,filled:true)
          else CupTag(text:'ЗАЯВКА ЧАСТИЧНАЯ',color:CupUi.yellow,filled:true),
          Spacer(),
          Text(team==null?'': '${team.players.length} игроков',
            style:TextStyle(color:CupUi.muted,fontSize:11)),
        ])),
      SizedBox(height:10),
      CupCard(
        margin:EdgeInsets.fromLTRB(12,1,12,10),padding:EdgeInsets.all(3),
        child:Row(children:[
          for(var i=0;i<2;i++)Expanded(child:InkWell(
            onTap:()=>setState(()=>selected=i),
            borderRadius:BorderRadius.circular(10),
            child:AnimatedContainer(duration:Duration(milliseconds:160),
              padding:EdgeInsets.symmetric(vertical:13,horizontal:7),
              decoration:BoxDecoration(color:selected==i?CupUi.raised:Colors.transparent,
                borderRadius:BorderRadius.circular(10),
                border:Border(bottom:BorderSide(color:selected==i?CupUi.red:Colors.transparent,width:2))),
              child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                fhrTeamLogo(i==0?widget.homeLogo:widget.awayLogo,size:25),
                SizedBox(width:7),
                Flexible(child:Text(i==0?widget.home:widget.away,maxLines:1,
                  overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,
                  style:TextStyle(color:selected==i?CupUi.white:CupUi.muted,fontSize:11,
                    fontWeight:FontWeight.w800))),
              ])),
          )),
        ])),
      if(team==null)CupMessage(title:'Состав не опубликован',
        message:'Для выбранной стороны пока нет подтверждённой заявки ФХР.')
      else ...[
        Padding(padding:EdgeInsets.fromLTRB(17,4,17,5),child:Text(
          teamName.toUpperCase(),style:TextStyle(color:CupUi.white,fontSize:12,
            fontWeight:FontWeight.w900,letterSpacing:.3))),
        Padding(padding:EdgeInsets.fromLTRB(17,0,17,8),
          child:Text('${team.players.length} игроков · ${team.goalies} вратарей · ${team.skaters} полевых',
            style:TextStyle(color:CupUi.muted,fontSize:11))),
        for(final entry in const [
          ('GOALIE','ВРАТАРИ'),('DEFENDER','ЗАЩИТНИКИ'),('FORWARD','НАПАДАЮЩИЕ'),
        ]) if(team.players.any((p)=>p.position==entry.$1))...[
          CupSection(title:entry.$2,subtitle:'${team.players.where((p)=>p.position==entry.$1).length} игроков'),
          CupCard(padding:EdgeInsets.symmetric(vertical:2),
            child:Column(children:[
              for(final player in team.players.where((p)=>p.position==entry.$1))
                _playerRow(context,player,teamName),
            ])),
        ],
        if(team.staff.isNotEmpty)...[
          CupSection(title:'ТРЕНЕРСКИЙ ШТАБ',subtitle:'По заявке на матч'),
          CupCard(padding:EdgeInsets.symmetric(vertical:4),child:Column(children:[
            for(final staff in team.staff)Padding(padding:EdgeInsets.symmetric(horizontal:13,vertical:9),
              child:Row(children:[
                _personnelPhoto(staff.photo),SizedBox(width:11),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(staff.name,style:TextStyle(color:CupUi.white,fontSize:12,fontWeight:FontWeight.w700)),
                  SizedBox(height:4),
                  Text(staff.position,style:TextStyle(color:CupUi.muted,fontSize:11)),
                ])),
              ])),
          ])),
        ],
      ],
      Padding(padding:EdgeInsets.fromLTRB(17,13,17,24),child:Text(
        'Статистика игроков и роли капитанов отображаются по сведениям, опубликованным ФХР именно для этого матча.',
        style:TextStyle(color:CupUi.dim,fontSize:11,height:1.45))),
    ]);
  }

  Widget _personnelPhoto(String? url){
    final u=url==null?null:Uri.tryParse(url);
    final ok=u!=null&&u.scheme=='https'&&u.host=='img.fhr.ru'&&u.path.startsWith('/personals/');
    return ClipRRect(borderRadius:BorderRadius.circular(8),
      child:Container(color:CupUi.raised,width:42,height:42,child:ok
        ?Image.network(url!,fit:BoxFit.cover,errorBuilder:(_,__,___)=>
          Icon(Icons.person_outline,color:CupUi.muted))
        :Icon(Icons.person_outline,color:CupUi.muted)));
  }

  Widget _playerRow(BuildContext context,GamePlayer p,String teamName){
    return InkWell(
      onTap:()=>showModalBottomSheet<void>(
        context:context,isScrollControlled:true,
        backgroundColor:CupUi.surface,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(22))),
        builder:(_)=>_playerSheet(p,teamName)),
      child:Padding(padding:EdgeInsets.fromLTRB(12,10,12,10),
        child:Row(children:[
          fhrPlayerPhoto(p.photo,size:43),SizedBox(width:10),
          SizedBox(width:28,child:Text('#${p.number}',
            style:TextStyle(color:CupUi.red,fontSize:12,fontWeight:FontWeight.w900))),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Flexible(child:Text(p.name,maxLines:1,overflow:TextOverflow.ellipsis,
                style:TextStyle(color:CupUi.white,fontSize:12,fontWeight:FontWeight.w700))),
              if(p.captainRole=='C'||p.captainRole=='A')...[
                SizedBox(width:5),
                CupTag(text:p.captainRole=='C'?'К':'А',color:CupUi.yellow,filled:true),
              ],
            ]),
            SizedBox(height:5),
            if(p.stats!=null&&p.stats!.published)
              Text('Г ${p.stats!.goals??'–'}   П ${p.stats!.assists??'–'}   О ${p.stats!.points??'–'}   Штр ${p.stats!.penaltyMinutes??'–'}',
                style:TextStyle(color:CupUi.muted,fontSize:10,fontWeight:FontWeight.w600))
            else Text(p.assignment.isNotEmpty?'Отметка ФХР: ${p.assignment}':p.positionLabel,
              style:TextStyle(color:CupUi.muted,fontSize:10)),
          ])),
          SizedBox(width:5),
          Icon(Icons.chevron_right_rounded,size:18,color:CupUi.dim),
        ])));
  }

  Widget _playerSheet(GamePlayer p,String teamName){
    final url=Uri.tryParse(p.url??'');
    final canOpen=url!=null&&url.scheme=='https'&&url.host=='junior.fhr.ru'
      &&url.path.startsWith('/player/');
    return SafeArea(top:false,child:Padding(padding:EdgeInsets.fromLTRB(18,13,18,26),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Container(width:38,height:4,decoration:BoxDecoration(color:CupUi.stroke,
          borderRadius:BorderRadius.circular(3))),
        SizedBox(height:21),
        fhrPlayerPhoto(p.photo,size:108),
        SizedBox(height:13),
        Text(p.name,textAlign:TextAlign.center,
          style:TextStyle(color:CupUi.white,fontSize:20,fontWeight:FontWeight.w900)),
        SizedBox(height:8),
        CupTag(text:'#${p.number} · ${p.positionLabel.toUpperCase()}',
          color:CupUi.red,filled:true),
        SizedBox(height:11),
        Text(teamName,textAlign:TextAlign.center,
          style:TextStyle(color:CupUi.muted,fontSize:12)),
        if(p.captainRole!=null)Padding(padding:EdgeInsets.only(top:7),
          child:Text(p.captainRole=='C'?'Капитан':'Ассистент капитана',
            style:TextStyle(color:CupUi.yellow,fontSize:11,fontWeight:FontWeight.w700))),
        if(p.stats!=null&&p.stats!.published)...[
          SizedBox(height:22),
          Row(children:[
            for(final (label,value) in [
              ('Г',p.stats!.goals),('П',p.stats!.assists),('О',p.stats!.points),
              ('ШТР',p.stats!.penaltyMinutes),
            ]) Expanded(child:Column(children:[
              Text(value?.toString()??'–',style:TextStyle(color:CupUi.white,fontSize:19,fontWeight:FontWeight.w900)),
              SizedBox(height:3),
              Text(label,style:TextStyle(color:CupUi.muted,fontSize:10,fontWeight:FontWeight.w700)),
            ])),
          ]),
        ],
        if(canOpen)...[
          SizedBox(height:22),
          SizedBox(width:double.infinity,child:FilledButton.icon(
            onPressed:()=>launchUrl(url,mode:LaunchMode.externalApplication),
            icon:Icon(Icons.open_in_new_rounded,size:17),
            label:Text('ПРОФИЛЬ ИГРОКА НА ФХР'))),
        ],
      ])));
  }
}

class MatchScorersPanel extends StatelessWidget {
  final GameLineups lineups;
  final String home,away;
  const MatchScorersPanel({super.key,required this.lineups,required this.home,required this.away});
  @override Widget build(BuildContext context){
    if(!lineups.available)return SizedBox.shrink();
    final scorers=<({GamePlayer player,String club})>[];
    for(final team in lineups.teams) {
      final name=team.side=='home'?home:away;
      for(final player in team.players) {
        if((player.stats?.points??0)>0)scorers.add((player:player,club:name));
      }
    }
    if(scorers.isEmpty)return SizedBox.shrink();
    scorers.sort((a,b){
      final pa=a.player.stats!,pb=b.player.stats!;
      final byPoints=(pb.points??0).compareTo(pa.points??0);
      return byPoints!=0?byPoints:(pb.goals??0).compareTo(pa.goals??0);
    });
    return Column(children:[
      CupSection(title:'БОМБАРДИРЫ МАТЧА',subtitle:'Только показатели из официальной заявки ФХР'),
      CupCard(padding:EdgeInsets.symmetric(horizontal:12,vertical:6),
        child:Column(children:[
          for(var i=0;i<scorers.length;i++)...[
            Padding(padding:EdgeInsets.symmetric(vertical:10),child:Row(children:[
              SizedBox(width:24,child:Text('${i+1}',style:TextStyle(
                color:CupUi.muted,fontSize:12,fontWeight:FontWeight.w700))),
              fhrPlayerPhoto(scorers[i].player.photo,size:35),SizedBox(width:10),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(scorers[i].player.name,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:CupUi.white,fontSize:12,fontWeight:FontWeight.w700)),
                SizedBox(height:3),
                Text(scorers[i].club,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:CupUi.muted,fontSize:10)),
              ])),
              SizedBox(width:68,child:Text(
                '${scorers[i].player.stats!.goals??0}+${scorers[i].player.stats!.assists??0}',
                textAlign:TextAlign.right,
                style:TextStyle(color:CupUi.white,fontSize:14,fontWeight:FontWeight.w900))),
            ])),
            if(i+1<scorers.length)CupDiv(indent:20),
          ],
        ])),
    ]);
  }
}
