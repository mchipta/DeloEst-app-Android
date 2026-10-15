import 'package:flutter/material.dart';
import 'ad_page.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});
  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final _q = TextEditingController();
  String _cat = '';
  int _type = 0; // 0 все, 1 нужен исполнитель, 2 предлагаю услуги
  bool _favOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => S.i.loadAds());
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<Ad> _filtered() {
    final q = _q.text.trim().toLowerCase();
    final r = S.i.ads.where((a) {
      if (_type == 1 && a.type != kTypes[0]) return false;
      if (_type == 2 && a.type != kTypes[1]) return false;
      if (_favOnly && !S.i.isFav(a.id)) return false;
      if (_cat.isNotEmpty && a.category != _cat) return false;
      if (q.isNotEmpty && !('${a.title} ${a.desc} ${a.category} ${a.city}'.toLowerCase().contains(q))) {
        return false;
      }
      return true;
    }).toList();
    r.sort((a, b) => b.ts.compareTo(a.ts));
    return r;
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
                  SliverToBoxAdapter(child: _header(context, p)),
                  if (list.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: _empty(p))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (c, i) => AdCard(
                            ad: list[i],
                            onTap: () => Navigator.push(
                                c, MaterialPageRoute(builder: (_) => AdPage(ad: list[i]))),
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
        Text(S.i.loadError ?? 'Ничего не найдено',
            textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Потяните вниз, чтобы обновить', style: TextStyle(color: p.mu, fontSize: 13)),
      ]),
    );
  }

  Widget _header(BuildContext context, Pal p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Logo(),
          const SizedBox(width: 10),
          Text('Дело', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.tx)),
          const GradText('Есть', size: 22),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _q,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: p.tx),
          decoration: deco(context, null,
                  hint: 'Уборка, грузчики, ремонт…',
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
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _pill(p, 'Все', _type == 0, () => setState(() => _type = 0)),
            _pill(p, 'Нужен исполнитель', _type == 1, () => setState(() => _type = 1)),
            _pill(p, 'Предлагаю услуги', _type == 2, () => setState(() => _type = 2)),
            if (S.i.logged) _pill(p, 'Избранное', _favOnly, () => setState(() => _favOnly = !_favOnly), icon: Icons.favorite_border),
          ]),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _pill(p, 'Все категории', _cat.isEmpty, () => setState(() => _cat = '')),
            for (final c in kCats)
              _pill(p, c.name, _cat == c.name, () => setState(() => _cat = _cat == c.name ? '' : c.name),
                  icon: c.icon),
          ]),
        ),
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
            Text(t,
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600, color: on ? Colors.white : p.tx)),
          ]),
        ),
      ),
    );
  }
}
