import 'package:flutter/material.dart';
import 'ad_page.dart';
import 'auth.dart';
import 'favorites.dart';
import 'map_page.dart';
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
  String _cat = '', _type = '', _city = '', _min = '', _max = '', _sort = '';

  @override
  void initState() {
    super.initState();
    _qFocus.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => S.i.loadAds());
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
      (_sort.isNotEmpty ? 1 : 0);

  String get _filterSummary => [
        if (_type.isNotEmpty) _type,
        if (_cat.isNotEmpty) _cat,
        if (_city.trim().isNotEmpty) _city.trim(),
        if (_min.isNotEmpty) 'от $_min ₽',
        if (_max.isNotEmpty) 'до $_max ₽',
        if (_sort == 'hi') 'Сначала дороже',
        if (_sort == 'lo') 'Сначала дешевле',
      ].join(' · ');

  List<Ad> _filtered() {
    final q = _q.text.trim();
    final c = _city.trim().toLowerCase();
    final mn = int.tryParse(digitsOnly(_min)) ?? 0;
    final mx = int.tryParse(digitsOnly(_max)) ?? 0;
    final r = S.i.ads.where((a) {
      if (S.i.isBlocked(a.pid)) return false;
      final n = payNum(a.pay);
      if (_type.isNotEmpty && a.type != _type) return false;
      if (_cat.isNotEmpty && a.category != _cat) return false;
      if (c.isNotEmpty && !a.city.toLowerCase().contains(c)) return false;
      if (q.isNotEmpty && !smartMatchAd(q, a.title, a.desc, a.category, a.city, a.addr)) return false;
      if (mn > 0 && (n == null || n < mn)) return false;
      if (mx > 0 && (n == null || n > mx)) return false;
      return true;
    }).toList();
    r.sort((a, b) {
      if (_sort.isNotEmpty) {
        final p = payNum(a.pay), t = payNum(b.pay);
        if (p == null && t != null) return 1;
        if (t == null && p != null) return -1;
        if (p != null && t != null && p != t) return _sort == 'hi' ? t.compareTo(p) : p.compareTo(t);
      }
      return b.ts.compareTo(a.ts);
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
    S.i.ss.add(s);
    S.i.saveSS();
    toast(context, 'Поиск сохранён в избранном');
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
      _cityC.clear();
      _minC.clear();
      _maxC.clear();
    });
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pal(context).card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          final p = pal(c);
          Widget dd(String label, String value, List<List<String>> items, void Function(String) f) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PickerField(
                label: label,
                value: value,
                items: [for (final it in items) PickItem(it[0], it[1])],
                onChanged: (v) {
                  f(v);
                  setS(() {});
                  setState(() {});
                },
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Фильтры', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.tx)),
                const SizedBox(height: 14),
                dd('Тип', _type, [['', 'Все типы'], [kTypes[0], kTypes[0]], [kTypes[1], kTypes[1]]], (v) => _type = v),
                dd('Категория', _cat, [['', 'Все категории'], for (final k in kCats) [k.name, k.name]], (v) => _cat = v),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CityField(
                    controller: _cityC,
                    decoration: deco(c, 'Город'),
                    onChanged: (v) {
                      setState(() => _city = v);
                      setS(() {});
                    },
                  ),
                ),
                Row(children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12, right: 6),
                      child: TextField(contextMenuBuilder: appContextMenu, 
                        controller: _minC,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: p.tx),
                        decoration: deco(c, 'Оплата от, ₽'),
                        onChanged: (v) {
                          setState(() => _min = digitsOnly(v));
                          setS(() {});
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 6),
                      child: TextField(contextMenuBuilder: appContextMenu, 
                        controller: _maxC,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: p.tx),
                        decoration: deco(c, 'до, ₽'),
                        onChanged: (v) {
                          setState(() => _max = digitsOnly(v));
                          setS(() {});
                        },
                      ),
                    ),
                  ),
                ]),
                dd('Сортировка', _sort, [['', 'Сначала новые'], ['hi', 'Сначала с высокой оплатой'], ['lo', 'Сначала с низкой оплатой']], (v) => _sort = v),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: OutBtn('Сбросить', onTap: () {
                      _resetFilters();
                      setS(() {});
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: GradBtn('Показать (${_filtered().length})', onTap: () => Navigator.pop(c))),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        final p = pal(context);
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
      ]),
    );
  }

  String get _sortLabel => _sort == 'hi' ? 'Дороже' : _sort == 'lo' ? 'Дешевле' : 'Новые';

  Future<void> _pickCity() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pal(context).card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          final p = pal(c);
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Город', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.tx)),
                const SizedBox(height: 14),
                CityField(
                  controller: _cityC,
                  decoration: deco(c, 'Город'),
                  onChanged: (v) {
                    setState(() => _city = v);
                    setS(() {});
                  },
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutBtn('Все города', onTap: () {
                      setState(() {
                        _city = '';
                        _cityC.clear();
                      });
                      Navigator.pop(c);
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: GradBtn('Показать (${_filtered().length})', onTap: () => Navigator.pop(c))),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _chipBox(Pal p, Widget child) => Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.bd)),
        child: child,
      );

  // Город: нажатие открывает выбор города
  Widget _cityChip(Pal p) {
    return Flexible(
      child: Tap(
        onTap: _pickCity,
        scale: .96,
        child: _chipBox(
          p,
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on_outlined, size: 18, color: p.ac),
            const SizedBox(width: 6),
            Flexible(
              child: Text(_city.trim().isEmpty ? 'Все города' : _city.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.tx)),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: p.mu),
          ]),
        ),
      ),
    );
  }

  // Сортировка: короткая подпись и меню из трёх пунктов
  Widget _sortChip(Pal p) {
    return PopupMenuButton<String>(
      tooltip: 'Сортировка',
      initialValue: _sort,
      color: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.bd)),
      onSelected: (v) {
        haptic();
        setState(() => _sort = v);
      },
      itemBuilder: (c) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: '', child: Text('Сначала новые', style: TextStyle(color: p.tx))),
        PopupMenuItem<String>(value: 'hi', child: Text('Сначала с высокой оплатой', style: TextStyle(color: p.tx))),
        PopupMenuItem<String>(value: 'lo', child: Text('Сначала с низкой оплатой', style: TextStyle(color: p.tx))),
      ],
      child: _chipBox(
        p,
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_sortLabel, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.tx)),
          const SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: p.mu),
        ]),
      ),
    );
  }

  // Категория: круглая цветная плитка и подпись под ней (цвета как на сайте)
  Widget _catTile(Pal p, String label, IconData icon, Color hue, bool sel, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tap(
        onTap: onTap,
        scale: .94,
        child: SizedBox(
          width: 84,
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: sel ? LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                color: sel ? null : Color.alphaBlend(hue.withOpacity(.15), p.card),
                borderRadius: BorderRadius.circular(19),
                boxShadow: sel ? [BoxShadow(color: p.ac.withOpacity(.35), blurRadius: 16, offset: const Offset(0, 6))] : null,
              ),
              child: Icon(icon, size: 24, color: sel ? Colors.white : hue),
            ),
            const SizedBox(height: 7),
            Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, height: 1.2, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: sel ? p.tx : p.mu)),
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
    ];
    OutlineInputBorder none = const OutlineInputBorder(borderSide: BorderSide.none);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
          const Logo(),
          const SizedBox(width: 10),
          Text('Дело', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.tx)),
          const GradText('Есть', size: 22),
          const Spacer(),
          IconButton(
            tooltip: 'Избранное',
            icon: Stack(clipBehavior: Clip.none, children: [
              Icon(Icons.favorite_border_rounded, color: p.ac),
              if (S.i.logged && S.i.fav.isNotEmpty)
                Positioned(right: -7, top: -6, child: Container(
                  constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [p.ac, p.ac2]), borderRadius: BorderRadius.circular(99)),
                  child: Text(S.i.fav.length > 99 ? '99+' : '${S.i.fav.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                )),
            ]),
            onPressed: () {
              haptic();
              if (!S.i.logged) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage()));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage()));
              }
            },
          ),
        ]),
          const SizedBox(height: 10),
          Row(children: [
            _cityChip(p),
            const SizedBox(width: 8),
            _sortChip(p),
          ]),
          const SizedBox(height: 12),
          // поиск и фильтры в одной «капсуле»
          Container(
            height: 58,
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.bd),
              boxShadow: [BoxShadow(color: p.ac.withOpacity(.07), blurRadius: 16, offset: const Offset(0, 5))],
            ),
            child: Row(children: [
              const SizedBox(width: 14),
              Icon(Icons.search_rounded, color: p.mu),
              Expanded(
                child: TextField(contextMenuBuilder: appContextMenu, 
                  controller: _q,
                  focusNode: _qFocus,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: TextStyle(color: p.tx, fontSize: 15.5),
                  decoration: InputDecoration(
                    hintText: 'Поиск: грузчик, уборка…',
                    hintStyle: TextStyle(color: p.mu.withOpacity(.75)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.cancel_rounded, size: 20, color: p.mu.withOpacity(.7)),
                  ),
                ),
              Tap(
                onTap: _openFilters,
                scale: .92,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, right: 7),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.tune_rounded, size: 22, color: Colors.white),
                      ),
                      if (af > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(color: p.tx, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.card, width: 2)),
                            child: Text('$af', style: TextStyle(color: p.bg, fontSize: 11, height: 1.1, fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
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
        height: 96,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
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
