import 'package:cached_network_image/cached_network_image.dart';
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
import 'review.dart';
import 'settings.dart';
import 'share.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

// Кабинет — одна прокручиваемая страница, как на сайте: шапка, вкладки-чипы, содержимое, внизу «О сервисе» и «О приложении»
// mode: 'profile' — «Профиль» (шапка, рейтинг, отзывы, ссылки), 'ads' — «Объявления» (мои объявления и отклики, как в Авито)
class CabinetPage extends StatefulWidget {
  final String mode;
  const CabinetPage({super.key, this.mode = 'profile'});
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

  bool get _adsMode => widget.mode == 'ads';

  @override
  void initState() {
    super.initState();
    ct = _adsMode ? 'ads' : 'rev';
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
    // данные грузит только та вкладка, которая сейчас открыта (сервер и так медленный)
    if (S.i.tab != (_adsMode ? 6 : 3)) return;
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

  // Удаление своего объявления: спрашиваем, потому что вернуть его уже нельзя
  Future<void> _confirmDelete(Ad ad) async {
    final p = pal(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: p.card,
        title: Text('Удалить объявление?', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800)),
        content: Text('«${ad.title}» исчезнет навсегда. Вернуть его будет нельзя.', style: TextStyle(color: p.mu, height: 1.35)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Отмена', style: TextStyle(color: p.mu))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Удалить', style: TextStyle(color: p.dng, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok == true) await _act('del', {'id': ad.id}, 'Объявление удалено');
  }

  Future<bool> _act(String a, Map<String, dynamic> d, String okMsg) async {
    try {
      await Api.call(a, d);
      if (mounted) toast(context, okMsg);
      if (a == 'status' || a == 'del' || a == 'bump' || a == 'urgent' || a == 'renew') S.i.loadAds();
      await _load();
      return true;
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e), err: true);
      return false;
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
        if (_adsMode) return _buildAds(p);
        return Scaffold(
          appBar: AppBar(
            title: Text(S.i.logged ? 'Профиль' : 'Войти'),
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
                      Appear(delay: 70, child: _ratingRow(p)),
                      if (data != null) ...[const SizedBox(height: 12), Appear(delay: 100, child: _stats(p))],
                      if (data != null) ...[const SizedBox(height: 12), Appear(delay: 130, child: _fill(p))],
                      const SizedBox(height: 18),
                      Text('Отзывы обо мне', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: p.tx)),
                      const SizedBox(height: 10),
                      if (loading && data == null)
                        Padding(padding: const EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: p.ac))),
                      if (err != null && data == null)
                        Padding(padding: const EdgeInsets.all(24), child: Text(err!, textAlign: TextAlign.center, style: TextStyle(color: p.mu))),
                      if (data != null) ..._reviews(p),
                    ],
                  ),
                )
              : ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + navPad(context)), children: [
                  SizedBox(height: 360, child: const NeedAuth(icon: Icons.person_outline, title: 'Ваш профиль', text: 'Войдите, чтобы видеть свои объявления, отклики и управлять ими.')),
                  const BottomLinks(support: true),
                ]),
        );
      },
    );
  }

  // Вкладка «Объявления»: мои объявления, отклики мне, мои отклики + кнопка «Разместить объявление»
  Widget _buildAds(Pal p) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои объявления'), centerTitle: true),
      body: !S.i.logged
          ? const NeedAuth(icon: Icons.add_box_outlined, title: 'Мои объявления', text: 'Войдите, чтобы размещать объявления и видеть отклики на них.')
          : Stack(children: [
              RefreshIndicator(
                color: p.ac,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 120 + navPad(context)),
                  children: [
                    ..._alerts(p),
                    Appear(child: _chips(p)),
                    const SizedBox(height: 14),
                    if (loading && data == null)
                      Padding(padding: const EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: p.ac))),
                    if (err != null && data == null)
                      Padding(padding: const EdgeInsets.all(24), child: Text(err!, textAlign: TextAlign.center, style: TextStyle(color: p.mu))),
                    if (data != null)
                      SmoothSwitch(child: KeyedSubtree(key: ValueKey('$ct-$caf'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _content(p)))),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: navPad(context) + 16,
                // отдельный слой: кнопка закреплена и не перерисовывается при смене вкладок списка
                child: RepaintBoundary(child: GradBtn('Разместить объявление', icon: Icons.add_rounded, radius: 18, onTap: () { haptic(); S.i.goTab(2); })),
              ),
            ]),
    );
  }

  // Рейтинг и число отзывов — две плитки, как в Авито
  Widget _ratingRow(Pal p) {
    final rs = _list('reviews');
    var avg = 0.0;
    if (rs.isNotEmpty) {
      var sum = 0.0;
      for (final r in rs) {
        sum += ((r['rating'] as num?) ?? 0).toDouble();
      }
      avg = sum / rs.length;
    }
    final ads = _list('ads');
    final open = ads.where((a) => a['status'] == 'open').length;
    Widget box(Widget top, String sub, VoidCallback? f) => Expanded(
          child: Tap(
            onTap: f ?? () {},
            scale: .98,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.bd)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                top,
                const SizedBox(height: 4),
                Text(sub, style: TextStyle(color: p.mu, fontSize: 13)),
              ]),
            ),
          ),
        );
    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      box(
        Row(children: [
          Text(rs.isEmpty ? '—' : avg.toStringAsFixed(1).replaceAll('.', ','), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: p.tx)),
          const SizedBox(width: 6),
          Icon(Icons.star_rounded, color: const Color(0xFFFFB300), size: 24),
        ]),
        rs.isEmpty ? 'Отзывов пока нет' : '${rs.length} ${plural(rs.length, 'отзыв', 'отзыва', 'отзывов')}',
        null,
      ),
      const SizedBox(width: 10),
      box(
        Text('$open', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: p.tx)),
        'объявлений',
        () { haptic(); S.i.goTab(6); },
      ),
    ]));
  }

  // Заполненность профиля: что ещё добавить, чтобы вам доверяли
  Widget _fill(Pal p) {
    final av = (S.i.user?['avatar'] ?? '').toString();
    final items = <List<Object>>[
      ['Имя', S.i.name.trim().isNotEmpty],
      ['Фото', av.isNotEmpty],
      ['Телефон', S.i.phone.isNotEmpty],
      ['Первое объявление', _list('ads').isNotEmpty],
    ];
    final done = items.where((e) => e[1] == true).length;
    final miss = items.where((e) => e[1] != true).map((e) => e[0] as String).toList();
    if (miss.isEmpty) return const SizedBox.shrink();
    return Tap(
      onTap: () {
        haptic();
        if (miss.first == 'Первое объявление') {
          S.i.goTab(2);
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditPage()));
        }
      },
      scale: .98,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.bd)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Профиль заполнен на ${done * 100 ~/ items.length}%', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800, fontSize: 15))),
            Icon(Icons.chevron_right_rounded, color: p.mu),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: done / items.length, minHeight: 7, backgroundColor: p.bg2, valueColor: AlwaysStoppedAnimation(p.ac)),
          ),
          const SizedBox(height: 8),
          Text('Добавьте: ${miss.join(', ').toLowerCase()}', style: TextStyle(color: p.mu, fontSize: 13)),
        ]),
      ),
    );
  }

  // Статистика: просмотры, отклики, выполненные работы, срок на сервисе
  Widget _stats(Pal p) {
    final st = data?['stats'] is Map ? Map<String, dynamic>.from(data!['stats'] as Map) : <String, dynamic>{};
    int n(String k) => (st[k] as num?)?.toInt() ?? 0;
    Widget tile(IconData ic, Color c, int v, String l) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.bd)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: c.withOpacity(.16), borderRadius: BorderRadius.circular(11)),
                child: Icon(ic, size: 18, color: c),
              ),
              const SizedBox(height: 10),
              Text('$v', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: p.tx, height: 1.1)),
              const SizedBox(height: 2),
              Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontSize: 12.5)),
            ]),
          ),
        );
    return Column(children: [
      Row(children: [
        tile(Icons.visibility_outlined, p.ac, n('views'), 'просмотров'),
        const SizedBox(width: 10),
        tile(Icons.mark_chat_unread_outlined, const Color(0xFF4C8DFF), n('resp'), 'откликов'),
        const SizedBox(width: 10),
        tile(Icons.task_alt_rounded, p.ok, n('done'), 'выполнено'),
      ]),
      if (n('since') > 0) ...[
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.event_available_outlined, size: 16, color: p.mu),
          const SizedBox(width: 6),
          Text(sinceLabel(n('since')), style: TextStyle(color: p.mu, fontSize: 13)),
        ]),
      ],
    ]);
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
        // «Выйти» перенесено вниз настроек; здесь только просмотр публичного профиля
        Tap(
          onTap: openProfile,
          scale: .98,
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
              Text('Публичный профиль', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
            ]),
          ),
        ),
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
    final tabs = <List<String>>[
      ['ads', 'Мои объявления'],
      ['in', 'Отклики мне'],
      ['out', 'Мои отклики'],
    ];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final t in tabs)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                haptic();
                setState(() => ct = t[0]);
                _markSeen();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 22),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: ct == t[0] ? p.tx : Colors.transparent, width: 2.5))),
                alignment: Alignment.center,
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: t[1], style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ct == t[0] ? p.tx : p.mu)),
                  if (t[0] == 'in' && pend > 0)
                    TextSpan(text: '  $pend', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: p.ac)),
                ])),
              ),
            ),
        ],
      ),
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
      items.add(all.isEmpty
          ? EmptyState(
              icon: Icons.campaign_outlined,
              title: 'Объявлений пока нет',
              text: 'Опубликуйте первое — это бесплатно и без комиссии.',
              button: 'Разместить объявление',
              onTap: () => S.i.goTab(2))
          : _empty(p, 'В этой группе ничего нет'));
    }
    for (final m in shown) {
      final ad = Ad.fromJson(m);
      final isOpen = ad.status == 'open';
      items.add(AdCard(
        ad: ad,
        showFav: false,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: ad))),
        footer: OwnerPanel(
          ad: ad,
          onEdit: () async {
            final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => PostScreen(edit: ad, embedded: false)));
            if (r == true) _load();
          },
          onToggle: () => _act('status', {'id': ad.id, 's': isOpen ? 'closed' : 'open'}, isOpen ? 'Объявление снято' : 'Объявление снова опубликовано'),
          onRepublish: () => _act('republish', {'id': ad.id}, 'Объявление опубликовано снова и поднято в ленте'),
          onAutoRenew: (v) => _act('autoRenew', {'id': ad.id, 'on': v}, v ? 'Автопродление включено' : 'Автопродление выключено'),
          onUrgent: () => _act('urgent', {'id': ad.id, 'on': !ad.urgent}, ad.urgent ? 'Метка снята' : 'Метка «Срочно» на 3 дня'),
          onShare: () => showShare(context, ad),
          onDelete: () => _confirmDelete(ad),
          onRenew: (isOpen && DateTime.now().millisecondsSinceEpoch - ad.upd > 14 * 86400000)
              ? () => _act('renew', {'id': ad.id}, 'Спасибо, объявление продлено')
              : null,
        ),
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
    if (rows.isEmpty) return [
      EmptyState(
          icon: Icons.mark_email_unread_outlined,
          title: 'Откликов пока нет',
          text: 'Они появятся здесь, когда кто-то ответит на ваше объявление.',
          button: 'Разместить объявление',
          onTap: () => S.i.goTab(2))
    ];
    final items = <Widget>[];
    for (final r in rows) {
      final st = (r['st'] ?? '').toString();
      final rid = (r['rid'] ?? '').toString();
      final ph = (r['phone'] ?? '').toString();
      final msg = (r['msg'] ?? '').toString();
      final adId = (r['adId'] ?? '').toString();
      final fresh = _fresh.contains(rid);
      final adObj = _adById(adId);
      final title = (r['ad'] ?? '').toString().trim();
      final pid = (r['pid'] ?? '').toString();
      final name = (r['name'] ?? '').toString();
      final canCall = st != 'rejected' && ph.isNotEmpty;
      items.add(Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(p).copyWith(border: Border.all(color: fresh ? p.ac : p.bd, width: fresh ? 1.6 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(name, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: p.tx)),
                Text(siteDateTime(((r['ts'] as num?) ?? 0).toInt(), S.i.timeZone), style: TextStyle(color: p.mu, fontSize: 12.5)),
              ]),
            ),
            if (fresh) _statePill('новый', p.ac) else if (st == 'chosen') _statePill('Исполнитель', p.ok) else if (st == 'done') _statePill('Выполнено', p.ok) else if (st == 'rejected') _statePill('Отклонён', p.mu),
          ]),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 12),
            _adMini(p, title: title, ad: adObj, onTap: adObj == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: adObj)))),
          ],
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: p.ac, width: 3))),
              child: Text(msg, style: TextStyle(color: p.tx, fontSize: 14.5, height: 1.35)),
            ),
          ],
          if (st == 'rejected') ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: _small(p, 'Удалить', ico: 'trash', color: p.dng, () => _act('rdel', {'rid': rid}, 'Отклик удалён'))),
          ] else ...[
            const SizedBox(height: 12),
            Row(children: [
              if (canCall) Expanded(child: _big(p, fmtPhone(ph), 'phone', () => _call(ph), accent: true)),
              if (canCall && pid.isNotEmpty) const SizedBox(width: 8),
              if (pid.isNotEmpty) Expanded(child: _big(p, 'Написать', 'chat', () => _chat(pid, name, adId: adId))),
            ]),
            if (st != 'done') ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _big(p, st == 'chosen' ? 'Работа выполнена' : 'Выбрать исполнителем', 'check',
                      st == 'chosen'
                          ? () async {
                              // работа выполнена: сразу просим оценить исполнителя
                              if (await _act('fin', {'rid': rid}, 'Отмечено как выполнено') && mounted && pid.isNotEmpty) {
                                showReviewSheet(context, pid: pid, name: name);
                              }
                            }
                          : () => _act('pick', {'rid': rid}, 'Исполнитель выбран'),
                      main: true),
                ),
                const SizedBox(width: 8),
                _sq(p, 'x', () => _act('rej', {'rid': rid}, 'Отклик отклонён'), color: p.dng),
              ]),
            ] else if (pid.isNotEmpty) ...[
              const SizedBox(height: 8),
              _big(p, 'Оценить работу', 'star', () => showReviewSheet(context, pid: pid, name: name), accent: true),
            ],
          ],
        ]),
      ));
    }
    return items;
  }

  List<Widget> _sent(Pal p) {
    final rows = _list('sent').reversed.toList();
    if (rows.isEmpty) return [
      EmptyState(
          icon: Icons.send_outlined,
          title: 'Вы пока не откликались',
          text: 'Найдите подходящую подработку и напишите автору.',
          button: 'Найти объявления',
          onTap: () => S.i.goTab(1))
    ];
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
      final callPh = (st == 'rejected' || found == null) ? '' : found.phone;
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
            _adMini(p, title: title.isEmpty ? 'Объявление удалено' : title, ad: found, pay: (r['pay'] ?? '').toString(), city: city, onTap: found == null ? null : open),
            if (msg.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(border: Border(left: BorderSide(color: p.ac, width: 3))),
                child: Text(msg, style: TextStyle(color: p.tx, fontSize: 14.5, height: 1.35)),
              ),
            ],
            if (canWrite || callPh.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                if (callPh.isNotEmpty) Expanded(child: _big(p, fmtPhone(callPh), 'phone', () => _call(callPh), accent: true)),
                if (callPh.isNotEmpty && canWrite) const SizedBox(width: 8),
                if (canWrite) Expanded(child: _big(p, 'Написать', 'chat', () => _chat(pid, '', adId: adId))),
              ]),
            ],
            if (st == 'done' && pid.isNotEmpty) ...[
              const SizedBox(height: 8),
              _big(p, 'Оценить работу', 'star', () => showReviewSheet(context, pid: pid), accent: true),
            ],
          ]),
        ),
      ));
    }
    return items;
  }

  // Объявление, по которому отклик: миниатюра, название, оплата; нажатие открывает объявление
  Widget _adMini(Pal p, {required String title, Ad? ad, String pay = '', String city = '', VoidCallback? onTap}) {
    final payText = ad != null ? adPay(ad) : pay;
    final hasImg = ad != null && ad.imgs.isNotEmpty;
    return Tap(
      onTap: onTap,
      scale: .98,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: p.ac.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
            child: hasImg
                ? CachedNetworkImage(imageUrl: imgUrl(ad.imgs.first, 200), fit: BoxFit.cover, errorWidget: (c, u, e) => Icon(catIcon(ad.category), color: p.ac, size: 22))
                : Icon(ad != null ? catIcon(ad.category) : Icons.sell_outlined, color: p.ac, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: p.tx)),
              if (payText.isNotEmpty || city.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  if (payText.isNotEmpty) Flexible(child: PriceTag(payText, size: 13, dense: true)),
                  if (payText.isNotEmpty && city.isNotEmpty) Text('  ·  ', style: TextStyle(color: p.mu, fontSize: 12.5)),
                  if (city.isNotEmpty) Flexible(child: Text(city, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontSize: 12.5))),
                ]),
              ],
            ]),
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded, size: 20, color: p.mu),
        ]),
      ),
    );
  }

  // Кнопка в ряду отклика: одинаковая высота, текст в одну строку
  Widget _big(Pal p, String text, String ico, VoidCallback f, {bool accent = false, bool main = false}) {
    final hi = accent || main;
    return Tap(
      onTap: f,
      scale: .97,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hi ? p.ac.withOpacity(.12) : p.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hi ? p.ac.withOpacity(.45) : p.bd),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Ico(ico, size: 16, color: hi ? p.ac : p.tx),
            const SizedBox(width: 7),
            Text(text, maxLines: 1, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: hi ? p.ac : p.tx)),
          ]),
        ),
      ),
    );
  }

  // Квадратная кнопка-иконка (написать, отклонить)
  Widget _sq(Pal p, String ico, VoidCallback f, {Color? color}) => Tap(
        onTap: f,
        scale: .94,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.bd)),
          child: Ico(ico, size: 17, color: color ?? p.tx),
        ),
      );

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
}
