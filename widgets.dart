import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';

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
          height: 46,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [p.ac, p.ac2]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: p.ac.withOpacity(.16), blurRadius: 12, offset: const Offset(0, 4))],
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
        height: 46,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(14),
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
    final width = MediaQuery.sizeOf(context).width;
    final thumb = width >= 600 ? 112.0 : 92.0;
    return Appear(
      child: Tap(
        onTap: onTap,
        scale: .99,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: cardDeco(p, r: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: thumb, height: thumb, child: _cover(p, thumb)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          typeTag(context, ad.type),
                          _categoryTag(p, ad.category),
                        ],
                      ),
                    ),
                    if (showFav && S.i.logged) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => S.i.toggleFav(ad.id),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 3, top: 1),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutBack,
                            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                            child: Icon(
                              S.i.isFav(ad.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              key: ValueKey(S.i.isFav(ad.id)),
                              color: S.i.isFav(ad.id) ? p.ac : p.mu,
                              size: 21,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  Text(ad.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.18, color: p.tx)),
                  const SizedBox(height: 4),
                  Text(payF(ad.pay),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.ok)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(Icons.place_outlined, size: 13, color: p.mu),
                      Text(ad.city.isEmpty ? 'Город не указан' : ad.city,
                          style: TextStyle(fontSize: 12, color: p.mu), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('· ${siteDateTime(ad.ts, S.i.timeZone)}', style: TextStyle(fontSize: 12, color: p.mu)),
                      Icon(Icons.visibility_outlined, size: 13, color: p.mu),
                      Text('${ad.opens}', style: TextStyle(fontSize: 12, color: p.mu)),
                    ],
                  ),
                  if (ad.desc.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(ad.desc.trim(), maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, height: 1.25, color: p.mu)),
                  ],
                ]),
              ),
            ]),
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ]),
        ),
      ),
    );
  }

  Widget _categoryTag(Pal p, String category) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: p.bg2,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: p.bd),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(catIcon(category), size: 12, color: p.mu),
        const SizedBox(width: 3),
        Flexible(child: Text(category, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: p.mu, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _cover(Pal p, double size) {
    Widget ph() => Container(
          decoration: BoxDecoration(
            color: Color.alphaBlend(p.ac.withOpacity(.07), p.bg2),
            border: Border.all(color: p.bd),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(catIcon(ad.category), size: size * .35, color: p.ac.withOpacity(.75)),
        );
    return ClipRRect(
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
      ]),
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
  final String kind; // tg, wa или vk
  final double size;
  const BrandIcon(this.kind, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final Color bg = kind == 'tg'
        ? const Color(0xFF229ED9)
        : kind == 'wa'
            ? const Color(0xFF25D366)
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
          borderRadius: BorderRadius.circular(14),
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
          borderRadius: BorderRadius.circular(14),
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
