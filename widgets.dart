import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cities.dart';
import 'icons.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';

String imgUrl(String id, int w) => 'https://lh3.googleusercontent.com/d/$id=w$w';

/// Единый вызов лёгкой вибрации (для нажатий на кнопки, табы и сердечко)
void haptic([bool strong = false]) => S.vibrate(strong);

// Сообщения-подсказки (нужно ввести, не удалось и т.п.) показываем как ошибку, остальные как успех
const _toastErrStarts = ['Не удалось', 'Не больше', 'Введите', 'Укажите', 'Напишите', 'Поставьте', 'Слишком', 'Разрешите', 'Сначала', 'Войдите'];

void toast(BuildContext c, String m, {bool? err}) {
  final bad = err ?? _toastErrStarts.any((x) => m.startsWith(x));
  TopToastHost.show(m, kind: bad ? 'er' : 'ok');
}

class _ToastEntry {
  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int seconds;
  final int id;
  final String kind;
  const _ToastEntry({
    required this.message,
    this.kind = 'ok',
    this.title,
    this.actionLabel,
    this.onAction,
    this.seconds = 4,
    required this.id,
  });
}

/// Верхнее всплывающее уведомление в фирменном дизайне ДелоЕсть (как на сайте)
class TopToastHost extends StatefulWidget {
  final Widget child;
  const TopToastHost({super.key, required this.child});

  static _TopToastHostState? _state;

  static void show(
    String message, {
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    int seconds = 4,
    String? kind,
  }) {
    _state?._push(_ToastEntry(
      message: message,
      kind: kind ?? (title != null ? 'hi' : 'ok'),
      title: title,
      actionLabel: actionLabel,
      onAction: onAction,
      seconds: seconds,
      id: DateTime.now().microsecondsSinceEpoch,
    ));
  }

  @override
  State<TopToastHost> createState() => _TopToastHostState();
}

