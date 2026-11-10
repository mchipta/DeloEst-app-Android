import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'about.dart';
import 'ad_page.dart';
import 'api.dart';
import 'auth.dart';
import 'messages.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

const _months = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
];

class StarsRow extends StatelessWidget {
  final double value;
  final double size;
  const StarsRow(this.value, {super.key, this.size = 18});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Icon(value >= i - .25 ? Icons.star_rounded : (value >= i - .75 ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: size, color: const Color(0xFFFFB400)),
    ]);
  }
}

class ProfilePage extends StatefulWidget {
  final String pid, name;
  const ProfilePage({super.key, required this.pid, this.name = ''});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? d;
  bool loading = true;
  String? err;
  int _tab = 0; // 0 объявления · 1 отзывы · 2 о себе

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await Api.call('profile', {'pid': widget.pid});
      if (mounted) {
        setState(() {
          d = j;
          err = null;
        });
      }
    } catch (e) {
      final m = S.i.fail(e);
      if (mounted) setState(() => err = m);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        final p = pal(context);
        final me = d?['me'] == true || (S.i.logged && S.i.pid == widget.pid);
        final blocked = S.i.isBlocked(widget.pid);
        final uName = (d?['name'] ?? widget.name).toString();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Профиль'),
            actions: [
              if (!me && widget.pid.isNotEmpty)
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (!S.i.logged) {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage()));
                      if (!mounted || !S.i.logged) return;
                    }
                    if (v == 'report' && mounted) {
                      await showReportSheet(context, id: 'user:${widget.pid}', label: 'пользователя');
                    }
                    if (v == 'block' && mounted) {
                      await toggleUserBlock(context, pid: widget.pid, name: uName);
                    }
                  },
                  itemBuilder: (c) => [
                    PopupMenuItem(
                      value: 'block',
                      child: menuRow(c, Icons.visibility_off_outlined, blocked ? 'Разблокировать' : 'Заблокировать'),
                    ),
                    PopupMenuItem(value: 'report', child: menuRow(c, Icons.warning_amber_rounded, 'Пожаловаться')),
                  ],
                ),
            ],
          ),
          bottomNavigationBar: (!me && !loading && d != null && widget.pid.isNotEmpty && !blocked) ? _actionBar(p, uName) : null,
          body: SmoothSwitch(
            child: loading
                ? Center(key: const ValueKey('loading'), child: CircularProgressIndicator(color: p.ac))
                : d == null
                    ? Center(key: const ValueKey('err'), child: Padding(padding: const EdgeInsets.all(24), child: Text(err ?? 'Не удалось загрузить профиль', style: TextStyle(color: p.mu))))
                    : KeyedSubtree(key: const ValueKey('body'), child: _body(p, d!)),
          ),
        );
      },
    );
  }

  // Нижняя панель чужого профиля: предложить задачу и написать
  Widget _actionBar(Pal p, String uName) => Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).viewPadding.bottom),
        decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.bd))),
        child: Row(children: [
          Expanded(
            child: Tap(
              onTap: () => _offer(uName),
              scale: .97,
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.ac.withOpacity(.5))),
                child: Text('Предложить задачу', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: GradBtn('Написать', radius: 18, onTap: () => _write(uName))),
        ]),
      );

  Future<bool> _needLogin() async {
    if (S.i.logged) return true;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage()));
    return mounted && S.i.logged;
  }

  Future<void> _write(String uName, {String adId = '', String prefill = ''}) async {
    if (!await _needLogin()) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPage(pid: widget.pid, name: uName, avatar: (d?['avatar'] ?? '').toString(), ver: d?['ver'] == true, adId: adId, prefill: prefill)),
    );
  }

  // «Предложить задачу»: выбираете своё объявление, и человеку уходит приглашение карточкой
  Future<void> _offer(String uName) async {
    if (!await _needLogin()) return;
    if (!mounted) return;
    final mine = S.i.ads.where((a) => a.pid == S.i.pid && a.status == 'open').toList();
    final p = pal(context);
    if (mine.isEmpty) {
      toast(context, 'Сначала опубликуйте объявление, и мы предложим его этому человеку');
      return;
    }
    final a = await showModalBottomSheet<Ad>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(c).viewPadding.bottom),
        decoration: BoxDecoration(color: p.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: p.bd, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 14),
          Text('Какую задачу предложить?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: p.tx)),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final x in mine)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(x.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.tx, fontWeight: FontWeight.w700)),
                  subtitle: Text([adPay(x), x.city].where((e) => e.isNotEmpty).join(' · '), style: TextStyle(color: p.mu)),
                  trailing: Icon(Icons.chevron_right_rounded, color: p.mu),
                  onTap: () => Navigator.pop(c, x),
                ),
            ]),
          ),
        ]),
      ),
    );
    if (a == null || !mounted) return;
    _write(uName, adId: a.id, prefill: 'Здравствуйте! У меня есть задача, посмотрите: $kSiteUrl#/ad/${a.id}');
  }

  Future<void> _toggleFree(bool on) async {
    try {
      await Api.call('free', {'on': on});
      await _load();
      if (mounted) toast(context, on ? 'Вы отмечены как «Свободен сегодня» до конца дня' : 'Отметка снята');
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e), err: true);
    }
  }

  Widget _chip(Pal p, String t, Color c, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(.4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: c), const SizedBox(width: 4)],
          Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ]),
      );

  // Рейтинг героем: оценка, звёзды и полоски распределения
  Widget _ratingHero(Pal p, double rt, int rc, List<int> dist, String name) => Tap(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewsPage(pid: widget.pid, name: name)));
          if (mounted) _load();
        },
        scale: .98,
        child: Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: p.bd)),
          child: Row(children: [
            Column(children: [
              Text(rt.toStringAsFixed(1), style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: p.tx, height: 1, letterSpacing: -1)),
              const SizedBox(height: 6),
              StarsRow(rt),
              const SizedBox(height: 4),
              Text('$rc ${plural(rc, 'отзыв', 'отзыва', 'отзывов')}', style: TextStyle(color: p.mu, fontSize: 12.5)),
            ]),
            const SizedBox(width: 18),
            Expanded(
              child: Column(children: [
                for (var k = 5; k >= 1; k--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(children: [
                      SizedBox(width: 14, child: Text('$k', style: TextStyle(color: p.mu, fontSize: 12, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: rc == 0 ? 0 : dist[k - 1] / rc, minHeight: 6, backgroundColor: p.bg2, color: const Color(0xFFFFB400)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(width: 22, child: Text('${dist[k - 1]}', textAlign: TextAlign.right, style: TextStyle(color: p.mu, fontSize: 12))),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
      );

  Widget _tabs(Pal p, int ads, int revs) {
    Widget tab(int i, String label) {
      final on = _tab == i;
      return Expanded(
        child: Tap(
          onTap: () {
            haptic();
            setState(() => _tab = i);
          },
          scale: .97,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? p.card : Colors.transparent, borderRadius: BorderRadius.circular(12), border: on ? Border.all(color: p.bd) : null),
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: on ? p.tx : p.mu)),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [tab(0, 'Объявления · $ads'), tab(1, 'Отзывы · $revs'), tab(2, 'О себе')]),
    );
  }

  Widget _about(Pal p, Map<String, dynamic> d, bool me) {
    final bio = (d['bio'] ?? '').toString();
    final skills = (d['skills'] is List ? d['skills'] as List : <dynamic>[]).map((e) => e.toString()).toList();
    final prices = (d['prices'] ?? '').toString().split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final photos = (d['portfolio'] is List ? d['portfolio'] as List : <dynamic>[]).map((e) => e.toString()).toList();
    final empty = bio.isEmpty && skills.isEmpty && prices.isEmpty && photos.isEmpty;
    Widget head(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 8), child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: p.tx)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (empty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(me ? 'Расскажите о себе: навыки, цены и фото работ помогают получать больше откликов.' : 'Человек пока ничего о себе не рассказал.', style: TextStyle(color: p.mu, height: 1.4)),
        ),
      if (bio.isNotEmpty) Text(bio, style: TextStyle(color: p.tx, fontSize: 15.5, height: 1.4)),
      if (skills.isNotEmpty) ...[
        head('Навыки'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final s in skills) _chip(p, s, p.ac)]),
      ],
      if (prices.isNotEmpty) ...[
        head('Цены'),
        Container(
          decoration: cardDeco(p),
          child: Column(children: [
            for (var i = 0; i < prices.length; i++) ...[
              if (i > 0) Container(height: 1, color: p.bd),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), child: Align(alignment: Alignment.centerLeft, child: Text(prices[i], style: TextStyle(color: p.tx, fontSize: 14.5)))),
            ],
          ]),
        ),
      ],
      if (photos.isNotEmpty) ...[
        head('Фото работ'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (var i = 0; i < photos.length; i++)
              Tap(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoViewer(ids: photos, index: i))),
                scale: .96,
                child: ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedNetworkImage(imageUrl: imgUrl(photos[i], 400), fit: BoxFit.cover)),
              ),
          ],
        ),
      ],
      if (me) ...[
        const SizedBox(height: 18),
        GradBtn(empty ? 'Заполнить «О себе»' : 'Редактировать «О себе»', radius: 18, onTap: () async {
          final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AboutEditor(data: d)));
          if (ok == true && mounted) _load();
        }),
      ],
    ]);
  }

  Widget _body(Pal p, Map<String, dynamic> d) {
    final name = (d['name'] ?? widget.name).toString();
    final me = d['me'] == true || (S.i.logged && S.i.pid == widget.pid);
    final rc = (d['rc'] as num?)?.toInt() ?? 0;
    final rt = (d['rt'] as num?)?.toDouble() ?? 0;
    final created = (d['created'] as num?)?.toInt() ?? 0;
    final dn = (d['dn'] as num?)?.toInt() ?? 0;
    final free = d['free'] == true;
    final bio = (d['bio'] ?? '').toString();
    final dist = (d['dist'] is List ? d['dist'] as List : <dynamic>[0, 0, 0, 0, 0]).map((e) => (e as num).toInt()).toList();
    final ads = (d['ads'] is List ? d['ads'] as List : <dynamic>[]).map((e) => Ad.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final reviews = (d['reviews'] is List ? d['reviews'] as List : <dynamic>[]).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    String since = '';
    if (created > 0) {
      final t = DateTime.fromMillisecondsSinceEpoch(created);
      since = 'На сайте с ${t.day} ${_months[t.month - 1]} ${t.year}';
    }
    return RefreshIndicator(
      color: p.ac,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.bd),
            boxShadow: [BoxShadow(color: p.ac.withOpacity(.10), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [free ? p.ok : p.ac, free ? p.ok : p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: p.card),
                  child: Avatar(name, data: (d['avatar'] ?? '').toString(), size: 62),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: p.tx, height: 1.15)),
                  if (d['ver'] == true) const Padding(padding: EdgeInsets.only(top: 6), child: VerifiedBadge(size: 18, label: true)),
                  if (bio.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(bio, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontSize: 13.5, height: 1.3))),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (free) _chip(p, 'Свободен сегодня', p.ok, icon: Icons.bolt_rounded),
              if (dn > 0) _chip(p, 'Выполнено: $dn', p.ok, icon: Icons.check_circle_outline_rounded),
              if (since.isNotEmpty) _chip(p, since, p.mu, icon: Icons.calendar_today_outlined),
            ]),
            if (me) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: p.bd),
              Tap(
                onTap: () => _toggleFree(!free),
                scale: .99,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Свободен сегодня', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.tx)),
                        Text('Заказчики увидят отметку до конца дня', style: TextStyle(fontSize: 12.5, color: p.mu)),
                      ]),
                    ),
                    IgnorePointer(
                      child: Switch(value: free, onChanged: (_) {}, activeColor: Colors.white, activeTrackColor: p.ok, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    ),
                  ]),
                ),
              ),
            ],
          ]),
        ),
        if (rc > 0) _ratingHero(p, rt, rc, dist, name),
        _tabs(p, ads.length, rc),
        if (_tab == 0) ...[
          if (ads.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text('Активных объявлений нет', style: TextStyle(color: p.mu))),
          for (final a in ads) AdCard(ad: a, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: a)))),
        ],
        if (_tab == 1) ...[
          if (reviews.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text('Отзывов пока нет. Они появятся после первой выполненной работы.', style: TextStyle(color: p.mu, height: 1.4))),
          for (final r in reviews.take(20))
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: cardDeco(p),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text((r['name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: p.tx))),
                  Text(ago((r['ts'] as num?)?.toInt() ?? 0), style: TextStyle(color: p.mu, fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                StarsRow(((r['rating'] as num?) ?? 0).toDouble()),
                if ((r['text'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text((r['text'] ?? '').toString(), style: TextStyle(color: p.tx, height: 1.35))),
                if ((r['reply'] ?? '').toString().isNotEmpty) replyBox(p, 'Ответ', (r['reply'] ?? '').toString(), ts: (r['rts'] as num?)?.toInt() ?? 0),
              ]),
            ),
          if (rc > 0 || !me)
            TextButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewsPage(pid: widget.pid, name: name)));
                if (mounted) _load();
              },
              child: Text(me ? 'Все отзывы и ответы' : 'Оставить отзыв', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800)),
            ),
        ],
        if (_tab == 2) _about(p, d, me),
      ]),
    );
  }
}

