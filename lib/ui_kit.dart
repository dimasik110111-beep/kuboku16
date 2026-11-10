import 'package:flutter/material.dart';

/// JUNIOR U16 / LIVE DESK — broadcast scoreboard design system.
class CupUi {
  static bool light = true;
  static const navy = Color(0xFF00212D);

  static Color get background => light ? Colors.white : const Color(0xFF091820);
  static Color get surface => light ? Colors.white : const Color(0xFF142830);
  static Color get raised => light ? const Color(0xFFEDF0F1) : const Color(0xFF223740);
  static Color get stroke => light ? const Color(0xFFE4E8EA) : const Color(0xFF334A53);

  /// Primary action. Historical name is retained for backwards compatibility.
  static const red = Color(0xFFEB0050);
  static const ice = Color(0xFF005481);
  static const gold = Color(0xFFFFD47A);
  static const violet = Color(0xFFB7A7EE);
  static const coral = Color(0xFFFF9C81);
  static const teal = Color(0xFF6ED4B8);
  static const orange = Color(0xFFFFAE72);
  static List<Color> get featureAccents => light
      ? const [red, ice, Color(0xFF158A83),
          Color(0xFF7A56B5), Color(0xFFCB7215), Color(0xFF156D54), Color(0xFF92650D)]
      : const [ice, violet, teal, coral, orange, Color(0xFF4DE6AD), gold];
  static Color get redMuted => light ? const Color(0xFFFFE6EF) : const Color(0xFF45212F);
  static Color get green => light ? const Color(0xFF16714A) : const Color(0xFF83E8A6);
  static Color get yellow => light ? const Color(0xFF91600F) : const Color(0xFFFFD47A);
  static Color get white => light ? navy : const Color(0xFFF3F7F8);
  static Color get soft => light ? const Color(0xFF334A53) : const Color(0xFFD5E2E7);
  static Color get muted => light ? const Color(0xFF647078) : const Color(0xFF9BB4BD);
  static Color get dim => light ? const Color(0xFF89949A) : const Color(0xFF78919A);
  static List<Color> get heroGradient => light
      ? const [Color(0xFF00394A), navy, Color(0xFF102D42)]
      : const [Color(0xFF26382D), Color(0xFF121C17), Color(0xFF35251D)];
}

/// Broadcast panel: field markings and sharp scoreboard framing.
/// Positioned layers are pointer-ignored so interactive children remain usable.
class CupArena extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  const CupArena({
    super.key,
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.fromLTRB(21, 22, 21, 23),
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: margin ?? const EdgeInsets.fromLTRB(12, 12, 12, 9),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: .24),
            blurRadius: 16, offset: const Offset(0, 7)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: CupUi.heroGradient,
          ),
          border: Border.all(color: CupUi.ice.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(children: [
          Positioned.fill(child: IgnorePointer(
            child: CustomPaint(painter: _ArenaLines()))),
          Positioned(top:0,left:0,right:0,child:IgnorePointer(child:Container(
            height:4,decoration:const BoxDecoration(gradient:LinearGradient(
              colors:[CupUi.red,CupUi.orange,CupUi.ice]))))),
          Padding(padding: padding, child: child),
        ]),
      ),
    ),
  );
}

class _ArenaLines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .085)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width * .82, size.height * .5);
    for (final radius in [60.0, 115.0]) {
      canvas.drawCircle(center, radius, paint);
    }
    final edge = Path()
      ..moveTo(size.width * .38, 0)
      ..lineTo(size.width * .38, size.height)
      ..moveTo(size.width * .68, 0)
      ..lineTo(size.width * .68, size.height);
    canvas.drawPath(edge, paint..color = Colors.white.withValues(alpha: .045));
    canvas.drawCircle(center, 4, Paint()..color = CupUi.ice.withValues(alpha: .35));
  }
  @override
  bool shouldRepaint(covariant _ArenaLines oldDelegate) => false;
}

class CupCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  const CupCard({
    super.key, required this.child, this.padding, this.margin, this.color,
  });
  @override
  Widget build(BuildContext context) {
    final base = color ?? CupUi.surface;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: padding,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: CupUi.stroke.withValues(alpha: CupUi.light ? .94 : .75)),
        boxShadow: null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class CupSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const CupSection({
    super.key, required this.title, this.subtitle, this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    return Container(color:CupUi.raised,
      padding:const EdgeInsets.fromLTRB(18,9,18,9),
      child:Row(children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(title,style:TextStyle(color:CupUi.white,
            fontWeight:FontWeight.w900,fontSize:12,letterSpacing:.2)),
          if(subtitle!=null)Text(subtitle!,style:TextStyle(color:CupUi.muted,fontSize:10)),
        ])),
        if(trailing!=null)trailing!,
      ]));
  }
}

class CupTag extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;
  const CupTag({
    super.key, required this.text,
    this.color = const Color(0xFF8995A6), this.filled = false,
  });
  @override
  Widget build(BuildContext context) {
    final tone = color == const Color(0xFF8995A6) ? CupUi.muted : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? tone.withValues(alpha: .14) : CupUi.raised,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: tone.withValues(alpha: filled ? .3 : .12)),
      ),
      child: Text(text, style: TextStyle(color: tone,
        fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .9)),
    );
  }
}

class CupMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? retry;
  const CupMessage({
    super.key, this.icon = Icons.info_outline,
    required this.title, required this.message, this.retry,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
    child: CupCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 58, height: 58,
          decoration: BoxDecoration(color: CupUi.redMuted,
            borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, color: CupUi.red, size: 28)),
        const SizedBox(height: 15),
        Text(title, textAlign: TextAlign.center,
          style: TextStyle(color: CupUi.white, fontSize: 16,
            fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center,
          style: TextStyle(color: CupUi.muted, fontSize: 12, height: 1.5)),
        if (retry != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: OutlinedButton.icon(onPressed: retry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('ПОВТОРИТЬ'))),
      ]),
    ),
  );
}

class CupDiv extends StatelessWidget {
  final double indent;
  const CupDiv({super.key, this.indent = 0});
  @override
  Widget build(BuildContext context) => Container(
    height: .8, color: CupUi.stroke, margin: EdgeInsets.only(left: indent));
}

class CupReveal extends StatefulWidget {
  final Widget child;
  const CupReveal({super.key, required this.child});
  @override
  State<CupReveal> createState() => _CupRevealState();
}
class _CupRevealState extends State<CupReveal>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(vsync: this,
    duration: const Duration(milliseconds: 520))..forward();
  late final curve = CurvedAnimation(parent: controller,
    curve: Curves.easeOutCubic);
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .06),
          end: Offset.zero).animate(curve),
        child: widget.child,
      ),
    );
  }
}

class CupLivePulse extends StatefulWidget {
  const CupLivePulse({super.key});
  @override
  State<CupLivePulse> createState() => _CupLivePulseState();
}
class _CupLivePulseState extends State<CupLivePulse>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1050))
    ..repeat(reverse: true);
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return _dot(1);
    }
    return AnimatedBuilder(animation: controller,
      builder: (_, __) => _dot(.45 + controller.value * .55));
  }
  Widget _dot(double opacity) => Container(
    width: 7, height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: CupUi.green.withValues(alpha: opacity),
      boxShadow: [BoxShadow(
        color: CupUi.green.withValues(alpha: opacity * .5), blurRadius: 8)]),
  );
}