class _TopToastHostState extends State<TopToastHost> {
  _ToastEntry? _cur;
  bool _vis = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    TopToastHost._state = this;
  }

  @override
  void dispose() {
    if (TopToastHost._state == this) TopToastHost._state = null;
    _t?.cancel();
    super.dispose();
  }

  void _push(_ToastEntry e) {
    _t?.cancel();
    if (!mounted) return;
    setState(() {
      _cur = e;
      _vis = true;
    });
    _t = Timer(Duration(seconds: e.seconds), _hide);
  }

  void _hide() {
    _t?.cancel();
    if (!mounted) return;
    setState(() => _vis = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final e = _cur;
    final topPad = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        widget.child,
        if (e != null)
          Positioned(
            top: topPad + 10,
            left: 14,
            right: 14,
            child: IgnorePointer(
              ignoring: !_vis,
              child: AnimatedSlide(
                offset: _vis ? Offset.zero : const Offset(0, -1.2),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _vis ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _card(p, e))),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Карточка как на сайте: цветной значок, текст и полоска времени снизу
  Widget _card(Pal p, _ToastEntry e) {
    final er = e.kind == 'er';
    final hi = e.kind == 'hi';
    final tone = er ? p.dng : (hi ? p.ac : p.ok);
    final icon = er ? Icons.error_outline_rounded : (hi ? Icons.notifications_active_rounded : Icons.check_rounded);
    final hasTitle = e.title != null && e.title!.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < 0) _hide();
        },
        onTap: () {
          haptic();
          final fn = e.onAction;
          _hide();
          if (fn != null) fn();
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: er ? Color.alphaBlend(p.dng.withOpacity(.45), p.bd) : p.bd),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 22, offset: const Offset(0, 8))],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 18, 15),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: hi ? null : tone,
                        gradient: hi ? LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: hasTitle
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(e.title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.tx, fontWeight: FontWeight.w700, fontSize: 14, height: 1.25)),
                                const SizedBox(height: 2),
                                Text(e.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontWeight: FontWeight.w500, fontSize: 13, height: 1.3)),
                              ],
                            )
                          : Text(e.message, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.tx, fontWeight: FontWeight.w600, fontSize: 14, height: 1.3)),
                    ),
                    if (e.actionLabel != null && e.onAction != null) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [p.ac, p.ac2]), borderRadius: BorderRadius.circular(10)),
                        child: Text(e.actionLabel!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(e.id),
                  tween: Tween<double>(begin: 1, end: 0),
                  duration: Duration(seconds: e.seconds),
                  builder: (_, v, __) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(widthFactor: v, child: Container(height: 3, color: tone)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Нажатие с лёгким «вдавливанием» и мягкой вибрацией (для кнопок и карточек)
class Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool strongHaptic;
  const Tap({super.key, required this.child, this.onTap, this.scale = .97, this.strongHaptic = false});
  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => setState(() => down = true) : null,
      onTapUp: on ? (_) => setState(() => down = false) : null,
      onTapCancel: on ? () => setState(() => down = false) : null,
      onTap: on
          ? () {
              haptic(widget.strongHaptic);
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Плавное переключение содержимого при смене вкладок, фильтров или загрузке (как на сайте #app.pin)
class SmoothSwitch extends StatelessWidget {
  final Widget child;
  final Duration duration;
  const SmoothSwitch({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .03), end: Offset.zero).animate(a),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

/// Анимированное сердечко «В избранное» с пружинящим увеличением, кольцом и вибрацией (как .fv.pop на сайте)
class FavHeart extends StatefulWidget {
  final String adId;
  final double size;
  final Color? inactiveColor;
  final VoidCallback? onGuestTap;
  const FavHeart({
    super.key,
    required this.adId,
    this.size = 21,
    this.inactiveColor,
    this.onGuestTap,
  });

  @override
  State<FavHeart> createState() => _FavHeartState();
}

class _FavHeartState extends State<FavHeart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.34).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.34, end: 0.92).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 30),
  ]).animate(_c);
  bool _lastFav = false;

  @override
  void initState() {
    super.initState();
    _lastFav = S.i.isFav(widget.adId);
  }

  @override
  void didUpdateWidget(covariant FavHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cur = S.i.isFav(widget.adId);
    if (cur != _lastFav) {
      _lastFav = cur;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    if (!S.i.logged) {
      haptic();
      widget.onGuestTap?.call();
      return;
    }
    S.i.toggleFav(widget.adId);
    _lastFav = S.i.isFav(widget.adId);
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final fav = S.i.isFav(widget.adId);
    if (fav != _lastFav) {
      _lastFav = fav;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _c.forward(from: 0);
      });
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final ringT = _c.value;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (fav && ringT > 0 && ringT < 1)
                IgnorePointer(
                  child: Transform.scale(
                    scale: 0.8 + ringT * 1.15,
                    child: Container(
                      width: widget.size + 6,
                      height: widget.size + 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: p.ac.withOpacity((1 - ringT) * .55),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.scale(
                scale: _c.isAnimating ? _scale.value : 1.0,
                child: Icon(
                  fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: fav ? p.ac : (widget.inactiveColor ?? p.mu),
                  size: widget.size,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Плавное появление: проявление + лёгкий подъём снизу
class Appear extends StatefulWidget {
  final Widget child;
  final int delay; // мс
  const Appear({super.key, required this.child, this.delay = 0});
  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final Animation<double> a = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.delay == 0) {
      c.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) c.forward();
      });
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .06), end: Offset.zero).animate(a),
          child: widget.child,
        ),
      );
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 34});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(Icons.check_rounded, color: Colors.white, size: size * .68),
    );
  }
}

class GradText extends StatelessWidget {
  final String text;
  final double size;
  const GradText(this.text, {super.key, this.size = 20});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(colors: [p.ac, p.ac2]).createShader(r),
      child: Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}

