import 'package:flutter/material.dart';

class CupUi {
  // Shared visual language: graphite rink, cold navy surfaces, clear status colors.
  static bool light=false;
  static Color get background=>light?const Color(0xFFF3F6FA):const Color(0xFF070B13);
  static Color get surface=>light?const Color(0xFFFFFFFF):const Color(0xFF101928);
  static Color get raised=>light?const Color(0xFFEAF0F7):const Color(0xFF19283C);
  static Color get stroke=>light?const Color(0xFFDCE4EE):const Color(0xFF2C3D54);
  static const red=Color(0xFFFF4966);
  static const ice=Color(0xFF80D6FF);
  static Color get redMuted=>light?const Color(0xFFFFE7EA):const Color(0xFF40212A);
  static Color get green=>light?const Color(0xFF087D56):const Color(0xFF45D6A0);
  static Color get yellow=>light?const Color(0xFF91600F):const Color(0xFFFFC86B);
  static Color get white=>light?const Color(0xFF142235):const Color(0xFFF5F8FD);
  static Color get soft=>light?const Color(0xFF34435A):const Color(0xFFC7D2E2);
  static Color get muted=>light?const Color(0xFF62738B):const Color(0xFF8795A9);
  static Color get dim=>light?const Color(0xFF8796AA):const Color(0xFF647187);
  static List<Color> get heroGradient=>light
    ?const [Color(0xFF172B4D),Color(0xFF244978)]
    :const [Color(0xFF1D3655),Color(0xFF101928),Color(0xFF341C2D)];
}

class CupCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  const CupCard({super.key,required this.child,this.padding,this.margin,this.color});
  @override
  Widget build(BuildContext context){
    final base=color??CupUi.surface;
    return AnimatedContainer(duration:const Duration(milliseconds:280),curve:Curves.easeOutCubic,
    margin:margin??EdgeInsets.symmetric(horizontal:12,vertical:6),
    padding:padding,
    decoration:BoxDecoration(color:color??(CupUi.light?CupUi.surface:null),borderRadius:BorderRadius.circular(22),
      gradient:color==null&&!CupUi.light?LinearGradient(
        begin:Alignment.topLeft,end:Alignment.bottomRight,
        colors:[Color.lerp(base,CupUi.raised,.28)!,base]):null,
      border:Border.all(color:CupUi.stroke.withValues(alpha:CupUi.light ? .9 : .78),width:.8),
      boxShadow:CupUi.light?[BoxShadow(color:const Color(0xFF233552).withValues(alpha:.055),
        blurRadius:18,offset:Offset(0,5))]:[
          BoxShadow(color:Colors.black.withValues(alpha:.25),blurRadius:28,offset:Offset(0,11)),
        ]),
    clipBehavior:Clip.antiAlias,
    child:Material(type:MaterialType.transparency,child:child),
  );}
}

class CupSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const CupSection({super.key,required this.title,this.subtitle,this.trailing});
  @override
  Widget build(BuildContext context)=>Padding(
    padding:EdgeInsets.fromLTRB(18,20,16,11),
    child:Row(children:[
      Container(height:22,width:4,decoration:BoxDecoration(
        gradient:LinearGradient(colors:[CupUi.red,CupUi.red.withValues(alpha:.25)]),
        borderRadius:BorderRadius.circular(4))),
      SizedBox(width:9),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:TextStyle(color:CupUi.white,fontWeight:FontWeight.w900,fontSize:13,letterSpacing:.7)),
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
    padding:EdgeInsets.symmetric(horizontal:10,vertical:6),
    decoration:BoxDecoration(
      color:filled?effectiveColor.withValues(alpha:.14):CupUi.raised,
      borderRadius:BorderRadius.circular(99),
      border:Border.all(color:effectiveColor.withValues(alpha:filled ? .20 : .09))),
    child:Text(text,style:TextStyle(fontWeight:FontWeight.w900,fontSize:9,color:effectiveColor,letterSpacing:.35)),
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
    child:Container(width:double.infinity,padding:EdgeInsets.symmetric(horizontal:18,vertical:25),
      decoration:BoxDecoration(color:CupUi.surface,borderRadius:BorderRadius.circular(22),
        border:Border.all(color:CupUi.stroke)),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Container(height:56,width:56,decoration:BoxDecoration(color:CupUi.redMuted,borderRadius:BorderRadius.circular(18)),
        child:Icon(icon,color:CupUi.red,size:27)),
      SizedBox(height:13),
      Text(title,textAlign:TextAlign.center,style:TextStyle(color:CupUi.white,fontSize:15,fontWeight:FontWeight.w800)),
      SizedBox(height:7),
      Text(message,textAlign:TextAlign.center,style:TextStyle(color:CupUi.muted,fontSize:12,height:1.45)),
      if(retry!=null)Padding(padding:EdgeInsets.only(top:8),child:OutlinedButton.icon(
        onPressed:retry,icon:Icon(Icons.refresh_rounded,size:16),label:Text('ПОВТОРИТЬ'))),
    ])),
  );
}

class CupDiv extends StatelessWidget {
  final double indent;
  const CupDiv({super.key,this.indent=0});
  @override Widget build(BuildContext context)=>Container(height:.8,color:CupUi.stroke,margin:EdgeInsets.only(left:indent));
}

class CupReveal extends StatefulWidget {
  final Widget child;
  const CupReveal({super.key,required this.child});
  @override State<CupReveal> createState()=>_CupRevealState();
}
class _CupRevealState extends State<CupReveal> with SingleTickerProviderStateMixin {
  late final controller=AnimationController(vsync:this,duration:const Duration(milliseconds:430))..forward();
  late final curve=CurvedAnimation(parent:controller,curve:Curves.easeOutCubic);
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    if(MediaQuery.maybeOf(context)?.disableAnimations??false)return widget.child;
    return FadeTransition(opacity:curve,child:SlideTransition(
      position:Tween<Offset>(begin:const Offset(0,.035),end:Offset.zero).animate(curve),
      child:widget.child));
  }
}

class CupLivePulse extends StatefulWidget {
  const CupLivePulse({super.key});
  @override State<CupLivePulse> createState()=>_CupLivePulseState();
}
class _CupLivePulseState extends State<CupLivePulse> with SingleTickerProviderStateMixin {
  late final controller=AnimationController(vsync:this,duration:const Duration(milliseconds:1050))
    ..repeat(reverse:true);
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    if(MediaQuery.maybeOf(context)?.disableAnimations??false)return _dot(1);
    return AnimatedBuilder(animation:controller,builder:(_,__)=>_dot(.45+controller.value*.55));
  }
  Widget _dot(double opacity)=>Container(width:7,height:7,
    decoration:BoxDecoration(shape:BoxShape.circle,color:CupUi.green.withValues(alpha:opacity),
      boxShadow:[BoxShadow(color:CupUi.green.withValues(alpha:opacity*.5),blurRadius:8)]));
}

