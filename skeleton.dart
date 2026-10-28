import 'package:flutter/material.dart';
import 'theme.dart';

/// Анимация «блика» для скелетонов: один контроллер на весь список.
class _SkelAnim extends InheritedWidget {
  final Animation<double> anim;
  const _SkelAnim({required this.anim, required super.child});

  static Animation<double>? of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<_SkelAnim>()?.anim;

  @override
  bool updateShouldNotify(_SkelAnim old) => old.anim != anim;
}

class Skeleton extends StatefulWidget {
  final Widget child;
  const Skeleton({super.key, required this.child});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SkelAnim(anim: _c, child: widget.child);
}

class SkelBox extends StatelessWidget {
  final double? w;
  final double h;
  final double r;
  final bool circle;
  const SkelBox({super.key, this.w, required this.h, this.r = 8, this.circle = false});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final base = Color.alphaBlend(p.mu.withOpacity(.10), p.card);
    final hi = Color.alphaBlend(p.mu.withOpacity(.22), p.card);
    final anim = _SkelAnim.of(context);
    Widget box(double t) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circle ? null : BorderRadius.circular(r),
            gradient: LinearGradient(
              begin: Alignment(-2 + 4 * t, 0),
              end: Alignment(-0.5 + 4 * t, 0),
              colors: [base, hi, base],
            ),
          ),
        );
    if (anim == null) return box(.5);
    return AnimatedBuilder(animation: anim, builder: (_, __) => box(anim.value));
  }
}

Widget _line(double f, double h, {double r = 8, double top = 0}) => Padding(
      padding: EdgeInsets.only(top: top),
      child: FractionallySizedBox(widthFactor: f, alignment: Alignment.centerLeft, child: SkelBox(h: h, r: r)),
    );

/// Заглушка карточки объявления в ленте.
class AdCardSkeleton extends StatelessWidget {
  const AdCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: cardDeco(p),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SkelBox(w: 92, h: 92, r: 14),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            _line(.5, 22, r: 99),
            _line(.9, 16, top: 10),
            _line(.45, 16, top: 8),
            _line(.7, 12, top: 10),
          ]),
        ),
      ]),
    );
  }
}

/// Заглушка строки в списке диалогов.
class DialogSkeleton extends StatelessWidget {
  const DialogSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: cardDeco(p),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SkelBox(w: 52, h: 52, circle: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            _line(.4, 15),
            _line(.75, 22, r: 99, top: 8),
            _line(.55, 12, top: 8),
          ]),
        ),
      ]),
    );
  }
}
