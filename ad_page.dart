import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'auth.dart';
import 'messages.dart';
import 'models.dart';
import 'profile.dart';
import 'settings.dart';
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

  Future<void> _openSocial(String kind, String phone) async {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('8')) digits = '7${digits.substring(1)}';
    const message = 'Здравствуйте, я с ДелоЕсть по вашему объявлению';
    await Clipboard.setData(const ClipboardData(text: message));
    final uri = kind == 'wa'
        ? Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}')
        : Uri.parse('https://t.me/+${digits}?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) toast(context, 'Текст скопирован — можно отправить его в чате');
    } catch (_) {
      if (mounted) toast(context, 'Текст скопирован. Не удалось открыть приложение');
    }
  }

  Future<void> _report() async {
    final r = await askFields(context, 'Пожаловаться', [const FieldSpec('Что не так с объявлением?', multi: true)],
        ok: 'Отправить');
    if (r == null || r[0].isEmpty) return;
    try {
      await Api.call('report', {'id': ad.id, 'reason': r[0]});
      if (mounted) toast(context, 'Спасибо, мы проверим объявление');
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e));
    }
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => _ReplySheet(adId: ad.id),
    );
    if (ok == true && mounted) toast(context, 'Отклик отправлен — автор увидит ваш номер телефона');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        final p = pal(context);
        final mine = S.i.logged && S.i.pid.isNotEmpty && S.i.pid == ad.pid;
        final ph = _phone();
        return Scaffold(
          appBar: AppBar(title: const Text('Объявление'), actions: [
            if (S.i.logged)
              IconButton(
                icon: Icon(S.i.isFav(ad.id) ? Icons.favorite : Icons.favorite_border, color: S.i.isFav(ad.id) ? p.ac : null),
                onPressed: () => S.i.toggleFav(ad.id),
              ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'report') _report();
                if (v == 'share') showShare(context, ad);
              },
              itemBuilder: (c) => [
                const PopupMenuItem(value: 'share', child: Text('Поделиться')),
                if (S.i.logged && !mine) const PopupMenuItem(value: 'report', child: Text('Пожаловаться')),
              ],
            ),
          ]),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            _gallery(p),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              typeTag(context, ad.type),
              CatChip(ad.category),
              if (ad.status == 'closed') Tag('Закрыто', p.mu),
            ]),
            const SizedBox(height: 10),
            Text(ad.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.tx, height: 1.2)),
            const SizedBox(height: 6),
            Text(payF(ad.pay), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.ok)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.place_outlined, size: 16, color: p.mu),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(ad.city.isEmpty ? 'Город не указан' : ad.city,
                      style: TextStyle(color: p.mu, fontSize: 14))),
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
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => ProfilePage(pid: ad.pid, name: ad.author))),
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
              )
            else ...[
              GradBtn('Откликнуться', icon: Icons.send_rounded, onTap: _reply),
              const SizedBox(height: 10),
              OutBtn('Написать автору', icon: Icons.chat_bubble_outline, onTap: _write),
              if (ph.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  _contactBtn(p, const CallBadge(), 'Позвонить', () => _call(ph)),
                  const SizedBox(width: 8),
                  _contactBtn(p, const BrandIcon('wa', size: 30), 'WhatsApp', () => _openSocial('wa', ph)),
                  const SizedBox(width: 8),
                  _contactBtn(p, const BrandIcon('tg', size: 30), 'Telegram', () => _openSocial('tg', ph)),
                ]),
              ],
            ],
          ]),
        );
      },
    );
  }

  Widget _contactBtn(Pal p, Widget icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Tap(
        onTap: onTap,
        scale: .96,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.bd),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            icon,
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, style: TextStyle(color: p.tx, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
          ]),
        ),
      ),
    );
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

  Widget _gallery(Pal p) {
    if (ad.imgs.isEmpty) {
      return Container(
        height: 190,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(18)),
        child: Icon(catIcon(ad.category), size: 64, color: p.mu),
      );
    }
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: PageView.builder(
            itemCount: ad.imgs.length,
            onPageChanged: (i) => setState(() => page = i),
            itemBuilder: (c, i) => GestureDetector(
              onTap: () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => PhotoViewer(ids: ad.imgs, index: i))),
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
      if (ad.imgs.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < ad.imgs.length; i++)
              Container(
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: PageView.builder(
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
  bool busy = false;
  String? err;

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
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 18, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Отклик на объявление', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.tx)),
        const SizedBox(height: 4),
        Text('Автор увидит ваше имя и номер телефона', style: TextStyle(color: p.mu, fontSize: 13.5)),
        const SizedBox(height: 14),
        TextField(contextMenuBuilder: appContextMenu, 
          controller: _msg,
          maxLines: 4,
          minLines: 3,
          maxLength: 500,
          style: TextStyle(color: p.tx),
          decoration: deco(context, 'Сообщение', hint: 'Например: могу сегодня после 18:00'),
        ),
        if (err != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(err!, style: TextStyle(color: p.dng))),
        GradBtn('Отправить отклик', busy: busy, onTap: _send),
      ]),
    );
  }
}