// Блок «ответ автора» под отзывом
Widget replyBox(Pal p, String label, String text, {int ts = 0}) => Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: p.bg2,
        borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
        border: Border(left: BorderSide(color: p.ac, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: p.ac, fontWeight: FontWeight.w800, fontSize: 12.5))),
          if (ts > 0) Text(ago(ts), style: TextStyle(color: p.mu, fontSize: 12)),
        ]),
        const SizedBox(height: 3),
        Text(text, style: TextStyle(color: p.tx, height: 1.35)),
      ]),
    );

// Отзывы о человеке: список, ответы автора и форма «Оставить отзыв»
class ReviewsPage extends StatefulWidget {
  final String pid, name;
  const ReviewsPage({super.key, required this.pid, this.name = ''});
  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  Map<String, dynamic>? d;
  bool loading = true;
  String? err;
  int stars = 0;
  final txt = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    txt.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final j = await Api.call('profile', {'pid': widget.pid});
      if (mounted) {
        setState(() {
          d = j;
          err = null;
        });
      }
    } catch (e) {
      final m = S.i.fail(e);
      if (mounted) setState(() => err = m);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _rate() async {
    if (stars < 1) {
      toast(context, 'Поставьте оценку от 1 до 5');
      return;
    }
    setState(() => busy = true);
    try {
      await Api.call('rate', {'pid': widget.pid, 'rating': stars, 'text': txt.text.trim()});
      if (mounted) toast(context, 'Спасибо за отзыв!');
      txt.clear();
      stars = 0;
      await _load();
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e), err: true);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Отзывы')),
      body: SmoothSwitch(
        child: loading
            ? Center(key: const ValueKey('loading'), child: CircularProgressIndicator(color: p.ac))
            : d == null
                ? Center(key: const ValueKey('err'), child: Padding(padding: const EdgeInsets.all(24), child: Text(err ?? 'Не удалось загрузить отзывы', style: TextStyle(color: p.mu))))
                : KeyedSubtree(key: const ValueKey('body'), child: _body(p, d!)),
      ),
    );
  }

  Widget _body(Pal p, Map<String, dynamic> d) {
    final name = (d['name'] ?? widget.name).toString();
    final rc = (d['rc'] as num?)?.toInt() ?? 0;
    final rt = (d['rt'] as num?)?.toDouble() ?? 0;
    final reviews = (d['reviews'] is List ? d['reviews'] as List : <dynamic>[]).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return RefreshIndicator(
      color: p.ac,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(p),
          child: Row(children: [
            Icon(Icons.star_rounded, size: 34, color: const Color(0xFFFFB400)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rc > 0 ? '$rt из 5' : 'Пока нет отзывов', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: p.tx)),
                Text(rc > 0 ? '$rc ${plural(rc, 'отзыв', 'отзыва', 'отзывов')} о $name' : name, style: TextStyle(color: p.mu, fontSize: 13)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (d['can'] == true) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: cardDeco(p),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Оставить отзыв', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.tx)),
              const SizedBox(height: 8),
              Row(children: [
                for (var i = 1; i <= 5; i++)
                  GestureDetector(
                    onTap: () { haptic(); setState(() => stars = i); },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(i <= stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 36, color: const Color(0xFFFFB400)),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              TextField(
                contextMenuBuilder: appContextMenu,
                controller: txt,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                style: TextStyle(color: p.tx),
                decoration: deco(context, 'Комментарий (необязательно)'),
              ),
              GradBtn('Отправить отзыв', busy: busy, onTap: _rate),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        if (reviews.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('Отзывов пока нет', style: TextStyle(color: p.mu)))),
        for (final r in reviews)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: cardDeco(p, r: 16),
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
              if ((r['reply'] ?? '').toString().isNotEmpty) replyBox(p, 'Ответ: $name', (r['reply']).toString(), ts: (r['rts'] as num?)?.toInt() ?? 0),
            ]),
          ),
      ]),
    );
  }
}