class GradBtn extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? ico;
  final bool busy;
  final double radius;
  const GradBtn(this.text, {super.key, this.onTap, this.icon, this.ico, this.busy = false, this.radius = 12});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Opacity(
      opacity: (onTap == null && !busy) ? .55 : 1,
      child: Tap(
        onTap: busy ? null : onTap,
        scale: .96,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [p.ac, p.ac2]),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [BoxShadow(color: p.ac.withOpacity(.16), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: busy
              ? const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (ico != null) ...[Ico(ico!, color: Colors.white, size: 20), const SizedBox(width: 8)]
                  else if (icon != null) ...[Icon(icon, color: Colors.white, size: 21), const SizedBox(width: 8)],
                  Flexible(
                    child: Text(text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ]),
        ),
      ),
    );
  }
}

class OutBtn extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final double radius;
  const OutBtn(this.text, {super.key, this.onTap, this.icon, this.color, this.radius = 12});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final col = color ?? p.tx;
    return Tap(
      onTap: onTap,
      scale: .96,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: p.bd, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, color: col, size: 21), const SizedBox(width: 8)],
          Text(text, style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  final String text;
  final Color color;
  const Tag(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Цена-плашка: крупно и цветом, чтобы взгляд находил её первой (как на сайте, .pay)
class PriceTag extends StatelessWidget {
  final String pay;
  final double size;
  final bool dense;
  final bool plain; // без плашки: крупный текст (список объявлений)
  const PriceTag(this.pay, {super.key, this.size = 17, this.dense = false, this.plain = false});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final text = payF(pay);
    final fixed = RegExp(r'\d').hasMatch(text);
    final col = fixed ? p.ok : p.mu;
    if (plain) {
      return Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: fixed ? size + 3 : size - 2,
              fontWeight: fixed ? FontWeight.w800 : FontWeight.w600,
              color: col,
              height: 1.2));
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 1 : 3),
      decoration: BoxDecoration(color: col.withOpacity(.13), borderRadius: BorderRadius.circular(R.s)),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: col, height: 1.25)),
    );
  }
}

Widget typeTag(BuildContext c, String type) {
  final p = pal(c);
  return Tag(type, type == kTypes[0] ? p.ac : p.ok);
}

