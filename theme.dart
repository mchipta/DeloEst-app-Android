import 'package:flutter/material.dart';

// Цвета — те же, что в CSS сайта (светлая и тёмная темы), тёплая палитра с душой
class Pal {
  final Color bg, bg2, card, tx, mu, bd, ac, ac2, ok, dng;
  const Pal({
    required this.bg,
    required this.bg2,
    required this.card,
    required this.tx,
    required this.mu,
    required this.bd,
    required this.ac,
    required this.ac2,
    required this.ok,
    required this.dng,
  });

  static const light = Pal(
    bg: Color(0xFFFDFBF7),
    bg2: Color(0xFFF5EDE2),
    card: Color(0xFFFFFFFF),
    tx: Color(0xFF1C1512),
    mu: Color(0xFF6E645E),
    bd: Color(0xFFEADFD3),
    ac: Color(0xFFFF5722),
    ac2: Color(0xFFFF9800),
    ok: Color(0xFF16A34A),
    dng: Color(0xFFDC2626),
  );

  // Тёмная тема: глубокий тёплый графит и благородный терракотовый акцент
  static const dark = Pal(
    bg: Color(0xFF12100E),
    bg2: Color(0xFF1A1714),
    card: Color(0xFF201C18),
    tx: Color(0xFFF7F2ED),
    mu: Color(0xFFA69B92),
    bd: Color(0xFF332B24),
    ac: Color(0xFFFF6838),
    ac2: Color(0xFFFFA02E),
    ok: Color(0xFF34D399),
    dng: Color(0xFFF87171),
  );
}

Pal pal(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? Pal.dark : Pal.light;

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Pal.dark : Pal.light;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    visualDensity: VisualDensity.standard,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    dividerColor: p.bd,
    colorScheme: ColorScheme.fromSeed(seedColor: p.ac, brightness: b)
        .copyWith(primary: p.ac, surface: p.card, onSurface: p.tx),
    dialogTheme: DialogTheme(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: p.bd),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      position: PopupMenuPosition.under,
      color: p.card,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: p.tx),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.bd),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.card),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStatePropertyAll(BorderSide(color: p.bd)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.tx,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: p.tx, fontSize: 20, fontWeight: FontWeight.w800),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: QuickPageTransitions(),
      TargetPlatform.iOS: QuickPageTransitions(),
      TargetPlatform.linux: QuickPageTransitions(),
      TargetPlatform.macOS: QuickPageTransitions(),
      TargetPlatform.windows: QuickPageTransitions(),
      TargetPlatform.fuchsia: QuickPageTransitions(),
    }),
    textSelectionTheme: TextSelectionThemeData(cursorColor: p.ac, selectionColor: p.ac.withOpacity(.28), selectionHandleColor: p.ac),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.tx,
      contentTextStyle: TextStyle(color: p.bg, fontWeight: FontWeight.w600),
    ),
  );
}

BoxDecoration cardDeco(Pal p, {double r = 20}) => BoxDecoration(
      color: p.card,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: p.bd),
      boxShadow: [
        BoxShadow(
          color: p.ac.withOpacity(.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );

InputDecoration deco(BuildContext c, String? label, {String? hint, Widget? suffix, Widget? prefix}) {
  final p = pal(c);
  OutlineInputBorder ob(Color col, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: col, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffix,
    prefixIcon: prefix,
    filled: true,
    fillColor: p.card,
    labelStyle: TextStyle(color: p.mu),
    hintStyle: TextStyle(color: p.mu.withOpacity(.7)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: ob(p.bd),
    border: ob(p.bd),
    focusedBorder: ob(p.ac, 1.6),
  );
}

/// Плавный переход между экранами (как на сайте + жест «свайп назад» от левого края):
/// мягкое проявление, лёгкий подъём/сдвиг и масштабирование.
class QuickPageTransitions extends PageTransitionsBuilder {
  const QuickPageTransitions();
  static const PageTransitionsBuilder _cupertino = CupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (route.popGestureInProgress) {
      return _cupertino.buildTransitions<T>(route, context, animation, secondaryAnimation, child);
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, .75, curve: Curves.easeOut),
      reverseCurve: const Interval(.15, 1, curve: Curves.easeIn),
    );
    final outCurve = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(begin: Offset.zero, end: const Offset(-.04, 0)).animate(outCurve),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: .975).animate(outCurve),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(fade),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(.06, .018), end: Offset.zero).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: .975, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Единая шкала скруглений (как на сайте: --r1, --r2, --r3)
class R {
  static const double s = 12, m = 16, l = 22;
}
