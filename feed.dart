import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'ad_page.dart';
import 'auth.dart';
import 'map_page.dart';
import 'near.dart';
import 'models.dart';
import 'state.dart';
import 'skeleton.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});
  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final _q = TextEditingController();
  final _qFocus = FocusNode();
  final _cityC = TextEditingController();
  final _minC = TextEditingController();
  final _maxC = TextEditingController();
  String _cat = '', _type = '', _city = '', _min = '', _max = '', _sort = '', _rad = '';
  String _pt = '', _wh = ''; // тип оплаты и когда нужно (today / tomorrow / week)
  bool _urg = false; // только срочные
  bool _auto = false;

  @override
  void initState() {
    super.initState();
    _qFocus.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => S.i.loadAds().then((_) => Near.i.fill(S.i.ads)));
  }

  @override
  void dispose() {
    _q.dispose();
    _qFocus.dispose();
    _cityC.dispose();
    _minC.dispose();
    _maxC.dispose();
    super.dispose();
  }

  int get _activeFilters =>
      (_type.isNotEmpty ? 1 : 0) +
      (_city.trim().isNotEmpty ? 1 : 0) +
      (_min.isNotEmpty ? 1 : 0) +
      (_max.isNotEmpty ? 1 : 0) +
      (_sort.isNotEmpty ? 1 : 0) +
      (_pt.isNotEmpty ? 1 : 0) +
      (_wh.isNotEmpty ? 1 : 0) +
      (_urg ? 1 : 0) +
      (Near.i.has && _rad.isNotEmpty ? 1 : 0);

  String get _filterSummary => [
        if (_type.isNotEmpty) _type,
        if (_cat.isNotEmpty) _cat,
        if (_city.trim().isNotEmpty) _city.trim(),
        if (_min.isNotEmpty) 'от $_min ₽',
        if (_max.isNotEmpty) 'до $_max ₽',
        if (_sort == 'hi') 'Сначала дороже',
        if (_sort == 'lo') 'Сначала дешевле',
        if (_sort == 'soon') 'Сначала ближайшие по дате',
        if (_pt.isNotEmpty) payTypeLabel(_pt),
        if (_wh.isNotEmpty) _whLabel(_wh),
        if (_urg) 'Срочно',
      ].join(' · ');

  static String _whLabel(String w) => w == 'today' ? 'Сегодня' : w == 'tomorrow' ? 'Завтра' : w == 'week' ? 'На неделе' : '';

  static String _ptOf(Ad a) =>
      a.payType.isNotEmpty ? a.payType : (const {'h': 'hour', 'd': 'day', 't': 'job', 'm': 'month', 'n': 'neg'}[payParse(a.pay).p] ?? '');

  List<Ad> _filtered() {
    final q = _q.text.trim();
    final c = _city.trim().toLowerCase();
    final mn = int.tryParse(digitsOnly(_min)) ?? 0;
    final mx = int.tryParse(digitsOnly(_max)) ?? 0;
    final rad = Near.i.has ? (int.tryParse(_rad) ?? 0) : 0;
    final r = S.i.ads.where((a) {
      if (S.i.isBlocked(a.pid)) return false;
      final amt = adAmt(a);
      final n = amt > 0 ? amt.toDouble() : null;
      if (_type.isNotEmpty && a.type != _type) return false;
      if (_cat.isNotEmpty && a.category != _cat) return false;
      if (c.isNotEmpty && !a.city.toLowerCase().contains(c)) return false;
      if (q.isNotEmpty && !smartMatchAd(q, a.title, a.desc, a.category, a.city, a.addr)) return false;
      if (mn > 0 && (n == null || n < mn)) return false;
      if (mx > 0 && (n == null || n > mx)) return false;
      if (_urg && !a.urgent) return false;
      if (_pt.isNotEmpty && _ptOf(a) != _pt) return false;
      if (_wh.isNotEmpty) {
        final w = adWhen(a);
        if (w == null) return false;
        final now = DateTime.now(), t0 = DateTime(now.year, now.month, now.day);
        final df = DateTime(w.year, w.month, w.day).difference(t0).inDays;
        if (_wh == 'today' && df != 0) return false;
        if (_wh == 'tomorrow' && df != 1) return false;
        if (_wh == 'week' && (df < 0 || df > 7)) return false;
      }
      if (rad > 0) {
        final d = Near.i.dist(a);
        if (d == null || d.km > rad) return false;
      }
      return true;
    }).toList();
    final byNear = Near.i.has && (_sort.isEmpty || _sort == 'near');
    r.sort((a, b) {
      if (_sort == 'hi' || _sort == 'lo') {
        final p = adAmt(a) > 0 ? adAmt(a) : null, t = adAmt(b) > 0 ? adAmt(b) : null;
        if (p == null && t != null) return 1;
        if (t == null && p != null) return -1;
        if (p != null && t != null && p != t) return _sort == 'hi' ? t.compareTo(p) : p.compareTo(t);
      } else if (_sort == 'soon') {
        final x = adWhen(a), y = adWhen(b);
        if (x == null && y != null) return 1;
        if (y == null && x != null) return -1;
        if (x != null && y != null && x != y) return x.compareTo(y);
      } else if (byNear) {
        final x = Near.i.kmOr(a), y = Near.i.kmOr(b);
        if (x != y) return x.compareTo(y);
      }
      if (a.urgent != b.urgent && _sort.isEmpty) return a.urgent ? -1 : 1;
      return b.up.compareTo(a.up);
    });
    return r;
  }

  String _ssLabel(Map<String, String> s) {
    final parts = <String>[
      s['q'] ?? '',
      s['type'] ?? '',
      s['cat'] ?? '',
      s['city'] ?? '',
      (s['min'] ?? '').isEmpty ? '' : 'от ${s['min']} ₽',
      (s['max'] ?? '').isEmpty ? '' : 'до ${s['max']} ₽',
      s['sort'] == 'hi' ? 'дороже' : s['sort'] == 'lo' ? 'дешевле' : '',
      (s['rad'] ?? '').isEmpty ? '' : 'до ${s['rad']} км',
      (s['pt'] ?? '').isEmpty ? '' : payTypeLabel(s['pt']!),
      (s['wh'] ?? '').isEmpty ? '' : _whLabel(s['wh']!),
      s['urg'] == '1' ? 'Срочно' : '',
    ].where((e) => e.isNotEmpty).toList();
    return parts.join(' · ');
  }

  Map<String, String> _curSS() => {
        'q': _q.text.trim(),
        'type': _type,
        'cat': _cat,
        'city': _city.trim(),
        'min': _min,
        'max': _max,
        'sort': _sort,
        'rad': _rad,
        'pt': _pt,
        'wh': _wh,
        'urg': _urg ? '1' : '',
      };

  void _saveSearch() {
    final s = _curSS();
    final lab = _ssLabel(s);
    if (lab.isEmpty) {
      toast(context, 'Сначала задайте поиск или фильтр');
      return;
    }
    if (S.i.ss.any((x) => _ssLabel(x) == lab)) {
      toast(context, 'Такой поиск уже сохранён');
      return;
    }
    S.i.addSS(s);
    toast(context, S.i.logged ? 'Поиск сохранён. Пришлём push, когда появится новое' : 'Поиск сохранён в избранном');
  }

  void _useSearch(Map<String, String> s) {
    setState(() {
      _q.text = s['q'] ?? '';
      _type = s['type'] ?? '';
      _cat = s['cat'] ?? '';
      _city = s['city'] ?? '';
      _min = s['min'] ?? '';
      _max = s['max'] ?? '';
      _sort = s['sort'] ?? '';
      _rad = s['rad'] ?? '';
      _pt = s['pt'] ?? '';
      _wh = s['wh'] ?? '';
      _urg = s['urg'] == '1';
      _cityC.text = _city;
      _minC.text = _min;
      _maxC.text = _max;
    });
  }

  void _resetFilters() {
    setState(() {
      _type = '';
      _cat = '';
      _city = '';
      _min = '';
      _max = '';
      _sort = '';
      _rad = '';
      _pt = '';
      _wh = '';
      _urg = false;
      _cityC.clear();
      _minC.clear();
      _maxC.clear();
    });
  }

  Widget _fChip(Pal p, String label, bool on, VoidCallback f, {IconData? icon, Color? hue}) => Tap(
        onTap: () {
          haptic();
          f();
        },
        scale: .96,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.fromLTRB(icon != null ? 8 : 16, icon != null ? 8 : 11, 16, icon != null ? 8 : 11),
          decoration: BoxDecoration(
            color: on ? p.ac.withOpacity(.14) : p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? p.ac : p.bd, width: on ? 1.6 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: (hue ?? p.ac).withOpacity(.2), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, size: 18, color: hue ?? p.ac),
              ),
              const SizedBox(width: 9),
            ],
            Text(label, style: TextStyle(fontSize: 15, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? p.ac : p.tx)),
          ]),
        ),
      );

  // «Рядом со мной» живёт в фильтрах: определить место и сортировать по расстоянию
  Widget _geoTile(Pal p, VoidCallback after) {
    final on = Near.i.has;
    return Tap(
      onTap: () async {
        await _locate();
        after();
      },
      scale: .98,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? p.ac.withOpacity(.08) : p.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? p.ac : p.bd, width: on ? 1.6 : 1),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: p.ac.withOpacity(.14), borderRadius: BorderRadius.circular(14)),
            child: Near.i.busy
                ? Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.2, color: p.ac))
                : Icon(on ? Icons.my_location_rounded : Icons.location_searching_rounded, size: 22, color: p.ac),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(on ? 'Рядом со мной' : 'Определить, где я', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: p.tx)),
              const SizedBox(height: 2),
              Text(on ? 'Ближайшие объявления показываем первыми' : 'Покажем объявления рядом с вами',
                  style: TextStyle(fontSize: 12.5, color: p.mu)),
            ]),
          ),
          if (on) Icon(Icons.check_circle_rounded, color: p.ac, size: 22),
        ]),
      ),
    );
  }

  // Фильтры открываются отдельным экраном, как в Авито: категория, тип, где искать, оплата, сортировка
  Future<void> _openFilters() async {
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push<void>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          final p = pal(c);
          void upd(VoidCallback f) {
            setState(f);
            setS(() {});
          }

          Widget title(String t) => Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 10),
                child: Text(t, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.tx, letterSpacing: -.2)),
              );

          final sortItems = <List<String>>[
            if (Near.i.has) ['', 'Сначала ближайшие'] else ['', 'Сначала новые'],
            if (Near.i.has) ['new', 'Сначала новые'],
            ['soon', 'Сначала ближайшие по дате'],
            ['hi', 'Сначала с высокой оплатой'],
            ['lo', 'Сначала с низкой оплатой'],
          ];
          final curSort = (_sort == 'new' && !Near.i.has) ? '' : _sort;
          final n = _filtered().length;
          return Scaffold(
            appBar: AppBar(
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: Tap(
                  onTap: () => Navigator.pop(c),
                  scale: .9,
                  child: Container(
                    decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.close_rounded, color: p.tx, size: 22),
                  ),
                ),
              ),
              title: const Text('Фильтры'),
              centerTitle: true,
              actions: [
                TextButton(
                  onPressed: () {
                    haptic();
                    upd(() {
                      _resetFilters();
                      _cat = '';
                    });
                  },
                  child: Text('Сбросить', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ],
            ),
            body: Stack(children: [
              SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 0, 16, 110 + MediaQuery.of(c).viewInsets.bottom),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Категория', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.tx, letterSpacing: -.2)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final k in kCats)
                      _fChip(p, k.name, _cat == k.name, () => upd(() => _cat = _cat == k.name ? '' : k.name),
                          icon: catIcon(k.name), hue: catHue(k.name)),
                  ]),
                  title('Что нужно'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _fChip(p, 'Любое', _type.isEmpty, () => upd(() => _type = '')),
                    for (final t in kTypes) _fChip(p, t, _type == t, () => upd(() => _type = _type == t ? '' : t)),
                  ]),
                  title('Где искать'),
                  CityField(
                    controller: _cityC,
                    decoration: deco(c, 'Город', prefix: Icon(Icons.place_outlined, color: p.mu)),
                    onChanged: (v) => upd(() => _city = v),
                  ),
                  const SizedBox(height: 10),
                  _geoTile(p, () => upd(() {})),
                  if (Near.i.has) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _fChip(p, 'Любое расстояние', _rad.isEmpty, () => upd(() => _rad = '')),
                      for (final k in const [3, 5, 10, 25, 50]) _fChip(p, 'до $k км', _rad == '$k', () => upd(() => _rad = _rad == '$k' ? '' : '$k')),
                    ]),
                  ],
                  title('Оплата'),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        contextMenuBuilder: appContextMenu,
                        controller: _minC,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: p.tx),
                        decoration: deco(c, 'от, ₽'),
                        onChanged: (v) => upd(() => _min = digitsOnly(v)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        contextMenuBuilder: appContextMenu,
                        controller: _maxC,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: p.tx),
                        decoration: deco(c, 'до, ₽'),
                        onChanged: (v) => upd(() => _max = digitsOnly(v)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _fChip(p, 'Любая оплата', _pt.isEmpty, () => upd(() => _pt = '')),
                    for (final t in kPayTypes) _fChip(p, t[1], _pt == t[0], () => upd(() => _pt = _pt == t[0] ? '' : t[0])),
                  ]),
                  title('Когда'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _fChip(p, 'Любое время', _wh.isEmpty, () => upd(() => _wh = '')),
                    for (final w in const ['today', 'tomorrow', 'week']) _fChip(p, _whLabel(w), _wh == w, () => upd(() => _wh = _wh == w ? '' : w)),
                    _fChip(p, 'Только срочные', _urg, () => upd(() => _urg = !_urg)),
                  ]),
                  title('Сортировка'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final it in sortItems) _fChip(p, it[1], curSort == it[0], () => upd(() => _sort = it[0])),
                  ]),
                ]),
              ),
              // кнопка прижата к низу, как «Показать больше 1 тыс. объявлений» в Авито
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, 22, 16, 12 + MediaQuery.of(c).viewPadding.bottom),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.bg.withOpacity(0), p.bg, p.bg]),
                  ),
                  child: GradBtn(n == 0 ? 'Ничего не найдено' : 'Показать $n ${plural(n, 'объявление', 'объявления', 'объявлений')}', radius: 18, onTap: () => Navigator.pop(c)),
                ),
              ),
            ]),
          );
        },
      ),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([S.i, Near.i]),
      builder: (context, _) {
        final p = pal(context);
        // как только открыта вкладка «Поиск» — определяем место (один раз за запуск)
        if (S.i.tab == 1 && !_auto) {
          _auto = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await Near.i.auto();
            Near.i.fill(S.i.ads);
          });
        }
        final pend = S.i.pendingSearch;
        if (pend != null) {
          S.i.pendingSearch = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _useSearch(pend);
          });
        }
        final list = _filtered();
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: p.ac,
              onRefresh: S.i.loadAds,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _header(context, p, list.length)),
                  if (list.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: _empty(p))
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + navPad(context)),
                      sliver: S.i.feedMode == 1 ? _grid(context, list) : _rows(context, list),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // кнопка «Рядом со мной»: определить место и показать ближайшие объявления
  Future<void> _locate() async {
    haptic();
    final r = await Near.i.locate();
    if (!mounted) return;
    switch (r) {
      case NearResult.ok:
        setState(() => _sort = '');
        Near.i.fill(S.i.ads);
        toast(context, 'Показываем ближайшие объявления');
        break;
      case NearResult.off:
        _askSettings('Включите геолокацию на телефоне, чтобы видеть объявления рядом с вами.', false);
        break;
      case NearResult.forever:
        _askSettings('Доступ к геолокации выключен. Разрешите его в настройках приложения.', true);
        break;
      case NearResult.denied:
        toast(context, 'Разрешите доступ к геолокации, чтобы видеть ближайшие объявления');
        break;
      case NearResult.fail:
        toast(context, nearMsg(r), err: true);
        break;
    }
  }

  Future<void> _askSettings(String text, bool app) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Геолокация выключена'),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Не сейчас')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Открыть настройки')),
        ],
      ),
    );
    if (go == true) {
      if (app) {
        await Geolocator.openAppSettings();
      } else {
        await Geolocator.openLocationSettings();
      }
    }
  }

  Widget _rows(BuildContext context, List<Ad> list) => SliverList(
        delegate: SliverChildBuilderDelegate(
          (c, i) => AdCard(
            ad: list[i],
            mode: S.i.feedMode,
            onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => AdPage(ad: list[i]))),
          ),
          childCount: list.length,
        ),
      );

  // Плитка: два столбца на телефоне, три на широком экране
  Widget _grid(BuildContext context, List<Ad> list) {
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 700 ? 3 : 2;
    final w = (width - 32 - 10 * (cols - 1)) / cols;
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (c, i) => AdCard(
          ad: list[i],
          mode: 1,
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => AdPage(ad: list[i]))),
        ),
        childCount: list.length,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: w / 1.25 + 108,
      ),
    );
  }

  // Единый переключатель: список, плитка, компактно | карта (все найденные объявления метками)
  Widget _modeToggle(Pal p) {
    const icons = [Icons.view_agenda_outlined, Icons.grid_view_rounded, Icons.view_list_rounded];
    const tips = ['Список', 'Плитка', 'Компактно'];
    Widget seg(IconData icon, String tip, bool on, VoidCallback f, {Color? tint}) => Tooltip(
          message: tip,
          child: Tap(
            onTap: f,
            scale: .9,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 36,
              height: 30,
              decoration: BoxDecoration(
                color: on ? p.ac.withOpacity(.16) : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 19, color: on ? p.ac : (tint ?? p.mu)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.bd)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++) seg(icons[i], tips[i], S.i.feedMode == i, () => S.i.setFeedMode(i)),
        Container(width: 1, height: 18, margin: const EdgeInsets.symmetric(horizontal: 3), color: p.bd),
        seg(Icons.location_on_outlined, 'Карта', false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapPage(ads: _filtered()))), tint: p.ac),
      ]),
    );
  }

  Widget _empty(Pal p) {
    if (S.i.loading && S.i.ads.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Skeleton(child: Column(mainAxisSize: MainAxisSize.min, children: List.generate(6, (_) => const AdCardSkeleton()))),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(S.i.loadError != null ? Icons.wifi_off_rounded : Icons.search_off_rounded, size: 52, color: p.mu),
        const SizedBox(height: 12),
        Text(S.i.loadError ?? 'Ничего не найдено. Попробуйте изменить запрос или фильтры',
            textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Потяните вниз, чтобы обновить', style: TextStyle(color: p.mu, fontSize: 13)),
        if (S.i.loadError == null) ...[
          const SizedBox(height: 14),
          OutBtn('Сбросить поиск и фильтры', onTap: () {
            _q.clear();
            _resetFilters();
          }),
        ],
      ]),
    );
  }

  String _shortCat(String n) => n == 'Строительство и ремонт' ? 'Стройка и ремонт' : n == 'Репетиторство' ? 'Репетиторы' : n;

  // Категория: круглая цветная плитка и подпись под ней (цвета как на сайте)
  Widget _catTile(Pal p, String label, IconData icon, Color hue, bool sel, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Tap(
        onTap: onTap,
        scale: .94,
        child: SizedBox(
          width: 74,
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: sel ? LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                color: sel ? null : Color.alphaBlend(hue.withOpacity(.24), p.card),
                borderRadius: BorderRadius.circular(19),
                boxShadow: sel ? [BoxShadow(color: p.ac.withOpacity(.35), blurRadius: 16, offset: const Offset(0, 6))] : null,
              ),
              child: Icon(icon, size: 26, color: sel ? Colors.white : hue),
            ),
            const SizedBox(height: 7),
            Text(_shortCat(label),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, height: 1.2, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: p.tx)),
          ]),
        ),
      ),
    );
  }

  Widget _tagChip(Pal p, String text, VoidCallback onRemove) {
    return Tap(
      onTap: onRemove,
      scale: .96,
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 5, 7, 5),
        decoration: BoxDecoration(
          color: p.ac.withOpacity(.10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: p.ac.withOpacity(.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.tx)),
          const SizedBox(width: 4),
          Icon(Icons.close_rounded, size: 15, color: p.ac),
        ]),
      ),
    );
  }

  Widget _sugText(Pal p, String s) {
    final q = _q.text.trim().toLowerCase().replaceAll('ё', 'е');
    final sl = s.toLowerCase().replaceAll('ё', 'е');
    final base = TextStyle(fontSize: 15, color: p.tx, fontWeight: FontWeight.w600);
    if (q.isNotEmpty && sl.startsWith(q) && q.length <= s.length) {
      return Text.rich(TextSpan(children: [
        TextSpan(text: s.substring(0, q.length), style: base.copyWith(fontWeight: FontWeight.w800, color: p.ac)),
        TextSpan(text: s.substring(q.length), style: base),
      ]));
    }
    return Text(s, style: base);
  }

  Widget _header(BuildContext context, Pal p, int count) {
    final af = _activeFilters;
    final lab = _ssLabel(_curSS());
    // «Сохранить поиск» только когда пользователь что-то искал: текст, категория или фильтр
    final canSave = S.i.logged && lab.isNotEmpty;
    final saved = canSave && S.i.ss.any((x) => _ssLabel(x) == lab);
    final sugs = _qFocus.hasFocus
        ? smartSuggest(_q.text, S.i.ads.map((a) => a.title))
        : const <String>[];
    final tags = <List<Object>>[
      if (_type.isNotEmpty) [_type, () => setState(() => _type = '')],
      if (_city.trim().isNotEmpty)
        [
          _city.trim(),
          () => setState(() {
                _city = '';
                _cityC.clear();
              })
        ],
      if (_min.isNotEmpty)
        [
          'от $_min ₽',
          () => setState(() {
                _min = '';
                _minC.clear();
              })
        ],
      if (_max.isNotEmpty)
        [
          'до $_max ₽',
          () => setState(() {
                _max = '';
                _maxC.clear();
              })
        ],
      if (_sort == 'hi') ['Сначала дороже', () => setState(() => _sort = '')],
      if (_sort == 'lo') ['Сначала дешевле', () => setState(() => _sort = '')],
      if (_sort == 'soon') ['Ближайшие по дате', () => setState(() => _sort = '')],
      if (_pt.isNotEmpty) [payTypeLabel(_pt), () => setState(() => _pt = '')],
      if (_wh.isNotEmpty) [_whLabel(_wh), () => setState(() => _wh = '')],
      if (_urg) ['Срочно', () => setState(() => _urg = false)],
      if (Near.i.has && _rad.isNotEmpty) ['до $_rad км', () => setState(() => _rad = '')],
    ];
    OutlineInputBorder none = const OutlineInputBorder(borderSide: BorderSide.none);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // как в Авито: вытянутая капсула поиска и отдельная кнопка фильтров справа
          Row(children: [
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: _qFocus.hasFocus ? p.ac : p.bd, width: _qFocus.hasFocus ? 1.6 : 1),
                ),
                child: Row(children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search_rounded, color: p.tx, size: 24),
                  Expanded(
                    child: TextField(contextMenuBuilder: appContextMenu,
                      controller: _q,
                      focusNode: _qFocus,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      style: TextStyle(color: p.tx, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Найти подработку или услугу',
                        hintStyle: TextStyle(color: p.mu.withOpacity(.85)),
                        filled: false,
                        isDense: true,
                        border: none,
                        enabledBorder: none,
                        focusedBorder: none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                      ),
                    ),
                  ),
                  if (_q.text.isNotEmpty)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        haptic();
                        _q.clear();
                        setState(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.cancel_rounded, size: 20, color: p.mu.withOpacity(.7)),
                      ),
                    ),
                  const SizedBox(width: 6),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Tap(
              onTap: _openFilters,
              scale: .92,
              child: SizedBox(
                width: 52,
                height: 52,
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: af > 0 ? p.ac : p.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: af > 0 ? p.ac : p.bd),
                    ),
                    child: Icon(Icons.tune_rounded, size: 24, color: af > 0 ? Colors.white : p.tx),
                  ),
                  if (af > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: p.tx, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.bg, width: 2)),
                        child: Text('$af', style: TextStyle(color: p.bg, fontSize: 11, height: 1.1, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
          // Выпадающие подсказки умного поиска при вводе
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: sugs.isEmpty
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: cardDeco(p, r: 16),
                    child: Column(children: [
                      for (var i = 0; i < sugs.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: p.bd),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            haptic();
                            _q.value = TextEditingValue(
                              text: sugs[i],
                              selection: TextSelection.collapsed(offset: sugs[i].length),
                            );
                            _qFocus.unfocus();
                            setState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            child: Row(children: [
                              Icon(Icons.search_rounded, size: 18, color: p.ac),
                              const SizedBox(width: 10),
                              Expanded(child: _sugText(p, sugs[i])),
                              Icon(Icons.north_west_rounded, size: 16, color: p.mu),
                            ]),
                          ),
                        ),
                      ],
                    ]),
                  ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      // быстрые категории: цветные плитки
      SizedBox(
        height: 94,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
          children: [
            _catTile(p, 'Все', Icons.apps_rounded, p.ac, _cat.isEmpty, () => setState(() => _cat = '')),
            for (final k in kCats)
              _catTile(p, k.name, k.icon, catHue(k.name), _cat == k.name, () => setState(() => _cat = _cat == k.name ? '' : k.name)),
          ],
        ),
      ),
      if (tags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final t in tags) _tagChip(p, t[0] as String, t[1] as VoidCallback),
            GestureDetector(
              onTap: () { haptic(); _resetFilters(); },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text('Сбросить всё', style: TextStyle(color: p.ac, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            ),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 36,
            child: Row(children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: 'Найдено: ', style: TextStyle(color: p.mu, fontWeight: FontWeight.w600)),
                  TextSpan(text: '$count', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800)),
                ])),
              ),
              _modeToggle(p),
            ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topLeft,
            child: !canSave
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Tap(
                      onTap: _saveSearch,
                      scale: .96,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: saved ? p.card : p.ac.withOpacity(.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: saved ? p.bd : p.ac.withOpacity(.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 17, color: saved ? p.mu : p.ac),
                          const SizedBox(width: 5),
                          Text(saved ? 'Поиск сохранён' : 'Сохранить поиск',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: saved ? p.mu : p.tx)),
                        ]),
                      ),
                    ),
                  ),
          ),
        ]),
      ),
    ]);
  }
}
