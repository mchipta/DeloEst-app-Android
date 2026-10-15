import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

String imgUrl(String id, int w) => 'https://lh3.googleusercontent.com/d/$id=w$w';

void toast(BuildContext c, String m) {
  final sm = ScaffoldMessenger.maybeOf(c);
  if (sm == null) return;
  sm.hideCurrentSnackBar();
  sm.showSnackBar(SnackBar(content: Text(m)));
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
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [p.ac, p.ac2]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: busy ? null : onTap,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                      Text(text,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ]),
            ),
          ),
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
    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.bd),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, color: col, size: 20), const SizedBox(width: 8)],
            Text(text, style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
        ),
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
  const AdCard({super.key, required this.ad, required this.onTap, this.footer});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(p),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _thumb(p),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  typeTag(context, ad.type),
                  CatChip(ad.category),
                ]),
                const SizedBox(height: 6),
                Text(ad.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.tx, height: 1.25)),
                const SizedBox(height: 4),
                Text(payF(ad.pay), style: TextStyle(fontWeight: FontWeight.w800, color: p.ok, fontSize: 15)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.place_outlined, size: 14, color: p.mu),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(ad.city.isEmpty ? 'Город не указан' : ad.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: p.mu)),
                  ),
                ]),
                Text(ago(ad.ts), style: TextStyle(fontSize: 12.5, color: p.mu)),
              ]),
            ),
          ]),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ]),
      ),
    );
  }

  Widget _thumb(Pal p) {
    Widget ph() => Container(
          color: p.bg2,
          alignment: Alignment.center,
          child: Icon(catIcon(ad.category), size: 36, color: p.mu),
        );
    return SizedBox(
      width: 112,
      height: 112,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(fit: StackFit.expand, children: [
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
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.photo_camera_outlined, size: 12, color: Colors.white),
                  const SizedBox(width: 3),
                  Text('${ad.imgs.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
