import 'package:flutter/material.dart';
import 'ad_page.dart';
import 'info.dart';
import 'models.dart';
import 'state.dart';
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
  final _cityC = TextEditingController();
  final _minC = TextEditingController();
  final _maxC = TextEditingController();
  String _cat = '', _type = '', _city = '', _min = '', _max = '', _sort = '';
  bool _favOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => S.i.loadAds());
  }

  @override
  void dispose() {
    _q.dispose();
    _cityC.dispose();
    _minC.dispose();
    _maxC.dispose();
    super.dispose();
  }

  int get _activeFilters =>
      (_city.trim().isNotEmpty ? 1 : 0) + (_min.isNotEmpty ? 1 : 0) + (_max.isNotEmpty ? 1 : 0) + (_sort.isNotEmpty ? 1 : 0);

  List<Ad> _filtered() {
    final q = _q.text.trim().toLowerCase();
    final c = _city.trim().toLowerCase();
    final mn = int.tryParse(digitsOnly(_min)) ?? 0;
    final mx = int.tryParse(digitsOnly(_max)) ?? 0;
    final r = S.i.ads.where((a) {
      final n = payNum(a.pay);
      if (_favOnly && !S.i.isFav(a.id)) return false;
      if (_type.isNotEmpty && a.type != _type) return false;
      if (_cat.isNotEmpty && a.category != _cat) return false;
      if (c.isNotEmpty && !a.city.toLowerCase().contains(c)) return false;
      if (q.isNotEmpty && !('${a.title} ${a.desc}'.toLowerCase().contains(q))) return false;
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
      _favOnly = false;
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          final p = pal(c);
          Widget dd(String label, String value, List<List<String>> items, void Function(String) f) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                value: value,
                isExpanded: true,
                dropdownColor: p.card,
                style: TextStyle(color: p.tx, fontSize: 16),
                decoration: deco(c, label),
                items: [for (final it in items) DropdownMenuItem(value: it[0], child: Text(it[1]))],
                onChanged: (v) {
                  if (v == null) return;
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
                  child: TextField(
                    controller: _cityC,
                    style: TextStyle(color: p.tx),
                    textCapitalization: TextCapitalization.words,
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
                      child: TextField(
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
                      child: TextField(
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
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (c, i) => AdCard(
                            ad: list[i],
                            onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => AdPage(ad: list[i]))),
                          ),
                          childCount: list.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _empty(Pal p) {
    if (S.i.loading && S.i.ads.isEmpty) {
      return Center(child: CircularProgressIndicator(color: p.ac));
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

  Widget _header(BuildContext context, Pal p, int count) {
    final af = _activeFilters;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Logo(),
          const SizedBox(width: 10),
          Text('Дело', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.tx)),
          const GradText('Есть', size: 22),
          const Spacer(),
          IconButton(
            tooltip: 'О сервисе',
            icon: Icon(Icons.info_outline, color: p.mu),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoPage())),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: p.tx),
              decoration: deco(context, null,
                  hint: 'Поиск: грузчик, уборка…',
                  prefix: Icon(Icons.search, color: p.mu),
                  suffix: _q.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close, color: p.mu),
                          onPressed: () {
                            _q.clear();
                            setState(() {});
                          })),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openFilters,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: af > 0 ? p.ac : p.bd, width: af > 0 ? 1.6 : 1),
                ),
                child: Icon(Icons.tune_rounded, color: af > 0 ? p.ac : p.mu),
              ),
              if (af > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [p.ac, p.ac2]), shape: BoxShape.circle),
                    child: Text('$af', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _pill(p, 'Все', _type.isEmpty, () => setState(() => _type = '')),
            _pill(p, kTypes[0], _type == kTypes[0], () => setState(() => _type = kTypes[0])),
            _pill(p, kTypes[1], _type == kTypes[1], () => setState(() => _type = kTypes[1])),
            if (S.i.logged)
              _pill(p, 'Избранное', _favOnly, () => setState(() => _favOnly = !_favOnly), icon: Icons.favorite_border),
          ]),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _pill(p, 'Все категории', _cat.isEmpty, () => setState(() => _cat = '')),
            for (final c in kCats)
              _pill(p, c.name, _cat == c.name, () => setState(() => _cat = _cat == c.name ? '' : c.name), icon: c.icon),
          ]),
        ),
        if (_favOnly && S.i.ss.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Сохранённые поиски', style: TextStyle(fontWeight: FontWeight.w800, color: p.tx)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in List<Map<String, String>>.of(S.i.ss))
              Container(
                padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.bd)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: () => _useSearch(s),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search, size: 15, color: p.ac),
                      const SizedBox(width: 4),
                      Text(_ssLabel(s), style: TextStyle(fontSize: 13, color: p.tx, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () {
                      S.i.ss.remove(s);
                      S.i.saveSS();
                    },
                    child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.close, size: 16, color: p.mu)),
                  ),
                ]),
              ),
          ]),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text('Найдено: $count', style: TextStyle(color: p.mu, fontWeight: FontWeight.w600))),
          if (S.i.logged)
            GestureDetector(
              onTap: _saveSearch,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.bd)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bookmark_border, size: 17, color: p.ac),
                  const SizedBox(width: 5),
                  Text('Сохранить поиск', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: p.tx)),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _pill(Pal p, String t, bool on, VoidCallback f, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: on ? LinearGradient(colors: [p.ac, p.ac2]) : null,
            color: on ? null : p.card,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: on ? Colors.transparent : p.bd),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 15, color: on ? Colors.white : p.mu), const SizedBox(width: 5)],
            Text(t, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: on ? Colors.white : p.tx)),
          ]),
        ),
      ),
    );
  }
}
