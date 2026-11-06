import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class OfficialMatchProtocolPage extends StatefulWidget {
  final String matchUrl;
  const OfficialMatchProtocolPage({super.key,required this.matchUrl});
  @override
  State<OfficialMatchProtocolPage> createState()=>_OfficialMatchProtocolPageState();
}

class _OfficialMatchProtocolPageState extends State<OfficialMatchProtocolPage> {
  late final WebViewController controller;
  int progress=0;
  String? error;
  @override
  void initState(){
    super.initState();
    final uri=Uri.parse(widget.matchUrl);
    if(uri.scheme!='https' || uri.host!='junior.fhr.ru'
        || !RegExp(r'^/games/\d+/?$').hasMatch(uri.path)) {
      error='Недопустимая ссылка на протокол';
      return;
    }
    controller=WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xff11141b))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress:(p){if(mounted)setState(()=>progress=p);},
        onWebResourceError:(e){if(e.isForMainFrame==true && mounted)setState(()=>error=e.description);},
        onNavigationRequest:(request){
          final u=Uri.tryParse(request.url);
          return (u!=null && u.scheme=='https' &&
            (u.host=='junior.fhr.ru'||u.host=='img.fhr.ru'))
            ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
      ))
      ..loadRequest(uri);
  }
  @override
  Widget build(BuildContext context){
    final uri=Uri.tryParse(widget.matchUrl);
    final allowed=uri!=null && uri.scheme=='https' && uri.host=='junior.fhr.ru'
      && RegExp(r'^/games/\d+/?$').hasMatch(uri.path);
    return Scaffold(
      appBar:AppBar(title:const Text('Официальный протокол ФХР'),actions:[
        if(allowed)IconButton(onPressed:()=>controller.reload(),icon:const Icon(Icons.refresh)),
        IconButton(onPressed:allowed?()=>launchUrl(Uri.parse(widget.matchUrl),mode:LaunchMode.externalApplication):null,
          icon:const Icon(Icons.open_in_new)),
      ]),
      body:!allowed?const Center(child:Text('Недопустимая ссылка на протокол'))
        :Column(children:[
          if(progress<100)LinearProgressIndicator(value:progress/100),
          if(error!=null)Padding(padding:const EdgeInsets.all(12),
            child:Text('ФХР: $error',style:const TextStyle(color:Colors.orangeAccent))),
          Expanded(child:WebViewWidget(controller:controller)),
        ]),
    );
  }
}
