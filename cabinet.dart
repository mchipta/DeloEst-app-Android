import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ad_page.dart';
import 'api.dart';
import 'auth.dart';
import 'messages.dart';
import 'models.dart';
import 'post.dart';
import 'settings.dart';
import 'share.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

// Кабинет — одна прокручиваемая страница, как на сайте: шапка, вкладки-чипы, содержимое, внизу «О сервисе» и «О приложении»
class CabinetPage extends StatefulWidget {
  const CabinetPage({super.key});
  @override
  State<CabinetPage> createState() => _CabinetPageState();
}

class _CabinetPageState extends State<CabinetPage> {
  Map<String, dynamic>? data;
  bool loading = false;
  String? err;
  int _tick = -1;
  String ct = 'ads'; // ads, in, out, set
  String caf = 'all'; // all, open, closed
  final Set<String> _fresh = {};

  @override
  void initState() {
    super.initState();
    S.i.addListener(_onState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onState());
  }

  @override
  void dispose() {
    S.i.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (!mounted) return;
    if (!S.i.logged) {
      if (data != null) setState(() => data = null);
      _tick = -1;
      return;
    }
    if (S.i.cabTick != _tick) {
      _tick = S.i.cabTick;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final j = await Api.call('mine');
      if (mounted) setState(() => data = j);
      _markSeen();
    } catch (e) {
      final m = S.i.fail(e);
      if (mounted) setState(() => err = m);
    }
    if (mounted) setState(() => loading = false);
  }

  void _markSeen() {
    if (ct != 'in') return;
    var any = false;
    for (final r in _list('inbox')) {
      if ((r['st'] ?? '').toString().isEmpty) {
        _fresh.add((r['rid'] ?? '').toString());
        any = true;
      }
    }
    if (any) Api.call('rseen').then((_) {}, onError: (_) {});
  }

