import 'package:flutter/material.dart';
import 'home.dart';
import 'theme.dart';
import 'widgets.dart';

// Заставка: логотип в цветах текущей темы (светлая — оранжевый, тёмная — фиолетово-бирюзовый)
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
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: done ? const HomeShell(key: ValueKey('home')) : const _Splash(key: ValueKey('splash')),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (c, v, child) => Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.scale(scale: .6 + .4 * v, child: child),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Logo(size: 96),
            const SizedBox(height: 20),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Дело', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: p.tx)),
              const GradText('Есть', size: 34),
            ]),
            const SizedBox(height: 6),
            Text('подработка рядом с домом', style: TextStyle(color: p.mu, fontSize: 15)),
          ]),
        ),
      ),
    );
  }
}
