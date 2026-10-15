import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'settings.dart';
import 'site_defaults.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

// Тексты сайта: сначала значения по умолчанию, поверх них то, что сохранено в админке сайта (как Object.assign на сайте)
Future<Map<String, String>> loadSite() async {
  final j = await Api.call('site');
  final n = Map<String, String>.of(kSiteDefaults);
  final s = (j['site'] ?? '').toString();
  if (s.isNotEmpty) {
    final m = jsonDecode(s) as Map;
    m.forEach((k, v) {
      n[k.toString()] = (v ?? '').toString();
    });
  }
  return n;
}

List<List<String>> siteLines(String? s) => (s ?? '')
    .split('\n')
    .map((x) => x.trim())
    .where((x) => x.isNotEmpty)
    .map((x) => x.split('|').map((y) => y.trim()).toList())
    .toList();

List<String> sitePars(String? s) =>
    (s ?? '').split(RegExp(r'\n\s*\n')).map((x) => x.trim()).where((x) => x.isNotEmpty).toList();

String socialUrl(String v, String base) {
  final t = v.trim();
  if (t.startsWith('http')) return t;
  if (t.startsWith('@')) return '$base${t.substring(1)}';
  if (t.contains('/') || t.contains('.')) return 'https://$t';
  return '$base$t';
}

Future<void> openUrl(BuildContext context, Uri u) async {
  try {
    await launchUrl(u, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) toast(context, 'Не удалось открыть');
  }
}

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});
  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  Map<String, String> c = Map<String, String>.of(kSiteDefaults);
  bool loading = true;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final n = await loadSite();
      if (mounted) {
        setState(() {
          c = n;
          err = null;
        });
      }
    } catch (e) {
      final m = e is ApiError ? e.message : 'Не удалось загрузить тексты';
      if (mounted) setState(() => err = m);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _lead() async {
    final r = await askFields(
        context,
        'Заявка для бизнеса',
        [
          FieldSpec('Имя или компания', initial: S.i.name),
          FieldSpec('Телефон', initial: fmtPhone(S.i.phone), type: TextInputType.phone),
          const FieldSpec('Что нужно сделать?', multi: true),
        ],
        ok: 'Отправить');
    if (r == null) return;
    if (digitsOnly(r[1]).length < 8) {
      if (mounted) toast(context, 'Укажите телефон');
      return;
    }
    try {
      await Api.call('lead', {'name': r[0], 'phone': r[1], 'msg': r[2]});
      if (mounted) toast(context, 'Заявка отправлена, мы свяжемся с вами');
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e));
    }
  }

  Widget _h(Pal p, String t) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(t, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.tx)),
      );

  Widget _box(Pal p, String big, String small) => Container(
        width: (MediaQuery.of(context).size.width - 32 - 20) / 3,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: cardDeco(p, r: 16),
        child: Column(children: [
          GradText(big, size: 22),
          const SizedBox(height: 2),
          Text(small, textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 12.5)),
        ]),
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
          if (f != null) Icon(Icons.chevron_right, color: p.mu),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final stats = siteLines(c['stats']);
    final faq = siteLines(c['faq']);
    final reviews = siteLines(c['reviews']);
    final phone = (c['phone'] ?? '').trim();
    final email = (c['email'] ?? '').trim();
    final tg = (c['tg'] ?? '').trim();
    final vk = (c['vk'] ?? '').trim();
    final pill = (c['pill'] ?? '').trim();
    final h1a = (c['h1a'] ?? '').trim();
    final h1b = (c['h1b'] ?? '').trim();
    final lead = (c['lead'] ?? '').trim();
    return Scaffold(
      appBar: AppBar(title: const Text('О сервисе')),
      body: RefreshIndicator(
        color: p.ac,
        onRefresh: _load,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 0, 16, 30), children: [
          if (loading) LinearProgressIndicator(color: p.ac, backgroundColor: p.bd, minHeight: 3),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Не удалось обновить тексты с сайта ($err). Показаны сохранённые. Потяните вниз, чтобы повторить.',
                  style: TextStyle(color: p.dng, fontSize: 13)),
            ),
          if (pill.isNotEmpty || h1a.isNotEmpty || h1b.isNotEmpty || lead.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(18),
              decoration: cardDeco(p),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (pill.isNotEmpty) Tag(pill, p.ac),
                if (h1a.isNotEmpty) ...[const SizedBox(height: 10), Text(h1a, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.tx, height: 1.15))],
                if (h1b.isNotEmpty) GradText(h1b, size: 26),
                if (lead.isNotEmpty) ...[const SizedBox(height: 10), Text(lead, style: TextStyle(color: p.mu, fontSize: 15.5, height: 1.4))],
              ]),
            ),
          _h(p, 'О нас'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if ((c['year'] ?? '').isNotEmpty) _box(p, c['year']!, 'год основания'),
            for (final s in stats) _box(p, s.isNotEmpty ? s[0] : '', s.length > 1 ? s.sublist(1).join('|') : ''),
          ]),
          const SizedBox(height: 14),
          for (final t in sitePars(c['about']))
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(t, style: TextStyle(color: p.tx, fontSize: 15.5, height: 1.45))),
          if (reviews.isNotEmpty) ...[
            _h(p, 'Отзывы'),
            for (final r in reviews)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(p, r: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [for (var i = 0; i < 5; i++) const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFB400))]),
                  const SizedBox(height: 6),
                  Text(r.length > 2 ? r.sublist(2).join('|') : '', style: TextStyle(color: p.tx, height: 1.4)),
                  const SizedBox(height: 6),
                  Text(r.isNotEmpty ? r[0] : '', style: TextStyle(fontWeight: FontWeight.w800, color: p.tx)),
                  if (r.length > 1) Text(r[1], style: TextStyle(color: p.mu, fontSize: 13)),
                ]),
              ),
          ],
          if (faq.isNotEmpty) ...[
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
          ],
          _h(p, 'Для бизнеса'),
          for (final t in sitePars(c['biz']))
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(t, style: TextStyle(color: p.tx, fontSize: 15.5, height: 1.45))),
          const SizedBox(height: 4),
          GradBtn('Оставить заявку', icon: Icons.business_center_outlined, onTap: _lead),
          _h(p, 'Контакты'),
          if (phone.isNotEmpty)
            _contact(p, Icons.call_outlined, phone, () => openUrl(context, Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), '')))),
          if (email.isNotEmpty) _contact(p, Icons.mail_outline, email, () => openUrl(context, Uri(scheme: 'mailto', path: email))),
          if ((c['addr'] ?? '').trim().isNotEmpty) _contact(p, Icons.place_outlined, c['addr']!.trim(), null),
          if ((c['hours'] ?? '').trim().isNotEmpty) _contact(p, Icons.schedule, c['hours']!.trim(), null),
          if (tg.isNotEmpty) _contact(p, Icons.send_outlined, 'Telegram: $tg', () => openUrl(context, Uri.parse(socialUrl(tg, 'https://t.me/')))),
          if (vk.isNotEmpty) _contact(p, Icons.public, 'ВКонтакте: $vk', () => openUrl(context, Uri.parse(socialUrl(vk, 'https://vk.com/')))),
          if ((c['social'] ?? '').trim().isNotEmpty) _contact(p, Icons.share_outlined, c['social']!.trim(), null),
          const SizedBox(height: 14),
          Text(
              (c['copy'] ?? '').trim().isNotEmpty
                  ? c['copy']!.trim()
                  : '© 2026 ДелоЕсть. Сервис публикует объявления пользователей и не является стороной сделки.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.mu, fontSize: 12.5)),
        ]),
      ),
    );
  }
}

