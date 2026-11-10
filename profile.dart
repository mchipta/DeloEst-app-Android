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
  String _tab = 'ads'; // ads, pf, price, rev

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

  Future<void> _toggleFreeToday(bool on) async {
    haptic();
    try {
      final r = await Api.call('setFreeToday', {'on': on});
      await S.i.patchUser({'freeToday': r['freeToday'] == true, 'freeUntil': r['freeUntil'] ?? 0});
      S.i.loadAds();
      await _load();
      if (mounted) toast(context, on ? 'Статус «Свободен сегодня» включён на 24 часа' : 'Статус «Свободен сегодня» выключен');
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e), err: true);
    }
  }

  Future<void> _offerTask(String uName) async {
    if (!S.i.logged) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage()));
      if (!mounted || !S.i.logged) return;
    }
    final titleC = TextEditingController();
    final payC = TextEditingController();
    final whenC = TextEditingController();
    final descC = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pal(context).card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) {
        final p = pal(c);
        var busy = false;
        return StatefulBuilder(
          builder: (c, setS) => Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Предложить задачу', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: p.tx)),
                const SizedBox(height: 6),
                Text('Опишите задачу для $uName — предложение придёт в личные сообщения.', style: TextStyle(color: p.mu, fontSize: 13.5)),
                const SizedBox(height: 12),
                TextField(contextMenuBuilder: appContextMenu, controller: titleC, style: TextStyle(color: p.tx), decoration: deco(c, 'Что нужно сделать')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(contextMenuBuilder: appContextMenu, controller: payC, style: TextStyle(color: p.tx), decoration: deco(c, 'Бюджет / оплата'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(contextMenuBuilder: appContextMenu, controller: whenC, style: TextStyle(color: p.tx), decoration: deco(c, 'Когда нужно'))),
                ]),
                const SizedBox(height: 10),
                TextField(contextMenuBuilder: appContextMenu, controller: descC, minLines: 2, maxLines: 4, style: TextStyle(color: p.tx), decoration: deco(c, 'Подробности и адрес')),
                const SizedBox(height: 14),
                GradBtn('Отправить предложение', busy: busy, onTap: () async {
                  if (titleC.text.trim().length < 3) {
                    toast(c, 'Укажите, что нужно сделать');
                    return;
                  }
                  setS(() => busy = true);
                  try {
                    await Api.call('offerTask', {
                      'to': widget.pid,
                      'title': titleC.text.trim(),
                      'pay': payC.text.trim(),
                      'when': whenC.text.trim(),
                      'desc': descC.text.trim(),
                    });
                    if (c.mounted) Navigator.pop(c, true);
                  } catch (e) {
                    if (c.mounted) toast(c, S.i.fail(e), err: true);
                    setS(() => busy = false);
                  }
                }),
              ]),
            ),
          ),
        );
      },
    );
    if (ok == true && mounted) {
      toast(context, 'Предложение отправлено в чат');
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(pid: widget.pid, name: uName)));
    }
  }

  Future<void> _addPortfolio(List<Map<String, dynamic>> cur) async {
    final titleC = TextEditingController();
    final descC = TextEditingController();
    final priceC = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pal(context).card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) {
        final p = pal(c);
        var busy = false;
        return StatefulBuilder(
          builder: (c, setS) => Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Добавить работу в портфолио', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: p.tx)),
                const SizedBox(height: 12),
                TextField(contextMenuBuilder: appContextMenu, controller: titleC, style: TextStyle(color: p.tx), decoration: deco(c, 'Название работы')),
                const SizedBox(height: 10),
                TextField(contextMenuBuilder: appContextMenu, controller: descC, minLines: 2, maxLines: 4, style: TextStyle(color: p.tx), decoration: deco(c, 'Описание работы')),
                const SizedBox(height: 10),
                TextField(contextMenuBuilder: appContextMenu, controller: priceC, style: TextStyle(color: p.tx), decoration: deco(c, 'Стоимость (необязательно)')),
                const SizedBox(height: 14),
                GradBtn('Сохранить', busy: busy, onTap: () async {
                  if (titleC.text.trim().length < 2) {
                    toast(c, 'Укажите название работы');
                    return;
                  }
                  setS(() => busy = true);
                  try {
                    final next = [
                      ...cur,
                      {
                        'id': 'pf${DateTime.now().millisecondsSinceEpoch}',
                        'title': titleC.text.trim(),
                        'desc': descC.text.trim(),
                        'price': priceC.text.trim(),
                        'img': '',
                      }
                    ];
                    await Api.call('savePortfolio', {'list': next});
                    if (c.mounted) Navigator.pop(c, true);
                  } catch (e) {
                    if (c.mounted) toast(c, S.i.fail(e), err: true);
                    setS(() => busy = false);
                  }
                }),
              ]),
            ),
          ),
        );
      },
    );
    if (ok == true && mounted) {
      toast(context, 'Работа добавлена в портфолио');
      _load();
    }
  }

  Future<void> _addPricelist(List<Map<String, dynamic>> cur) async {
    final titleC = TextEditingController();
    final priceC = TextEditingController();
    final unitC = TextEditingController(text: 'за услугу');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pal(context).card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) {
        final p = pal(c);
        var busy = false;
        return StatefulBuilder(
          builder: (c, setS) => Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Добавить услугу в прайс', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: p.tx)),
                const SizedBox(height: 12),
                TextField(contextMenuBuilder: appContextMenu, controller: titleC, style: TextStyle(color: p.tx), decoration: deco(c, 'Название услуги')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(contextMenuBuilder: appContextMenu, controller: priceC, style: TextStyle(color: p.tx), decoration: deco(c, 'Цена (например: от 1 000 ₽)'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(contextMenuBuilder: appContextMenu, controller: unitC, style: TextStyle(color: p.tx), decoration: deco(c, 'Единица (за час / м²)'))),
                ]),
                const SizedBox(height: 14),
                GradBtn('Сохранить', busy: busy, onTap: () async {
                  if (titleC.text.trim().length < 2) {
                    toast(c, 'Укажите название услуги');
                    return;
                  }
                  setS(() => busy = true);
                  try {
                    final next = [
                      ...cur,
                      {
                        'id': 'pr${DateTime.now().millisecondsSinceEpoch}',
                        'title': titleC.text.trim(),
                        'price': priceC.text.trim().isEmpty ? 'Договорная' : priceC.text.trim(),
                        'unit': unitC.text.trim(),
                      }
                    ];
                    await Api.call('savePricelist', {'list': next});
                    if (c.mounted) Navigator.pop(c, true);
                  } catch (e) {
                    if (c.mounted) toast(c, S.i.fail(e), err: true);
                    setS(() => busy = false);
                  }
                }),
              ]),
            ),
          ),
        );
      },
    );
    if (ok == true && mounted) {
      toast(context, 'Услуга добавлена в прайс');
      _load();
    }
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

  Widget _badge(Pal p, IconData ic, String text, {Color? col}) {
    final c = col ?? p.tx;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: col != null ? col.withOpacity(.12) : p.bg2,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: col != null ? col.withOpacity(.35) : p.bd),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 14, color: col ?? p.ac),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }

  Widget _body(Pal p, Map<String, dynamic> d) {
    final name = (d['name'] ?? widget.name).toString();
    final me = d['me'] == true || (S.i.logged && S.i.pid == widget.pid);
    final blocked = S.i.isBlocked(widget.pid);
    final rc = (d['rc'] as num?)?.toInt() ?? 0;
    final rt = (d['rt'] as num?)?.toDouble() ?? 0;
    final created = (d['created'] as num?)?.toInt() ?? 0;
    final dn = (d['dn'] as num?)?.toInt() ?? 0;
    final ver = d['ver'] == true;
    final innOk = d['innOk'] == true;
    final freeToday = d['freeToday'] == true;
    final ads = (d['ads'] is List ? d['ads'] as List : <dynamic>[]).map((e) => Ad.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final pf = (d['portfolio'] is List ? d['portfolio'] as List : <dynamic>[]).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final pr = (d['pricelist'] is List ? d['pricelist'] as List : <dynamic>[]).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final revs = (d['reviews'] is List ? d['reviews'] as List : <dynamic>[]).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final dist = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    if (d['dist'] is Map) {
      final dm = Map<String, dynamic>.from(d['dist'] as Map);
      for (var s = 1; s <= 5; s++) {
        dist[s] = (dm['$s'] as num?)?.toInt() ?? 0;
      }
    } else {
      for (final r in revs) {
        final st = ((r['rating'] as num?)?.round() ?? 5).clamp(1, 5);
        dist[st] = (dist[st] ?? 0) + 1;
      }
    }

    String since = '';
    if (created > 0) {
      final t = DateTime.fromMillisecondsSinceEpoch(created);
      since = 'На сайте с ${t.day} ${_months[t.month - 1]} ${t.year}';
    }

    Widget tabChip(String k, String label, int count) {
      final on = _tab == k;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Tap(
          onTap: () => setState(() => _tab = k),
          scale: .96,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: on ? LinearGradient(colors: [p.ac, p.ac2]) : null,
              color: on ? null : p.card,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: on ? Colors.transparent : p.bd),
            ),
            child: Text(
              count > 0 ? '$label  $count' : label,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: on ? Colors.white : p.tx),
            ),
          ),
        ),
      );
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
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (ver) const VerifiedBadge(size: 16, label: true),
                    if (innOk) _badge(p, Icons.verified_user_outlined, 'Самозанятый · ИНН', col: p.ok),
                    if (freeToday) _badge(p, Icons.bolt_rounded, 'Свободен сегодня', col: p.ok),
                    if (dn >= 5 && rt >= 4.5) _badge(p, Icons.workspace_premium_outlined, 'Надёжный исполнитель', col: p.ac),
                    _badge(p, Icons.schedule_rounded, 'Отвечает быстро'),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            // Шапка с рейтингом и полосками оценок 5★–1★
            Tap(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewsPage(pid: widget.pid, name: name)));
                if (mounted) _load();
              },
              scale: .99,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd)),
                child: Row(children: [
                  SizedBox(
                    width: 88,
                    child: Column(children: [
                      Text(rc > 0 ? rt.toStringAsFixed(1) : '—', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: p.tx, height: 1.05)),
                      const SizedBox(height: 4),
                      StarsRow(rt, size: 15),
                      const SizedBox(height: 3),
                      Text(rc > 0 ? '$rc ${plural(rc, 'отзыв', 'отзыва', 'отзывов')}' : 'Нет отзывов', style: TextStyle(fontSize: 11.5, color: p.mu)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(children: [
                      for (var s = 5; s >= 1; s--)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            SizedBox(width: 24, child: Text('$s★', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.mu))),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: rc > 0 ? (dist[s] ?? 0) / rc : 0,
                                  minHeight: 6,
                                  backgroundColor: p.card,
                                  valueColor: AlwaysStoppedAnimation(p.ac),
                                ),
                              ),
                            ),
                            SizedBox(width: 24, child: Text('${dist[s] ?? 0}', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: p.mu))),
                          ]),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),
            if (me) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.bd)),
                child: Row(children: [
                  Icon(Icons.bolt_rounded, color: freeToday ? p.ok : p.ac),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Свободен сегодня', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: p.tx)),
                      Text('Зелёная метка в профиле и на ваших объявлениях на 24 ч', style: TextStyle(fontSize: 12, color: p.mu)),
                    ]),
                  ),
                  Switch(value: freeToday, activeColor: p.ok, onChanged: _toggleFreeToday),
                ]),
              ),
            ] else if (!blocked) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: GradBtn('Предложить задачу', icon: Icons.assignment_add, onTap: () => _offerTask(name))),
                const SizedBox(width: 8),
                Expanded(
                  child: OutBtn('Написать', icon: Icons.chat_bubble_outline_rounded, onTap: () async {
                    if (!S.i.logged) {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage()));
                      if (!mounted || !S.i.logged) return;
                    }
                    if (mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(pid: widget.pid, name: name, ver: ver)));
                    }
                  }),
                ),
              ]),
            ],
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
          ]),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            tabChip('ads', 'Объявления', ads.length),
            tabChip('pf', 'Портфолио', pf.length),
            tabChip('price', 'Прайс услуг', pr.length),
            tabChip('rev', 'Отзывы', rc),
          ]),
        ),
        const SizedBox(height: 12),
        if (_tab == 'ads') ...[
          if (ads.isEmpty) EmptyState(icon: Icons.campaign_outlined, title: 'Активных объявлений нет', text: me ? 'Опубликуйте объявление, чтобы находить заказы или исполнителей.' : 'У пользователя сейчас нет активных объявлений.'),
          for (final a in ads)
            AdCard(ad: a, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: a)))),
        ] else if (_tab == 'pf') ...[
          if (me)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutBtn('Добавить пример работы', icon: Icons.add_photo_alternate_outlined, onTap: () => _addPortfolio(pf)),
            ),
          if (pf.isEmpty)
            EmptyState(icon: Icons.photo_library_outlined, title: 'Портфолио пока пусто', text: me ? 'Добавьте примеры выполненных работ, чтобы заказчики выбирали вас чаще.' : 'Пользователь ещё не добавил примеры работ.'),
          for (var i = 0; i < pf.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: cardDeco(p, r: 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: p.ac.withOpacity(.14), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.work_outline_rounded, color: p.ac),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((pf[i]['title'] ?? '').toString(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: p.tx)),
                    if ((pf[i]['desc'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text((pf[i]['desc'] ?? '').toString(), style: TextStyle(color: p.mu, fontSize: 13.5, height: 1.35)),
                    ],
                    if ((pf[i]['price'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(payF((pf[i]['price'] ?? '').toString()), style: TextStyle(color: p.ok, fontWeight: FontWeight.w800, fontSize: 14)),
                    ],
                  ]),
                ),
                if (me)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: p.dng, size: 20),
                    onPressed: () async {
                      final next = [...pf]..removeAt(i);
                      await Api.call('savePortfolio', {'list': next});
                      _load();
                    },
                  ),
              ]),
            ),
        ] else if (_tab == 'price') ...[
          if (me)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutBtn('Добавить услугу в прайс', icon: Icons.add_rounded, onTap: () => _addPricelist(pr)),
            ),
          if (pr.isEmpty)
            EmptyState(icon: Icons.receipt_long_outlined, title: 'Прайс-лист не заполнен', text: me ? 'Укажите базовые расценки на ваши услуги.' : 'Пользователь ещё не указал прайс услуг.'),
          for (var i = 0; i < pr.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: cardDeco(p, r: 16),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((pr[i]['title'] ?? '').toString(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: p.tx)),
                    if ((pr[i]['unit'] ?? '').toString().isNotEmpty)
                      Text((pr[i]['unit'] ?? '').toString(), style: TextStyle(color: p.mu, fontSize: 12.5)),
                  ]),
                ),
                Text(payF((pr[i]['price'] ?? '').toString()), style: TextStyle(color: p.ok, fontWeight: FontWeight.w800, fontSize: 15)),
                if (me)
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: p.dng, size: 18),
                    onPressed: () async {
                      final next = [...pr]..removeAt(i);
                      await Api.call('savePricelist', {'list': next});
                      _load();
                    },
                  ),
              ]),
            ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutBtn(d['can'] == true ? 'Оставить или изменить отзыв' : 'Все отзывы и ответы', icon: Icons.star_outline_rounded, onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewsPage(pid: widget.pid, name: name)));
              if (mounted) _load();
            }),
          ),
          if (revs.isEmpty) EmptyState(icon: Icons.rate_review_outlined, title: 'Отзывов пока нет', text: 'Отзывы появляются после выполнения задач и заказов.'),
          for (final r in revs)
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
        ],
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
