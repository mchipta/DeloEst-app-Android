import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';

String imgUrl(String id, int w) => 'https://lh3.googleusercontent.com/d/$id=w$w';

void toast(BuildContext c, String m) {
  final sm = ScaffoldMessenger.maybeOf(c);
  if (sm == null) return;
  sm.hideCurrentSnackBar();
  sm.showSnackBar(SnackBar(content: Text(m)));
}

/// Нажатие с лёгким «вдавливанием» (для кнопок и карточек)
class Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Tap({super.key, required this.child, this.onTap, this.scale = .97});
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
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
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
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
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
  final bool busy;
  const GradBtn(this.text, {super.key, this.onTap, this.icon, this.busy = false});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Opacity(
      opacity: (onTap == null && !busy) ? .5 : 1,
      child: Tap(
        onTap: busy ? null : onTap,
        scale: .96,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [p.ac, p.ac2]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: p.ac.withOpacity(.35), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: busy
              ? const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(icon, color: Colors.white, size: 21), const SizedBox(width: 8)],
                  Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
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
  const OutBtn(this.text, {super.key, this.onTap, this.icon, this.color});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final col = color ?? p.tx;
    return Tap(
      onTap: onTap,
      scale: .96,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.bd, width: 1.2),
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
    final p = pal(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: p.bg2,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: p.bd),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
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
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    ImageProvider? img;
    if (data.startsWith('data:image')) {
      try {
        img = MemoryImage(base64Decode(data.substring(data.indexOf(',') + 1)));
      } catch (_) {
        img = null;
      }
    }
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
  const AdCard({super.key, required this.ad, required this.onTap, this.footer, this.showFav = true});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Appear(
      child: Tap(
        onTap: onTap,
        scale: .975,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: cardDeco(p, r: 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _cover(p),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  typeTag(context, ad.type),
                  CatChip(ad.category),
                ]),
                const SizedBox(height: 10),
                Text(ad.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.tx, height: 1.25)),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.place_outlined, size: 15, color: p.mu),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(ad.city.isEmpty ? 'Город не указан' : ad.city,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.mu)),
                  ),
                  Text('  ·  ${ago(ad.ts)}', style: TextStyle(fontSize: 13, color: p.mu)),
                ]),
                if (footer != null) ...[const SizedBox(height: 14), footer!],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _cover(Pal p) {
    Widget ph() => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [p.ac.withOpacity(.16), p.ac2.withOpacity(.16)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(catIcon(ad.category), size: 56, color: p.ac.withOpacity(.6)),
        );
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(fit: StackFit.expand, children: [
          ad.imgs.isEmpty
              ? ph()
              : CachedNetworkImage(
                  imageUrl: imgUrl(ad.imgs[0], 700),
                  fit: BoxFit.cover,
                  placeholder: (c, u) => Container(color: p.bg2),
                  errorWidget: (c, u, e) => ph(),
                ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [Colors.black.withOpacity(.45), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [p.ac, p.ac2]),
                borderRadius: BorderRadius.circular(99),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Text(payF(ad.pay),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
          if (ad.imgs.length > 1)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.photo_camera_outlined, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('${ad.imgs.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          if (showFav && S.i.logged)
            Positioned(
              right: 12,
              top: 12,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => S.i.toggleFav(ad.id),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.92), shape: BoxShape.circle),
                  child: Icon(S.i.isFav(ad.id) ? Icons.favorite : Icons.favorite_border,
                      size: 22, color: S.i.isFav(ad.id) ? p.ac : const Color(0xFF6B6480)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}


void showVerifiedInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (c) {
      final p = pal(c);
      return AlertDialog(
        backgroundColor: p.card,
        icon: Icon(Icons.verified, color: p.ok, size: 44),
        title: Text('Проверенный пользователь', textAlign: TextAlign.center, style: TextStyle(color: p.tx, fontWeight: FontWeight.w800)),
        content: Text(
            'Администрация ДелоЕсть проверила документы этого человека и подтвердила его личность. Это снижает риск мошенничества, но деньги заранее всё равно лучше не переводить.',
            style: TextStyle(color: p.mu, height: 1.4)),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text('Понятно', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800)))],
      );
    },
  );
}

// Значок «проверенный»: по нажатию объясняет, что это значит (в профиле и в объявлении)
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified, size: size, color: p.ok),
        if (label) ...[
          const SizedBox(width: 5),
          Text('Проверенный', style: TextStyle(color: p.ok, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ]),
    );
  }
}

class BrandIcon extends StatelessWidget {
  final String kind; // tg или vk
  final double size;
  const BrandIcon(this.kind, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final tg = kind == 'tg';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tg ? const Color(0xFF229ED9) : const Color(0xFF0077FF),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: tg
          ? Icon(Icons.send_rounded, color: Colors.white, size: size * .55)
          : Text('VK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .4)),
    );
  }
}
