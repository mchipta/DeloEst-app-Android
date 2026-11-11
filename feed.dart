import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:latlong2/latlong.dart' show LatLng;
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
  String _autoCity = ''; // город, подставленный по геолокации
  bool _autoCityTried = false;
  bool _nbBusy = false;
  bool _first = true; // «Сначала из города»: город первым, затем объявления в радиусе
  VoidCallback? _whereRefresh; // перерисовать открытый экран «Где искать»
  int get _radKm => int.tryParse(_rad) ?? 0;
  VoidCallback? _filterRefresh; // перерисовать открытый экран фильтров
  String _pt = '', _wh = ''; // тип оплаты и когда нужно (today / tomorrow / week)
  bool _urg = false; // только срочные
  bool _qfPhoto = false; // с фото
  bool _qfVer = false; // проверенные (ver или ИНН)
  bool _auto = false;
  int _regionSeen = -1;
  LatLng? _ctr; // центр поиска, если его передвинули на карте (иначе — центр города)

  @override
  void initState() {
    super.initState();
    _qFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _applyRegion();
    WidgetsBinding.instance.addPostFrameCallback((_) => S.i.loadAds().then((_) => Near.i.fill(S.i.ads)));
  }

  // Регион из настроек: город, радиус и «сначала из города» по умолчанию
  void _applyRegion() {
    _regionSeen = S.i.regionStamp;
    _city = S.i.regionCity;
    _cityC.text = _city;
    _rad = S.i.regionRad;
    _first = S.i.regionFirst;
    _ctr = null;
    _autoCity = '';
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
      (_min.isNotEmpty ? 1 : 0) +
      (_max.isNotEmpty ? 1 : 0) +
      (_sort.isNotEmpty ? 1 : 0) +
      (_pt.isNotEmpty ? 1 : 0) +
      (_wh.isNotEmpty ? 1 : 0);

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

  List<Ad> _filtered({bool neighbors = false}) {
    final q = _q.text.trim();
    final c = _city.trim().toLowerCase();
    final mn = int.tryParse(digitsOnly(_min)) ?? 0;
    final mx = int.tryParse(digitsOnly(_max)) ?? 0;
    final radKm = _radKm;
    final rad = (c.isEmpty && Near.i.has) ? radKm : 0; // радиус от вас, если город не выбран
    final around = c.isNotEmpty && radKm > 0; // город + радиус вокруг него
    final ref = around ? (_ctr ?? Geo.cityCached(_city.trim())) : null;
    if (neighbors && !(around && _first && ref != null)) return [];
    double kmRef(Ad a) {
      final pt = adPoint(a) ?? (a.city.trim().isEmpty ? null : Geo.cityCached(a.city));
      if (pt == null) return a.city.toLowerCase().contains(c) ? 0 : 1e9;
      return kmBetween(ref!, pt);
    }

    final r = S.i.ads.where((a) {
      if (S.i.isBlocked(a.pid)) return false;
      final amt = adAmt(a);
      final n = amt > 0 ? amt.toDouble() : null;
      if (_type.isNotEmpty && a.type != _type) return false;
      if (_cat.isNotEmpty && a.category != _cat) return false;
      if (c.isNotEmpty) {
        final inCity = a.city.toLowerCase().contains(c);
        if (neighbors) {
          if (inCity || kmRef(a) > radKm) return false; // после города: другие города в радиусе
        } else if (!inCity) {
          // без «сначала из города» объявления в радиусе идут в общем списке
          if (!(around && !_first && ref != null && kmRef(a) <= radKm)) return false;
        }
      }
      if (q.isNotEmpty && !smartMatchAd(q, a.title, a.desc, a.category, a.city, a.addr)) return false;
      if (mn > 0 && (n == null || n < mn)) return false;
      if (mx > 0 && (n == null || n > mx)) return false;
      if (_urg && !a.urgent) return false;
      if (_qfPhoto && a.imgs.isEmpty) return false;
      if (_qfVer && !(a.ver || a.innOk)) return false;
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
    final byRef = ref != null && (neighbors || !_first) && (_sort.isEmpty || _sort == 'near');
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
      } else if (byRef) {
        final x = kmRef(a), y = kmRef(b);
        if (x != y) return x.compareTo(y);
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
      _qfPhoto = false;
      _qfVer = false;
      _minC.clear();
      _maxC.clear();
      _applyRegion(); // город и радиус возвращаются к региону из настроек
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

  Widget _qChip(Pal p, IconData ic, String label, bool on, VoidCallback f) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Tap(
          onTap: () {
            haptic();
            f();
          },
          scale: .96,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: on ? LinearGradient(colors: [p.ac, p.ac2]) : null,
              color: on ? null : p.card,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: on ? Colors.transparent : p.bd),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ic, size: 15, color: on ? Colors.white : p.tx),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: on ? Colors.white : p.tx)),
            ]),
          ),
        ),
      );

  // «Рядом со мной» живёт в фильтрах: определить место и сортировать по расстоянию
  Widget _geoTile(Pal p, VoidCallback after) {
    final on = Near.i.has;
    return Tap(
      onTap: () async {
        if (on) {
          haptic();
          Near.i.turnOff();
          setState(() {
            _rad = '';
            if (_sort == 'new' || _sort == 'near') _sort = '';
            if (_autoCity.isNotEmpty && _city == _autoCity) {
              _city = '';
              _cityC.clear();
            }
            _autoCity = '';
            _autoCityTried = false;
          });
        } else {
          await _locate();
        }
        after();
      },
      scale: .98,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd)),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: p.ac.withOpacity(on ? .2 : .12), borderRadius: BorderRadius.circular(12)),
            child: Near.i.busy
                ? Padding(padding: const EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2.2, color: p.ac))
                : Icon(Icons.near_me_rounded, size: 20, color: p.ac),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Рядом со мной', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: p.tx)),
              const SizedBox(height: 1),
              Text(on ? 'Ближайшие объявления — первыми' : 'Включить, чтобы видеть ближайшие',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.mu)),
            ]),
          ),
          const SizedBox(width: 8),
          IgnorePointer(
            child: Switch(
              value: on,
              onChanged: (_) {},
              activeColor: Colors.white,
              activeTrackColor: p.ok,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ]),
      ),
    );
  }

  // Фильтры открываются отдельным экраном, как в Авито: категория, тип, где искать, оплата, сортировка
  Future<void> _openFilters() async {
    FocusScope.of(context).unfocus();
    if (Near.i.has && !_autoCityTried && !S.i.regionChosen) _fillCity();
    await Navigator.of(context).push<void>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          final p = pal(c);
          void upd(VoidCallback f) {
            setState(f);
            setS(() {});
          }

          _filterRefresh = () => setS(() {});

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
                  _whereCard(p, c, upd),
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
    _filterRefresh = null;
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
        if (_regionSeen != S.i.regionStamp) {
          _regionSeen = S.i.regionStamp;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(_applyRegion);
          });
        }
        final list = _filtered();
        final nb = _filtered(neighbors: true);
        if (_city.trim().isNotEmpty && _radKm > 0) WidgetsBinding.instance.addPostFrameCallback((_) => _prepNeighbors());
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
                  if (list.isEmpty && nb.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: _empty(p))
                  else ...[
                    if (list.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        sliver: S.i.feedMode == 1 ? _grid(context, list) : _rows(context, list),
                      ),
                    if (nb.isNotEmpty) ...[
                      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _nbHeader(p, list.isEmpty))),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + navPad(context)),
                        sliver: S.i.feedMode == 1 ? _grid(context, nb) : _rows(context, nb),
                      ),
                    ] else
                      SliverToBoxAdapter(child: SizedBox(height: 16 + navPad(context))),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // кнопка «Рядом со мной»: определить место и показать ближайшие объявления
  // Город выбран: если радиус не задан, сразу показываем и соседние города (50 км)
  void _setCity(String v) {
    final had = _city.trim().isNotEmpty;
    _city = v;
    _ctr = null;
    if (v.trim().isEmpty) {
      _rad = '';
    } else if (!had && _rad.isEmpty) {
      _rad = '50';
    }
  }

  // Сколько объявлений будет при выбранном радиусе (для кнопки на карте)
  int _countWith(String rad, LatLng? center, String? city) {
    final oldR = _rad, oldC = _ctr, oldT = _city;
    _rad = rad;
    if (center != null) _ctr = center;
    if (center != null && city != null && city.trim().isNotEmpty) _city = city;
    final n = _filtered().length + _filtered(neighbors: true).length;
    _rad = oldR;
    _ctr = oldC;
    _city = oldT;
    return n;
  }

  // Короткое описание места для карточки в фильтрах
  String get _whereTitle => _city.trim().isNotEmpty ? _city.trim() : (Near.i.has ? 'Рядом со мной' : 'Все города');

  String get _whereSub {
    if (_city.trim().isEmpty) return Near.i.has ? (_radKm > 0 ? 'В радиусе $_radKm км от вас' : 'Ближайшие объявления — первыми') : 'Выбрать город или регион';
    if (_radKm == 0) return 'Только этот город';
    return _first ? 'И в радиусе $_radKm км, сначала из города' : 'И в радиусе $_radKm км вместе';
  }

  Widget _whereCard(Pal p, BuildContext c, void Function(VoidCallback) upd) => Tap(
        onTap: () {
          haptic();
          _openWhere(c, upd);
        },
        scale: .98,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd)),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: p.ac.withOpacity(.14), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.place_rounded, size: 21, color: p.ac),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_whereTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.tx)),
                const SizedBox(height: 1),
                Text(_whereSub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.mu)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: p.mu),
          ]),
        ),
      );

  // Экран «Где искать»: город, «Сначала из города», радиус на карте
  Future<void> _openWhere(BuildContext context, void Function(VoidCallback) upd) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (c) => StatefulBuilder(
        builder: (c, setW) {
          final p = pal(c);
          _whereRefresh = () => setW(() {});
          void u(VoidCallback f) {
            upd(f);
            setW(() {});
          }

          final n = _filtered().length + _filtered(neighbors: true).length;
          final hasCity = _city.trim().isNotEmpty;
          final canRadius = hasCity || Near.i.has;

          Widget head(String t) => Padding(
                padding: const EdgeInsets.only(top: 22, bottom: 10),
                child: Text(t, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.tx, letterSpacing: -.2)),
              );

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
              title: const Text('Где искать'),
              centerTitle: true,
              actions: [
                TextButton(
                  onPressed: () {
                    haptic();
                    u(() {
                      _city = '';
                      _rad = '';
                      _first = true;
                      _ctr = null;
                      _cityC.clear();
                      _autoCity = '';
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
                  head('Город или регион'),
                  CityField(
                    controller: _cityC,
                    decoration: deco(c, 'Город или регион', prefix: Icon(Icons.place_outlined, color: p.mu)),
                    onChanged: (v) => u(() => _setCity(v)),
                  ),
                  const SizedBox(height: 10),
                  _geoTile(p, () => setW(() {})),
                  if (hasCity) ...[
                    const SizedBox(height: 14),
                    Tap(
                      onTap: () {
                        haptic();
                        u(() => _first = !_first);
                      },
                      scale: .99,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(child: Text('Сначала из ${_city.trim()}', style: TextStyle(fontSize: 16, color: p.tx))),
                          IgnorePointer(
                            child: Switch(
                              value: _first,
                              onChanged: (_) {},
                              activeColor: Colors.white,
                              activeTrackColor: p.ok,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Tap(
                    onTap: !canRadius
                        ? () => toast(c, 'Сначала выберите город или включите «Рядом со мной»')
                        : () async {
                            haptic();
                            final r = await Navigator.of(c).push<RadiusResult>(MaterialPageRoute(
                              builder: (_) => RadiusPage(city: _city, radius: _rad, center: _ctr, count: _countWith),
                            ));
                            if (r != null) {
                              u(() {
                                _rad = r.rad;
                                if (r.center != null) {
                                  _ctr = r.center;
                                  final nm = (r.city ?? '').trim();
                                  if (nm.isNotEmpty) {
                                    _city = nm;
                                    _cityC.text = nm;
                                  }
                                }
                              });
                            }
                          },
                    scale: .98,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd)),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Радиус', style: TextStyle(fontSize: 12.5, color: p.mu)),
                            const SizedBox(height: 2),
                            Text(_radKm > 0 ? '$_radKm км' : (hasCity ? 'Только город' : 'Не выбран'),
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: canRadius ? p.tx : p.mu)),
                          ]),
                        ),
                        Icon(Icons.map_outlined, color: p.ac),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded, color: p.mu),
                      ]),
                    ),
                  ),
                  if (hasCity && _radKm == 0) ...[
                    const SizedBox(height: 8),
                    Text('Выберите радиус, чтобы видеть объявления и из соседних городов.', style: TextStyle(fontSize: 12.5, color: p.mu)),
                  ],
                ]),
              ),
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
    _whereRefresh = null;
    if (mounted) setState(() {});
  }

  // Центры выбранного города и городов объявлений нужны, чтобы показать соседние города
  Future<void> _prepNeighbors() async {
    if (_nbBusy) return;
    final city = _city.trim();
    if (city.isEmpty) return;
    final need = _ctr == null && !Geo.hasCity(city);
    final todo = [for (final a in S.i.ads) if (adPoint(a) == null && a.city.trim().isNotEmpty && !Geo.hasCity(a.city)) a];
    if (!need && todo.isEmpty) return;
    _nbBusy = true;
    var changed = false;
    try {
      if (need) {
        await Geo.city(city);
        if (Geo.hasCity(city)) changed = true;
      }
      var n = 0;
      for (final a in todo) {
        if (n >= 10) break;
        if (Geo.hasCity(a.city)) continue;
        n++;
        await Geo.city(a.city);
        if (Geo.hasCity(a.city)) changed = true;
      }
    } finally {
      _nbBusy = false;
    }
    if (changed && mounted) setState(() {});
  }

  // Заголовок перед объявлениями из соседних городов
  Widget _nbHeader(Pal p, bool noneInCity) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.near_me_outlined, size: 20, color: p.ac),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(noneInCity ? 'В городе ничего нет — смотрите рядом' : 'Из соседних городов',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.tx, letterSpacing: -.2)),
              const SizedBox(height: 2),
              Text('В радиусе $_radKm км от «${_city.trim()}», сначала ближайшие', style: TextStyle(fontSize: 12.5, color: p.mu)),
            ]),
          ),
        ]),
      );

  // Местоположение определено, а город в фильтре пуст: подставляем город
  Future<void> _fillCity() async {
    _autoCityTried = true;
    final pos = Near.i.pos;
    if (pos == null || _city.trim().isNotEmpty) return;
    final c = await Geo.reverseCity(pos.latitude, pos.longitude);
    if (!mounted || c == null || _city.trim().isNotEmpty || !Near.i.has) return;
    setState(() {
      _setCity(c);
      _cityC.text = c;
      _autoCity = c;
    });
    _filterRefresh?.call();
    _whereRefresh?.call();
  }

  Future<void> _locate() async {
    haptic();
    final r = await Near.i.locate();
    if (!mounted) return;
    switch (r) {
      case NearResult.ok:
        setState(() => _sort = '');
        Near.i.fill(S.i.ads);
        _fillCity();
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
                    child: Stack(alignment: Alignment.centerLeft, children: [
                      TextField(contextMenuBuilder: appContextMenu,
                        controller: _q,
                        focusNode: _qFocus,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        style: TextStyle(color: p.tx, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: _qFocus.hasFocus ? 'Найти подработку или услугу' : null,
                          hintStyle: TextStyle(color: p.mu.withOpacity(.85)),
                          filled: false,
                          isDense: true,
                          border: none,
                          enabledBorder: none,
                          focusedBorder: none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                        ),
                      ),
                      // пока поле пустое и не в фокусе — печатаем подсказки, как в Авито
                      if (_q.text.isEmpty && !_qFocus.hasFocus)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TypewriterHint(phrases: kSearchHints, style: TextStyle(color: p.mu.withOpacity(.85), fontSize: 16)),
                              ),
                            ),
                          ),
                        ),
                    ]),
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
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 16, 8),
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
              if (canSave) ...[
                Tooltip(
                  message: saved ? 'Поиск сохранён' : 'Сохранить поиск',
                  child: Tap(
                    onTap: _saveSearch,
                    scale: .92,
                    child: Container(
                      width: 40,
                      height: 36,
                      decoration: BoxDecoration(
                        color: saved ? p.ac.withOpacity(.14) : p.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: saved ? p.ac.withOpacity(.5) : p.bd),
                      ),
                      child: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 20, color: saved ? p.ac : p.tx),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _modeToggle(p),
            ]),
          ),
        ]),
      ),
    ]);
  }
}
