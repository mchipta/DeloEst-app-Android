import 'dart:ui' show ImageFilter;
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
            systemNavigationBarColor: S.i.navTransparent ? p.bg : p.card,
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
              extendBody: S.i.navTransparent,
              body: _TabFade(
                tab: S.i.tab,
                child: IndexedStack(
                  index: S.i.tab,
                  children: const [LandingPage(), FeedPage(), PostScreen(), CabinetPage(), MessagesPage(embedded: true)],
                ),
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
    final n = items.length;
    final sel = items.indexWhere((it) => on(it[0] as int));
    final idle = Color.lerp(p.mu, p.tx, .5)!;
    final glass = S.i.navTransparent;
    // плавающая панель: скруглённая «таблетка» с отступами от краёв, подсветка выбранной вкладки едет между пунктами
    return Container(
      color: glass ? Colors.transparent : p.bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: _glass(glass, child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: glass ? p.card.withOpacity(.78) : p.card,
              borderRadius: BorderRadius.circular(33),
              border: Border.all(color: p.bd),
              boxShadow: glass ? null : [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: Stack(children: [
              if (sel >= 0)
                AnimatedAlign(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(n == 1 ? 0 : -1 + 2 * sel / (n - 1), 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / n,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: p.ac.withOpacity(.16), borderRadius: BorderRadius.circular(28)),
                      ),
                    ),
                  ),
                ),
              Row(children: [
                for (final it in items)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: on(it[0] as int),
                      label: it[3] as String,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => S.i.goTab((it[0] as int) == 2 && !S.i.logged ? 3 : (it[0] as int)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Stack(clipBehavior: Clip.none, children: [
                            AnimatedScale(
                              scale: on(it[0] as int) ? 1.1 : 1,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutBack,
                              child: Icon(on(it[0] as int) ? it[2] as IconData : it[1] as IconData,
                                  size: 24, color: on(it[0] as int) ? p.ac : idle),
                            ),
                            if ((it[4] as int) > 0)
                              Positioned(
                                right: -10,
                                top: -6,
                                child: Container(
                                  constraints: const BoxConstraints(minWidth: 17),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(color: p.ac, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.card, width: 1.5)),
                                  child: Text((it[4] as int) > 99 ? '99+' : '${it[4]}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                                ),
                              ),
                          ]),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: TextStyle(fontSize: 11, fontWeight: on(it[0] as int) ? FontWeight.w800 : FontWeight.w600, color: on(it[0] as int) ? p.ac : idle),
                            child: Text(it[3] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ]),
          )),
        ),
      ),
    );
  }

  // «стекло»: размытие того, что находится под панелью
  Widget _glass(bool on, {required Widget child}) => on
      ? ClipRRect(borderRadius: BorderRadius.circular(33), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: child))
      : child;
}


/// Короткое проявление при смене вкладки (вкладки при этом не пересоздаются)
class _TabFade extends StatefulWidget {
  final int tab;
  final Widget child;
  const _TabFade({required this.tab, required this.child});
  @override
  State<_TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<_TabFade> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: 1);
  late final Animation<double> a = CurvedAnimation(parent: c, curve: Curves.easeOut);

  @override
  void didUpdateWidget(covariant _TabFade old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) c.forward(from: 0);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: .35, end: 1).animate(a),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .012), end: Offset.zero).animate(a),
          child: widget.child,
        ),
      );
}
