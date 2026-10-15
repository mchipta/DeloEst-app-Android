import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cabinet.dart';
import 'feed.dart';
import 'post.dart';
import 'state.dart';
import 'theme.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        final p = pal(context);
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: p.card,
            systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          ),
          child: PopScope(
            canPop: S.i.tab == 0,
            onPopInvoked: (didPop) {
              if (!didPop) S.i.goTab(0);
            },
            child: Scaffold(
              body: IndexedStack(
                index: S.i.tab,
                children: const [FeedPage(), PostScreen(), CabinetPage()],
              ),
              bottomNavigationBar: _Tabs(p: p),
            ),
          ),
        );
      },
    );
  }
}

class _Tabs extends StatelessWidget {
  final Pal p;
  const _Tabs({required this.p});

  @override
  Widget build(BuildContext context) {
    final items = <List<Object>>[
      [Icons.search, 'Объявления'],
      [Icons.add_circle_outline, 'Разместить'],
      [Icons.person_outline, S.i.logged ? 'Кабинет' : 'Войти'],
    ];
    return Container(
      decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.bd))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => S.i.goTab(i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(items[i][0] as IconData, size: 25, color: S.i.tab == i ? p.ac : p.mu),
                    const SizedBox(height: 3),
                    Text(items[i][1] as String,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: S.i.tab == i ? FontWeight.w800 : FontWeight.w600,
                            color: S.i.tab == i ? p.ac : p.mu)),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
