import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home.dart';
import 'shortcuts.dart';
import 'theme.dart';
import 'widgets.dart';

// Заставка: плитка логотипа «выпрыгивает», галочка дорисовывается, название выезжает с двух сторон
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: p.bg,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
      child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween<double>(begin: .96, end: 1.0).animate(anim), child: child),
      ),
      child: done ? const ShortcutHost(key: ValueKey('home'), child: HomeShell()) : const _Splash(key: ValueKey('splash')),
      ),
    );
  }
}

class _Splash extends StatefulWidget {
  const _Splash({super.key});
  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _iv(double a, double b, Curve k) => CurvedAnimation(parent: _c, curve: Interval(a, b, curve: k));

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final pop = _iv(0, .42, Curves.easeOutBack);
    final check = _iv(.28, .62, Curves.easeOut);
    final txt = _iv(.4, .78, Curves.easeOutCubic);
    final tag = _iv(.62, 1, Curves.easeOut);
    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final pv = pop.value;
            final tv = txt.value;
            final gv = tag.value;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Transform.rotate(
                angle: (1 - pv) * -.28,
                child: Transform.scale(
                  scale: .35 + .65 * pv,
                  child: Opacity(
                    opacity: pv.clamp(0.0, 1.0),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(29),
                        boxShadow: [BoxShadow(color: p.ac.withOpacity(.35), blurRadius: 34, offset: const Offset(0, 12))],
                      ),
                      child: CustomPaint(size: const Size(96, 96), painter: _CheckPainter(check.value)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Opacity(
                  opacity: tv.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(-26 * (1 - tv), 0),
                    child: Text('Дело', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: p.tx)),
                  ),
                ),
                Opacity(
                  opacity: tv.clamp(0.0, 1.0),
                  child: Transform.translate(offset: Offset(26 * (1 - tv), 0), child: const GradText('Есть', size: 34)),
                ),
              ]),
              const SizedBox(height: 6),
              Opacity(
                opacity: gv.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - gv)),
                  child: Text('подработка рядом с домом', style: TextStyle(color: p.mu, fontSize: 15)),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

// Галочка, которая дорисовывается по мере анимации
class _CheckPainter extends CustomPainter {
  final double t;
  _CheckPainter(this.t);

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width * .29, s.height * .53)
      ..lineTo(s.width * .43, s.height * .67)
      ..lineTo(s.width * .72, s.height * .35);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * .09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t.clamp(0.0, 1.0)), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}
