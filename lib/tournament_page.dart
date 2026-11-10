import 'package:flutter/material.dart';
import 'cup_data.dart';
import 'tournament.dart';
import 'team_pages.dart';
import 'ui_kit.dart';
import 'scenario_page.dart';

class TournamentPage extends StatefulWidget {
  final List<Match> matches;
  final Iterable<String> teams;
  final String? Function(String) teamLogo;
  final ValueChanged<String> onTeam;
  final ValueChanged<Match> onMatch;
  const TournamentPage({
    super.key,required this.matches,required this.teams,
    required this.teamLogo,required this.onTeam,required this.onMatch,
  });
  @override
  State<TournamentPage> createState()=>_TournamentPageState();
}

class _TournamentPageState extends State<TournamentPage>{
  int section=0;
  CupTour selectedTour=CupTour.first;
  String? selectedGroup;
  CupTournament get model=>CupTournament(widget.matches,teams:widget.teams);

  Widget _chip(String text,bool active,VoidCallback tap,{bool small=false})=>Padding(
    padding:EdgeInsets.only(right:7),
    child:InkWell(onTap:tap,borderRadius:BorderRadius.circular(9),
      child:Container(
        padding:EdgeInsets.symmetric(horizontal:small?11:15,vertical:small?10:13),
        decoration:BoxDecoration(color:active?CupUi.red:CupUi.surface,
          borderRadius:BorderRadius.circular(9),
          border:Border.all(color:active?CupUi.red:CupUi.stroke)),
        child:Text(text,style:TextStyle(color:active?Colors.white:CupUi.muted,
          fontSize:10,fontWeight:FontWeight.w900,letterSpacing:.25)),
      )));

  Widget _progress(int played,int total){
    final frac=(played/total).clamp(0.0,1.0);
    return ClipRRect(borderRadius:BorderRadius.circular(5),child:LinearProgressIndicator(
      value:frac,minHeight:6,
      backgroundColor:CupUi.stroke,
      valueColor:const AlwaysStoppedAnimation<Color>(CupUi.red)));
  }

