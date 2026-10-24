import 'package:flutter/material.dart';
import 'ad_page.dart';
import 'api.dart';
import 'auth.dart';
import 'messages.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
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
      await _load();
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _write() async {
    if (!S.i.logged) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage()));
      if (!mounted || !S.i.logged) return;
    }
    final dd = d;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          pid: widget.pid,
          name: (dd?['name'] ?? widget.name).toString(),
          avatar: (dd?['avatar'] ?? '').toString(),
          ver: dd?['ver'] == true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: loading
          ? Center(child: CircularProgressIndicator(color: p.ac))
          : d == null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(err ?? 'Не удалось загрузить профиль', style: TextStyle(color: p.mu))))
              : _body(p, d!),
    );
  }

  Widget _body(Pal p, Map<String, dynamic> d) {
    final name = (d['name'] ?? widget.name).toString();
    final me = d['me'] == true;
    final rc = (d['rc'] as num?)?.toInt() ?? 0;
    final rt = (d['rt'] as num?)?.toDouble() ?? 0;
    final created = (d['created'] as num?)?.toInt() ?? 0;
    final dn = (d['dn'] as num?)?.toInt() ?? 0;
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
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight)),
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
                  const SizedBox(height: 6),
                  if (rc > 0)
                    Row(children: [
                      StarsRow(rt),
                      const SizedBox(width: 6),
                      Flexible(child: Text('$rt · $rc ${plural(rc, 'отзыв', 'отзыва', 'отзывов')}', style: TextStyle(color: p.mu, fontSize: 13))),
                    ])
                  else
                    Text('Пока нет отзывов', style: TextStyle(color: p.mu, fontSize: 13)),
                ]),
              ),
            ]),
            if (since.isNotEmpty || dn > 0) ...[
              const SizedBox(height: 14),
              Container(height: 1, color: p.bd),
              const SizedBox(height: 12),
              Row(children: [
                if (since.isNotEmpty) ...[
                  Icon(Icons.calendar_today_outlined, size: 15, color: p.ac),
                  const SizedBox(width: 6),
                  Expanded(child: Text(since, style: TextStyle(color: p.mu, fontSize: 13.5))),
                ] else
                  const Spacer(),
                if (dn > 0) Text('Выполнено: $dn', style: TextStyle(color: p.ok, fontWeight: FontWeight.w800, fontSize: 13.5)),
              ]),
            ],
            if (!me) ...[
              const SizedBox(height: 14),
              GradBtn('Написать', icon: Icons.chat_bubble_outline, onTap: _write),
            ],
          ]),
        ),
        const SizedBox(height: 18),
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
                    onTap: () => setState(() => stars = i),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(i <= stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 36, color: const Color(0xFFFFB400)),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              TextField(contextMenuBuilder: appContextMenu, 
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
          const SizedBox(height: 18),
        ],
        Text('Отзывы', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: p.tx)),
        const SizedBox(height: 8),
        if (reviews.isEmpty) Text('Отзывов пока нет', style: TextStyle(color: p.mu)),
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
            ]),
          ),
        const SizedBox(height: 14),
        Text('Объявления', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: p.tx)),
        const SizedBox(height: 8),
        if (ads.isEmpty) Text('Активных объявлений нет', style: TextStyle(color: p.mu)),
        for (final a in ads)
          AdCard(ad: a, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: a)))),
      ]),
    );
  }
}
