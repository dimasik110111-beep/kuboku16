import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ui_kit.dart';

const appVersion=28;
const releaseRepo='dimasik110111-beep/kuboku16';
class Diagnostics {
  static final List<String> events=[];
  static void record(String area,Object error){
    events.add('${DateTime.now().toUtc().toIso8601String()} $area: $error');
    if(events.length>30)events.removeAt(0);
  }
  static String get report=>'JUNIOR U16 v$appVersion\n${events.join('\n')}';
}
class FeedCache {
  static Future<Map<String,dynamic>?> read(String key)async{
    try{
      final raw=(await SharedPreferences.getInstance()).getString('v15:$key');
      return raw==null?null:Map<String,dynamic>.from(jsonDecode(raw) as Map);
    }catch(e){Diagnostics.record('cache read',e);return null;}
  }
  static Future<void> write(String key,Map<String,dynamic> value)async{
    try{await (await SharedPreferences.getInstance()).setString('v15:$key',jsonEncode(value));}
    catch(e){Diagnostics.record('cache write',e);}
  }
}
class LoadingCards extends StatelessWidget {
  const LoadingCards({super.key});
  @override Widget build(BuildContext context)=>ListView.builder(
    itemCount:5,itemBuilder:(_,i)=>Semantics(label:'Загрузка',child:CupCard(
      padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[_shape(28,28),const SizedBox(width:10),_shape(120,12),const Spacer(),_shape(38,17)]),
        const SizedBox(height:15),
        Row(children:[_shape(30,30),const SizedBox(width:10),Expanded(child:_shape(double.infinity,12)),
          const SizedBox(width:12),_shape(35,23)]),
        const SizedBox(height:9),
        Row(children:[_shape(30,30),const SizedBox(width:10),Expanded(child:_shape(double.infinity,12)),
          const SizedBox(width:12),_shape(35,23)]),
      ]))));
  static Widget _shape(double width,double height)=>Container(width:width,height:height,
    decoration:BoxDecoration(color:CupUi.raised,borderRadius:BorderRadius.circular(8)));
}
Future<void> shareCard(BuildContext context,String title,List<String> lines)async{
  try{
    final recorder=ui.PictureRecorder();final canvas=Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0,0,1080,1080),Paint()..color=const Color(0xFF0A1220));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(48,48,984,984),const Radius.circular(36)),Paint()..color=const Color(0xFF162338));
    canvas.drawRect(const Rect.fromLTWH(90,105,7,62),Paint()..color=CupUi.red);
    void text(String value,double y,double size,Color color,{int maxLines=2}){
      final p=TextPainter(text:TextSpan(text:value,style:TextStyle(fontFamily:'Manrope',fontSize:size,color:color,fontWeight:FontWeight.w700)),textDirection:TextDirection.ltr,maxLines:maxLines,ellipsis:'…')..layout(maxWidth:880);
      p.paint(canvas,Offset(110,y));
    }
    text('JUNIOR U16',110,44,Colors.white);
    text('КУБОК РОССИИ · 2026/27',178,24,const Color(0xFF9DB2CD));
    text(title,270,46,Colors.white,maxLines:3);
    for(var i=0;i<lines.take(5).length;i++){text(lines[i],490+i*78,30,const Color(0xFFCCD9EB));}
    text('Данные ФХР · ${DateTime.now().toIso8601String().substring(0,10)}',950,22,const Color(0xFF9DB2CD));
    final picture=recorder.endRecording();final image=await picture.toImage(1080,1080);
    final bytes=await image.toByteData(format:ui.ImageByteFormat.png);image.dispose();picture.dispose();
    if(bytes==null)throw StateError('PNG unavailable');
    await Share.shareXFiles([XFile.fromData(bytes.buffer.asUint8List(),mimeType:'image/png')],fileNameOverrides:['JUNIOR-U16.png']);
  }catch(e){Diagnostics.record('share',e);if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Не удалось отправить карточку. Попробуй ещё раз.')));}
}
int releaseNumber(String tag)=>int.tryParse(RegExp(r'^v(\d+)\.').firstMatch(tag)?.group(1)??'')??0;
class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});
  @override State<AppSettingsPage> createState()=>_AppSettingsPageState();
}
class _AppSettingsPageState extends State<AppSettingsPage>{
  final client=http.Client();bool loading=false;String? message;Map<String,dynamic>? release;
  @override void initState(){super.initState();check();}
  @override void dispose(){client.close();super.dispose();}
  Future<void> check()async{
    if(loading)return;setState(()=>loading=true);
    try{
      // This project distributes prereleases: /latest intentionally excludes them.
      final r=await client.get(Uri.parse('https://api.github.com/repos/$releaseRepo/releases?per_page=30')).timeout(const Duration(seconds:15));
      if(r.statusCode!=200)throw Exception('HTTP ${r.statusCode}');
      final all=(jsonDecode(r.body) as List).whereType<Map>().where((r)=>r['draft']!=true).toList()
        ..sort((a,b)=>releaseNumber('${b['tag_name']}').compareTo(releaseNumber('${a['tag_name']}')));
      if(!mounted)return;
      setState((){release=all.isEmpty?null:Map<String,dynamic>.from(all.first);message=release!=null&&releaseNumber('${release!['tag_name']}')>appVersion?'Доступно обновление':'Установлена актуальная версия';});
    }catch(e){Diagnostics.record('updates',e);if(mounted)setState(()=>message='Не удалось проверить обновления. Проверь интернет.');}
    finally{if(mounted)setState(()=>loading=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Приложение')),body:SafeArea(child:ListView(children:[
    CupSection(title:'JUNIOR U16 · v$appVersion',subtitle:'Обновления и диагностика'),
    CupCard(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(loading)const LinearProgressIndicator(),Text(message??'Проверяю обновления…'),
      TextButton(onPressed:loading?null:check,child:const Text('Проверить снова')),
      if(release!=null)...[
        Text('${release!['name']}',style:const TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:12),
        Text('${release!['body']??''}'),
        for(final asset in (release!['assets'] as List? ?? []).whereType<Map>())
          if('${asset['name']}'.endsWith('.apk')&&releaseNumber('${release!['tag_name']}')>appVersion)
            FilledButton.icon(onPressed:()async{
              final uri=Uri.tryParse('${asset['browser_download_url']}');
              if(uri!=null&&uri.scheme=='https'&&uri.host=='github.com'&&uri.path.startsWith('/$releaseRepo/releases/download/')){
                try{if(!await launchUrl(uri,mode:LaunchMode.externalApplication))throw StateError('Cannot launch');}
                catch(e){Diagnostics.record('download',e);if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Не удалось открыть скачивание')));}
              }
            },icon:const Icon(Icons.download_rounded),label:const Text('Скачать APK')),
      ],
    ])),
    CupSection(title:'ДИАГНОСТИКА',subtitle:'Журнал хранится только в этой сессии. Отправляешь его ты.'),
    CupCard(child:ListTile(leading:const Icon(Icons.copy_rounded),title:const Text('Скопировать сведения об ошибках'),onTap:()async{
      await Clipboard.setData(ClipboardData(text:Diagnostics.report));
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Диагностика скопирована')));
    })),
  ])));
}
