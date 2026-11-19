import 'package:flutter/material.dart';

/// Shared visual language for scores, standings and player profiles.
class CupUi {
  static bool light = true;
  static const navy = Color(0xFF17212F);

  static Color get background =>
      light ? const Color(0xFFF4F5F7) : const Color(0xFF10171F);
  static Color get surface => light ? Colors.white : const Color(0xFF19232D);
  static Color get raised =>
      light ? const Color(0xFFEEF1F3) : const Color(0xFF24313D);
  static Color get stroke =>
      light ? const Color(0xFFE3E7EB) : const Color(0xFF33414E);

  /// Primary action. Historical name is retained for backwards compatibility.
  static const red = Color(0xFF007F68);
  static Color get action => light ? red : const Color(0xFF77D6BC);
  static const ice = Color(0xFF58BFA9);
  static const signal = Color(0xFFBCE8D8);
  static const gold = Color(0xFFE1B54F);
  static const violet = Color(0xFF816AC6);
  static const coral = Color(0xFFE96D55);
  static const teal = Color(0xFF198D80);
  static const orange = Color(0xFFDF7946);
  static List<Color> get featureAccents => light
      ? const [
          red,
          violet,
          teal,
          coral,
          orange,
          Color(0xFF177350),
          Color(0xFF886519)
        ]
      : const [Color(0xFF5FD1E5), violet, teal, coral, orange, signal, gold];
  static Color get redMuted =>
      light ? const Color(0xFFE5F3EE) : const Color(0xFF183D35);
  static Color get green =>
      light ? const Color(0xFF16714A) : const Color(0xFF83E8A6);
  static Color get yellow =>
      light ? const Color(0xFF91600F) : const Color(0xFFFFD47A);
  static Color get white => light ? navy : const Color(0xFFF0F8F8);
  static Color get soft =>
      light ? const Color(0xFF465362) : const Color(0xFFCED7DF);
  static Color get muted =>
      light ? const Color(0xFF667382) : const Color(0xFFA4B3C0);
  static Color get dim =>
      light ? const Color(0xFF788492) : const Color(0xFF8D9FAC);
  static List<Color> get heroGradient => light
      ? const [Color(0xFF203A3B), Color(0xFF172D32)]
      : const [Color(0xFF223D3E), Color(0xFF182D32)];
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
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: CupUi.heroGradient,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(children: [
              Positioned.fill(
                  child: IgnorePointer(
                      child: CustomPaint(painter: _ArenaLines()))),
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
      ..color = Colors.white.withValues(alpha: .035)
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
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    final base = color ?? CupUi.surface;
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: padding,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: CupUi.stroke.withValues(alpha: CupUi.light ? .94 : .75)),
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
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(17, 26, 17, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        color: CupUi.white,
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w800,
                        fontSize: 21,
                        height: 1.2,
                        letterSpacing: -.6)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!,
                      style: TextStyle(
                          color: CupUi.muted, fontSize: 12, height: 1.4)),
                ],
              ])),
          if (trailing != null) trailing!,
        ]));
  }
}

class CupTag extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;
  const CupTag({
    super.key,
    required this.text,
    this.color = const Color(0xFF8995A6),
    this.filled = false,
  });
  @override
  Widget build(BuildContext context) {
    final tone = color == const Color(0xFF8995A6)
      ? CupUi.muted : color == CupUi.red ? CupUi.action : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? tone.withValues(alpha: .14) : CupUi.raised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: filled ? .3 : .12)),
      ),
      child: Text(text,
          style: TextStyle(
              color: tone,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .1)),
    );
  }
}

class CupMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? retry;
  final String actionLabel;
  const CupMessage({
    super.key,
    this.icon = Icons.info_outline,
    required this.title,
    required this.message,
    this.retry,
    this.actionLabel = 'Повторить',
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: CupCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                    color: CupUi.redMuted,
                    borderRadius: BorderRadius.circular(18)),
                child: Icon(icon, color: CupUi.red, size: 28)),
            const SizedBox(height: 15),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: CupUi.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: CupUi.muted, fontSize: 12, height: 1.5)),
            if (retry != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                      onPressed: retry,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(actionLabel))),
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
  late final controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220))
    ..forward();
  late final curve =
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .06), end: Offset.zero)
            .animate(curve),
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
      vsync: this, duration: const Duration(milliseconds: 1050));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      controller.stop();
    } else if (!controller.isAnimating) {
      controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return _dot(1);
    }
    return AnimatedBuilder(
        animation: controller,
        builder: (_, __) => _dot(.45 + controller.value * .55));
  }

  Widget _dot(double opacity) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CupUi.green.withValues(alpha: opacity),
            boxShadow: [
              BoxShadow(
                  color: CupUi.green.withValues(alpha: opacity * .5),
                  blurRadius: 8)
            ]),
      );
}