class CatChip extends StatelessWidget {
  final String name;
  const CatChip(this.name, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(catIcon(name), size: 14, color: p.mu),
      const SizedBox(width: 4),
      Flexible(
        child: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: p.mu, fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

class Avatar extends StatelessWidget {
  final String name;
  final String data;
  final double size;
  const Avatar(this.name, {super.key, this.data = '', this.size = 44});

  // Раскодированные байты кэшируем: одинаковый объект байтов -> картинка берётся из кэша без мигания
  static final Map<String, Uint8List> _bytes = {};
  static Uint8List? _decode(String data) {
    if (!data.startsWith('data:image')) return null;
    final hit = _bytes[data];
    if (hit != null) return hit;
    try {
      final b = base64Decode(data.substring(data.indexOf(',') + 1));
      if (_bytes.length > 60) _bytes.remove(_bytes.keys.first);
      _bytes[data] = b;
      return b;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final bytes = _decode(data);
    final img = bytes == null ? null : MemoryImage(bytes);
    final letter = name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        image: img == null ? null : DecorationImage(image: img, fit: BoxFit.cover),
      ),
      child: img == null
          ? Text(letter, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .42))
          : null,
    );
  }
}

class AdCard extends StatelessWidget {
  final Ad ad;
  final VoidCallback onTap;
  final Widget? footer;
  final bool showFav;
  final int mode; // 0 список, 1 плитка, 2 компактно
  const AdCard({super.key, required this.ad, required this.onTap, this.footer, this.showFav = true, this.mode = 0});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    if (mode == 1) return _tile(context, p);
    if (mode == 2) return _compact(context, p);
    final width = MediaQuery.sizeOf(context).width;
    final thumb = width >= 600 ? 112.0 : 92.0;
    return Appear(
      child: Tap(
        onTap: onTap,
        scale: .99,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: cardDeco(p, r: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: thumb, height: thumb, child: _cover(p, thumb)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _tagLine(p)),
                    if (showFav && S.i.logged) ...[
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 3, top: 1),
                        child: FavHeart(adId: ad.id, size: 21),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  Text(ad.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.18, color: p.tx)),
                  const SizedBox(height: 4),
                  PriceTag(ad.pay, size: 17, plain: true),
                  const SizedBox(height: 4),
                  Row(children: [
                    Ico('pin', size: 14, color: p.mu),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(adLoc(ad).isEmpty ? 'Город не указан' : adLoc(ad),
                          style: TextStyle(fontSize: 12, color: p.mu), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(' · ${siteShortAgo(ad.ts, S.i.timeZone)}', style: TextStyle(fontSize: 12, color: p.mu)),
                  ]),
                ]),
              ),
            ]),
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ]),
        ),
      ),
    );
  }


  // Одна строка: цветная точка и тип, дальше категория тихим серым
  Widget _tagLine(Pal p) {
    final need = ad.type == kTypes[0];
    final col = need ? p.ac : p.ok;
    return Row(children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(ad.type, maxLines: 1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: col)),
      if (ad.category.isNotEmpty)
        Flexible(
          child: Text(' · ${ad.category}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.mu)),
        ),
    ]);
  }

  Widget _heart(Pal p, {bool onPhoto = false}) {
    final heart = FavHeart(adId: ad.id, size: onPhoto ? 19 : 21);
    return onPhoto
        ? Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: p.card.withOpacity(.88), shape: BoxShape.circle),
            child: Center(child: heart),
          )
        : Padding(padding: const EdgeInsets.all(4), child: heart);
  }

  String _shortDate() => siteShortAgo(ad.ts, S.i.timeZone);

  // Плитка: крупное фото сверху, под ним цена, заголовок и город
  Widget _tile(BuildContext context, Pal p) {
    return Appear(
      child: Tap(
        onTap: onTap,
        scale: .98,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: cardDeco(p, r: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: 1.25,
              child: Stack(fit: StackFit.expand, children: [
                _coverBody(p, 90, flat: true),
                // справа остаётся место под сердечко; если тег не помещается, он слегка уменьшается, а не заезжает на сердечко
                Positioned(
                  left: 8,
                  top: 8,
                  right: showFav && S.i.logged ? 44 : 8,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    heightFactor: 1,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(color: p.card.withOpacity(.9), borderRadius: BorderRadius.circular(99)),
                        child: typeTag(context, ad.type),
                      ),
                    ),
                  ),
                ),
                if (showFav && S.i.logged) Positioned(right: 6, top: 6, child: _heart(p, onPhoto: true)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                PriceTag(ad.pay, size: 16, dense: true),
                const SizedBox(height: 4),
                Text(ad.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.2, color: p.tx)),
                const SizedBox(height: 4),
                Text('${adLoc(ad).isEmpty ? 'Город не указан' : adLoc(ad)} · ${_shortDate()}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: p.mu)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // Компактно: маленькое фото и три строки текста
  Widget _compact(BuildContext context, Pal p) {
    final need = ad.type == kTypes[0];
    return Appear(
      child: Tap(
        onTap: onTap,
        scale: .99,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
          decoration: cardDeco(p, r: 16),
          child: Row(children: [
            SizedBox(width: 62, height: 62, child: _cover(p, 62)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ad.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: p.tx)),
                const SizedBox(height: 2),
                PriceTag(ad.pay, size: 14, dense: true),
                const SizedBox(height: 2),
                Row(children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: need ? p.ac : p.ok, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text('${adLoc(ad).isEmpty ? 'Город не указан' : adLoc(ad)} · ${_shortDate()}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: p.mu)),
                  ),
                ]),
              ]),
            ),
            if (showFav && S.i.logged) _heart(p),
          ]),
        ),
      ),
    );
  }

  Widget _cover(Pal p, double size) => ClipRRect(borderRadius: BorderRadius.circular(12), child: _coverBody(p, size));

  Widget _coverBody(Pal p, double size, {bool flat = false}) {
    final hue = catHue(ad.category);
    Widget ph() => Container(
          decoration: BoxDecoration(
            color: Color.alphaBlend(hue.withOpacity(.14), p.card),
            border: flat ? null : Border.all(color: hue.withOpacity(.26)),
            borderRadius: flat ? null : BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(catIcon(ad.category), size: size * .35, color: hue),
        );
    return Stack(fit: StackFit.expand, children: [
        ad.imgs.isEmpty
            ? ph()
            : CachedNetworkImage(
                imageUrl: imgUrl(ad.imgs[0], 300),
                fit: BoxFit.cover,
                placeholder: (c, u) => Container(color: p.bg2),
                errorWidget: (c, u, e) => ph(),
              ),
        if (ad.imgs.length > 1)
          Positioned(
            right: 5,
            bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.photo_camera_outlined, size: 11, color: Colors.white),
                const SizedBox(width: 3),
                Text('${ad.imgs.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
    ]);
  }
}

void showVerifiedInfo(BuildContext context) {
  haptic();
  showDialog<void>(
    context: context,
    builder: (c) {
      final p = pal(c);
      return AlertDialog(
        backgroundColor: p.card,
        icon: Icon(Icons.verified, color: p.ok, size: 44),
        title: Text('Подтверждённый профиль', textAlign: TextAlign.center, style: TextStyle(color: p.tx, fontWeight: FontWeight.w800)),
        content: Text(
            'Администрация ДелоЕсть проверила документы этого человека и подтвердила его личность. Это снижает риск мошенничества, но деньги заранее всё равно лучше не переводить.',
            style: TextStyle(color: p.mu, height: 1.4)),
        actions: [TextButton(onPressed: () { haptic(); Navigator.pop(c); }, child: Text('Понятно', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800)))],
      );
    },
  );
}

