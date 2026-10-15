import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'settings.dart';
import 'site_defaults.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});
  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  Map<String, String> c = Map<String, String>.of(kSiteDefaults);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await Api.call('site');
      final s = (j['site'] ?? '').toString();
      if (s.isEmpty) return;
      final m = jsonDecode(s) as Map;
      final n = Map<String, String>.of(kSiteDefaults);
      m.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) n[k.toString()] = v.toString();
      });
      if (mounted) setState(() => c = n);
    } catch (_) {}
  }

  List<List<String>> _lines(String? s) => (s ?? '')
      .split('\n')
      .map((x) => x.trim())
      .where((x) => x.isNotEmpty)
      .map((x) => x.split('|').map((y) => y.trim()).toList())
      .toList();

  List<String> _paras(String? s) =>
      (s ?? '').split(RegExp(r'\n\s*\n')).map((x) => x.trim()).where((x) => x.isNotEmpty).toList();

  Future<void> _open(Uri u) async {
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) toast(context, 'Не удалось открыть');
    }
  }

  Future<void> _lead() async {
    final r = await askFields(
        context,
        'Заявка для бизнеса',
        [
          FieldSpec('Имя или компания', initial: S.i.name),
          FieldSpec('Телефон', initial: S.i.phone, type: TextInputType.phone),
          const FieldSpec('Что нужно сделать?', multi: true),
        ],
        ok: 'Отправить');
    if (r == null) return;
    if (r[1].replaceAll(RegExp(r'\D'), '').length < 8) {
      if (mounted) toast(context, 'Укажите телефон');
      return;
    }
    try {
      await Api.call('lead', {'name': r[0], 'phone': r[1], 'msg': r[2]});
      if (mounted) toast(context, 'Заявка отправлена');
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e));
    }
  }

  Widget _h(Pal p, String t) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(t, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.tx)),
      );

  Widget _box(Pal p, String big, String small) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: cardDeco(p, r: 16),
          child: Column(children: [
            GradText(big, size: 24),
            const SizedBox(height: 2),
            Text(small, textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 12.5)),
          ]),
        ),
      );

  Widget _contact(Pal p, IconData ic, String text, VoidCallback? f) {
    return GestureDetector(
      onTap: f,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(p, r: 14),
        child: Row(children: [
          Icon(ic, color: p.ac, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: p.tx, fontWeight: FontWeight.w600, fontSize: 15))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final stats = _lines(c['stats']);
    final faq = _lines(c['faq']);
    final phone = (c['phone'] ?? '').toString();
    final email = (c['email'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: const Text('О сервисе')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 30), children: [
        _h(p, 'О нас'),
        Row(children: [
          _box(p, c['year'] ?? '', 'год основания'),
          for (final s in stats.take(2)) _box(p, s.isNotEmpty ? s[0] : '', s.length > 1 ? s[1] : ''),
        ]),
        const SizedBox(height: 14),
        for (final t in _paras(c['about']))
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(t, style: TextStyle(color: p.tx, fontSize: 15.5, height: 1.45))),
        _h(p, 'Частые вопросы'),
        Container(
          decoration: cardDeco(p, r: 16),
          child: Column(children: [
            for (var i = 0; i < faq.length; i++)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  iconColor: p.ac,
                  collapsedIconColor: p.mu,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: Text(faq[i][0], style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: p.tx)),
                  children: [Text(faq[i].skip(1).join('|'), style: TextStyle(color: p.mu, fontSize: 15, height: 1.4))],
                ),
              ),
          ]),
        ),
        _h(p, 'Для бизнеса'),
        for (final t in _paras(c['biz']))
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(t, style: TextStyle(color: p.tx, fontSize: 15.5, height: 1.45))),
        const SizedBox(height: 4),
        GradBtn('Оставить заявку', icon: Icons.business_center_outlined, onTap: _lead),
        _h(p, 'Контакты'),
        if (phone.isNotEmpty)
          _contact(p, Icons.call_outlined, phone, () => _open(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), '')))),
        if (email.isNotEmpty) _contact(p, Icons.mail_outline, email, () => _open(Uri(scheme: 'mailto', path: email))),
        if ((c['addr'] ?? '').isNotEmpty) _contact(p, Icons.place_outlined, c['addr']!, null),
        if ((c['hours'] ?? '').isNotEmpty) _contact(p, Icons.schedule, c['hours']!, null),
        if ((c['social'] ?? '').isNotEmpty) _contact(p, Icons.send_outlined, c['social']!, null),
        const SizedBox(height: 14),
        Text(c['copy'] ?? '© 2026 ДелоЕсть. Сервис публикует объявления пользователей и не является стороной сделки.',
            textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 12.5)),
      ]),
    );
  }
}
