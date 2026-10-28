import 'package:flutter/material.dart';
import 'ad_page.dart';
import 'auth.dart';
import 'info.dart';
import 'legal.dart';
import 'cities.dart';
import 'models.dart';
import 'site_defaults.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

/// Native Flutter version of the public website's landing page.
/// All marketplace actions still use the same native screens and Apps Script API.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _q = TextEditingController();
  final _qFocus = FocusNode();
  final _city = TextEditingController();
  final _cityFocus = FocusNode();
  int _mode = 0;
  bool _siteLoading = true;
  Map<String, String> _site = {
    ...kSiteDefaults,
    'pill': 'Более 27 000 выполненных дел с 2021 года',
    'h1a': 'Подработка рядом —',
    'h1b': 'за пару минут',
    'lead': 'Находите заказы на день или исполнителей на час. Без комиссии, без посредников, прямо в вашем городе.',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSite());
  }

  @override
  void dispose() {
    _q.dispose();
    _qFocus.dispose();
    _city.dispose();
    _cityFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSite() async {
    try {
      final j = await loadSite();
      if (!mounted) return;
      setState(() {
        _site = {
          ..._site,
          ...j,
          'pill': (j['pill'] ?? '').trim().isEmpty ? _site['pill']! : j['pill']!,
          'h1a': (j['h1a'] ?? '').trim().isEmpty ? _site['h1a']! : j['h1a']!,
          'h1b': (j['h1b'] ?? '').trim().isEmpty ? _site['h1b']! : j['h1b']!,
          'lead': (j['lead'] ?? '').trim().isEmpty ? _site['lead']! : j['lead']!,
        };
        _siteLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _siteLoading = false);
    }
  }

  String get _type => kTypes[_mode == 0 ? 0 : 1];

  void _search({String category = ''}) {
    S.i.pendingSearch = {
      'q': _q.text.trim(),
      'type': _type,
      'cat': category,
      'city': _city.text.trim(),
      'min': '',
      'max': '',
      'sort': '',
    };
    S.i.goTab(1);
  }

  void _category(String category) {
    S.i.pendingSearch = {
      'q': '',
      'type': _type,
      'cat': category,
      'city': _city.text.trim(),
      'min': '',
      'max': '',
      'sort': '',
    };
    S.i.goTab(1);
  }

  void _openInfo({required int section, required String title}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => InfoPage(only: section, title: title)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        final p = pal(context);
        final recent = List<Ad>.of(S.i.ads)..sort((a, b) => b.ts.compareTo(a.ts));
        final reviews = siteLines(_site['reviews']);
        final faq = siteLines(_site['faq']);
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: p.ac,
              onRefresh: () async {
                await Future.wait([S.i.loadAds(), _loadSite()]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: 28 + navPad(context)),
                children: [
                  _topBar(p),
                  _hero(p),
                  _sectionTitle(p, 'Свежие объявления', 'Новые предложения рядом с вами.', action: 'Все объявления', onAction: () => S.i.goTab(1)),
                  if (S.i.loading && recent.isEmpty)
                    Padding(padding: const EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: p.ac)))
                  else if (recent.isEmpty)
                    _emptyAds(p)
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(children: [
                        for (final ad in recent.take(S.i.logged ? 6 : 4))
                          AdCard(ad: ad, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: ad)))),
                      ]),
                    ),
                  _sectionTitle(p, 'Работа на любой вкус', 'Выберите направление и смотрите свежие объявления.'),
                  _categories(p),
                  if (!S.i.logged) ...[
                    _sectionTitle(p, 'Как это работает', 'Три простых шага — и дело найдено.'),
                    _how(p),
                    _business(p),
                  ],
                  if (!S.i.logged) ...[
                    _sectionTitle(p, 'Частые вопросы', 'Коротко о самом важном.'),
                    _faq(p, faq),
                  ],
                  _footer(p),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(Pal p) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 8),
        child: Row(children: [
          const Logo(size: 34),
          const SizedBox(width: 8),
          Text('Дело', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: p.tx)),
          const GradText('Есть', size: 21),
          const Spacer(),
        ]),
      );

  Widget _hero(Pal p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.bd),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.ac.withOpacity(.13), p.card, p.ac2.withOpacity(.08)],
          stops: const [0, .55, 1],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (!S.i.logged) ...[
          Text(_site['h1a'] ?? 'Подработка рядом —', textAlign: TextAlign.center,
              style: TextStyle(color: p.tx, fontWeight: FontWeight.w900, fontSize: 30, height: 1.08, letterSpacing: -.7)),
          const SizedBox(height: 2),
          GradText(_site['h1b'] ?? 'за пару минут', size: 30),
          const SizedBox(height: 12),
          Text(_site['lead'] ?? '', textAlign: TextAlign.center,
              style: TextStyle(color: p.mu, fontSize: 14.5, height: 1.45)),
        ] else ...[
          Text(
            S.i.name.isEmpty ? 'Рады видеть вас!' : 'Привет, ${S.i.name}!',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.tx, fontWeight: FontWeight.w900, fontSize: 27, height: 1.12),
          ),
          const SizedBox(height: 8),
          Text('Продолжайте находить заказы и исполнителей рядом.', textAlign: TextAlign.center,
              style: TextStyle(color: p.mu, fontSize: 14, height: 1.4)),
        ],
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.bd)),
          child: Row(children: [
            Expanded(child: _modeButton(p, 'Ищу подработку', 0)),
            Expanded(child: _modeButton(p, 'Ищу исполнителя', 1)),
          ]),
        ),
        const SizedBox(height: 12),
        _queryAutocomplete(p),
        const SizedBox(height: 8),
        _cityAutocomplete(p),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: GradBtn('Найти', icon: Icons.search_rounded, onTap: _search)),
        const SizedBox(height: 13),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final c in kCats.take(5))
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: GestureDetector(
                  onTap: () => _category(c.name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(color: p.card.withOpacity(.9), borderRadius: BorderRadius.circular(99), border: Border.all(color: p.bd)),
                    child: Text(c.name, style: TextStyle(fontSize: 11.5, color: p.tx, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _queryAutocomplete(Pal p) {
    return RawAutocomplete<String>(
      textEditingController: _q,
      focusNode: _qFocus,
      optionsBuilder: (value) => smartSuggest(value.text, S.i.ads.map((a) => a.title)),
      displayStringForOption: (option) => option,
      onSelected: (value) {
        _q.text = value;
        FocusScope.of(context).unfocus();
        _search();
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
        contextMenuBuilder: appContextMenu,
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        style: TextStyle(color: p.tx),
        decoration: deco(
          context,
          null,
          hint: _mode == 0 ? 'Например: ищу подработку грузчиком…' : 'Например: нужен грузчик на сегодня…',
          prefix: Icon(Icons.search_rounded, color: p.mu),
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.only(top: 5),
            constraints: const BoxConstraints(maxHeight: 240),
            width: MediaQuery.of(context).size.width - 64,
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.bd),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.14), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: ListView(
              padding: const EdgeInsets.all(6),
              shrinkWrap: true,
              children: [
                for (final option in options)
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: Icon(Icons.search_rounded, color: p.ac, size: 20),
                    title: Text(option, style: TextStyle(color: p.tx, fontWeight: FontWeight.w600)),
                    onTap: () => onSelected(option),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cityAutocomplete(Pal p) {
    return RawAutocomplete<String>(
      textEditingController: _city,
      focusNode: _cityFocus,
      optionsBuilder: (value) => citySuggest(value.text),
      displayStringForOption: (option) => option,
      onSelected: (value) { _city.text = value; FocusScope.of(context).unfocus(); },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(contextMenuBuilder: appContextMenu, 
        controller: controller,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _search(),
        style: TextStyle(color: p.tx),
        decoration: deco(context, null, hint: 'Ваш город', prefix: Icon(Icons.place_outlined, color: p.mu)),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.only(top: 5),
            constraints: const BoxConstraints(maxHeight: 240),
            width: MediaQuery.of(context).size.width - 28,
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.bd),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: ListView(
              padding: const EdgeInsets.all(6),
              shrinkWrap: true,
              children: [for (final option in options)
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: Icon(Icons.location_city_rounded, color: p.ac, size: 20),
                  title: Text(option, style: TextStyle(color: p.tx, fontWeight: FontWeight.w600)),
                  onTap: () => onSelected(option),
                )],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeButton(Pal p, String title, int n) {
    final selected = _mode == n;
    return GestureDetector(
      onTap: () { setState(() => _mode = n); _q.clear(); FocusScope.of(context).unfocus(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? LinearGradient(colors: [p.ac, p.ac2]) : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(title, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? Colors.white : p.mu)),
      ),
    );
  }

  Widget _stats(Pal p, List<List<String>> stats) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final items = stats.take(4).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [
          for (final s in items)
            SizedBox(
              width: (MediaQuery.sizeOf(context).width - 41) / 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                decoration: cardDeco(p, r: 16),
                child: Column(children: [
                  GradText(s.isNotEmpty ? s[0] : '', size: 25),
                  const SizedBox(height: 2),
                  Text(s.length > 1 ? s.sublist(1).join('|') : '', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: p.mu, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(Pal p, String title, String sub, {String? action, VoidCallback? onAction}) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Text(title, style: TextStyle(fontSize: 22, letterSpacing: -.35, height: 1.15, fontWeight: FontWeight.w900, color: p.tx))),
            if (action != null && onAction != null)
              TextButton(onPressed: onAction, style: TextButton.styleFrom(foregroundColor: p.ac, padding: const EdgeInsets.symmetric(horizontal: 5)), child: Text(action)),
          ]),
          const SizedBox(height: 5),
          Text(sub, style: TextStyle(fontSize: 13.5, color: p.mu, height: 1.35)),
        ]),
      );

  Widget _emptyAds(Pal p) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        child: Column(children: [
          Icon(Icons.work_outline_rounded, color: p.mu, size: 36),
          const SizedBox(height: 8),
          Text('Пока нет объявлений', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('Загляните позже или разместите первое предложение.', textAlign: TextAlign.center,
              style: TextStyle(color: p.mu, fontSize: 13)),
        ]),
      );

  Widget _categories(Pal p) {
    final width = (MediaQuery.sizeOf(context).width - 41) / 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(spacing: 9, runSpacing: 9, children: [
        for (final c in kCats)
          SizedBox(
            width: width,
            child: Material(
              color: p.card,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _category(c.name),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 102),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(11)),
                        child: Icon(c.icon, color: p.ac, size: 21)),
                    const SizedBox(height: 9),
                    Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, height: 1.15, fontWeight: FontWeight.w800, color: p.tx)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _how(Pal p) {
    const steps = [
      ['Создайте аккаунт', 'Регистрация занимает минуту: логин, имя и телефон.', Icons.person_outline_rounded],
      ['Найдите или разместите', 'Откликайтесь на объявления или публикуйте своё.', Icons.search_rounded],
      ['Договоритесь напрямую', 'Обсудите оплату и сроки. Мы не берём комиссию.', Icons.chat_bubble_outline_rounded],
    ];
    final width = (MediaQuery.sizeOf(context).width - 41) / 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(spacing: 9, runSpacing: 9, children: [
        for (var i = 0; i < steps.length; i++)
          SizedBox(
            width: width,
            child: Container(
              constraints: const BoxConstraints(minHeight: 150),
              padding: const EdgeInsets.all(14),
              decoration: cardDeco(p, r: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 36, height: 36, alignment: Alignment.center,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [p.ac, p.ac2]), borderRadius: BorderRadius.circular(11)),
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
                const SizedBox(height: 12),
                Text(steps[i][0] as String, style: TextStyle(color: p.tx, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 5),
                Text(steps[i][1] as String, style: TextStyle(color: p.mu, height: 1.35, fontSize: 12.5)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _reviews(Pal p, List<List<String>> reviews) {
    if (reviews.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 218,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: reviews.length > 8 ? 8 : reviews.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final r = reviews[i];
          return SizedBox(
            width: MediaQuery.sizeOf(context).width * .78,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDeco(p, r: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [for (var i = 0; i < 5; i++) const Icon(Icons.star_rounded, color: Color(0xFFFF9F1C), size: 17)]),
                const SizedBox(height: 10),
                Expanded(child: Text(r.length > 2 ? r[2] : '', maxLines: 5, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.tx, height: 1.4, fontSize: 13.5))),
                const SizedBox(height: 8),
                Text(r.isNotEmpty ? r[0] : '', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800)),
                if (r.length > 1) Text(r[1], style: TextStyle(color: p.mu, fontSize: 12)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _faq(Pal p, List<List<String>> faq) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        for (final f in faq.take(5))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd)),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent, splashColor: p.ac.withOpacity(.06)),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                iconColor: p.ac,
                collapsedIconColor: p.mu,
                title: Text(f.isNotEmpty ? f[0] : '', style: TextStyle(color: p.tx, fontSize: 14, fontWeight: FontWeight.w800)),
                children: [Text(f.length > 1 ? f.sublist(1).join('|') : '', style: TextStyle(color: p.mu, height: 1.4, fontSize: 13.5))],
              ),
            ),
          ),
      ]),
    );
  }

  Widget _business(Pal p) => Container(
        margin: const EdgeInsets.fromLTRB(14, 26, 14, 4),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [p.ac, p.ac2]), borderRadius: BorderRadius.circular(24)),
        child: Column(children: [
          const Icon(Icons.handshake_outlined, color: Colors.white, size: 32),
          const SizedBox(height: 10),
          const Text('Нужны люди на задачу?', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, height: 1.15)),
          const SizedBox(height: 7),
          const Text('Разместите объявление и получите отклики без комиссии.', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4)),
          const SizedBox(height: 14),
          OutBtn('Для бизнеса', icon: Icons.business_center_outlined,
              onTap: () => _openInfo(section: 2, title: 'Для бизнеса')),
        ]),
      );

  Widget _footer(Pal p) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Logo(size: 29),
            const SizedBox(width: 7),
            Text('Дело', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: p.tx)),
            const GradText('Есть', size: 18),
          ]),
          const SizedBox(height: 8),
          Text(_site['foot'] ?? '', textAlign: TextAlign.center,
              style: TextStyle(color: p.mu, fontSize: 12, height: 1.45)),
          const SizedBox(height: 18),
          Text('РАЗДЕЛЫ', style: TextStyle(color: p.mu, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: .8)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _footerLink('Все объявления', () => S.i.goTab(1), p),
            _footerLink('Для бизнеса', () => _openInfo(section: 2, title: 'Для бизнеса'), p),
            _footerLink('О нас', () => _openInfo(section: 0, title: 'О нас'), p),
            _footerLink('Личный кабинет', () => S.i.goTab(3), p),
            _footerLink('Частые вопросы', () => _openInfo(section: 1, title: 'Частые вопросы'), p),
          ]),
          const SizedBox(height: 12),
          Text('КОНТАКТЫ', style: TextStyle(color: p.mu, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: .8)),
          const SizedBox(height: 6),
          if ((_site['phone'] ?? '').trim().isNotEmpty)
            _contactLine(p, Icons.call_outlined, _site['phone']!, () {
              final digits = _site['phone']!.replaceAll(RegExp(r'[^+0-9]'), '');
              openUrl(context, Uri(scheme: 'tel', path: digits));
            }),
          if ((_site['email'] ?? '').trim().isNotEmpty)
            _contactLine(p, Icons.mail_outline_rounded, 'michipta@ya.ru', () {
              openUrl(context, Uri(scheme: 'mailto', path: 'michipta@ya.ru'));
            }),
          if ((_site['tg'] ?? '').trim().isNotEmpty)
            _contactLine(p, Icons.send_rounded, 'Telegram', () => openUrl(context, Uri.parse(socialUrl(_site['tg']!, 'https://t.me/')))),
          if ((_site['vk'] ?? '').trim().isNotEmpty)
            _contactLine(p, Icons.public_rounded, 'ВКонтакте', () => openUrl(context, Uri.parse(socialUrl(_site['vk']!, 'https://vk.com/')))),
          if ((_site['addr'] ?? '').trim().isNotEmpty)
            _contactLine(p, Icons.place_outlined, _site['addr']!, null),
          if ((_site['hours'] ?? '').trim().isNotEmpty)
            _contactLine(p, Icons.schedule_rounded, _site['hours']!, null),
          const SizedBox(height: 12),
          Text('ДОКУМЕНТЫ', style: TextStyle(color: p.mu, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: .8)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _footerLink('Пользовательское соглашение', () => openLegal(context, 'offer'), p),
            _footerLink('Политика конфиденциальности', () => openLegal(context, 'privacy'), p),
            _footerLink('Согласие на обработку данных', () => openLegal(context, 'consent'), p),
          ]),
          const SizedBox(height: 14),
          Text(_site['copy'] ?? '© ДелоЕсть. Все права защищены.', textAlign: TextAlign.center,
              style: TextStyle(color: p.mu, fontSize: 11.5, height: 1.4)),
          if (_siteLoading) Padding(padding: const EdgeInsets.only(top: 8), child: Center(child: SizedBox(height: 2, width: 40, child: LinearProgressIndicator(color: p.ac, minHeight: 2)))),
        ]),
      );

  Widget _footerLink(String label, VoidCallback onTap, Pal p) => Tap(
        onTap: onTap,
        scale: .96,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: p.bd),
          ),
          child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.tx)),
        ),
      );

  Widget _contactLine(Pal p, IconData icon, String label, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: p.ac, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(color: p.tx, fontSize: 13, height: 1.35))),
            if (onTap != null) Icon(Icons.open_in_new_rounded, color: p.mu, size: 14),
          ]),
        ),
      );
}