// Значок «Подтверждённый»: по нажатию объясняет, что это значит (в профиле и в объявлении)
class VerifiedBadge extends StatelessWidget {
  final double size;
  final bool label;
  const VerifiedBadge({super.key, this.size = 18, this.label = false});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showVerifiedInfo(context),
      child: label
          ? Container(
              padding: const EdgeInsets.fromLTRB(7, 3, 11, 3),
              decoration: BoxDecoration(
                color: p.ok.withOpacity(.12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: p.ok.withOpacity(.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified, size: size - 1, color: p.ok),
                const SizedBox(width: 5),
                Text('Подтверждённый', style: TextStyle(color: p.ok, fontWeight: FontWeight.w800, fontSize: 12.5)),
              ]),
            )
          : Icon(Icons.verified, size: size, color: p.ok),
    );
  }
}

class BrandIcon extends StatelessWidget {
  final String kind; // tg, wa, vk, ya или max
  final double size;
  const BrandIcon(this.kind, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final Color bg = kind == 'tg'
        ? const Color(0xFF229ED9)
        : kind == 'wa'
            ? const Color(0xFF25D366)
            : kind == 'ya'
                ? const Color(0xFFFC3F1D)
                : kind == 'max'
                    ? const Color(0xFF5B5BF0)
                    : const Color(0xFF0077FF);
    final Widget glyph;
    if (kind == 'tg') {
      glyph = CustomPaint(size: Size.square(size * .64), painter: const _TgPainter());
    } else if (kind == 'wa') {
      glyph = SizedBox(
        width: size * .68,
        height: size * .68,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: Size.square(size * .68), painter: const _WaPainter()),
          Padding(
            padding: EdgeInsets.only(bottom: size * .04),
            child: Icon(Icons.phone, color: Colors.white, size: size * .27),
          ),
        ]),
      );
    } else if (kind == 'ya') {
      glyph = Text('Я', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * .48));
    } else if (kind == 'max') {
      glyph = Text('MAX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * .27, letterSpacing: -.3));
    } else {
      glyph = Text('VK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .4));
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * .3)),
      child: glyph,
    );
  }
}

