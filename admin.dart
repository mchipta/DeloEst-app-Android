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
  late final TabController tc = TabController(length: 3, vsync: this);
  Map<String, dynamic>? d;
  bool loading = true;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    tc.dispose();
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
      if (mounted) toast(context, S.i.fail(e));
    }
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
                    labelColor: p.ac,
                    unselectedLabelColor: p.mu,
                    indicatorColor: p.ac,
                    dividerColor: p.bd,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    tabs: [Tab(text: 'Объявления'), Tab(text: 'Жалобы (${reports.length})'), Tab(text: 'Заявки (${leads.length})')],
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
                      _list(p, [
                        for (final r in leads) _lead(p, r),
                      ], 'Заявок нет'),
                    ]),
                  ),
                ]),
    );
  }

  Widget _report(Pal p, Map<String, dynamic> r, List<Map<String, dynamic>> ads) {
    Map<String, dynamic>? am;
    for (final a in ads) {
      if (a['id'].toString() == r['adId'].toString()) am = a;
    }
    final title = am == null ? 'Объявление удалено' : (am['title'] ?? '').toString();
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
        if (ad != null) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _small(p, 'Открыть', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: ad)))),
            if (ad.status != 'hidden') _small(p, 'Скрыть', () => _do('mod', {'id': ad.id, 's': 'hidden'}, 'Объявление скрыто')),
            _small(p, 'Удалить', () async {
              if (await _confirm('Удалить объявление «${ad.title}»?')) {
                await _do('mod', {'id': ad.id, 's': 'deleted'}, 'Объявление удалено');
              }
            }, color: p.dng),
          ]),
        ],
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
