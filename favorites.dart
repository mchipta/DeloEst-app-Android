import 'package:flutter/material.dart';
import 'ad_page.dart';
import 'auth.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

// Избранное, как в Авито: вкладка нижнего меню, сверху переключатель «Объявления / Поиски»
class FavoritesPage extends StatefulWidget {
  final bool embedded;
  const FavoritesPage({super.key, this.embedded = false});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  int _t = 0; // 0 — объявления, 1 — сохранённые поиски
  String _col = 'all'; // all, srv, req, urg, or custom id

  Widget _tab(Pal p, String text, int n, int i) {
    final on = _t == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          haptic();
          setState(() => _t = i);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: on ? p.tx : p.bd, width: on ? 2.5 : 1))),
          alignment: Alignment.center,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: text, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: on ? p.tx : p.mu)),
            if (n > 0) TextSpan(text: '  $n', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.mu)),
          ])),
        ),
      ),
    );
  }

  Future<void> _addCol(BuildContext context) async {
    final p = pal(context);
    final ctl = TextEditingController();
    final nm = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: p.card,
        title: Text('Новая подборка', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800)),
        content: TextField(
          contextMenuBuilder: appContextMenu,
          controller: ctl,
          autofocus: true,
          style: TextStyle(color: p.tx),
          decoration: deco(c, 'Название подборки', hint: 'Например: Ремонт дачи'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Отмена', style: TextStyle(color: p.mu))),
          TextButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: Text('Создать', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (nm != null && nm.isNotEmpty) {
      await S.i.addFavCol(nm);
      if (mounted && S.i.favCols.isNotEmpty) {
        setState(() => _col = S.i.favCols.last['id'] ?? 'all');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        final p = pal(context);
        final allAds = S.i.ads.where((a) => S.i.isFav(a.id)).toList();
        final ads = allAds.where((a) {
          if (_col == 'all') return true;
          if (_col == 'srv') return a.type == kTypes[1];
          if (_col == 'req') return a.type == kTypes[0];
          if (_col == 'urg') return a.urgent;
          return S.i.favMap[a.id] == _col;
        }).toList();
        final ss = List<Map<String, String>>.of(S.i.ss);
        final cols = <List<String>>[
          ['all', 'Все (${allAds.length})'],
          ['srv', 'Исполнители'],
          ['req', 'Заказы'],
          ['urg', 'Срочные'],
          for (final c in S.i.favCols) [c['id'] ?? '', c['name'] ?? 'Подборка'],
        ];
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !widget.embedded,
            title: const Text('Избранное'),
          ),
          body: !S.i.logged
              ? const NeedAuth(
                  icon: Icons.favorite_border,
                  title: 'Избранное',
                  text: 'Войдите, чтобы добавлять объявления в избранное и сохранять поиски.')
              : ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + (widget.embedded ? navPad(context) : 0)), children: [
                  Row(children: [_tab(p, 'Объявления', allAds.length, 0), _tab(p, 'Поиски', ss.length, 1)]),
                  const SizedBox(height: 14),
                  if (_t == 0) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(children: [
                        for (final c in cols)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Tap(
                              onTap: () => setState(() => _col = c[0]),
                              scale: .96,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: _col == c[0] ? LinearGradient(colors: [p.ac, p.ac2]) : null,
                                  color: _col == c[0] ? null : p.card,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: _col == c[0] ? Colors.transparent : p.bd),
                                ),
                                child: Text(c[1], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _col == c[0] ? Colors.white : p.tx)),
                              ),
                            ),
                          ),
                        Tap(
                          onTap: () => _addCol(context),
                          scale: .96,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.bd)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.add_rounded, size: 16, color: p.ac),
                              const SizedBox(width: 4),
                              Text('Подборка', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: p.ac)),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                    if (ads.isEmpty)
                      EmptyState(
                          icon: Icons.favorite_border_rounded,
                          title: allAds.isEmpty ? 'Здесь пока пусто' : 'В этой подборке пока пусто',
                          text: 'Нажмите на сердечко ♡ на карточке объявления, чтобы сохранить его сюда.',
                          button: 'Найти объявления',
                          onTap: () => S.i.goTab(1)),
                    for (final a in ads)
                      AdCard(
                        ad: a,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: a))),
                        footer: S.i.favCols.isEmpty
                            ? null
                            : Wrap(spacing: 6, runSpacing: 6, children: [
                                for (final c in S.i.favCols)
                                  Tap(
                                    onTap: () => S.i.setFavCol(a.id, S.i.favMap[a.id] == c['id'] ? '' : (c['id'] ?? '')),
                                    scale: .96,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: S.i.favMap[a.id] == c['id'] ? p.ac.withOpacity(.16) : p.bg2,
                                        borderRadius: BorderRadius.circular(99),
                                        border: Border.all(color: S.i.favMap[a.id] == c['id'] ? p.ac : p.bd),
                                      ),
                                      child: Text(
                                        '📁 ${c['name'] ?? ''}',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: S.i.favMap[a.id] == c['id'] ? p.ac : p.mu),
                                      ),
                                    ),
                                  ),
                              ]),
                      ),
                  ] else ...[
                    if (ss.isEmpty)
                      EmptyState(
                          icon: Icons.bookmark_border_rounded,
                          title: 'Сохранённых поисков нет',
                          text: 'Задайте запрос или фильтры и сохраните поиск — мы напомним о новом.',
                          button: 'Перейти к поиску',
                          onTap: () => S.i.goTab(1)),
                    for (final s in ss)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd)),
                        child: Row(children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                haptic();
                                S.i.pendingSearch = s;
                                if (!widget.embedded) Navigator.pop(context);
                                S.i.goTab(1);
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                                child: Row(children: [
                                  Icon(Icons.search_rounded, size: 20, color: p.ac),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(ssLabel(s), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.tx))),
                                ]),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Удалить поиск',
                            icon: Icon(Icons.close_rounded, size: 20, color: p.mu),
                            onPressed: () {
                              S.i.delSS(s);
                            },
                          ),
                        ]),
                      ),
                  ],
                ]),
        );
      },
    );
  }
}