const List<String> kReportReasons = [
  'Мошенничество или просят предоплату',
  'Спам или реклама',
  'Неверная информация / чужой номер',
  'Грубость или оскорбления',
  'Запрещённые товары или услуги',
];

Future<void> showReportSheet(BuildContext context, {required String id, String label = 'объявление'}) async {
  final p = pal(context);
  String picked = kReportReasons.first;
  final ctl = TextEditingController();
  final res = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Пожаловаться на $label', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: p.tx)),
            const SizedBox(height: 6),
            Text('Выберите причину или опишите ситуацию — модератор проверит обращение.',
                style: TextStyle(color: p.mu, fontSize: 13.5)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in kReportReasons)
                Tap(
                  onTap: () => setS(() => picked = r),
                  scale: .96,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: picked == r ? p.ac.withOpacity(.15) : p.bg2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: picked == r ? p.ac : p.bd, width: picked == r ? 1.4 : 1),
                    ),
                    child: Text(r, style: TextStyle(color: picked == r ? p.ac : p.tx, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              contextMenuBuilder: appContextMenu,
              controller: ctl,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              style: TextStyle(color: p.tx),
              decoration: deco(c, 'Комментарий (необязательно)'),
            ),
            const SizedBox(height: 4),
            GradBtn('Отправить жалобу', onTap: () {
              final extra = ctl.text.trim();
              Navigator.pop(c, extra.isEmpty ? picked : '$picked: $extra');
            }),
          ]),
        ),
      ),
    ),
  );
  if (res == null || res.isEmpty || !context.mounted) return;
  try {
    await S.i.reportItem(id, res);
    if (context.mounted) toast(context, 'Спасибо! Жалоба отправлена на проверку');
  } catch (e) {
    if (context.mounted) toast(context, S.i.fail(e), err: true);
  }
}

Future<void> toggleUserBlock(BuildContext context, {required String pid, required String name}) async {
  if (pid.isEmpty) return;
  final blocked = S.i.isBlocked(pid);
  final p = pal(context);
  if (!blocked) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: p.card,
        title: Text('Заблокировать ${name.isEmpty ? 'пользователя' : name}?', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800)),
        content: Text(
          'Вы больше не будете видеть объявления этого пользователя, а он не сможет писать вам в чат и откликаться.',
          style: TextStyle(color: p.mu, height: 1.35),
        ),
        actions: [
          TextButton(onPressed: () { haptic(); Navigator.pop(c, false); }, child: Text('Отмена', style: TextStyle(color: p.mu))),
          TextButton(
            onPressed: () { haptic(); Navigator.pop(c, true); },
            child: Text('Заблокировать', style: TextStyle(color: p.dng, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
  }
  try {
    await S.i.setBlocked(pid, name, !blocked);
    if (context.mounted) {
      toast(context, !blocked ? 'Пользователь добавлен в чёрный список' : 'Пользователь разблокирован');
    }
  } catch (e) {
    if (context.mounted) toast(context, S.i.fail(e), err: true);
  }
}

// Самолётик Telegram
class _TgPainter extends CustomPainter {
  const _TgPainter();
  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / 24;
    final body = Path()
      ..moveTo(20.2 * k, 4.7 * k)
      ..lineTo(3.6 * k, 11.2 * k)
      ..lineTo(8.2 * k, 13.1 * k)
      ..lineTo(9.9 * k, 18.9 * k)
      ..lineTo(12.9 * k, 15.7 * k)
      ..lineTo(17.1 * k, 18.9 * k)
      ..close();
    canvas.drawPath(body, Paint()..color = Colors.white);
    canvas.drawLine(
      Offset(8.2 * k, 13.1 * k),
      Offset(16.2 * k, 8.2 * k),
      Paint()
        ..color = const Color(0xFF229ED9)
        ..strokeWidth = .9 * k
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Кольцо с хвостиком WhatsApp (трубка рисуется поверх иконкой)
class _WaPainter extends CustomPainter {
  const _WaPainter();
  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / 24;
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * k;
    canvas.drawCircle(Offset(12 * k, 11.4 * k), 7.4 * k, ring);
    final tail = Path()
      ..moveTo(5.2 * k, 15.4 * k)
      ..lineTo(3.8 * k, 20.6 * k)
      ..lineTo(9.4 * k, 18.4 * k)
      ..close();
    canvas.drawPath(tail, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Значок «Позвонить» в цветах приложения
class CallBadge extends StatelessWidget {
  final double size;
  const CallBadge({super.key, this.size = 30});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(Icons.call_rounded, color: Colors.white, size: size * .58),
    );
  }
}

class ChatBadge extends StatelessWidget {
  final double size;
  const ChatBadge({super.key, this.size = 30});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: size * .55),
    );
  }
}

// ---------- Выбор из списка в стиле приложения ----------
class PickItem {
  final String value;
  final String label;
  const PickItem(this.value, this.label);
}

Future<String?> showPickerSheet(BuildContext context,
    {required String title, required List<PickItem> items, required String selected}) {
  final p = pal(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  // Поверхность чуть светлее и «подкрашена» акцентом, чтобы не сливаться с фоном
  final surface = Color.alphaBlend(p.ac.withOpacity(dark ? .12 : .05), p.card);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.6),
    builder: (c) {
      final h = MediaQuery.sizeOf(c).height;
      return Container(
        constraints: BoxConstraints(maxHeight: h * .72),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: p.ac.withOpacity(.4), width: 1.2),
          boxShadow: [BoxShadow(color: p.ac.withOpacity(.22), blurRadius: 32, offset: const Offset(0, -6))],
        ),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: p.mu.withOpacity(.45), borderRadius: BorderRadius.circular(99)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: p.tx)),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                children: [
                  for (final it in items) _pickRow(p, it, it.value == selected, () => Navigator.pop(c, it.value)),
                ],
              ),
            ),
          ]),
        ),
      );
    },
  );
}

