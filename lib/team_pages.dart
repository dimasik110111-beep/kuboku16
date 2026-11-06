import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'cup_data.dart';

const _background=Color(0xff11141b), _panel=Color(0xff1b202b),
  _muted=Color(0xffa1a9b8), _red=Color(0xffef4c60);

Widget fhrTeamLogo(String? url,{double size=32}) {
  final valid=url!=null && Uri.tryParse(url)?.host=='img.fhr.ru';
  return SizedBox(width:size,height:size,child:valid
    ? Image.network(url,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.shield_outlined,color:_muted))
    : const Icon(Icons.shield_outlined,color:_muted));
}

Widget fhrPlayerPhoto(String? url,{double size=54}) {
  final valid=url!=null && Uri.tryParse(url)?.host=='img.fhr.ru';
  return ClipRRect(borderRadius:BorderRadius.circular(8),
    child:Container(width:size,height:size,color:_background,child:valid
      ? Image.network(url,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.person_outline,color:_muted))
      : const Icon(Icons.person_outline,color:_muted)));
}

Future<void> fhrOpen(String url) async {
  final uri=Uri.tryParse(url);
  if(uri==null || uri.scheme!='https' || uri.host!='junior.fhr.ru')return;
  await launchUrl(uri,mode:LaunchMode.externalApplication);
}

class TeamRosterPage extends StatefulWidget {
  final TeamInfo team;
  const TeamRosterPage({super.key,required this.team});
  @override
  State<TeamRosterPage> createState()=>_TeamRosterPageState();
}

class _TeamRosterPageState extends State<TeamRosterPage> {
  final FhrApiClient api=FhrApiClient(http.Client());
  late Future<TeamRoster> future;
  @override
  void initState() {super.initState();future=api.roster(widget.team.id);}
  @override
  void dispose(){api.client.close();super.dispose();}
  void refresh(){setState(()=>future=api.roster(widget.team.id));}
  Widget group(String title,List<PlayerInfo> players) {
    if(players.isEmpty)return const SizedBox.shrink();
    players.sort((a,b)=>int.tryParse(a.number)?.compareTo(int.tryParse(b.number)??0)??a.name.compareTo(b.name));
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Container(color:_background,padding:const EdgeInsets.fromLTRB(16,17,16,10),
        child:Text('$title  ·  ${players.length}',style:const TextStyle(fontSize:13,color:_muted,fontWeight:FontWeight.bold))),
      for(final p in players)Container(
        margin:const EdgeInsets.symmetric(horizontal:10,vertical:2),
        decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(10)),
        child:ListTile(
          leading:fhrPlayerPhoto(p.photo,size:48),
          title:Text(p.name,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600)),
          subtitle:Text('#${p.number} · ${p.position}',style:const TextStyle(fontSize:11,color:_muted)),
          trailing:const Icon(Icons.chevron_right,color:_muted,size:19),
          onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>PlayerCardPage(player:p,team:widget.team))),
        ),
      ),
    ]);
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.team.name,maxLines:1,overflow:TextOverflow.ellipsis),
      actions:[IconButton(onPressed:refresh,icon:const Icon(Icons.refresh))]),
    body:FutureBuilder<TeamRoster>(
      future:future,
      builder:(context,snapshot){
        if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
        if(snapshot.hasError)return Center(child:Padding(padding:const EdgeInsets.all(20),child:Column(
          mainAxisSize:MainAxisSize.min,children:[
            const Icon(Icons.cloud_off,size:36,color:_muted),
            const SizedBox(height:12),Text('Состав ФХР временно недоступен: ${snapshot.error}',textAlign:TextAlign.center),
            TextButton(onPressed:refresh,child:const Text('Повторить')),
            TextButton(onPressed:()=>fhrOpen(widget.team.url),child:const Text('Официальная страница команды')),
          ])));
        final roster=snapshot.data!;
        final p=roster.players;
        final keep=(String position)=>p.where((x)=>x.position.toLowerCase().contains(position)).toList();
        final goalies=keep('вратарь'),defenders=keep('защитник'),forwards=keep('нападающий');
        final unknown=p.where((x)=>!goalies.contains(x)&&!defenders.contains(x)&&!forwards.contains(x)).toList();
        return ListView(children:[
          Container(color:_panel,padding:const EdgeInsets.all(22),
            child:Column(children:[
              fhrTeamLogo(widget.team.logo,size:86),
              const SizedBox(height:12),
              Text(widget.team.name,textAlign:TextAlign.center,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800)),
              if(widget.team.city.isNotEmpty)Text(widget.team.city,style:const TextStyle(color:_muted,fontSize:12)),
              const SizedBox(height:12),
              Text('СОСТАВ ФХР  ·  ${roster.players.length} ИГРОКОВ',
                style:const TextStyle(color:_muted,fontSize:11,fontWeight:FontWeight.bold)),
            ])),
          if(roster.players.isEmpty)const Padding(padding:EdgeInsets.all(20),
            child:Text('ФХР пока не опубликовала состав.')),
          group('ВРАТАРИ',goalies),group('ЗАЩИТНИКИ',defenders),group('НАПАДАЮЩИЕ',forwards),
          group('ДРУГИЕ',unknown),
          const SizedBox(height:10),
          TextButton.icon(onPressed:()=>fhrOpen(widget.team.url),
            icon:const Icon(Icons.open_in_new),label:const Text('Официальный состав ФХР')),
          const Padding(padding:EdgeInsets.all(16),
            child:Text('Фотографии, имена, номера и позиции взяты из опубликованного состава на ФХР Джуниор.',
              style:TextStyle(color:_muted,fontSize:11))),
        ]);
      },
    ),
  );
}

class PlayerCardPage extends StatelessWidget {
  final PlayerInfo player;
  final TeamInfo team;
  const PlayerCardPage({super.key,required this.player,required this.team});
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Игрок')),
    body:ListView(children:[
      Container(color:_panel,padding:const EdgeInsets.all(28),
        child:Column(children:[
          fhrPlayerPhoto(player.photo,size:152),
          const SizedBox(height:16),
          Text(player.name,textAlign:TextAlign.center,
            style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
          const SizedBox(height:10),
          Text('№ ${player.number} · ${player.position}',style:const TextStyle(color:_red,fontWeight:FontWeight.bold)),
          const SizedBox(height:14),
          Row(mainAxisAlignment:MainAxisAlignment.center,children:[
            fhrTeamLogo(team.logo,size:29),const SizedBox(width:8),
            Flexible(child:Text(team.fullName,style:const TextStyle(color:_muted,fontSize:12))),
          ]),
        ])),
      const Padding(padding:EdgeInsets.all(16),
        child:Text('Карточка и фото предоставлены ФХР Джуниор. Личная статистика доступна в официальном профиле.',
          style:TextStyle(color:_muted,fontSize:12))),
      Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:FilledButton.icon(
        onPressed:()=>fhrOpen(player.url),icon:const Icon(Icons.open_in_new),
        label:const Text('Открыть профиль на ФХР'))),
    ]),
  );
}
