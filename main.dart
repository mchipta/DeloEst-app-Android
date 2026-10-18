import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'splash.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await S.init();
  // Фиолетовой иконки больше нет: если она была выбрана раньше, возвращаем оранжевую
  try {
    if (S.i.prefs.getString('launcher_icon_style') == 'purple') {
      await const MethodChannel('ru.deloest.delo_est/launcher_icon').invokeMethod('setLauncherIcon', 'orange');
      await S.i.prefs.setString('launcher_icon_style', 'orange');
    }
  } catch (_) {}
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
