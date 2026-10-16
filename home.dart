import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cabinet.dart';
import 'feed.dart';
import 'messages.dart';
import 'post.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

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
                children: const [FeedPage(), PostScreen(), MessagesPage(), CabinetPage()],
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
    // [значок в обычном виде, значок выбранного вкладки, подпись]
    final items = <List<Object>>[
      [Icons.search, Icons.search, 'Объявления'],
      [Icons.add_circle_outline, Icons.add_circle, 'Разместить'],
      [Icons.chat_bubble_outline, Icons.chat_bubble, 'Сообщения'],
      [Icons.person_outline, Icons.person, S.i.logged ? 'Кабинет' : 'Войти'],
    ];
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.bd)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Tap(
                  onTap: () => S.i.goTab(i),
                  scale: .92,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Stack(clipBehavior: Clip.none, children: [
                        Icon(S.i.tab == i ? items[i][1] as IconData : items[i][0] as IconData,
                            size: 25, color: S.i.tab == i ? p.ac : p.mu),
                        if (i == 2 && S.i.unread > 0)
                          Positioned(
                            right: -9,
                            top: -5,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 17),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [p.ac, p.ac2]),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: p.card, width: 1.5),
                              ),
                              child: Text(S.i.unread > 99 ? '99+' : '${S.i.unread}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                            ),
                          ),
                    ]),
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 240),
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: S.i.tab == i ? FontWeight.w800 : FontWeight.w600,
                          color: S.i.tab == i ? p.ac : p.mu),
                      child: Text(items[i][2] as String),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