Widget _pickRow(Pal p, PickItem it, bool sel, VoidCallback onTap) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Tap(
      onTap: onTap,
      scale: .985,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: sel ? p.ac.withOpacity(.16) : p.bg.withOpacity(.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? p.ac : p.bd, width: sel ? 1.4 : 1),
        ),
        child: Row(children: [
          Expanded(
            child: Text(it.label,
                style: TextStyle(fontSize: 15.5, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: p.tx)),
          ),
          const SizedBox(width: 10),
          sel
              ? Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [p.ac, p.ac2]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                )
              : Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd, width: 1.5)),
                ),
        ]),
      ),
    ),
  );
}

class PickerField extends StatelessWidget {
  final String label;
  final String value;
  final List<PickItem> items;
  final ValueChanged<String> onChanged;
  final String? sheetTitle;
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.sheetTitle,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    var shown = '';
    for (final it in items) {
      if (it.value == value) shown = it.label;
    }
    return Tap(
      scale: .99,
      onTap: () async {
        final v = await showPickerSheet(context,
            title: sheetTitle ?? (label.isEmpty ? 'Выберите' : label), items: items, selected: value);
        if (v != null) onChanged(v);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.bd),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (label.isNotEmpty)
                Text(label, style: TextStyle(fontSize: 12, color: p.mu, fontWeight: FontWeight.w600)),
              Text(shown,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: p.tx, fontWeight: FontWeight.w600)),
            ]),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, color: p.ac, size: 26),
        ]),
      ),
    );
  }
}


/// Нижний отступ для прокручиваемых списков на вкладках: при прозрачной панели
/// контент идёт под неё, поэтому последний элемент нужно приподнять над панелью.
double navPad(BuildContext c) => 80 + MediaQuery.of(c).viewPadding.bottom;


