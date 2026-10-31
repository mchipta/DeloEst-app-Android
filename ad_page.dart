import 'dart:ui' show ImageFilter;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'icons.dart';
import 'auth.dart';
import 'map_page.dart';
import 'messages.dart';
import 'models.dart';
import 'near.dart';
import 'profile.dart';
import 'share.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

class AdPage extends StatefulWidget {
  final Ad ad;
  const AdPage({super.key, required this.ad});
  @override
  State<AdPage> createState() => _AdPageState();
}

class _AdPageState extends State<AdPage> {
  int page = 0;
  late Ad ad;
  String _av = ''; // аватарка автора: в списке объявлений её нет, берём из профиля
  bool _replied = false;
  final GlobalKey _menuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    ad = widget.ad;
    Api.call('seen', {'id': ad.id, 'cid': S.i.cid}).then((_) {}, onError: (_) {});
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final pid = ad.pid;
    if (pid.isEmpty) return;
    final c = S.avatarCache[pid];
    if (c != null) {
      _av = c;
      return;
    }
    try {
      final j = await Api.call('profile', {'pid': pid});
      final av = (j['avatar'] ?? '').toString();
      S.avatarCache[pid] = av;
      if (mounted && av.isNotEmpty) setState(() => _av = av);
    } catch (_) {}
  }

  String _phone() {
    if (!S.i.logged) return ''; // контакты только для вошедших
    if (ad.phone.isNotEmpty) return ad.phone;
    for (final a in S.i.ads) {
      if (a.id == ad.id) return a.phone;
    }
    return '';
  }

  Future<void> _call(String ph) async {
    Api.call('view', {'id': ad.id}).then((_) {}, onError: (_) {});
    final digits = ph.replaceAll(RegExp(r'[^\d+]'), '');
    try {
      await launchUrl(Uri(scheme: 'tel', path: digits));
    } catch (_) {
      if (mounted) toast(context, 'Не удалось открыть набор номера');
    }
  }

  Future<void> _login() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage()));
  }

  Future<void> _write() async {
    if (!S.i.logged) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage()));
      if (!mounted || !S.i.logged) return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPage(pid: ad.pid, name: ad.author, ver: ad.ver, adId: ad.id)),
    );
  }

  Future<void> _report() async {
    if (!S.i.logged) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage()));
      if (!mounted || !S.i.logged) return;
    }
    await showReportSheet(context, id: ad.id, label: 'объявление');
  }

  Future<void> _openMoreMenu(Pal p, bool mine) async {
    haptic();
    final ctx = _menuKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final pos = (box != null && overlay != null)
        ? RelativeRect.fromRect(
            Rect.fromPoints(
              box.localToGlobal(Offset(0, box.size.height + 6), ancestor: overlay),
              box.localToGlobal(box.size.bottomRight(const Offset(0, 6)), ancestor: overlay),
            ),
            Offset.zero & overlay.size,
          )
        : const RelativeRect.fromLTRB(100, 80, 14, 0);
    final v = await showMenu<String>(
      context: context,
      position: pos,
      color: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.bd)),
      items: [
        PopupMenuItem(value: 'share', child: menuRow(context, Icons.send_outlined, 'Поделиться')),
        if (!mine) PopupMenuItem(value: 'report', child: menuRow(context, Icons.warning_amber_rounded, 'Пожаловаться')),
      ],
    );
    if (!mounted || v == null) return;
    haptic();
    if (v == 'report') _report();
    if (v == 'share') showShare(context, ad);
  }

  Future<void> _reply() async {
    if (!S.i.logged) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage()));
      if (!mounted || !S.i.logged) return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pal(context).card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => _ReplySheet(adId: ad.id),
    );
    if (ok == true && mounted) {
      setState(() => _replied = true);
      toast(context, 'Отклик отправлен — автор увидит ваш номер телефона');
    }
  }

  // Круглая полупрозрачная кнопка с размытием фона (поверх фото/обложки объявления)
  Widget _glassBtn(Pal p, {Key? key, required VoidCallback onTap, required Widget child, String? tooltip}) {
    final btn = Tap(
      key: key,
      onTap: onTap,
      scale: .9,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.card.withOpacity(.68),
              shape: BoxShape.circle,
              border: Border.all(color: p.bd.withOpacity(.85), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.14), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: child,
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        final p = pal(context);
        final dark = Theme.of(context).brightness == Brightness.dark;
        final mine = S.i.logged && S.i.pid.isNotEmpty && S.i.pid == ad.pid;
        final ph = _phone();
        final topPad = MediaQuery.paddingOf(context).top;
        final botPad = MediaQuery.paddingOf(context).bottom;
        final barWidget = _bar(p, mine, ph);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          ),
          child: Scaffold(
            extendBody: true,
            extendBodyBehindAppBar: true,
            bottomNavigationBar: barWidget,
            body: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.only(top: 0, bottom: 28 + (barWidget != null ? 82 + botPad : 16 + botPad)),
                  children: [
                    _gallery(p, topPad),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          typeTag(context, ad.type),
                          CatChip(ad.category),
                          if (ad.status == 'closed') Tag('Закрыто', p.mu),
                        ]),
                        const SizedBox(height: 10),
                        Text(ad.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.tx, height: 1.2)),
                        const SizedBox(height: 6),
                        PriceTag(ad.pay, size: 22),
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.place_outlined, size: 16, color: p.mu),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(adLoc(ad).isEmpty ? 'Город не указан' : adLoc(ad),
                                  style: TextStyle(color: p.mu, fontSize: 14))),
                          if (Near.i.dist(ad) != null)
                            Text('  ·  ${Near.i.dist(ad)!.label}', style: TextStyle(color: p.ac, fontSize: 14, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 2),
                        Row(children: [
                          Text(siteDateTime(ad.ts, S.i.timeZone), style: TextStyle(color: p.mu, fontSize: 13)),
                          if (ad.opens > 0) ...[
                            Text('  ·  ', style: TextStyle(color: p.mu, fontSize: 13)),
                            Icon(Icons.visibility_outlined, size: 16, color: p.mu),
                            const SizedBox(width: 4),
                            Text('${ad.opens}', style: TextStyle(color: p.mu, fontSize: 13)),
                          ],
                        ]),
                        const SizedBox(height: 16),
                        Text('Описание', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.tx)),
                        const SizedBox(height: 6),
                        Text(ad.desc, style: TextStyle(fontSize: 15, height: 1.45, color: p.tx)),
                        Appear(delay: 120, child: AdMiniMap(ad: ad)),
                        const SizedBox(height: 18),
                        Tap(
                          onTap: () => Navigator.push(
                              context, MaterialPageRoute(builder: (_) => ProfilePage(pid: ad.pid, name: ad.author))),
                          scale: .98,
                          child: _author(p),
                        ),
                        const SizedBox(height: 18),
                        if (mine)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: cardDeco(p),
                            child: Text('Это ваше объявление. Управлять им и откликами можно в кабинете.',
                                style: TextStyle(color: p.mu)),
                          )
                        else if (ad.status == 'closed')
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: cardDeco(p),
                            child: Text('Объявление закрыто автором', style: TextStyle(color: p.mu)),
                          )
                        else if (!S.i.logged)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: cardDeco(p),
                            child: Column(children: [
                              Icon(Icons.lock_outline_rounded, color: p.ac, size: 30),
                              const SizedBox(height: 8),
                              Text('Контакты скрыты', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.tx)),
                              const SizedBox(height: 4),
                              Text('Войдите, чтобы увидеть телефон автора, написать ему и откликнуться на объявление.',
                                  textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 13.5, height: 1.35)),
                              const SizedBox(height: 14),
                              GradBtn('Войти', icon: Icons.login_rounded, onTap: _login),
                            ]),
                          ),
                      ]),
                    ),
                  ],
                ),
                // Плавающие заблюренные кнопки поверх фото/обложки: Назад слева, Сердечко и Ещё справа
                Positioned(
                  top: topPad + 8,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      _glassBtn(
                        p,
                        tooltip: 'Назад',
                        onTap: () => Navigator.maybePop(context),
                        child: Icon(Icons.arrow_back_rounded, size: 22, color: p.tx),
                      ),
                      const Spacer(),
                      ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.card.withOpacity(.68),
                              shape: BoxShape.circle,
                              border: Border.all(color: p.bd.withOpacity(.85), width: 1),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.14), blurRadius: 10, offset: const Offset(0, 3))],
                            ),
                            child: FavHeart(
                              adId: ad.id,
                              size: 21,
                              inactiveColor: p.tx,
                              onGuestTap: _login,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _glassBtn(
                        p,
                        key: _menuKey,
                        tooltip: 'Ещё',
                        onTap: () => _openMoreMenu(p, mine),
                        child: Icon(Icons.more_vert_rounded, size: 22, color: p.tx),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Плавающая прозрачная панель-«таблетка» снизу (как главное меню): только кнопки чата, звонка и «Откликнуться»
  Widget? _bar(Pal p, bool mine, String ph) {
    if (mine || ad.status == 'closed' || !S.i.logged) return null;
    final glass = S.i.navTransparent;
    final pill = Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: glass ? p.card.withOpacity(.74) : p.card,
        borderRadius: BorderRadius.circular(31),
        border: Border.all(color: p.bd),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.14), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        _sq(p, 'chat', _write, tooltip: 'Написать'),
        if (ph.isNotEmpty) ...[
          const SizedBox(width: 8),
          _sq(p, 'phone', () => _call(ph), tooltip: 'Позвонить'),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: GradBtn(
            _replied ? 'Вы откликнулись' : 'Откликнуться',
            ico: _replied ? 'check' : 'sendr',
            radius: 23,
            onTap: _replied ? null : _reply,
          ),
        ),
      ]),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        child: glass
            ? ClipRRect(
                borderRadius: BorderRadius.circular(31),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: pill,
                ),
              )
            : pill,
      ),
    );
  }

  // Круглая контурная кнопка-иконка в плавающей таблетке
  Widget _sq(Pal p, String ico, VoidCallback onTap, {String? tooltip}) {
    final btn = Tap(
      onTap: onTap,
      scale: .92,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.ac.withOpacity(.10),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: p.ac, width: 1.5),
        ),
        child: Ico(ico, size: 21, color: p.ac),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  Widget _author(Pal p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(p),
      child: Row(children: [
        Avatar(ad.author, data: _av),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(ad.author.isEmpty ? 'Пользователь' : ad.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.tx)),
              ),
            ]),
            if (ad.ver) const Padding(padding: EdgeInsets.only(top: 3, bottom: 2), child: VerifiedBadge(size: 17, label: true)),
            const SizedBox(height: 2),
            if (ad.rc > 0)
              Row(children: [
                const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFB400)),
                const SizedBox(width: 3),
                Text('${ad.rt} · ${ad.rc} ${plural(ad.rc, 'отзыв', 'отзыва', 'отзывов')}',
                    style: TextStyle(color: p.mu, fontSize: 13)),
              ])
            else
              Text('Пока нет отзывов', style: TextStyle(color: p.mu, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  Widget _gallery(Pal p, double topPad) {
    if (ad.imgs.isEmpty) {
      return Container(
        height: 196 + topPad,
        padding: EdgeInsets.only(top: topPad * .45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.bg2,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(R.l)),
        ),
        child: Icon(catIcon(ad.category), size: 66, color: p.mu),
      );
    }
    return Column(children: [
      ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(R.l)),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 220 + topPad),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: PageView.builder(
              itemCount: ad.imgs.length,
              onPageChanged: (i) {
                haptic();
                setState(() => page = i);
              },
              itemBuilder: (c, i) => GestureDetector(
                onTap: () {
                  haptic();
                  Navigator.push(c, MaterialPageRoute(builder: (_) => PhotoViewer(ids: ad.imgs, index: i)));
                },
                child: CachedNetworkImage(
                  imageUrl: imgUrl(ad.imgs[i], 1000),
                  fit: BoxFit.cover,
                  placeholder: (c, u) => Container(color: p.bg2),
                  errorWidget: (c, u, e) => Container(color: p.bg2, child: Icon(Icons.broken_image_outlined, color: p.mu)),
                ),
              ),
            ),
          ),
        ),
      ),
      if (ad.imgs.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < ad.imgs.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == page ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == page ? p.ac : p.bd,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ]),
        ),
    ]);
  }
}

