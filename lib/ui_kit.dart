import 'package:flutter/material.dart';

class CupUi {
  // v14: both palettes are genuine UI colors. Team/player images are unchanged.
  // The root app sets light when the saved theme preference changes.
  static bool light=false;
  static Color get background=>light?const Color(0xFFF4F6FA):const Color(0xFF0A1220);
  static Color get surface=>light?const Color(0xFFFFFFFF):const Color(0xFF142033);
  static Color get raised=>light?const Color(0xFFECF1F7):const Color(0xFF1C2C43);
  static Color get stroke=>light?const Color(0xFFE0E6EF):const Color(0xFF2A3C55);
  static const red=Color(0xFFFF536D);
  static Color get redMuted=>light?const Color(0xFFFFE5EA):const Color(0xFF4C2833);
  static Color get green=>light?const Color(0xFF087D56):const Color(0xFF42CE91);
  static Color get yellow=>light?const Color(0xFF91600F):const Color(0xFFF5BE5B);
  static Color get white=>light?const Color(0xFF142235):const Color(0xFFF6F8FC);
  static Color get soft=>light?const Color(0xFF34435A):const Color(0xFFCFD6E0);
  static Color get muted=>light?const Color(0xFF62738B):const Color(0xFF8995A6);
  static Color get dim=>light?const Color(0xFF8796AA):const Color(0xFF5E697A);
}

class CupCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  const CupCard({super.key,required this.child,this.padding,this.margin,this.color});
  @override
  Widget build(BuildContext context)=>Container(
    margin:margin??EdgeInsets.symmetric(horizontal:12,vertical:6),
    padding:padding,
    decoration:BoxDecoration(color:color??CupUi.surface,borderRadius:BorderRadius.circular(20),
      border:Border.all(color:CupUi.stroke,width:.75),
      boxShadow:CupUi.light?[BoxShadow(color:const Color(0xFF233552).withValues(alpha:.055),
        blurRadius:18,offset:Offset(0,5))]:null),
    clipBehavior:Clip.antiAlias,
    child:Material(type:MaterialType.transparency,child:child),
  );
}

class CupSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const CupSection({super.key,required this.title,this.subtitle,this.trailing});
  @override
  Widget build(BuildContext context)=>Padding(
    padding:EdgeInsets.fromLTRB(18,21,16,10),
    child:Row(children:[
      Container(height:17,width:3,decoration:BoxDecoration(color:CupUi.red,borderRadius:BorderRadius.circular(2))),
      SizedBox(width:9),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:TextStyle(color:CupUi.white,fontWeight:FontWeight.w800,fontSize:13,letterSpacing:.3)),
        if(subtitle!=null)Padding(padding:EdgeInsets.only(top:4),
          child:Text(subtitle!,style:TextStyle(color:CupUi.muted,fontSize:11))),
      ])),
      if(trailing!=null)trailing!,
    ]),
  );
}

class CupTag extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;
  const CupTag({super.key,required this.text,this.color=const Color(0xFF8995A6),this.filled=false});
  @override
  Widget build(BuildContext context){
    final effectiveColor=color==const Color(0xFF8995A6)?CupUi.muted:color;
    return Container(
    padding:EdgeInsets.symmetric(horizontal:9,vertical:5),
    decoration:BoxDecoration(
      color:filled?effectiveColor.withValues(alpha:.14):CupUi.raised,
      borderRadius:BorderRadius.circular(6)),
    child:Text(text,style:TextStyle(fontWeight:FontWeight.w800,fontSize:10,color:effectiveColor,letterSpacing:.2)),
  );
  }
}

class CupMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? retry;
  const CupMessage({super.key,this.icon=Icons.info_outline,required this.title,required this.message,this.retry});
  @override
  Widget build(BuildContext context)=>Padding(
    padding:EdgeInsets.symmetric(horizontal:20,vertical:30),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Container(height:52,width:52,decoration:BoxDecoration(color:CupUi.raised,borderRadius:BorderRadius.circular(15)),
        child:Icon(icon,color:CupUi.muted,size:26)),
      SizedBox(height:13),
      Text(title,textAlign:TextAlign.center,style:TextStyle(color:CupUi.white,fontSize:15,fontWeight:FontWeight.w800)),
      SizedBox(height:7),
      Text(message,textAlign:TextAlign.center,style:TextStyle(color:CupUi.muted,fontSize:12,height:1.45)),
      if(retry!=null)TextButton(onPressed:retry,child:Text('ПОВТОРИТЬ')),
    ]),
  );
}

class CupDiv extends StatelessWidget {
  final double indent;
  const CupDiv({super.key,this.indent=0});
  @override Widget build(BuildContext context)=>Container(height:.8,color:CupUi.stroke,margin:EdgeInsets.only(left:indent));
}

