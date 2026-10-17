import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'splash.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await S.init();
  runApp(const DeloApp());
}

class DeloApp extends StatelessWidget {
  const DeloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) => MaterialApp(
        title: 'ДелоЕсть',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: S.msgKey,
        themeMode: S.i.themeMode,
        // русские подписи системных элементов: «Копировать», «Вставить», «Выбрать все»…
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const SplashGate(),
      ),
    );
  }
}