class PhotoViewer extends StatelessWidget {
  final List<String> ids;
  final int index;
  const PhotoViewer({super.key, required this.ids, required this.index});
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: index),
            itemCount: ids.length,
            itemBuilder: (c, i) => InteractiveViewer(
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: imgUrl(ids[i], 1600),
                  fit: BoxFit.contain,
                  placeholder: (c, u) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorWidget: (c, u, e) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + 8,
            left: 14,
            child: Tap(
              onTap: () => Navigator.maybePop(context),
              scale: .9,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.16),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplySheet extends StatefulWidget {
  final String adId;
  const _ReplySheet({required this.adId});
  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _msg = TextEditingController();
  final List<String> _tpls = ['Могу сегодня', 'Свой транспорт', 'Есть опыт'];
  bool busy = false;
  String? err;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  void _addTpl(String t) {
    final v = _msg.text.trim();
    final next = '${v.isEmpty ? '' : '$v '}$t.';
    if (next.length > 300) return;
    setState(() {
      _msg.text = next;
      _msg.selection = TextSelection.collapsed(offset: next.length);
      _tpls.remove(t);
    });
  }

  Future<void> _send() async {
    setState(() {
      busy = true;
      err = null;
    });
    try {
      await Api.call('reply', {'id': widget.adId, 'msg': _msg.text.trim()});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final m = S.i.fail(e);
      if (m == 'Вы уже откликались') {
        if (mounted) Navigator.pop(context, true);
        return;
      }
      if (mounted) setState(() => err = m);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 18, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Отклик на объявление',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.tx)),
        const SizedBox(height: 8),
        Text('Напишите пару слов о себе', textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 13.5)),
        const SizedBox(height: 12),
        TextField(
          contextMenuBuilder: appContextMenu,
          controller: _msg,
          maxLines: 4,
          minLines: 3,
          maxLength: 300,
          style: TextStyle(color: p.tx),
          decoration: deco(context, null, hint: 'Опыт, когда можете приехать').copyWith(counterText: ''),
        ),
        if (_tpls.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in _tpls)
              Tap(
                onTap: () => _addTpl(t),
                scale: .96,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.ac.withOpacity(.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: p.ac.withOpacity(.35)),
                  ),
                  child: Text(t, style: TextStyle(color: p.tx, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
          ]),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.phone_outlined, size: 15, color: p.mu),
          const SizedBox(width: 6),
          Expanded(child: Text('Автор увидит ваш номер телефона', style: TextStyle(color: p.mu, fontSize: 13.5))),
        ]),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: TextStyle(color: p.dng))),
        const SizedBox(height: 12),
        GradBtn('Отправить отклик', busy: busy, onTap: _send),
        const SizedBox(height: 8),
        OutBtn('Отмена', color: p.mu, onTap: () => Navigator.pop(context)),
      ]),
    );
  }
}