/// Поле города с подсказками из списка городов России: «Пер» → Первоуральск, Пермь…
/// Подсказки раскрываются прямо под полем (не поверх клавиатуры).
class CityField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onPicked;
  final ValueChanged<String>? onSubmitted;
  const CityField({super.key, required this.controller, this.decoration, this.onChanged, this.onPicked, this.onSubmitted});
  @override
  State<CityField> createState() => _CityFieldState();
}

class _CityFieldState extends State<CityField> {
  final FocusNode _f = FocusNode();
  List<String> _s = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_upd);
    _f.addListener(_upd);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_upd);
    _f.dispose();
    super.dispose();
  }

  void _upd() {
    if (!mounted) return;
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _upd());
      return;
    }
    final next = _f.hasFocus ? citySuggest(widget.controller.text) : const <String>[];
    var same = next.length == _s.length;
    for (var i = 0; same && i < next.length; i++) {
      if (next[i] != _s[i]) same = false;
    }
    if (!same) setState(() => _s = next);
  }

  void _pick(String c) {
    haptic();
    widget.controller.value = TextEditingValue(text: c, selection: TextSelection.collapsed(offset: c.length));
    widget.onChanged?.call(c);
    widget.onPicked?.call(c);
    _f.unfocus();
    setState(() => _s = const []);
  }

  Widget _name(Pal p, String name) {
    final q = widget.controller.text.trim();
    final n = name.toLowerCase().replaceAll('ё', 'е');
    final qn = q.toLowerCase().replaceAll('ё', 'е');
    final base = TextStyle(fontSize: 15, color: p.tx);
    if (qn.isNotEmpty && n.startsWith(qn) && qn.length <= name.length) {
      return Text.rich(TextSpan(children: [
        TextSpan(text: name.substring(0, qn.length), style: base.copyWith(fontWeight: FontWeight.w800, color: p.ac)),
        TextSpan(text: name.substring(qn.length), style: base),
      ]));
    }
    return Text(name, style: base);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(contextMenuBuilder: appContextMenu, 
        controller: widget.controller,
        focusNode: _f,
        textCapitalization: TextCapitalization.words,
        style: TextStyle(color: p.tx),
        decoration: widget.decoration ?? deco(context, null, hint: 'Начните вводить город'),
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.topCenter,
        child: _s.isEmpty
            ? const SizedBox(width: double.infinity)
            : Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 6),
                decoration: cardDeco(p, r: 16),
                child: Column(children: [
                  for (var i = 0; i < _s.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: p.bd),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _pick(_s[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          Icon(Icons.location_city_rounded, size: 18, color: p.mu),
                          const SizedBox(width: 10),
                          Expanded(child: _name(p, _s[i])),
                        ]),
                      ),
                    ),
                  ],
                ]),
              ),
      ),
    ]);
  }
}


/// Меню выделения текста (вырезать, копировать…) в стиле приложения:
/// карточка с акцентной обводкой вместо стандартной тёмной плашки.
Widget appContextMenu(BuildContext context, EditableTextState state) {
  final p = pal(context);
  final a = state.contextMenuAnchors;
  final items = state.contextMenuButtonItems;
  if (items.isEmpty) return const SizedBox.shrink();
  return TextSelectionToolbar(
    anchorAbove: a.primaryAnchor,
    anchorBelow: a.secondaryAnchor ?? a.primaryAnchor,
    toolbarBuilder: (c, child) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.bd),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.22), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: IconTheme(data: IconThemeData(color: p.tx), child: child),
      ),
    ),
    children: [
      for (final it in items)
        TextSelectionToolbarTextButton(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          onPressed: () {
            haptic();
            it.onPressed?.call();
          },
          child: Text(
            AdaptiveTextSelectionToolbar.getButtonLabel(context, it),
            style: TextStyle(color: p.tx, fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
    ],
  );
}

// Пункт выпадающего меню: значок и подпись (как на сайте)
Widget menuRow(BuildContext context, IconData icon, String text) {
  final p = pal(context);
  return Row(children: [Icon(icon, size: 20, color: p.ac), const SizedBox(width: 12), Text(text)]);
}
