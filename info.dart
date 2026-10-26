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
  final int? only; // показать один раздел без переключателя: 1 — вопросы, 3 — контакты
  final String title;
  const InfoPage({super.key, this.only, this.title = 'О сервисе'});
  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  Map<String, String> c = Map<String, String>.of(kSiteDefaults);
  bool loading = true;
  String? err;
  int sec = 0;

  @override
  void initState() {
    super.initState();
    sec = widget.only ?? 0;
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

  Widget _contactW(Pal p, Widget lead, String text, VoidCallback? f) {
    return GestureDetector(
      onTap: f,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: cardDeco(p, r: 14),
        child: Row(children: [
          lead,
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: p.tx, fontWeight: FontWeight.w600, fontSize: 15))),
          if (f != null) Icon(Icons.chevron_right, color: p.mu),
        ]),
      ),
    );
  }

  Widget _icoBox(Pal p, IconData ic) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(12)),
        child: Icon(ic, color: p.ac, size: 22),
      );

  Widget _seg(Pal p) {
    const names = ['О нас', 'Вопросы', 'Бизнесу', 'Контакты'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd)),
      child: Row(children: [
        for (var i = 0; i < names.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => sec = i),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: sec == i ? LinearGradient(colors: [p.ac, p.ac2]) : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(names[i], style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: sec == i ? Colors.white : p.tx)),
              ),
            ),
          ),
      ]),
    );
  }

  List<Widget> _about(Pal p) {
    final pill = (c['pill'] ?? '').trim();
    final h1a = (c['h1a'] ?? '').trim();
    final h1b = (c['h1b'] ?? '').trim();
    final lead = (c['lead'] ?? '').trim();
    return [
      if (pill.isNotEmpty || h1a.isNotEmpty || h1b.isNotEmpty || lead.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: cardDeco(p),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (h1a.isNotEmpty) ...[const SizedBox(height: 10), Text(h1a, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: p.tx, height: 1.15))],
            if (h1b.isNotEmpty) GradText(h1b, size: 24),
            if (lead.isNotEmpty) ...[const SizedBox(height: 10), Text(lead, style: TextStyle(color: p.mu, fontSize: 15, height: 1.4))],
          ]),
        ),
      for (final e in sitePars(c['about']).asMap().entries) _aboutCard(p, e.value, e.key == 0),
    ];
  }

  // Абзац «О нас» в карточке с цветной полоской слева; первый абзац крупнее
  Widget _aboutCard(Pal p, String text, bool first) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        decoration: cardDeco(p, r: 18),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Text(text,
                    style: TextStyle(
                        color: p.tx,
                        fontSize: first ? 16.5 : 15.5,
                        fontWeight: first ? FontWeight.w600 : FontWeight.w400,
                        height: 1.5)),
              ),
            ),
          ]),
        ),
      );

  List<Widget> _faq(Pal p) {
    final faq = siteLines(c['faq']);
    if (faq.isEmpty) return [Padding(padding: const EdgeInsets.all(24), child: Text('Вопросов пока нет', style: TextStyle(color: p.mu)))];
    return [
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
                children: [Text(faq[i].skip(1).join('|'), style: TextStyle(color: p.mu, fontSize: 15, height: 1.45))],
              ),
            ),
        ]),
      ),
    ];
  }

  List<Widget> _biz(Pal p) => [
        for (final t in sitePars(c['biz']))
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: TextStyle(color: p.tx, fontSize: 15.5, height: 1.5))),
        const SizedBox(height: 6),
        GradBtn('Оставить заявку', icon: Icons.business_center_outlined, onTap: _lead),
      ];

  List<Widget> _contacts(Pal p) {
    final phone = (c['phone'] ?? '').trim();
    final email = (c['email'] ?? '').trim();
    final tg = (c['tg'] ?? '').trim();
    final vk = (c['vk'] ?? '').trim();
    return [
      if (phone.isNotEmpty)
        _contactW(p, _icoBox(p, Icons.call_outlined), phone, () => openUrl(context, Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), '')))),
      if (email.isNotEmpty) _contactW(p, _icoBox(p, Icons.mail_outline), email, () => openUrl(context, Uri(scheme: 'mailto', path: email))),
      if ((c['addr'] ?? '').trim().isNotEmpty) _contactW(p, _icoBox(p, Icons.place_outlined), c['addr']!.trim(), null),
      if ((c['hours'] ?? '').trim().isNotEmpty) _contactW(p, _icoBox(p, Icons.schedule), c['hours']!.trim(), null),
      if (tg.isNotEmpty) _contactW(p, const BrandIcon('tg'), tg, () => openUrl(context, Uri.parse(socialUrl(tg, 'https://t.me/')))),
      if (vk.isNotEmpty) _contactW(p, const BrandIcon('vk'), vk, () => openUrl(context, Uri.parse(socialUrl(vk, 'https://vk.com/')))),
      if ((c['social'] ?? '').trim().isNotEmpty) _contactW(p, _icoBox(p, Icons.share_outlined), c['social']!.trim(), null),
      const SizedBox(height: 10),
      Text(
          (c['copy'] ?? '').trim().isNotEmpty
              ? c['copy']!.trim()
              : '© 2026 ДелоЕсть. Сервис публикует объявления пользователей и не является стороной сделки.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.mu, fontSize: 12.5)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        color: p.ac,
        onRefresh: _load,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
          if (loading) LinearProgressIndicator(color: p.ac, backgroundColor: p.bd, minHeight: 3),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Не удалось обновить тексты с сайта ($err). Показаны сохранённые. Потяните вниз, чтобы повторить.',
                  style: TextStyle(color: p.dng, fontSize: 13)),
            ),
          if (widget.only == null) ...[_seg(p), const SizedBox(height: 16)],
          ...(sec == 0 ? _about(p) : sec == 1 ? _faq(p) : sec == 2 ? _biz(p) : _contacts(p)),
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
  bool checkingUpdate = false;

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

  Future<void> _checkUpdate() async {
    setState(() => checkingUpdate = true);
    final hasNew = await S.i.checkAppUpdate(silent: false);
    if (!mounted) return;
    setState(() => checkingUpdate = false);
    final dl = S.i.updateUrl ?? 'https://github.com/mchipta/DeloEst-app-Android/releases/latest/download/DeloEst.apk';
    final name = S.i.updateName ?? S.i.updateTag ?? 'последняя сборка';
    final p = pal(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: p.card,
        title: Text(hasNew ? 'Доступно обновление!' : 'Проверка обновлений', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800)),
        content: Text(
          hasNew
              ? 'Вышла новая сборка: $name.\nСкачать и установить свежий DeloEst.apk поверх текущей версии?'
              : 'У вас установлена версия $kAppVersion (последний релиз на GitHub: $name).\nПри желании вы можете скачать свежий APK-файл напрямую.',
          style: TextStyle(color: p.mu, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Закрыть', style: TextStyle(color: p.mu))),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Скачать APK', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      if (S.i.updateTag != null) S.i.prefs.setString('seen_release_tag', S.i.updateTag!);
      openUrl(context, Uri.parse(dl));
    }
  }

  String _handle(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.pathSegments.isEmpty) return url;
    return u.pathSegments.last;
  }

  Widget _soc(Pal p, String kind, String title, String url) {
    return Expanded(
      child: GestureDetector(
        onTap: () => openUrl(context, Uri.parse(url)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          decoration: cardDeco(p, r: 18),
          child: Column(children: [
            BrandIcon(kind, size: 52),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(color: p.tx, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(_handle(url), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final tgUrl = socialUrl(tg.isEmpty ? 'mchipta' : tg, 'https://t.me/');
    final vkUrl = socialUrl(vk.isEmpty ? 'mchipta' : vk, 'https://vk.com/');
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
        Center(child: Text('Версия $kAppVersion', style: TextStyle(color: p.mu, fontSize: 15))),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(p, r: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.system_update_rounded, color: p.ac, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Автообновление приложения', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(
                    S.i.updateName != null ? 'Последняя сборка: ${S.i.updateName}' : 'Единая цифровая подпись — обновления ставятся поверх',
                    style: TextStyle(color: p.mu, fontSize: 12.5),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            GradBtn('Проверить обновление', icon: Icons.refresh_rounded, busy: checkingUpdate, onTap: _checkUpdate),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(p, r: 18),
          child: Row(children: [
            const Avatar('mchipta', size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Разработчик', style: TextStyle(color: p.mu, fontSize: 13)),
                Text('mchipta', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800, fontSize: 19)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _soc(p, 'tg', 'Telegram', tgUrl),
          const SizedBox(width: 12),
          _soc(p, 'vk', 'ВКонтакте', vkUrl),
        ]),
        const SizedBox(height: 18),
        Text('Приложение сервиса ДелоЕсть. Объявления, аккаунты и сообщения общие с сайтом.',
            textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 13.5)),
      ]),
    );
  }
}
