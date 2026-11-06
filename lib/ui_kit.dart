import 'package:flutter/material.dart';

class CupUi {
  static const background=Color(0xFF0C1018);
  static const surface=Color(0xFF171D27);
  static const raised=Color(0xFF202836);
  static const stroke=Color(0xFF2A3341);
  static const red=Color(0xFFED4860);
  static const redMuted=Color(0xFF4C2833);
  static const green=Color(0xFF42CE91);
  static const yellow=Color(0xFFF5BE5B);
  static const white=Color(0xFFF6F8FC);
  static const soft=Color(0xFFCFD6E0);
  static const muted=Color(0xFF8995A6);
  static const dim=Color(0xFF5E697A);
}

class CupCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  const CupCard({super.key,required this.child,this.padding,this.margin,this.color});
  @override
  Widget build(BuildContext context)=>Container(
    margin:margin??const EdgeInsets.symmetric(horizontal:12,vertical:6),
    padding:padding,
    decoration:BoxDecoration(color:color??CupUi.surface,borderRadius:BorderRadius.circular(14),
      border:Border.all(color:CupUi.stroke,width:.8)),
    clipBehavior:Clip.antiAlias,
    child:child,
  );
}

class CupSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const CupSection({super.key,required this.title,this.subtitle,this.trailing});
  @override
  Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.fromLTRB(18,21,16,10),
    child:Row(children:[
      Container(height:17,width:3,decoration:BoxDecoration(color:CupUi.red,borderRadius:BorderRadius.circular(2))),
      const SizedBox(width:9),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:const TextStyle(color:CupUi.white,fontWeight:FontWeight.w800,fontSize:13,letterSpacing:.3)),
        if(subtitle!=null)Padding(padding:const EdgeInsets.only(top:4),
          child:Text(subtitle!,style:const TextStyle(color:CupUi.muted,fontSize:11))),
      ])),
      if(trailing!=null)trailing!,
    ]),
  );
}

class CupTag extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;
  const CupTag({super.key,required this.text,this.color=CupUi.muted,this.filled=false});
  @override
  Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
    decoration:BoxDecoration(
      color:filled?color.withValues(alpha:.17):CupUi.raised,
      borderRadius:BorderRadius.circular(6)),
    child:Text(text,style:TextStyle(fontWeight:FontWeight.w800,fontSize:10,color:color,letterSpacing:.2)),
  );
}

class CupMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? retry;
  const CupMessage({super.key,this.icon=Icons.info_outline,required this.title,required this.message,this.retry});
  @override
  Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.symmetric(horizontal:20,vertical:30),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Container(height:52,width:52,decoration:BoxDecoration(color:CupUi.raised,borderRadius:BorderRadius.circular(15)),
        child:Icon(icon,color:CupUi.muted,size:26)),
      const SizedBox(height:13),
      Text(title,textAlign:TextAlign.center,style:const TextStyle(color:CupUi.white,fontSize:15,fontWeight:FontWeight.w800)),
      const SizedBox(height:7),
      Text(message,textAlign:TextAlign.center,style:const TextStyle(color:CupUi.muted,fontSize:12,height:1.45)),
      if(retry!=null)TextButton(onPressed:retry,child:const Text('ПОВТОРИТЬ')),
    ]),
  );
}

class CupDiv extends StatelessWidget {
  final double indent;
  const CupDiv({super.key,this.indent=0});
  @override Widget build(BuildContext context)=>Container(height:.8,color:CupUi.stroke,margin:EdgeInsets.only(left:indent));
}
