import 'package:flutter/material.dart';
import 'ad_page.dart';
import 'auth.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

// Избранное: сохранённые поиски и избранные объявления (как на сайте)
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        final p = pal(context);
        final ads = S.i.ads.where((a) => S.i.isFav(a.id)).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Избранное')),
          body: !S.i.logged
              ? const NeedAuth(
                  icon: Icons.favorite_border,
                  title: 'Избранное',
                  text: 'Войдите, чтобы сохранять объявления и поиски.')
              : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                  if (S.i.ss.isNotEmpty) ...[
                    Text('Сохранённые поиски', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.tx)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final s in List<Map<String, String>>.of(S.i.ss))
                        Container(
                          padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.bd)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            GestureDetector(
                              onTap: () {
                                S.i.pendingSearch = s;
                                Navigator.pop(context);
                                S.i.goTab(0);
                              },
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.search, size: 15, color: p.ac),
                                const SizedBox(width: 4),
                                Text(ssLabel(s), style: TextStyle(fontSize: 13, color: p.tx, fontWeight: FontWeight.w600)),
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
                    const SizedBox(height: 20),
                  ],
                  Text('Избранные объявления', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.tx)),
                  const SizedBox(height: 10),
                  if (ads.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text('Здесь пока пусто. Нажмите на сердечко у объявления, чтобы сохранить его.',
                          textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 15)),
                    ),
                  for (final a in ads)
                    AdCard(ad: a, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: a)))),
                ]),
        );
      },
    );
  }
}
