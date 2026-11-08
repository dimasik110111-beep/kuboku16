import 'package:flutter/material.dart';

/// JUNIOR U16 / ARENA DESIGN SYSTEM — v28.
/// The tokens deliberately support both palettes; match data is not themed.
class CupUi {
  static bool light = false;

  static Color get background => light ? const Color(0xFFF3F6FC) : const Color(0xFF060A12);
  static Color get surface => light ? const Color(0xFFFFFFFF) : const Color(0xFF0D1522);
  static Color get raised => light ? const Color(0xFFE8EEF9) : const Color(0xFF152234);
  static Color get stroke => light ? const Color(0xFFD5E0F0) : const Color(0xFF26374C);

  /// Primary action. Historical name is retained for backwards compatibility.
  static const red = Color(0xFF516DFA);
  static const ice = Color(0xFF8CEAFF);
  static const gold = Color(0xFFFFD47A);
  static Color get redMuted => light ? const Color(0xFFE5EAFF) : const Color(0xFF1F2D61);
  static Color get green => light ? const Color(0xFF087D56) : const Color(0xFF4DE6AD);
  static Color get yellow => light ? const Color(0xFF91600F) : const Color(0xFFFFD47A);
  static Color get white => light ? const Color(0xFF142235) : const Color(0xFFF5F8FF);
  static Color get soft => light ? const Color(0xFF34435A) : const Color(0xFFD2DCF2);
  static Color get muted => light ? const Color(0xFF62738B) : const Color(0xFF9BAAC4);
  static Color get dim => light ? const Color(0xFF8796AA) : const Color(0xFF657795);
  static List<Color> get heroGradient => light
      ? const [Color(0xFF183C79), Color(0xFF142B59), Color(0xFF263A82)]
      : const [Color(0xFF17356C), Color(0xFF0A172A), Color(0xFF151A32)];
}

/// Arena poster: quiet rink geometry, two light sources, high-contrast content.
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
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(color: CupUi.red.withValues(alpha: .18),
            blurRadius: 36, offset: const Offset(0, 14)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: CupUi.heroGradient,
          ),
          border: Border.all(color: CupUi.ice.withValues(alpha: .22)),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(children: [
          Positioned.fill(child: IgnorePointer(
            child: CustomPaint(painter: _ArenaLines()))),
          Positioned(right: -68, top: -92, child: IgnorePointer(child: Container(
            height: 245, width: 245,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                CupUi.ice.withValues(alpha: .24),
                CupUi.red.withValues(alpha: .08),
                Colors.transparent,
              ])),
          ))),
          Positioned(left: -110, bottom: -145, child: IgnorePointer(child: Container(
            height: 260, width: 260,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                CupUi.red.withValues(alpha: .26), Colors.transparent,
              ])),
          ))),
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
    final center = Offset(size.width * .87, size.height * .50);
    for (final radius in [68.0, 120.0, 179.0]) {
      canvas.drawCircle(center, radius, paint);
    }
    final edge = Path()
      ..moveTo(size.width * .30, 0)
      ..lineTo(size.width * .69, size.height)
      ..moveTo(size.width * .72, 0)
      ..lineTo(size.width * 1.11, size.height);
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
        color: color ?? (CupUi.light ? CupUi.surface : null),
        gradient: color == null && !CupUi.light
            ? LinearGradient(begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(base, CupUi.raised, .27)!, base])
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CupUi.stroke.withValues(alpha: CupUi.light ? .94 : .75)),
        boxShadow: CupUi.light
          ? [BoxShadow(color: const Color(0xFF233552).withValues(alpha: .06),
              blurRadius: 18, offset: const Offset(0, 5))]
          : [BoxShadow(color: Colors.black.withValues(alpha: .21),
              blurRadius: 22, offset: const Offset(0, 9))],
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 28, 16, 12),
    child: Row(children: [
      Container(width: 4, height: 31,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [CupUi.ice, CupUi.red]),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: CupUi.ice.withValues(alpha: .35),
            blurRadius: 10)])),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: CupUi.white,
            fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -.35)),
          if (subtitle != null) Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle!, style: TextStyle(
              color: CupUi.muted, fontSize: 11)),
          ),
        ])),
      if (trailing != null) trailing!,
    ]),
  );
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: filled ? tone.withValues(alpha: .14) : CupUi.raised,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: tone.withValues(alpha: filled ? .3 : .12)),
      ),
      child: Text(text, style: TextStyle(color: tone,
        fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .55)),
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
            borderRadius: BorderRadius.circular(19)),
          child: Icon(icon, color: CupUi.ice, size: 28)),
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
