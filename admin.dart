import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ad_page.dart';
import 'api.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  late final TabController tc = TabController(length: 4, vsync: this);
  Map<String, dynamic>? d;
  bool loading = true;
  String? err;

  final _pushTitle = TextEditingController(text: 'ДелоЕсть');
  final _pushBody = TextEditingController();
  final _pushTo = TextEditingController();
  bool _sendingPush = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    tc.dispose();
    _pushTitle.dispose();
    _pushBody.dispose();
    _pushTo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final j = await Api.call('adm');
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

  List<Map<String, dynamic>> _l(String k) {
    final v = d == null ? null : d![k];
    if (v is! List) return [];
    return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _do(String a, Map<String, dynamic> data, String okMsg) async {
    try {
      await Api.call(a, data);
      if (mounted) toast(context, okMsg);
      S.i.loadAds();
      await _load();
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e), err: true);
    }
  }

  Future<void> _sendPushBroadcast() async {
    final body = _pushBody.text.trim();
    if (body.isEmpty) {
      toast(context, 'Введите текст Push-уведомления');
      return;
    }
    setState(() => _sendingPush = true);
    try {
      await Api.call('sendPush', {
        'title': _pushTitle.text.trim().isEmpty ? 'ДелоЕсть' : _pushTitle.text.trim(),
        'body': body,
        'to': _pushTo.text.trim(),
      });
      _pushBody.clear();
      if (mounted) toast(context, 'Push-уведомление разослано!');
      await _load();
      S.i.refreshUnread();
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e), err: true);
    }
    if (mounted) setState(() => _sendingPush = false);
  }

  Future<bool> _confirm(String text) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Да')),
        ],
      ),
    );
    return r == true;
  }

  Widget _small(Pal p, String t, VoidCallback f, {Color? color}) => GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.bd)),
          child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color ?? p.tx)),
        ),
      );

  Widget _list(Pal p, List<Widget> items, String empty) => RefreshIndicator(
        color: p.ac,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (items.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Text(empty, textAlign: TextAlign.center, style: TextStyle(color: p.mu))),
            ...items,
          ],
        ),
      );

  Widget _adActions(Pal p, Ad ad, String login) {
    final hidden = ad.status == 'hidden';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          '${hidden ? 'Скрыто' : ad.status == 'closed' ? 'Закрыто автором' : 'Опубликовано'}  ·  ${ad.author}${login.isEmpty ? '' : ' ($login)'}',
          style: TextStyle(color: hidden ? p.dng : p.mu, fontSize: 12.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _small(p, hidden ? 'Показать' : 'Скрыть', () => _do('mod', {'id': ad.id, 's': hidden ? 'open' : 'hidden'}, hidden ? 'Объявление показано' : 'Объявление скрыто')),
        _small(p, ad.ver ? 'Снять проверку' : 'Проверить автора', () {
          if (login.isNotEmpty) _do('verify', {'login': login, 'on': !ad.ver}, ad.ver ? 'Проверка снята' : 'Автор проверен');
        }),
        if (login.isNotEmpty)
          _small(p, 'Бан автора', () async {
            if (await _confirm('Заблокировать аккаунт $login и скрыть его объявления?')) {
              await _do('ban', {'login': login, 'on': true}, 'Пользователь заблокирован');
            }
          }, color: p.dng),
        _small(p, 'Удалить', () async {
          if (await _confirm('Удалить объявление «${ad.title}»?')) {
            await _do('mod', {'id': ad.id, 's': 'deleted'}, 'Объявление удалено');
          }
        }, color: p.dng),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final ads = _l('ads');
    final reports = _l('reports');
    final pushes = _l('pushes');
    final leads = _l('leads');
    return Scaffold(
      appBar: AppBar(title: const Text('Админ-панель')),
      body: loading
          ? Center(child: CircularProgressIndicator(color: p.ac))
          : d == null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(err ?? 'Нет доступа', style: TextStyle(color: p.mu))))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Пользователей: ${d!['users']}  ·  Объявлений: ${ads.length}', style: TextStyle(color: p.mu, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  TabBar(
                    controller: tc,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: p.ac,
                    unselectedLabelColor: p.mu,
                    indicatorColor: p.ac,
                    dividerColor: p.bd,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    tabs: [
                      const Tab(text: 'Объявления'),
                      Tab(text: 'Жалобы (${reports.length})'),
                      Tab(text: 'Push-рассылка (${pushes.length})'),
                      Tab(text: 'Заявки (${leads.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(controller: tc, children: [
                      _list(p, [
                        for (final m in ads)
                          AdCard(
                            ad: Ad.fromJson(m),
                            showFav: false,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: Ad.fromJson(m)))),
                            footer: _adActions(p, Ad.fromJson(m), (m['login'] ?? '').toString()),
                          ),
                      ], 'Объявлений нет'),
                      _list(p, [
                        for (final r in reports) _report(p, r, ads),
                      ], 'Жалоб нет'),
                      _pushTab(p, pushes),
                      _list(p, [
                        for (final r in leads) _lead(p, r),
                      ], 'Заявок нет'),
                    ]),
                  ),
                ]),
    );
  }

  Widget _pushTab(Pal p, List<Map<String, dynamic>> pushes) {
    return RefreshIndicator(
      color: p.ac,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDeco(p, r: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(Icons.campaign_rounded, color: p.ac, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Отправить Push-уведомление', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: p.tx)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                'Уведомление придёт в системную шторку Android-приложения и всплывёт на сайте у всех пользователей (или у конкретного человека).',
                style: TextStyle(color: p.mu, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 12),
              TextField(
                contextMenuBuilder: appContextMenu,
                controller: _pushTitle,
                style: TextStyle(color: p.tx),
                decoration: deco(context, 'Заголовок', hint: 'ДелоЕсть'),
              ),
              const SizedBox(height: 10),
              TextField(
                contextMenuBuilder: appContextMenu,
                controller: _pushBody,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                style: TextStyle(color: p.tx),
                decoration: deco(context, 'Текст Push-уведомления', hint: 'Например: Новые подработки в вашем городе!'),
              ),
              const SizedBox(height: 4),
              TextField(
                contextMenuBuilder: appContextMenu,
                controller: _pushTo,
                style: TextStyle(color: p.tx),
                decoration: deco(context, 'Кому (оставьте пустым — ВСЕМ)', hint: 'Пусто = всем, либо email / pid'),
              ),
              const SizedBox(height: 12),
              GradBtn('Разослать Push-уведомление', icon: Icons.send_rounded, busy: _sendingPush, onTap: _sendPushBroadcast),
            ]),
          ),
          const SizedBox(height: 18),
          Text('История Push-рассылок', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.tx)),
          const SizedBox(height: 8),
          if (pushes.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text('Рассылок пока не было', textAlign: TextAlign.center, style: TextStyle(color: p.mu))),
          for (final item in pushes)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: cardDeco(p, r: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text((item['title'] ?? 'ДелоЕсть').toString(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: p.tx)),
                  ),
                  Text(ago(((item['ts'] as num?) ?? 0).toInt()), style: TextStyle(color: p.mu, fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                Text((item['body'] ?? '').toString(), style: TextStyle(color: p.tx, height: 1.35)),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      (item['to'] ?? '').toString().isEmpty ? 'Всем пользователям' : 'Адресно: ${item['to']}',
                      style: TextStyle(color: p.ac, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  _small(p, 'Удалить', () => _do('delPush', {'id': item['id']}, 'Push удалён'), color: p.dng),
                ]),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _report(Pal p, Map<String, dynamic> r, List<Map<String, dynamic>> ads) {
    final rawId = (r['adId'] ?? '').toString();
    final isUserRep = rawId.startsWith('user:');
    final targetPid = isUserRep ? rawId.substring(5) : '';
    Map<String, dynamic>? am;
    if (!isUserRep) {
      for (final a in ads) {
        if (a['id'].toString() == rawId) am = a;
      }
    }
    final title = isUserRep
        ? 'Жалоба на пользователя ($targetPid)'
        : am == null
            ? 'Объявление удалено ($rawId)'
            : (am['title'] ?? '').toString();
    final ad = am == null ? null : Ad.fromJson(am);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(p, r: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: p.tx)),
        const SizedBox(height: 4),
        Text((r['reason'] ?? '').toString(), style: TextStyle(color: p.tx, height: 1.35)),
        const SizedBox(height: 4),
        Text('От ${(r['login'] ?? '').toString()} · ${ago(((r['ts'] as num?) ?? 0).toInt())}', style: TextStyle(color: p.mu, fontSize: 12.5)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (ad != null) ...[
            _small(p, 'Открыть', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: ad)))),
            if (ad.status != 'hidden') _small(p, 'Скрыть', () => _do('mod', {'id': ad.id, 's': 'hidden'}, 'Объявление скрыто')),
            _small(p, 'Удалить', () async {
              if (await _confirm('Удалить объявление «${ad.title}»?')) {
                await _do('mod', {'id': ad.id, 's': 'deleted'}, 'Объявление удалено');
              }
            }, color: p.dng),
            if (ad.pid.isNotEmpty)
              _small(p, 'Заблокировать автора', () async {
                if (await _confirm('Заблокировать автора объявления «${ad.author}»?')) {
                  await _do('ban', {'pid': ad.pid, 'on': true}, 'Автор заблокирован');
                }
              }, color: p.dng),
          ],
          if (isUserRep && targetPid.isNotEmpty)
            _small(p, 'Заблокировать пользователя', () async {
              if (await _confirm('Заблокировать пользователя $targetPid?')) {
                await _do('ban', {'pid': targetPid, 'on': true}, 'Пользователь заблокирован');
              }
            }, color: p.dng),
        ]),
      ]),
    );
  }

  Widget _lead(Pal p, Map<String, dynamic> r) {
    final ph = (r['phone'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(p, r: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text((r['name'] ?? '').toString(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: p.tx))),
          Text(ago(((r['ts'] as num?) ?? 0).toInt()), style: TextStyle(color: p.mu, fontSize: 12)),
        ]),
        if (ph.isNotEmpty)
          GestureDetector(
            onTap: () => launchUrl(Uri(scheme: 'tel', path: ph.replaceAll(RegExp(r'[^\d+]'), ''))),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(ph, style: TextStyle(color: p.ac, fontWeight: FontWeight.w700)),
            ),
          ),
        if ((r['msg'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text((r['msg']).toString(), style: TextStyle(color: p.tx, height: 1.35)),
        ],
      ]),
    );
  }
}