// ---------- О приложении ----------
class AboutAppPage extends StatefulWidget {
  const AboutAppPage({super.key});
  @override
  State<AboutAppPage> createState() => _AboutAppPageState();
}

class _AboutAppPageState extends State<AboutAppPage> {
  String tg = '', vk = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final n = await loadSite();
      if (mounted) {
        setState(() {
          tg = (n['tg'] ?? '').trim();
          vk = (n['vk'] ?? '').trim();
        });
      }
    } catch (_) {}
  }

  Widget _row(Pal p, IconData ic, String label, String value, VoidCallback? f) {
    return GestureDetector(
      onTap: f,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(p, r: 14),
        child: Row(children: [
          Icon(ic, color: p.ac, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: p.mu, fontSize: 12.5)),
              Text(value, style: TextStyle(color: p.tx, fontWeight: FontWeight.w700, fontSize: 15.5)),
            ]),
          ),
          if (f != null) Icon(Icons.chevron_right, color: p.mu),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final tgUrl = socialUrl(tg.isEmpty ? '@mchipta' : tg, 'https://t.me/');
    return Scaffold(
      appBar: AppBar(title: const Text('О приложении')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        const SizedBox(height: 8),
        const Center(child: Logo(size: 84)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Дело', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: p.tx)),
          const GradText('Есть', size: 28),
        ]),
        const SizedBox(height: 4),
        Center(child: Text('подработка рядом с домом', style: TextStyle(color: p.mu, fontSize: 15))),
        const SizedBox(height: 22),
        _row(p, Icons.info_outline, 'Версия приложения', kAppVersion, null),
        _row(p, Icons.code, 'Разработчик', '@mchipta', () => openUrl(context, Uri.parse('https://t.me/mchipta'))),
        _row(p, Icons.send_outlined, 'Telegram', tg.isEmpty ? '@mchipta' : tg, () => openUrl(context, Uri.parse(tgUrl))),
        if (vk.isNotEmpty)
          _row(p, Icons.public, 'ВКонтакте', vk, () => openUrl(context, Uri.parse(socialUrl(vk, 'https://vk.com/')))),
        const SizedBox(height: 10),
        Text('Приложение сервиса ДелоЕсть. Объявления и аккаунты общие с сайтом.',
            textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 13.5)),
      ]),
    );
  }
}
