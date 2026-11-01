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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        final p = pal(context);
        final ads = S.i.ads.where((a) => S.i.isFav(a.id)).toList();
        final ss = List<Map<String, String>>.of(S.i.ss);
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
                  Row(children: [_tab(p, 'Объявления', ads.length, 0), _tab(p, 'Поиски', ss.length, 1)]),
                  const SizedBox(height: 14),
                  if (_t == 0) ...[
                    if (ads.isEmpty)
                      EmptyState(
                          icon: Icons.favorite_border_rounded,
                          title: 'Здесь пока пусто',
                          text: 'Нажмите на сердечко ♡ на карточке объявления, чтобы сохранить его сюда.',
                          button: 'Найти объявления',
                          onTap: () => S.i.goTab(1)),
                    for (final a in ads)
                      AdCard(ad: a, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: a)))),
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