  Future<void> _act(String a, Map<String, dynamic> d, String okMsg) async {
    try {
      await Api.call(a, d);
      if (mounted) toast(context, okMsg);
      if (a == 'status') S.i.loadAds();
      await _load();
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e));
    }
  }

  List<Map<String, dynamic>> _list(String k) {
    final v = data == null ? null : data![k];
    if (v is! List) return [];
    return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _call(String ph) async {
    final digits = ph.replaceAll(RegExp(r'[^\d+]'), '');
    try {
      await launchUrl(Uri(scheme: 'tel', path: digits));
    } catch (_) {
      if (mounted) toast(context, 'Не удалось открыть набор номера');
    }
  }

  void _chat(String pid, String name, {String adId = ''}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(pid: pid, name: name, adId: adId)));
  }

  Ad? _adById(String id) {
    for (final a in S.i.ads) {
      if (a.id == id) return a;
    }
    for (final m in _list('ads')) {
      if ((m['id'] ?? '').toString() == id) return Ad.fromJson(m);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        final p = pal(context);
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          appBar: AppBar(title: Text(S.i.logged ? 'Кабинет' : 'Профиль'), actions: [
            IconButton(
              tooltip: 'Тема',
              icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              onPressed: () => S.i.setTheme(dark ? ThemeMode.light : ThemeMode.dark),
            ),
          ]),
          body: S.i.logged
              ? RefreshIndicator(
                  color: p.ac,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _header(p),
                      ..._alerts(p),
                      _chips(p),
                      const SizedBox(height: 12),
                      if (loading && data == null)
                        Padding(padding: const EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: p.ac))),
                      if (err != null && data == null)
                        Padding(padding: const EdgeInsets.all(24), child: Text(err!, textAlign: TextAlign.center, style: TextStyle(color: p.mu))),
                      if (data != null || ct == 'set') ..._content(p),
                      const BottomLinks(),
                    ],
                  ),
                )
              : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
                  SizedBox(height: 360, child: const NeedAuth(icon: Icons.person_outline, title: 'Ваш кабинет', text: 'Войдите, чтобы видеть свои объявления, отклики и управлять ими.')),
                  const BottomLinks(),
                ]),
        );
      },
    );
  }

  Widget _header(Pal p) {
    final av = (S.i.user?['avatar'] ?? '').toString();
    final mail = S.i.login.contains('@') ? S.i.login : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(p),
      child: Row(children: [
        Avatar(S.i.name, data: av, size: 60),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(S.i.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: p.tx)),
            if (mail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(children: [
                  Icon(Icons.mail_outline, size: 15, color: p.mu),
                  const SizedBox(width: 5),
                  Expanded(child: Text(mail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontSize: 13.5))),
                ]),
              ),
            if (S.i.phone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(children: [
                  Icon(Icons.call_outlined, size: 15, color: p.mu),
                  const SizedBox(width: 5),
                  Text(fmtPhone(S.i.phone), style: TextStyle(color: p.mu, fontSize: 13.5)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  int get _pend {
    final ads = _list('ads');
    var n = 0;
    for (final r in _list('inbox')) {
      if ((r['st'] ?? '').toString().isNotEmpty) continue;
      final id = (r['adId'] ?? '').toString();
      if (ads.any((a) => (a['id'] ?? '').toString() == id && a['status'] == 'open')) n++;
    }
    return n;
  }

  List<Widget> _alerts(Pal p) {
    final out = <Widget>[];
    Widget al(int n, String text, VoidCallback f) => GestureDetector(
          onTap: f,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [p.ac.withOpacity(.14), p.ac2.withOpacity(.14)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.ac.withOpacity(.4)),
            ),
            child: Row(children: [
              Text('$n', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: p.ac)),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: p.tx))),
              Icon(Icons.chevron_right, color: p.mu),
            ]),
          ),
        );
    final pend = _pend;
    if (pend > 0) {
      out.add(al(pend, plural(pend, 'новый отклик', 'новых отклика', 'новых откликов'), () {
        setState(() => ct = 'in');
        _markSeen();
      }));
    }
    if (S.i.unread > 0) {
      out.add(al(S.i.unread, plural(S.i.unread, 'непрочитанное сообщение', 'непрочитанных сообщения', 'непрочитанных сообщений'),
          () => S.i.goTab(2)));
    }
    return out;
  }

  Widget _chips(Pal p) {
    final pend = _pend;
    Widget chip(String key, String label, IconData ic, {int badge = 0}) {
      final on = ct == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () {
            setState(() => ct = key);
            _markSeen();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: on ? LinearGradient(colors: [p.ac, p.ac2]) : null,
              color: on ? null : p.card,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: on ? Colors.transparent : p.bd),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ic, size: 17, color: on ? Colors.white : p.mu),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: on ? Colors.white : p.tx)),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: on ? Colors.white : p.ac, borderRadius: BorderRadius.circular(99)),
                  child: Text('$badge', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: on ? p.ac : Colors.white)),
                ),
              ],
            ]),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        chip('ads', 'Объявления', Icons.inventory_2_outlined),
        chip('in', 'Отклики мне', Icons.bolt_outlined, badge: pend),
        chip('out', 'Мои отклики', Icons.send_outlined),
        chip('set', 'Настройки', Icons.settings_outlined),
      ]),
    );
  }

  List<Widget> _content(Pal p) {
    switch (ct) {
      case 'in':
        return _inbox(p);
      case 'out':
        return _sent(p);
      case 'set':
        return const [SettingsBody()];
      default:
        return _myAds(p);
    }
  }

  Widget _empty(Pal p, String text) => Padding(
        padding: const EdgeInsets.all(28),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 15)),
      );

  Widget _small(Pal p, String text, VoidCallback f, {Color? color, bool fill = false}) {
    final c = color ?? p.tx;
    return GestureDetector(
      onTap: f,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: fill ? LinearGradient(colors: [p.ac, p.ac2]) : null,
          color: fill ? null : p.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fill ? Colors.transparent : p.bd),
        ),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: fill ? Colors.white : c)),
      ),
    );
  }

  List<Widget> _myAds(Pal p) {
    final all = _list('ads');
    final open = all.where((a) => a['status'] == 'open').length;
    final shown = all.where((a) => caf == 'all' ? true : caf == 'open' ? a['status'] == 'open' : a['status'] != 'open').toList();
    Widget f(String key, String label, int n) {
      final on = caf == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => caf = key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: on ? p.ac.withOpacity(.14) : p.card,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: on ? p.ac : p.bd),
            ),
            child: Text('$label  $n', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: on ? p.ac : p.tx)),
          ),
        ),
      );
    }

    final items = <Widget>[];
    if (all.isNotEmpty) {
      items.add(Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [f('all', 'Все', all.length), f('open', 'Активные', open), f('closed', 'Снятые', all.length - open)]),
          ),
        ),
        _small(p, '+ Новое', () => S.i.goTab(1), fill: true),
      ]));
      items.add(const SizedBox(height: 12));
    }
    if (shown.isEmpty) {
      items.add(_empty(p, all.isEmpty ? 'У вас пока нет объявлений' : 'В этой группе ничего нет'));
      if (all.isEmpty) items.add(Center(child: SizedBox(width: 260, child: GradBtn('Разместить объявление', icon: Icons.add, onTap: () => S.i.goTab(1)))));
    }
    for (final m in shown) {
      final ad = Ad.fromJson(m);
      final isOpen = ad.status == 'open';
      final hidden = ad.status == 'hidden';
      items.add(AdCard(
        ad: ad,
        showFav: false,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: ad))),
        footer: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Tag(hidden ? 'Скрыто' : isOpen ? 'Активно' : 'Снято', hidden ? p.dng : isOpen ? p.ok : p.mu),
            const SizedBox(width: 10),
            Icon(Icons.visibility_outlined, size: 15, color: p.mu),
            const SizedBox(width: 4),
            Text('${ad.opens}', style: TextStyle(color: p.mu, fontSize: 13)),
            Text('  ·  телефон открывали: ${ad.views}', style: TextStyle(color: p.mu, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (isOpen) _small(p, 'Открыть', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: ad)))),
            _small(p, 'Изменить', () async {
              final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => PostScreen(edit: ad, embedded: false)));
              if (r == true) _load();
            }),
            if (!hidden)
              _small(p, isOpen ? 'Снять' : 'Опубликовать', () => _act('status', {'id': ad.id, 's': isOpen ? 'closed' : 'open'}, isOpen ? 'Объявление снято' : 'Объявление снова опубликовано')),
            if (isOpen) _small(p, 'Поделиться', () => showShare(context, ad)),
          ]),
        ]),
      ));
    }
    return items;
  }

  List<Widget> _inbox(Pal p) {
    final rows = _list('inbox');
    rows.sort((a, b) {
      final fa = _fresh.contains((a['rid'] ?? '').toString()), fb = _fresh.contains((b['rid'] ?? '').toString());
      if (fa != fb) return fa ? -1 : 1;
      return ((b['ts'] as num?) ?? 0).compareTo((a['ts'] as num?) ?? 0);
    });
    if (rows.isEmpty) return [_empty(p, 'Откликов пока нет. Они появятся здесь, когда кто-то ответит на ваше объявление')];
    final items = <Widget>[];
    for (final r in rows) {
      final st = (r['st'] ?? '').toString();
      final rid = (r['rid'] ?? '').toString();
      final ph = (r['phone'] ?? '').toString();
      final msg = (r['msg'] ?? '').toString();
      final adId = (r['adId'] ?? '').toString();
      final fresh = _fresh.contains(rid);
      final adObj = _adById(adId);
      items.add(Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(p).copyWith(border: Border.all(color: fresh ? p.ac : p.bd, width: fresh ? 1.6 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar((r['name'] ?? '').toString(), size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((r['name'] ?? '').toString(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: p.tx)),
                Text('${(r['ad'] ?? '').toString()} · ${ago(((r['ts'] as num?) ?? 0).toInt())}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontSize: 12.5)),
              ]),
            ),
            if (fresh) Tag('новый', p.ac) else if (st == 'chosen') Tag('Исполнитель', p.ok) else if (st == 'done') Tag('Выполнено', p.ok) else if (st == 'rejected') Tag('Отклонён', p.mu),
          ]),
          if (st != 'rejected' && ph.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _call(ph),
              child: Row(children: [
                Icon(Icons.call_outlined, size: 17, color: p.ac),
                const SizedBox(width: 6),
                Text(fmtPhone(ph), style: TextStyle(color: p.ac, fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
          if (msg.isNotEmpty) ...[const SizedBox(height: 8), Text(msg, style: TextStyle(color: p.tx, height: 1.35))],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (st == 'rejected')
              _small(p, 'Удалить', () => _act('rdel', {'rid': rid}, 'Отклик удалён'))
            else ...[
              if ((r['pid'] ?? '').toString().isNotEmpty) _small(p, 'Написать', () => _chat((r['pid']).toString(), (r['name'] ?? '').toString(), adId: adId)),
              if (st == 'chosen')
                _small(p, 'Работа выполнена', () => _act('fin', {'rid': rid}, 'Отмечено как выполнено'), fill: true)
              else if (st != 'done')
                _small(p, 'Выбрать исполнителем', () => _act('pick', {'rid': rid}, 'Исполнитель выбран')),
              if (st != 'done') _small(p, 'Отклонить', () => _act('rej', {'rid': rid}, 'Отклик отклонён'), color: p.dng),
            ],
            if (adObj != null) _small(p, 'Объявление', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: adObj)))),
          ]),
        ]),
      ));
    }
    return items;
  }

  List<Widget> _sent(Pal p) {
    final rows = _list('sent').reversed.toList();
    if (rows.isEmpty) return [_empty(p, 'Вы пока ни на что не откликались')];
    final items = <Widget>[];
    for (final r in rows) {
      final st = (r['st'] ?? '').toString();
      final adId = (r['adId'] ?? '').toString();
      final found = _adById(adId);
      final label = st == 'chosen' ? 'Вас выбрали исполнителем' : st == 'done' ? 'Выполнено' : st == 'rejected' ? 'Отклонён' : 'ждёт ответа';
      final col = (st == 'chosen' || st == 'done') ? p.ok : st == 'rejected' ? p.mu : p.ac;
      final meta = [payF((r['pay'] ?? '').toString()), (r['city'] ?? '').toString()].where((e) => e.isNotEmpty).join(' · ');
      items.add(GestureDetector(
        onTap: found == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: found))),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: cardDeco(p),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text((r['ad'] ?? 'Объявление удалено').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: p.tx))),
              const SizedBox(width: 8),
              Tag(label, col),
            ]),
            const SizedBox(height: 4),
            Text('${meta.isEmpty ? '' : '$meta · '}отклик ${ago(((r['ts'] as num?) ?? 0).toInt())}', style: TextStyle(color: p.mu, fontSize: 13)),
            if ((r['msg'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Вы: ${r['msg']}', style: TextStyle(color: p.tx, height: 1.35)),
            ],
            if ((r['pid'] ?? '').toString().isNotEmpty && (r['ad'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                _small(p, 'Написать автору', () => _chat((r['pid']).toString(), '', adId: adId)),
                if (found != null) _small(p, 'Объявление', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: found)))),
              ]),
            ],
          ]),
        ),
      ));
    }
    return items;
  }
}
