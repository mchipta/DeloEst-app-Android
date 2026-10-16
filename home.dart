import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cabinet.dart';
import 'feed.dart';
import 'landing.dart';
import 'messages.dart';
import 'post.dart';
import 'state.dart';
import 'theme.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    S.i.openMessages = () {
      Navigator.of(context).popUntil((r) => r.isFirst);
      S.i.goTab(4);
    };
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
            canPop: S.i.tab == S.i.rootTab,
            onPopInvoked: (didPop) {
              if (didPop) return;
              if (S.i.tab == 2 && (S.i.postBack?.call() ?? false)) return;
              S.i.goTab(S.i.rootTab);
            },
            child: Scaffold(
              body: IndexedStack(
                index: S.i.tab,
                children: const [LandingPage(), FeedPage(), PostScreen(), CabinetPage(), MessagesPage(embedded: true)],
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
    // [индекс вкладки, иконка, иконка выбранной, подпись, бейдж]
    final items = <List<Object>>[
      // не вошедшему поиск доступен на «Главной», вошедшему «Главная» не нужна
      if (!S.i.logged) [0, Icons.home_outlined, Icons.home_rounded, 'Главная', 0],
      if (S.i.logged) [1, Icons.search_rounded, Icons.search_rounded, 'Поиск', 0],
      [2, Icons.add_circle_outline_rounded, Icons.add_circle_rounded, 'Разместить', 0],
      // «Сообщения» видны только вошедшему в аккаунт
      if (S.i.logged) [4, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Сообщения', S.i.unread],
      [3, Icons.person_outline_rounded, Icons.person_rounded, S.i.logged ? 'Кабинет' : 'Войти', 0],
    ];
    // у не вошедшего результаты поиска (вкладка 1) открываются из «Главной», подсвечиваем её
    bool on(int i) => S.i.tab == i || (!S.i.logged && i == 0 && S.i.tab == 1);
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.bd)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(children: [
            for (final it in items)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: on(it[0] as int),
                  label: it[3] as String,
                  child: InkWell(
                    onTap: () => S.i.goTab((it[0] as int) == 2 && !S.i.logged ? 3 : (it[0] as int)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Stack(clipBehavior: Clip.none, children: [
                        Icon(on(it[0] as int) ? it[2] as IconData : it[1] as IconData,
                            size: 23, color: on(it[0] as int) ? p.ac : p.mu),
                        if ((it[4] as int) > 0)
                          Positioned(
                            right: -9,
                            top: -5,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: p.ac, borderRadius: BorderRadius.circular(99)),
                              child: Text((it[4] as int) > 99 ? '99+' : '${it[4]}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 3),
                      Text(it[3] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, fontWeight: on(it[0] as int) ? FontWeight.w800 : FontWeight.w600,
                              color: on(it[0] as int) ? p.ac : p.mu)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