  Widget _summary(CupTournament cup){
    final progress=(cup.completedQualifyingGames/expectedQualifyingGames).clamp(0.0,1.0);
    return CupArena(
      margin:const EdgeInsets.fromLTRB(12,9,12,12),
      padding:const EdgeInsets.fromLTRB(19,21,19,21),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(height:34,width:34,decoration:BoxDecoration(
            color:Colors.white.withValues(alpha:.11),
            borderRadius:BorderRadius.circular(11)),
            child:const Icon(Icons.hub_rounded,color:CupUi.ice,size:19)),
          const SizedBox(width:10),
          const Expanded(child:Text('ПУТЬ К ФИНАЛУ',
            style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,
              fontSize:13,letterSpacing:.5))),
          CupTag(text:cup.qualificationComplete?'ОТБОР ЗАВЕРШЁН':'ОТБОР ИДЁТ',
            color:cup.qualificationComplete?CupUi.green:CupUi.yellow,filled:true),
        ]),
        const SizedBox(height:22),
        Row(children:[
          SizedBox(width:91,height:91,child:Stack(
            alignment:Alignment.center,children:[
              SizedBox.expand(child:CircularProgressIndicator(
                value:progress,strokeWidth:7,strokeCap:StrokeCap.round,
                backgroundColor:Colors.white.withValues(alpha:.16),
                valueColor:const AlwaysStoppedAnimation<Color>(CupUi.ice))),
              Text('${(progress*100).round()}%',style:const TextStyle(
                color:Colors.white,fontSize:24,fontWeight:FontWeight.w900)),
            ])),
          const SizedBox(width:19),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('КВАЛИФИКАЦИЯ',style:TextStyle(
              color:CupUi.ice,fontSize:10,fontWeight:FontWeight.w900,
              letterSpacing:1.1)),
            const SizedBox(height:9),
            Text('${cup.completedQualifyingGames} / $expectedQualifyingGames',
              style:const TextStyle(color:Colors.white,fontSize:27,
                fontWeight:FontWeight.w900,letterSpacing:-1)),
            const SizedBox(height:6),
            Text('матчей пройдено',style:TextStyle(
              color:CupUi.soft,fontSize:11)),
          ])),
        ]),
        const SizedBox(height:22),
        Container(padding:const EdgeInsets.symmetric(vertical:14,horizontal:6),
          decoration:BoxDecoration(
            color:Colors.white.withValues(alpha:.075),
            borderRadius:BorderRadius.circular(18),
            border:Border.all(color:Colors.white.withValues(alpha:.10))),
          child:Row(children:[
            _smallMetric('20','КОМАНД'),
            Container(width:1,height:27,color:Colors.white.withValues(alpha:.14)),
            _smallMetric('3','ОТБОРА'),
            Container(width:1,height:27,color:Colors.white.withValues(alpha:.14)),
            _smallMetric('8','ЗОЛОТО'),
            Container(width:1,height:27,color:Colors.white.withValues(alpha:.14)),
            _smallMetric('12','СЕРЕБРО'),
          ])),
      ]),
    );
  }

  Widget _smallMetric(String value,String label)=>Expanded(child:Column(
    crossAxisAlignment:CrossAxisAlignment.center,children:[
      Text(value,style:TextStyle(color:CupUi.white,fontSize:17,fontWeight:FontWeight.w900)),
      SizedBox(height:4),
      Text(label,style:TextStyle(color:CupUi.muted,fontSize:9,fontWeight:FontWeight.w800)),
    ]));

  Widget _stageCard(CupTournament cup,CupTour tour,int number){
    final item=cup.overview(tour);
    final played=item.playedAt(cup.now);
    final gold=tour==CupTour.gold,silver=tour==CupTour.silver;
    final special=gold||silver;
    return CupCard(
      margin:EdgeInsets.fromLTRB(12,4,12,7),
      child:InkWell(
        onTap:(){
          if(special){setState(()=>section=2);}
          else setState((){
            section=1;selectedTour=tour;
            selectedGroup=null;
          });
        },
        child:Padding(padding:EdgeInsets.all(15),child:Column(children:[
          Row(children:[
            Container(width:36,height:36,alignment:Alignment.center,
              decoration:BoxDecoration(color:special?CupUi.redMuted:CupUi.raised,
                borderRadius:BorderRadius.circular(10)),
              child:Text('$number',style:TextStyle(color:special?CupUi.red:CupUi.white,
                fontSize:17,fontWeight:FontWeight.w900))),
            SizedBox(width:11),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(item.title,style:TextStyle(color:CupUi.white,fontSize:13,fontWeight:FontWeight.w900)),
              SizedBox(height:5),
              Text(item.dates,style:TextStyle(color:CupUi.muted,fontSize:10,fontWeight:FontWeight.w700)),
            ])),
            Icon(item.hasPublishedMatches||special?Icons.chevron_right_rounded:Icons.lock_clock_outlined,
              size:21,color:CupUi.muted),
          ]),
          SizedBox(height:13),
          Row(children:[
            Expanded(child:Text(
              special
                ?(item.hasPublishedMatches?'${item.published} игр ФХР':'Календарь пока не опубликован')
                :'$played / ${item.expectedGames} матчей',
              style:TextStyle(color:special?CupUi.soft:CupUi.white,
                fontWeight:FontWeight.w700,fontSize:11))),
            if(!special)Text(
              item.fullyPlayed?'ЗАВЕРШЁН':item.published>0?'ОПУБЛИКОВАН':'ОЖИДАЕТСЯ',
              style:TextStyle(color:item.fullyPlayed?CupUi.green:CupUi.yellow,
                fontSize:9,fontWeight:FontWeight.w800)),
          ]),
          if(!special)...[
            SizedBox(height:9),
            _progress(played,item.expectedGames),
            if(item.crossoverCount>0)Padding(padding:EdgeInsets.only(top:10),
              child:Row(children:[
                Icon(Icons.compare_arrows_rounded,color:CupUi.yellow,size:14),
                SizedBox(width:6),
                Expanded(child:Text('Стыковые встречи: ${item.crossoverCount} игр',
                  style:TextStyle(fontSize:10,color:CupUi.muted))),
              ])),
          ],
          if(special)Padding(padding:EdgeInsets.only(top:7),
            child:Text(gold?'Участники: места 1–8 после трёх туров':'Участники: места 9–20 после трёх туров',
              style:TextStyle(color:CupUi.muted,fontSize:10))),
        ])),
      ));
  }

  Widget _regulationInfo()=>CupCard(
    padding:EdgeInsets.fromLTRB(14,15,14,15),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Icon(Icons.menu_book_outlined,size:18,color:CupUi.red),
        SizedBox(width:9),
        Expanded(child:Text('КАК УСТРОЕН ТУРНИР',style:TextStyle(
          fontSize:12,fontWeight:FontWeight.w900,color:CupUi.white))),
      ]),
      SizedBox(height:12),
      Text('• Три отборочных тура: сентябрь, ноябрь, январь.\n'
        '• Второй и третий туры включают межгрупповые стыковые матчи.\n'
        '• Стыковки идут в общий зачёт, но не в таблицу группы.\n'
        '• После отбора: 8 команд в Золотом, 12 в Серебряном финале.\n'
        '• Победа — 2 очка, поражение в ОТ/по буллитам — 1 очко.',
        style:TextStyle(color:CupUi.soft,fontSize:11,height:1.65)),
      SizedBox(height:10),
      Text('ФХР · Регламент Кубка России U16, сезон 2026/27, статьи 4, 14, 17.',
        style:TextStyle(color:CupUi.dim,fontSize:10,height:1.35)),
    ]));

  Widget _stages(CupTournament cup)=>Column(children:[
    CupSection(title:'ПЯТЬ ТУРОВ',subtitle:'Путь к Золотому и Серебряному финалам'),
    _stageCard(cup,CupTour.first,1),
    _stageCard(cup,CupTour.second,2),
    _stageCard(cup,CupTour.third,3),
    _stageCard(cup,CupTour.silver,4),
    _stageCard(cup,CupTour.gold,5),
    CupSection(title:'РЕГЛАМЕНТ'),
    _regulationInfo(),
    SizedBox(height:25),
  ]);

  Widget _standingsTable(List<Rank> rows,{bool general=false,bool finalTable=false}){
    return CupCard(
      margin:EdgeInsets.fromLTRB(12,6,12,11),
      padding:EdgeInsets.symmetric(vertical:3),
      child:Column(children:[
        Container(color:CupUi.raised,
          padding:EdgeInsets.symmetric(horizontal:10,vertical:11),
          child:Row(children:[
            SizedBox(width:29,child:Text('№',style:TextStyle(color:CupUi.muted,fontSize:10,fontWeight:FontWeight.w800))),
            Expanded(child:Text('КОМАНДА',style:TextStyle(color:CupUi.muted,fontSize:10,fontWeight:FontWeight.w800))),
            SizedBox(width:28,child:Text('И',textAlign:TextAlign.center,style:TextStyle(color:CupUi.muted,fontSize:10))),
            SizedBox(width:36,child:Text('РШ',textAlign:TextAlign.center,style:TextStyle(color:CupUi.muted,fontSize:10))),
            SizedBox(width:29,child:Text('О',textAlign:TextAlign.center,style:TextStyle(color:CupUi.muted,fontSize:10))),
          ])),
        for(var i=0;i<rows.length;i++)...[
          InkWell(onTap:()=>widget.onTeam(rows[i].team),child:Container(
            decoration:BoxDecoration(color:i.isEven?CupUi.raised.withValues(alpha:.34):Colors.transparent,
              border:Border(left:BorderSide(color:general&&i<8?CupUi.green:
                i==8?CupUi.orange:Colors.transparent,width:3))),
            padding:EdgeInsets.symmetric(horizontal:9,vertical:11),
            child:Row(children:[
              SizedBox(width:26,child:Text('${(i+1).toString().padLeft(2,'0')}',
                style:TextStyle(color:general&&i<8?CupUi.green:CupUi.muted,
                fontFamily:'monospace',fontSize:11,fontWeight:FontWeight.w900))),
              fhrTeamLogo(widget.teamLogo(rows[i].team),size:22),
              SizedBox(width:6),
              Expanded(child:Row(children:[
                Flexible(child:Text(rows[i].team,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:CupUi.white,fontSize:11,fontWeight:FontWeight.w700))),
                if(rows[i].provisionalTie)Padding(padding:EdgeInsets.only(left:4),
                  child:Icon(Icons.warning_amber_rounded,color:CupUi.yellow,size:13)),
              ])),
              SizedBox(width:28,child:Text('${rows[i].gp}',textAlign:TextAlign.center,
                style:TextStyle(color:CupUi.soft,fontFamily:'monospace',fontSize:11))),
              SizedBox(width:36,child:Text('${rows[i].diff}',textAlign:TextAlign.center,
                style:TextStyle(color:CupUi.muted,fontFamily:'monospace',fontSize:11))),
              Container(width:29,height:26,alignment:Alignment.center,
                decoration:BoxDecoration(color:general&&i<8
                  ?CupUi.green.withValues(alpha:.13):CupUi.raised,
                  borderRadius:BorderRadius.circular(4)),
                child:Text('${rows[i].pts}',textAlign:TextAlign.center,
                  style:TextStyle(color:general&&i<8?CupUi.green:CupUi.white,
                    fontFamily:'monospace',fontSize:13,fontWeight:FontWeight.w900))),
            ]),
          )),
          if(i+1<rows.length)CupDiv(indent:9),
        ],
      ]),
    );
  }

  Widget _gameCard(List<Match> games,{String? heading}){
    if(games.isEmpty)return SizedBox.shrink();
    return Column(children:[
      if(heading!=null)CupSection(title:heading,subtitle:'По опубликованному календарю ФХР'),
      CupCard(margin:EdgeInsets.fromLTRB(12,5,12,12),
        child:Column(children:[
          for(var i=0;i<games.length;i++)...[
            InkWell(onTap:()=>widget.onMatch(games[i]),
              child:Padding(padding:EdgeInsets.fromLTRB(11,12,11,12),
                child:Row(children:[
                  SizedBox(width:52,child:Column(children:[
                    Text(games[i].dayLabel,style:TextStyle(color:CupUi.muted,fontSize:11,fontWeight:FontWeight.w800)),
                    SizedBox(height:4),
                    Text(games[i].isLive?'● LIVE':games[i].finished?'КОН.':games[i].timeMsk,
                      style:TextStyle(color:games[i].isLive?CupUi.green:
                        games[i].finished?CupUi.muted:CupUi.yellow,fontSize:9,fontWeight:FontWeight.w900)),
                  ])),
                  SizedBox(width:7),
                  Expanded(child:Column(children:[
                    _teamLine(games[i].home),
                    SizedBox(height:9),
                    _teamLine(games[i].away),
                  ])),
                  SizedBox(width:45,child:Text(
                    games[i].hasScore?games[i].score:'—',
                    textAlign:TextAlign.center,
                    style:TextStyle(color:CupUi.white,fontSize:14,fontWeight:FontWeight.w900))),
                  Icon(Icons.chevron_right_rounded,color:CupUi.dim,size:17),
                ]))),
            if(i+1<games.length)CupDiv(indent:13),
          ],
        ]),
      ),
    ]);
  }
  Widget _teamLine(String name)=>Row(children:[
    fhrTeamLogo(widget.teamLogo(name),size:19),SizedBox(width:7),
    Expanded(child:Text(name,maxLines:1,overflow:TextOverflow.ellipsis,
      style:TextStyle(color:CupUi.white,fontWeight:FontWeight.w700,fontSize:11))),
  ]);

  Widget _groupTables(CupTournament cup){
    final names=cup.groupNames(round:selectedTour);
    final selected=selectedGroup!=null&&names.contains(selectedGroup)?selectedGroup:null;
    final round=cup.overview(selectedTour);
    final crossover=cup.crossoverMatches(round:selectedTour);
    return Column(children:[
      CupSection(title:'ТАБЛИЦЫ ГРУПП',subtitle:'Отдельные зачёты и общий рейтинг'),
      SingleChildScrollView(scrollDirection:Axis.horizontal,
        padding:EdgeInsets.symmetric(horizontal:12,vertical:5),
        child:Row(children:[
          _chip('ОБЩАЯ',selectedTour==CupTour.other,()=>setState((){
            selectedTour=CupTour.other;selectedGroup=null;
          }),small:true),
          _chip('ТУР I',selectedTour==CupTour.first,()=>setState((){
            selectedTour=CupTour.first;selectedGroup=null;
          }),small:true),
          _chip('ТУР II',selectedTour==CupTour.second,()=>setState((){
            selectedTour=CupTour.second;selectedGroup=null;
          }),small:true),
          _chip('ТУР III',selectedTour==CupTour.third,()=>setState((){
            selectedTour=CupTour.third;selectedGroup=null;
          }),small:true),
        ])),
      if(selectedTour==CupTour.other)...[
        CupSection(title:'ОБЩАЯ ТАБЛИЦА',subtitle:'Все отборочные матчи, включая стыковки'),
        if(widget.matches.any((m)=>m.isQualifier&&m.isLive&&m.goals!=null))
          Padding(padding:const EdgeInsets.symmetric(horizontal:13),child:Container(
            padding:const EdgeInsets.all(11),decoration:BoxDecoration(
              color:CupUi.green.withValues(alpha:.10),borderRadius:BorderRadius.circular(12),
              border:Border.all(color:CupUi.green.withValues(alpha:.25))),
            child:Row(children:[Icon(Icons.sensors_rounded,color:CupUi.green,size:17),
              const SizedBox(width:8),Expanded(child:Text(
                'LIVE-таблица учитывает текущий счёт и пересчитывается при обновлении данных. Очки предварительные до финальной сирены.',
                style:TextStyle(color:CupUi.soft,fontSize:9,height:1.4)))]))),
        _standingsTable(widget.matches.any((m)=>m.isQualifier&&m.isLive&&m.goals!=null)
          ?cup.liveTable():cup.qualificationRanking,general:true),
        _notice('Таблица предварительная до завершения 140 отборочных игр. '
          'Значок предупреждения обозначает неразрешённое равенство мест.'),
      ]else...[
        CupSection(title:round.title,subtitle:'${round.played} / ${round.expectedGames} игр сыграно'),
        if(names.isNotEmpty)SingleChildScrollView(scrollDirection:Axis.horizontal,
          padding:EdgeInsets.symmetric(horizontal:12,vertical:4),
          child:Row(children:[
            for(final name in names)_chip(name.replaceFirst('Группа ','ГР. '),
              selected==name,()=>setState(()=>selectedGroup=name),small:true),
          ])),
        if(names.isEmpty)CupMessage(title:'Группы ещё не опубликованы',
          message:'Таблицы появятся автоматически после публикации расписания ФХР.'),
        if(names.isNotEmpty)...[
          if(selected==null)...[
            for(final name in names)...[
              CupSection(title:name.toUpperCase(),subtitle:'Внутригрупповые матчи, без стыковок'),
              _standingsTable(cup.liveTable(group:name)),
              _gameCard(cup.groupMatches(name),heading:'МАТЧИ ГРУППЫ'),
            ],
          ]else...[
            CupSection(title:selected.toUpperCase(),subtitle:'Официальные матчи группы'),
            _standingsTable(cup.liveTable(group:selected)),
            _gameCard(cup.groupMatches(selected),heading:'КАЛЕНДАРЬ ГРУППЫ'),
          ],
        ],
        if(crossover.isNotEmpty)_gameCard(crossover,heading:'СТЫКОВЫЕ МАТЧИ · ТУР ${selectedTour==CupTour.second?'II':'III'}'),
        if(crossover.isNotEmpty)_notice('Стыковые матчи приносят очки в ОБЩУЮ таблицу, '
          'но НЕ влияют на места внутри групп этого тура.'),
        if(selectedTour==CupTour.second&&names.isEmpty)_secondTourPreview(cup),
        if(selectedTour==CupTour.third&&names.isEmpty)_snakePreview(cup),
      ],
      SizedBox(height:20),
    ]);
  }

  Widget _secondTourPreview(CupTournament cup){
    final preview=cup.secondTourPreview();
    return Column(children:[
      CupSection(title:'РАСПРЕДЕЛЕНИЕ НА ВТОРОЙ ТУР',
        subtitle:'Статья 4: результаты первого тура и пятые места'),
      if(!cup.firstComplete)_notice(
        'До завершения первого тура показана только схема рассева. '
        'Фактические группы определяются по местам после тура.'),
      for(var i=0;i<preview.length;i++)CupCard(
        padding:EdgeInsets.fromLTRB(13,12,13,12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('ГРУППА ${i+1}',style:TextStyle(
            color:CupUi.white,fontWeight:FontWeight.w900,fontSize:12)),
          SizedBox(height:9),
          for(var j=0;j<preview[i].length;j++)Padding(
            padding:EdgeInsets.symmetric(vertical:5),
            child:Row(children:[
              SizedBox(width:25,child:Text('${j+1}.',
                style:TextStyle(color:CupUi.red,fontWeight:FontWeight.w800,fontSize:11))),
              Expanded(child:Text(preview[i][j],
                style:TextStyle(color:CupUi.soft,fontSize:12))),
            ])),
        ])),
    ]);
  }

  Widget _snakePreview(CupTournament cup){
    final preview=cup.thirdTourProjection();
    final rank=cup.table();
    final places={for(var i=0;i<rank.length;i++)rank[i].team:i+1};
    final completed=cup.firstTwoComplete;
    const labels=['А','Б','В','Г'];
    final before= cup.overview(CupTour.first).played+cup.overview(CupTour.second).played;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      CupSection(title:'LIVE-РАССЕВ III ТУРА',
        subtitle:'Автоматически меняется с каждым подтверждённым результатом ФХР'),
      CupArena(margin:const EdgeInsets.fromLTRB(12,4,12,10),
        padding:const EdgeInsets.fromLTRB(17,19,17,19),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Icon(Icons.hub_rounded,color:CupUi.ice,size:20),
            const SizedBox(width:9),
            const Expanded(child:Text('ПУТЬ В ТРЕТИЙ ТУР',style:TextStyle(
              color:Colors.white,fontSize:14,fontWeight:FontWeight.w900))),
            CupTag(text:completed?'ЗАКРЕПЛЁН':'ПРОЕКЦИЯ',
              color:completed?CupUi.green:CupUi.yellow,filled:true),
          ]),
          const SizedBox(height:8),
          Text(completed
            ?'Все 90 матчей I–II туров завершены. Рассев рассчитан по общей таблице.'
            :'В зачёт попадают завершённые матчи I–II туров, включая стыки. LIVE-счёт до подтверждения результата не учитывается.',
            style:TextStyle(color:CupUi.soft,fontSize:11,height:1.4)),
          const SizedBox(height:15),
          ClipRRect(borderRadius:BorderRadius.circular(9),child:
            LinearProgressIndicator(value:(before/(firstTourGames+secondTourGames)).clamp(0.0,1.0),
              minHeight:6,backgroundColor:Colors.white.withValues(alpha:.16),
              valueColor:const AlwaysStoppedAnimation<Color>(CupUi.ice))),
          const SizedBox(height:8),
          Text('$before / ${firstTourGames+secondTourGames} матчей I–II туров',
            style:TextStyle(color:CupUi.ice,fontSize:10,fontWeight:FontWeight.w800)),
        ])),
      for(var i=0;i<preview.length;i++)CupCard(
        margin:const EdgeInsets.fromLTRB(12,4,12,7),
        padding:EdgeInsets.zero,
        child:Column(children:[
          Padding(padding:const EdgeInsets.fromLTRB(14,13,14,12),child:Row(children:[
            Container(width:37,height:37,alignment:Alignment.center,
              decoration:BoxDecoration(color:CupUi.redMuted,
                borderRadius:BorderRadius.circular(12)),
              child:Text(labels[i],style:TextStyle(color:CupUi.ice,
                fontSize:19,fontWeight:FontWeight.w900))),
            const SizedBox(width:11),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('ГРУППА ${labels[i]}',style:TextStyle(color:CupUi.white,
                fontWeight:FontWeight.w900,fontSize:14)),
              const SizedBox(height:3),
              Text(CupTournament.thirdTourSnake[i].join(' · '),
                style:TextStyle(color:CupUi.muted,fontSize:10)),
            ])),
            CupTag(text:'5 КОМАНД',color:CupUi.ice),
          ])),
          CupDiv(),
          for(var j=0;j<preview[i].length;j++)AnimatedContainer(
            key:ValueKey('seed:$i:$j:${preview[i][j]}'),
            duration:const Duration(milliseconds:420),
            curve:Curves.easeOutCubic,
            padding:const EdgeInsets.symmetric(vertical:10,horizontal:14),
            decoration:BoxDecoration(color:j.isEven
              ?CupUi.raised.withValues(alpha:.21):Colors.transparent),
            child:Row(children:[
              SizedBox(width:28,child:Text(
                '${CupTournament.thirdTourSnake[i][j]}',
                style:TextStyle(color:CupUi.ice,fontSize:12,
                  fontWeight:FontWeight.w900))),
              fhrTeamLogo(widget.teamLogo(preview[i][j]),size:27),
              const SizedBox(width:10),
              Expanded(child:Text(preview[i][j],maxLines:2,
                overflow:TextOverflow.ellipsis,style:TextStyle(
                color:CupUi.white,fontWeight:FontWeight.w800,fontSize:12))),
              if(places.containsKey(preview[i][j]))
                Text('${rank[places[preview[i][j]]!-1].pts} О',
                  style:TextStyle(color:CupUi.soft,fontSize:11,fontWeight:FontWeight.w900)),
            ]),
          ),
        ])),
      Padding(padding:const EdgeInsets.fromLTRB(18,9,18,18),
        child:Text('Текущая схема — расчёт по змейке статьи 4. Пока I–II туры не завершены, команды могут менять группы после каждого официального результата.',
          style:TextStyle(color:CupUi.muted,fontSize:11,height:1.55))),
    ]);
  }

  Widget _notice(String text)=>CupCard(
    padding:EdgeInsets.all(13),color:CupUi.raised,
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(Icons.info_outline_rounded,color:CupUi.yellow,size:18),
      SizedBox(width:10),
      Expanded(child:Text(text,style:TextStyle(color:CupUi.soft,fontSize:11,height:1.45))),
    ]));

  Widget _finalDivision(CupTournament cup,CupTour finalRound){
    final gold=finalRound==CupTour.gold;
    final candidates=gold?cup.goldQualifiers:cup.silverQualifiers;
    final fixtures=cup.tourMatches(finalRound);
    final finalTable=cup.finalTable(finalRound);
    return Column(children:[
      CupSection(title:gold?'ЗОЛОТОЙ ФИНАЛ':'СЕРЕБРЯНЫЙ ФИНАЛ',
        subtitle:gold?'8 лучших команд квалификации':'Команды, занявшие места 9–20'),
      CupCard(padding:EdgeInsets.fromLTRB(13,13,13,13),
        child:Row(children:[
          Container(width:42,height:42,alignment:Alignment.center,
            decoration:BoxDecoration(color:gold?CupUi.redMuted:CupUi.raised,
              borderRadius:BorderRadius.circular(12)),
            child:Icon(Icons.emoji_events_outlined,color:gold?CupUi.red:CupUi.soft,size:23)),
          SizedBox(width:11),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(gold?'МЕСТА 1–8':'МЕСТА 9–20',
              style:TextStyle(color:CupUi.white,fontSize:13,fontWeight:FontWeight.w900)),
            SizedBox(height:5),
            Text('АПРЕЛЬ 2027',style:TextStyle(color:CupUi.muted,fontSize:10)),
          ])),
          CupTag(text:fixtures.isNotEmpty?'${fixtures.length} игр ФХР':'ОЖИДАЕТСЯ',
            color:fixtures.isNotEmpty?CupUi.green:CupUi.yellow,filled:true),
        ])),
      if(candidates.isNotEmpty)...[
        CupSection(title:'УЧАСТНИКИ ПО ИТОГАМ ОТБОРА'),
        CupCard(padding:EdgeInsets.symmetric(vertical:3),
          child:Column(children:[
            for(var i=0;i<candidates.length;i++)Padding(
              padding:EdgeInsets.symmetric(horizontal:12,vertical:10),
              child:Row(children:[
                SizedBox(width:28,child:Text('${gold?i+1:i+9}',
                  style:TextStyle(color:CupUi.red,fontWeight:FontWeight.w900,fontSize:12))),
                fhrTeamLogo(widget.teamLogo(candidates[i].team),size:24),
                SizedBox(width:9),
                Expanded(child:Text(candidates[i].team,
                  style:TextStyle(color:CupUi.white,fontSize:11,fontWeight:FontWeight.w700))),
                Text('${candidates[i].pts} оч.',style:TextStyle(color:CupUi.muted,fontSize:11)),
              ])),
          ])),
      ]else...[
        _notice('Состав участников определяется только после трёх туров и всех стыковок. '
          'До этого нельзя считать текущее место окончательным.'),
        CupCard(padding:EdgeInsets.all(12),
          child:Text(gold?'8 путёвок · места 1–8':'12 путёвок · места 9–20',
            textAlign:TextAlign.center,
            style:TextStyle(color:CupUi.soft,fontSize:12,fontWeight:FontWeight.w700))),
      ],
      if(finalTable.isNotEmpty)...[
        CupSection(title:'ТАБЛИЦА ФИНАЛЬНОГО ТУРА',subtitle:'Только опубликованные игры финала'),
        _standingsTable(finalTable,finalTable:true),
      ],
      if(fixtures.isNotEmpty)_gameCard(fixtures,heading:'ФИНАЛЬНЫЕ МАТЧИ ФХР'),
      if(fixtures.isEmpty)CupMessage(icon:Icons.calendar_month_outlined,
        title:'Сетка ещё не опубликована',
        message:'Пары матчей и расписание появятся после официальной публикации ФХР. '
          'Приложение не создаёт вымышленные четвертьфиналы и полуфиналы.'),
    ]);
  }

  Widget _finals(CupTournament cup)=>Column(children:[
    CupSection(title:'ФИНАЛЬНЫЕ ТУРЫ',subtitle:'Составы и пары определяются ФХР'),
    _finalDivision(cup,CupTour.gold),
    SizedBox(height:13),
    _finalDivision(cup,CupTour.silver),
    SizedBox(height:25),
  ]);

  @override Widget build(BuildContext context){
    final cup=model;
    return ListView(children:[
      CupSection(title:'ТУРНИРНАЯ СИСТЕМА',
        subtitle:'ФХР · сезон 2026/27 · 20 команд · 5 туров'),
      CupReveal(child:_summary(cup)),
      Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ScenarioPage(matches:widget.matches,teams:cup.participants.toList(),teamLogos:{for(final name in cup.participants)name:widget.teamLogo(name)}))),icon:const Icon(Icons.tune),label:const Text('Интерактивные расклады'))),
      SingleChildScrollView(scrollDirection:Axis.horizontal,
        padding:EdgeInsets.fromLTRB(12,0,12,7),
        child:Row(children:[
          _chip('ЭТАПЫ',section==0,()=>setState(()=>section=0)),
          _chip('ТАБЛИЦЫ',section==1,()=>setState(()=>section=1)),
          _chip('ФИНАЛЫ',section==2,()=>setState(()=>section=2)),
          _chip('РАССЕВ III',section==3,()=>setState(()=>section=3)),
        ])),
      if(section==0)_stages(cup),
      if(section==1)_groupTables(cup),
      if(section==2)_finals(cup),
      if(section==3)_snakePreview(cup),
    ]);
  }
}


