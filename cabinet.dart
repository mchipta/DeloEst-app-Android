import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ad_page.dart';
import 'api.dart';
import 'auth.dart';
import 'messages.dart';
import 'models.dart';
import 'post.dart';
import 'settings.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class CabinetPage extends StatefulWidget {
  const CabinetPage({super.key});
  @override
  State<CabinetPage> createState() => _CabinetPageState();
}

class _CabinetPageState extends State<CabinetPage> with SingleTickerProviderStateMixin {
  late final TabController tc = TabController(length: 3, vsync: this);
  Map<String, dynamic>? data;
  bool loading = false;
  String? err;
  int _tick = -1;

  @override
  void initState() {
    super.initState();
    S.i.addListener(_onState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onState());
  }

  @override
  void dispose() {
    S.i.removeListener(_onState);
    tc.dispose();
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
      Api.call('rseen').then((_) {}, onError: (_) {});
      if (mounted) setState(() => data = j);
    } catch (e) {
      final m = S.i.fail(e);
      if (mounted) setState(() => err = m);
    }
    if (mounted) setState(() => loading = false);
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        final p = pal(context);
        return Scaffold(
          appBar: AppBar(title: Text(S.i.logged ? 'Кабинет' : 'Войти'), actions: [
            if (S.i.logged)
              IconButton(
                tooltip: 'Настройки',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
              ),
            _themeBtn(p),
          ]),
          body: S.i.logged
              ? Column(children: [
                  _header(p),
                  TabBar(
                    controller: tc,
                    labelColor: p.ac,
                    unselectedLabelColor: p.mu,
                    indicatorColor: p.ac,
                    dividerColor: p.bd,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    tabs: const [Tab(text: 'Объявления'), Tab(text: 'Отклики мне'), Tab(text: 'Мои отклики')],
                  ),
                  Expanded(
                    child: TabBarView(controller: tc, children: [_myAds(p), _inbox(p), _sent(p)]),
                  ),
                ])
              : const NeedAuth(
                  icon: Icons.person_outline,
                  title: 'Ваш кабинет',
                  text: 'Войдите, чтобы видеть свои объявления, отклики и управлять ими.'),
        );
      },
    );
  }

  Widget _themeBtn(Pal p) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: 'Тема',
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => S.i.setTheme(dark ? ThemeMode.light : ThemeMode.dark),
    );
  }

  Widget _header(Pal p) {
    final av = (S.i.user?['avatar'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(p),
      child: Row(children: [
        Avatar(S.i.name, data: av, size: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(S.i.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.tx)),
            Text(S.i.phone.isEmpty ? S.i.login : S.i.phone, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontSize: 13.5)),
          ]),
        ),
        TextButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Выйти из аккаунта?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Выйти')),
                ],
              ),
            );
            if (ok == true) {
              await S.i.setUser(null);
              S.i.loadAds();
            }
          },
          icon: Icon(Icons.logout, size: 18, color: p.mu),
          label: Text('Выйти', style: TextStyle(color: p.mu)),
        ),
      ]),
    );
  }

  Widget _wrap(Pal p, List<Widget> items, String empty) {
    return RefreshIndicator(
      color: p.ac,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          if (loading && data == null) Padding(padding: const EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: p.ac))),
          if (err != null && data == null) Padding(padding: const EdgeInsets.all(24), child: Text(err!, textAlign: TextAlign.center, style: TextStyle(color: p.mu))),
          if (data != null && items.isEmpty)
            Padding(padding: const EdgeInsets.all(32), child: Text(empty, textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 15))),
          ...items,
        ],
      ),
    );
  }

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

  Widget _myAds(Pal p) {
    final items = <Widget>[];
    for (final m in _list('ads')) {
      final ad = Ad.fromJson(m);
      final open = ad.status == 'open';
      final hidden = ad.status == 'hidden';
      items.add(AdCard(
        ad: ad,
        showFav: false,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: ad))),
        footer: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              '${hidden ? 'Скрыто модератором' : open ? 'Опубликовано' : 'Закрыто'}  ·  ${ad.opens} ${plural(ad.opens, 'просмотр', 'просмотра', 'просмотров')}',
              style: TextStyle(color: hidden ? p.dng : p.mu, fontSize: 13, fontWeight: FontWeight.w600)),
          if (!hidden) ...[
            const SizedBox(height: 10),
            Row(children: [
              _small(p, open ? 'Закрыть' : 'Открыть', () => _act('status', {'id': ad.id, 's': open ? 'closed' : 'open'}, open ? 'Объявление закрыто' : 'Объявление снова опубликовано')),
              const SizedBox(width: 8),
              _small(p, 'Изменить', () async {
                final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => PostScreen(edit: ad, embedded: false)));
                if (r == true) _load();
              }),
            ]),
          ],
        ]),
      ));
    }
    return _wrap(p, items, 'Вы ещё не размещали объявления.\nНажмите «Разместить» внизу.');
  }

  Widget _chip(Pal p, String text, Color c) => Tag(text, c);

  void _chat(String pid, String name) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(pid: pid, name: name)));
  }

  Widget _inbox(Pal p) {
    final items = <Widget>[];
    for (final r in _list('inbox')) {
      final st = (r['st'] ?? '').toString();
      final rid = (r['rid'] ?? '').toString();
      final ph = (r['phone'] ?? '').toString();
      final msg = (r['msg'] ?? '').toString();
      items.add(Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(p),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar((r['name'] ?? '').toString(), size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((r['name'] ?? '').toString(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: p.tx)),
                Text('на «${(r['ad'] ?? '').toString()}» · ${ago(int.tryParse((r['ts'] ?? '0').toString()) ?? 0)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontSize: 12.5)),
              ]),
            ),
            if (st == 'chosen') _chip(p, 'Исполнитель', p.ok),
            if (st == 'done') _chip(p, 'Выполнено', p.ok),
            if (st == 'rejected') _chip(p, 'Отклонён', p.mu),
            if (st == '') _chip(p, 'Новый', p.ac),
          ]),
          if (msg.isNotEmpty) ...[const SizedBox(height: 8), Text(msg, style: TextStyle(color: p.tx, height: 1.35))],
          if (ph.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _call(ph),
              child: Row(children: [
                Icon(Icons.call_outlined, size: 17, color: p.ac),
                const SizedBox(width: 6),
                Text(ph, style: TextStyle(color: p.ac, fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if ((r['pid'] ?? '').toString().isNotEmpty)
              _small(p, 'Написать', () => _chat((r['pid']).toString(), (r['name'] ?? '').toString())),
            if (st == '' || st == 'seen') _small(p, 'Выбрать исполнителем', () => _act('pick', {'rid': rid}, 'Исполнитель выбран'), fill: true),
            if (st == 'chosen') _small(p, 'Работа выполнена', () => _act('fin', {'rid': rid}, 'Отмечено как выполнено'), fill: true),
            if (st != 'done' && st != 'rejected') _small(p, 'Отклонить', () => _act('rej', {'rid': rid}, 'Отклик отклонён'), color: p.dng),
            if (st == 'rejected') _small(p, 'Убрать', () => _act('rdel', {'rid': rid}, 'Отклик убран')),
          ]),
        ]),
      ));
    }
    return _wrap(p, items, 'Откликов пока нет.\nКак только кто-то откликнется на ваше объявление, он появится здесь.');
  }

  Widget _sent(Pal p) {
    final items = <Widget>[];
    for (final r in _list('sent')) {
      final st = (r['st'] ?? '').toString();
      final adId = (r['adId'] ?? '').toString();
      Ad? found;
      for (final a in S.i.ads) {
        if (a.id == adId) found = a;
      }
      final label = st == 'chosen'
          ? 'Вас выбрали исполнителем'
          : st == 'done'
              ? 'Выполнено'
              : st == 'rejected'
                  ? 'Отклонён'
                  : 'Ожидает ответа';
      final col = (st == 'chosen' || st == 'done') ? p.ok : st == 'rejected' ? p.mu : p.ac;
      items.add(GestureDetector(
        onTap: found == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: found!))),
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
            Text('${payF((r['pay'] ?? '').toString())}${(r['city'] ?? '').toString().isEmpty ? '' : ' · ${r['city']}'}', style: TextStyle(color: p.ok, fontWeight: FontWeight.w700, fontSize: 13.5)),
            if ((r['msg'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Вы: ${r['msg']}', style: TextStyle(color: p.mu, height: 1.35)),
            ],
            const SizedBox(height: 4),
            Text(ago(int.tryParse((r['ts'] ?? '0').toString()) ?? 0), style: TextStyle(color: p.mu, fontSize: 12.5)),
            if ((r['pid'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: _small(p, 'Написать автору', () => _chat((r['pid']).toString(), '')),
              ),
            ],
          ]),
        ),
      ));
    }
    return _wrap(p, items, 'Вы ещё не откликались на объявления.');
  }
}
