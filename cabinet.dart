import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ad_page.dart';
import 'admin.dart';
import 'api.dart';
import 'icons.dart';
import 'auth.dart';
import 'messages.dart';
import 'models.dart';
import 'post.dart';
import 'profile.dart';
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
  String ct = 'ads'; // ads, in, out, rev, set
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
      if (mounted) toast(context, S.i.fail(e), err: true);
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
        return Scaffold(
          appBar: AppBar(
            title: Text(S.i.logged ? 'Кабинет' : 'Профиль'),
            actions: S.i.logged ? [
              IconButton(
                tooltip: 'Настройки приложения',
                onPressed: () { haptic(); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())); },
                icon: Icon(Icons.settings_outlined, color: pal(context).ac),
              ),
            ] : null,
          ),
          body: S.i.logged
              ? RefreshIndicator(
                  color: p.ac,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + navPad(context)),
                    children: [
                      Appear(child: _header(p)),
                      ..._alerts(p),
                      Appear(delay: 70, child: _chips(p)),
                      const SizedBox(height: 12),
                      if (ct != 'set' && loading && data == null)
                        Padding(padding: const EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: p.ac))),
                      if (ct != 'set' && err != null && data == null)
                        Padding(padding: const EdgeInsets.all(24), child: Text(err!, textAlign: TextAlign.center, style: TextStyle(color: p.mu))),
                      if (data != null || ct == 'set') SmoothSwitch(child: KeyedSubtree(key: ValueKey('$ct-$caf-${loading && data == null}'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _content(p)))),
                    ],
                  ),
                )
              : ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + navPad(context)), children: [
                  SizedBox(height: 360, child: const NeedAuth(icon: Icons.person_outline, title: 'Ваш кабинет', text: 'Войдите, чтобы видеть свои объявления, отклики и управлять ими.')),
                  const BottomLinks(support: true),
                ]),
        );
      },
    );
  }

  Widget _header(Pal p) {
    final av = (S.i.user?['avatar'] ?? '').toString();
    final isMail = S.i.login.contains('@');
    final mail = isMail ? S.i.login : '@${S.i.login}';

    Widget contact(IconData icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: p.ac),
          const SizedBox(width: 7),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.tx, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ]);

    void openProfile() => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(pid: S.i.pid, name: S.i.name)));
    void openEdit() => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditPage()));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.bd),
        boxShadow: [BoxShadow(color: p.ac.withOpacity(.10), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          GestureDetector(
            onTap: openEdit,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, color: p.card),
                child: Avatar(S.i.name, data: av, size: 62),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(S.i.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: p.tx, height: 1.15)),
              const SizedBox(height: 6),
              contact(isMail ? Icons.mail_outline : Icons.person_outline, mail),
              if (S.i.phone.isNotEmpty) ...[
                const SizedBox(height: 4),
                contact(Icons.call_outlined, fmtPhone(S.i.phone)),
              ],
            ]),
          ),
          IconButton(
            tooltip: 'Изменить профиль',
            onPressed: openEdit,
            icon: Icon(Icons.edit_outlined, color: p.tx),
            style: IconButton.styleFrom(
              backgroundColor: p.bg2,
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: Tap(
              onTap: openProfile,
              scale: .97,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: p.ac.withOpacity(.30), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_outline_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Мой профиль', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () { haptic(); confirmLogout(context); },
              icon: const Icon(Icons.logout_rounded, size: 17),
              label: const Text('Выйти'),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.tx,
                backgroundColor: p.bg2,
                side: BorderSide(color: p.bd, width: 1),
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
        ]),
        if (S.i.user?['admin'] == true) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () { haptic(); Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPage())); },
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: const Text('Админ-панель'),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.tx,
              backgroundColor: p.bg2,
              side: BorderSide(color: p.bd, width: 1),
              minimumSize: const Size(0, 42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
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

  int get _unans => _list('reviews').where((r) => (r['reply'] ?? '').toString().isEmpty).length;

  Future<void> _answer(Map<String, dynamic> r) async {
    final res = await askFields(
      context,
      'Ответ на отзыв',
      [FieldSpec('Ваш ответ', initial: (r['reply'] ?? '').toString(), multi: true)],
      ok: 'Опубликовать',
      hint: 'Ответ увидят все, кто откроет ваш профиль.',
    );
    if (res == null || !mounted) return;
    final v = res[0].trim();
    if (v.isEmpty) {
      toast(context, 'Напишите ответ');
      return;
    }
    await _act('rrep', {'id': r['id'], 'text': v}, 'Ответ опубликован');
  }

  List<Widget> _reviews(Pal p) {
    final list = _list('reviews');
    if (list.isEmpty) return [_empty(p, 'Отзывов о вас пока нет. Они появятся здесь после выполненной работы.')];
    return [
      for (final r in list)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text((r['name'] ?? '').toString(), style: TextStyle(fontWeight: FontWeight.w800, color: p.tx))),
              Text(ago((r['ts'] as num?)?.toInt() ?? 0), style: TextStyle(color: p.mu, fontSize: 12)),
            ]),
            const SizedBox(height: 3),
            StarsRow(((r['rating'] as num?) ?? 0).toDouble(), size: 16),
            if ((r['text'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text((r['text']).toString(), style: TextStyle(color: p.tx, height: 1.35)),
            ],
            if ((r['reply'] ?? '').toString().isNotEmpty) replyBox(p, 'Ваш ответ', (r['reply']).toString(), ts: (r['rts'] as num?)?.toInt() ?? 0),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if ((r['reply'] ?? '').toString().isEmpty)
                _small(p, 'Ответить', () => _answer(r), fill: true, icon: Icons.reply_rounded)
              else ...[
                _small(p, 'Изменить', () => _answer(r), ico: 'edit'),
                _small(p, 'Удалить ответ', () => _act('rrep', {'id': r['id'], 'text': ''}, 'Ответ удалён'), color: p.dng, ico: 'trash'),
              ],
            ]),
          ]),
        ),
    ];
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
              borderRadius: BorderRadius.circular(12),
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
    return out;
  }

  Widget _chips(Pal p) {
    final pend = _pend;
    final tabs = <List<Object>>[
      ['ads', 'Мои объявления', 'work'],
      ['in', 'Отклики мне', 'bolt'],
      ['out', 'Мои отклики', 'send'],
      ['rev', 'Отзывы', 'star'],
    ];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: p.bd)),
      child: Row(children: [
        for (final t in tabs)
          Expanded(
            child: GestureDetector(
              onTap: () {
                haptic();
                setState(() => ct = t[0] as String);
                _markSeen();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                constraints: const BoxConstraints(minHeight: 66),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                decoration: BoxDecoration(
                  gradient: ct == t[0] ? LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: ct == t[0] ? [BoxShadow(color: p.ac.withOpacity(.32), blurRadius: 12, offset: const Offset(0, 4))] : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Ico(t[2] as String, size: 21, color: ct == t[0] ? Colors.white : p.mu),
                    if ((t[0] == 'in' ? pend : (t[0] == 'rev' ? _unans : 0)) > 0)
                      Positioned(right: -10, top: -7, child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: ct == t[0] ? Colors.white : p.ac, borderRadius: BorderRadius.circular(99)),
                        child: Text('${t[0] == 'in' ? pend : _unans}', style: TextStyle(color: ct == t[0] ? p.ac : Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                      )),
                  ]),
                  const SizedBox(height: 5),
                  Text(t[1] as String, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10.5, height: 1.05, color: ct == t[0] ? Colors.white : p.mu)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  List<Widget> _content(Pal p) {
    switch (ct) {
      case 'in':
        return _inbox(p);
      case 'out':
        return _sent(p);
      case 'rev':
        return _reviews(p);
      case 'set':
        return [];
      default:
        return _myAds(p);
    }
  }

  Widget _empty(Pal p, String text) => Padding(
        padding: const EdgeInsets.all(28),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 15)),
      );

  Widget _small(Pal p, String text, VoidCallback f, {Color? color, bool fill = false, IconData? icon, String? ico}) {
    final c = color ?? p.tx;
    return Tap(
      onTap: f,
      scale: .96,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: fill ? LinearGradient(colors: [p.ac, p.ac2]) : null,
          color: fill ? null : p.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fill ? Colors.transparent : p.bd),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (ico != null) ...[Ico(ico, size: 17, color: fill ? Colors.white : c), const SizedBox(width: 6)]
          else if (icon != null) ...[Icon(icon, size: 17, color: fill ? Colors.white : c), const SizedBox(width: 6)],
          Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: fill ? Colors.white : c)),
        ]),
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
          onTap: () { haptic(); setState(() => caf = key); },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
        Expanded(child: f('all', 'Все', all.length)),
        Expanded(child: f('open', 'Активные', open)),
        Expanded(child: f('closed', 'Снятые', all.length - open)),
      ]));
      items.add(const SizedBox(height: 12));
    }
    if (shown.isEmpty) {
      items.add(_empty(p, all.isEmpty
          ? 'У вас пока нет объявлений. Нажмите «Разместить» в нижнем меню, чтобы опубликовать первое.'
          : 'В этой группе ничего нет'));
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
            if (isOpen) _small(p, 'Открыть', ico: 'box', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: ad)))),
            _small(p, 'Изменить', ico: 'edit', () async {
              final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => PostScreen(edit: ad, embedded: false)));
              if (r == true) _load();
            }),
            if (!hidden)
              _small(p, isOpen ? 'Снять' : 'Опубликовать', ico: isOpen ? 'eyeoff' : 'pub', color: isOpen ? p.dng : p.ok, () => _act('status', {'id': ad.id, 's': isOpen ? 'closed' : 'open'}, isOpen ? 'Объявление снято' : 'Объявление снова опубликовано')),
            if (isOpen) _small(p, 'Поделиться', ico: 'share', () => showShare(context, ad)),
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
                Text('${(r['ad'] ?? '').toString()} · ${siteDateTime(((r['ts'] as num?) ?? 0).toInt(), S.i.timeZone)}',
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
              _small(p, 'Удалить', ico: 'trash', color: p.dng, () => _act('rdel', {'rid': rid}, 'Отклик удалён'))
            else ...[
              if ((r['pid'] ?? '').toString().isNotEmpty) _small(p, 'Написать', ico: 'chat', () => _chat((r['pid']).toString(), (r['name'] ?? '').toString(), adId: adId)),
              if (st == 'chosen')
                _small(p, 'Работа выполнена', () => _act('fin', {'rid': rid}, 'Отмечено как выполнено'), fill: true, ico: 'check')
              else if (st != 'done')
                _small(p, 'Выбрать исполнителем', ico: 'check', () => _act('pick', {'rid': rid}, 'Исполнитель выбран')),
              if (st != 'done') _small(p, 'Отклонить', () => _act('rej', {'rid': rid}, 'Отклик отклонён'), color: p.dng, ico: 'x'),
            ],
            if (adObj != null) _small(p, 'Объявление', ico: 'box', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: adObj)))),
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
      final title = (r['ad'] ?? '').toString().trim();
      final city = (r['city'] ?? '').toString().trim();
      final msg = (r['msg'] ?? '').toString().trim();
      final pid = (r['pid'] ?? '').toString();
      final label = st == 'chosen' ? 'Вас выбрали' : st == 'done' ? 'Выполнено' : st == 'rejected' ? 'Отклонён' : 'Ждёт ответа';
      final col = (st == 'chosen' || st == 'done') ? p.ok : st == 'rejected' ? p.mu : p.ac;
      final canWrite = pid.isNotEmpty && title.isNotEmpty;
      void open() => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: found!)));
      items.add(Tap(
        onTap: found == null ? null : open,
        scale: .99,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(p, r: R.m),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _statePill(label, col),
              const Spacer(),
              Text(siteDateTime(((r['ts'] as num?) ?? 0).toInt(), S.i.timeZone), style: TextStyle(color: p.mu, fontSize: 12.5)),
            ]),
            const SizedBox(height: 12),
            Text(title.isEmpty ? 'Объявление удалено' : title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, height: 1.25, color: title.isEmpty ? p.mu : p.tx)),
            if (payF((r['pay'] ?? '').toString()).isNotEmpty || city.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                PriceTag((r['pay'] ?? '').toString(), size: 15, dense: true),
                if (city.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Ico('pin', size: 14, color: p.mu),
                    const SizedBox(width: 4),
                    Text(city, style: TextStyle(color: p.mu, fontSize: 13.5)),
                  ]),
              ]),
            ],
            if (msg.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: const BorderRadius.only(topRight: Radius.circular(R.s), bottomRight: Radius.circular(R.s)),
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(width: 3, color: p.ac),
                    Expanded(
                      child: Container(
                        color: p.bg2,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(msg, style: TextStyle(color: p.tx, fontSize: 14.5, height: 1.35)),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
            if (canWrite || found != null) ...[
              const SizedBox(height: 14),
              Row(children: [
                if (canWrite) Expanded(child: _wide(p, 'Написать автору', 'chat', () => _chat(pid, '', adId: adId))),
                if (canWrite && found != null) const SizedBox(width: 8),
                if (found != null) Expanded(child: _wide(p, 'Объявление', 'box', open)),
              ]),
            ],
          ]),
        ),
      ));
    }
    return items;
  }

  // Статус отклика: тонкая обводка цвета статуса (как .st2 на сайте)
  Widget _statePill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: c.withOpacity(.10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: c.withOpacity(.30)),
        ),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
      );

  // Кнопка на всю ширину половины ряда (как .acts .btn на сайте)
  Widget _wide(Pal p, String text, String ico, VoidCallback f) => Tap(
        onTap: f,
        scale: .97,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(R.s), border: Border.all(color: p.bd)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Ico(ico, size: 17, color: p.tx),
              const SizedBox(width: 7),
              Text(text, maxLines: 1, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: p.tx)),
            ]),
          ),
        ),
      );
}
