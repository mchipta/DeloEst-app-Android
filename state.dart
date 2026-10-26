import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'models.dart';
import 'util.dart';

class S extends ChangeNotifier {
  static final S i = S._();
  S._();

  static const MethodChannel _notifyCh = MethodChannel('ru.deloest.delo_est/notify');

  late SharedPreferences prefs;
  Map<String, dynamic>? user;
  List<Ad> ads = [];
  bool loading = false;
  String? loadError;
  ThemeMode themeMode = ThemeMode.system;
  int tab = 0;
  // корневая вкладка: у вошедшего «Главной» нет, ею служит «Поиск»
  int get rootTab => logged ? 1 : 0;
  int cabTick = 0;
  int msgTick = 0;
  int unread = 0;
  bool messagesOpen = false;
  bool messageNotificationsEnabled = true;
  // прозрачная плавающая нижняя панель: контент виден сквозь неё, как в Telegram
  bool navTransparent = true;
  // вид списка объявлений: 0 список, 1 плитка, 2 компактно
  int feedMode = 0;
  bool chatQuickSuggestionsEnabled = true;
  String timeZone = '';
  VoidCallback? openMessages;
  // экран «Разместить»: системная «назад» сначала возвращает на прошлый шаг формы
  bool Function()? postBack;
  Set<String> fav = {};
  Map<String, String> mutedChats = {};
  Map<String, String> blockedUsers = {};
  List<Map<String, String>> ss = [];
  Map<String, String>? pendingSearch;
  String cid = '';
  int lastPushTs = 0;
  String? updateTag;
  String? updateUrl;
  String? updateName;
  Timer? _timer;
  bool _unreadInit = false;
  int chatOpen = 0;
  static final msgKey = GlobalKey<ScaffoldMessengerState>();
  // аватарки авторов (по pid), чтобы не запрашивать профиль заново
  static final Map<String, String> avatarCache = {};

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    i.prefs = p;
    final u = p.getString('user');
    if (u != null) {
      try {
        i.user = Map<String, dynamic>.from(jsonDecode(u) as Map);
        Api.token = i.user!['t'] as String?;
        i.tab = 1; // у вошедшего вкладки «Главная» нет, стартуем с поиска
      } catch (_) {
        i.user = null;
      }
    }
    i.messageNotificationsEnabled = p.getBool('messages_notifications') ?? true;
    i.navTransparent = p.getBool('nav_transparent') ?? true;
    i.feedMode = (p.getInt('feed_mode') ?? 0).clamp(0, 2).toInt();
    applyEdgeToEdge(true); // панель всегда плавающая, вокруг неё ничего нет
    i.chatQuickSuggestionsEnabled = p.getBool('chat_quick_suggestions') ?? true;
    i.timeZone = p.getString('timezone') ?? '';
    i.lastPushTs = p.getInt('last_push_ts') ?? DateTime.now().millisecondsSinceEpoch;
    if (!p.containsKey('last_push_ts')) {
      await p.setInt('last_push_ts', i.lastPushTs);
    }
    final tm = p.getString('theme');
    i.themeMode = tm == 'dark'
        ? ThemeMode.dark
        : tm == 'light'
            ? ThemeMode.light
            : ThemeMode.system;
    var c = p.getString('cid');
    if (c == null || c.isEmpty) {
      final r = Random();
      c = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
      await p.setString('cid', c);
    }
    i.cid = c;
    final fl = p.getStringList('fav');
    if (fl != null) i.fav = fl.toSet();
    final muted = p.getString('muted_chats');
    if (muted != null) {
      try {
        i.mutedChats = Map<String, String>.from(jsonDecode(muted) as Map);
      } catch (_) {}
    }
    final bl = p.getString('blocked_users');
    if (bl != null) {
      try {
        i.blockedUsers = Map<String, String>.from(jsonDecode(bl) as Map);
      } catch (_) {}
    }
    final sj = p.getString('ss');
    if (sj != null) {
      try {
        i.ss = (jsonDecode(sj) as List).map((e) => Map<String, String>.from(e as Map)).toList();
      } catch (_) {}
    }
    final cached = p.getString('ads');
    if (cached != null) {
      try {
        i.ads = (jsonDecode(cached) as List)
            .map((e) => Ad.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }
    requestPushPermission();
    i._timer = Timer.periodic(const Duration(seconds: 20), (_) => i.refreshUnread());
    i.refreshUnread();
    if (i.logged) i.syncBlocks();
    Future.delayed(const Duration(seconds: 3), () => i.checkAppUpdate(silent: true));
  }

  static Future<void> requestPushPermission() async {
    try {
      await _notifyCh.invokeMethod('request');
    } catch (_) {}
  }

  static Future<void> showSystemPush(String title, String body, {int? id}) async {
    try {
      await _notifyCh.invokeMethod('show', {
        'title': title,
        'body': body,
        'id': id ?? (DateTime.now().millisecondsSinceEpoch & 0x7fffffff),
      });
    } catch (_) {}
  }

  bool get logged => user != null;
  String get pid => (user?['pid'] ?? '').toString();
  String get phone => (user?['phone'] ?? '').toString();
  String get name => (user?['name'] ?? '').toString();
  String get login => (user?['login'] ?? '').toString();

  Future<void> setUser(Map<String, dynamic>? j) async {
    user = j;
    Api.token = j == null ? null : j['t'] as String?;
    if (j == null) {
      await prefs.remove('user');
    } else {
      await prefs.setString('user', jsonEncode(j));
    }
    cabTick++;
    if (j == null) {
      unread = 0;
      _unreadInit = false;
      if (tab == 4) tab = 0; // вкладка «Сообщения» только для вошедших
    } else if (tab == 0) {
      tab = 1; // вошли: «Главная» скрыта, открываем поиск
    }
    notifyListeners();
    if (j != null) {
      refreshUnread();
      syncBlocks();
    }
  }

  Future<void> patchUser(Map<String, dynamic> m) async {
    if (user == null) return;
    user = <String, dynamic>{...user!, ...m};
    await prefs.setString('user', jsonEncode(user));
    notifyListeners();
  }

  bool isFav(String id) => fav.contains(id);

  bool isChatMuted(String pid) => mutedChats.containsKey(pid);

  bool isBlocked(String pid) => pid.isNotEmpty && blockedUsers.containsKey(pid);

  Future<void> reportItem(String id, String reason) async {
    await Api.call('report', {'id': id, 'reason': reason});
  }

  Future<void> setBlocked(String targetPid, String targetName, bool on) async {
    if (logged) {
      await Api.call('block', {'pid': targetPid, 'on': on});
    }
    if (on) {
      blockedUsers[targetPid] = targetName.isEmpty ? 'Пользователь' : targetName;
    } else {
      blockedUsers.remove(targetPid);
    }
    await prefs.setString('blocked_users', jsonEncode(blockedUsers));
    notifyListeners();
  }

  Future<void> syncBlocks() async {
    if (!logged) return;
    try {
      final j = await Api.call('blocks');
      final list = j['list'];
      if (list is List) {
        final next = <String, String>{};
        for (final it in list) {
          final m = Map<String, dynamic>.from(it as Map);
          final p = (m['pid'] ?? '').toString();
          final n = (m['name'] ?? 'Пользователь').toString();
          if (p.isNotEmpty) next[p] = n;
        }
        blockedUsers = next;
        await prefs.setString('blocked_users', jsonEncode(blockedUsers));
        notifyListeners();
      }
    } catch (_) {}
  }

  // подсказки и предупреждение в чате скрываются отдельно для каждого собеседника (навсегда)
  bool chipsHidden(String pid) => prefs.getBool('qh_${user?['pid'] ?? ''}_$pid') ?? false;
  Future<void> hideChips(String pid) => prefs.setBool('qh_${user?['pid'] ?? ''}_$pid', true);
  bool safeHidden(String pid) => prefs.getBool('safe_${user?['pid'] ?? ''}_$pid') ?? false;
  Future<void> hideSafe(String pid) => prefs.setBool('safe_${user?['pid'] ?? ''}_$pid', true);

  Future<void> setChatQuickSuggestionsEnabled(bool enabled) async {
    chatQuickSuggestionsEnabled = enabled;
    await prefs.setBool('chat_quick_suggestions', enabled);
    notifyListeners();
  }

  Future<void> setChatMuted(String pid, String name, bool muted) async {
    if (muted) {
      mutedChats[pid] = name;
    } else {
      mutedChats.remove(pid);
    }
    await prefs.setString('muted_chats', jsonEncode(mutedChats));
    _unreadInit = false; // переключение фильтра уведомлений не должно выглядеть новым сообщением
    notifyListeners();
    refreshUnread();
  }

  Future<void> saveSS() async {
    await prefs.setString('ss', jsonEncode(ss));
    notifyListeners();
  }

  Future<void> toggleFav(String id) async {
    if (!fav.remove(id)) fav.add(id);
    await prefs.setStringList('fav', fav.toList());
    notifyListeners();
  }

  Future<void> refreshUnread() async {
    try {
      // Проверяем серверные Push-уведомления (рассылки админа и события по сделкам)
      final pj = await Api.call('pushes', {'after': lastPushTs});
      final plist = pj['list'];
      if (plist is List && plist.isNotEmpty) {
        var maxTs = lastPushTs;
        for (final raw in plist) {
          final m = Map<String, dynamic>.from(raw as Map);
          final ts = (m['ts'] as num?)?.toInt() ?? 0;
          final title = (m['title'] ?? 'ДелоЕсть').toString();
          final body = (m['body'] ?? '').toString();
          if (ts > maxTs) maxTs = ts;
          if (messageNotificationsEnabled && body.isNotEmpty) {
            await showSystemPush(title, body);
            final sm = msgKey.currentState;
            if (sm != null) {
              sm.hideCurrentSnackBar();
              sm.showSnackBar(SnackBar(content: Text('$title: $body')));
            }
          }
        }
        if (maxTs > lastPushTs) {
          lastPushTs = maxTs;
          await prefs.setInt('last_push_ts', lastPushTs);
        }
      }
    } catch (_) {}

    if (!logged) {
      if (unread != 0) {
        unread = 0;
        notifyListeners();
      }
      return;
    }
    try {
      int n;
      if (mutedChats.isEmpty) {
        final j = await Api.call('unread');
        n = (j['n'] as num?)?.toInt() ?? 0;
      } else {
        // Когда есть отключённые диалоги, считаем непрочитанное по диалогам,
        // как это делает веб-версия, чтобы приглушённые чаты не поднимали бейдж.
        final j = await Api.call('dialogs');
        n = 0;
        final list = j['list'];
        if (list is List) {
          for (final item in list) {
            final d = Map<String, dynamic>.from(item as Map);
            if (!isChatMuted((d['pid'] ?? '').toString())) {
              n += (d['n'] as num?)?.toInt() ?? int.tryParse((d['n'] ?? '0').toString()) ?? 0;
            }
          }
        }
      }
      if (_unreadInit && n > unread && messageNotificationsEnabled && !messagesOpen && chatOpen == 0) {
        await showSystemPush('Новое сообщение', 'Откройте ДелоЕсть, чтобы прочитать сообщение');
        final sm = msgKey.currentState;
        if (sm != null) {
          sm.hideCurrentSnackBar();
          sm.showSnackBar(SnackBar(
            content: const Text('Новое сообщение'),
            action: SnackBarAction(label: 'Открыть', onPressed: () => openMessages?.call()),
          ));
        }
      }
      _unreadInit = true;
      if (n != unread) {
        unread = n;
        msgTick++;
        notifyListeners();
      }
    } catch (e) {
      if (e is ApiError && e.message == 'auth') fail(e);
    }
  }

  /// Проверка обновлений APK через GitHub Releases репозитория
  Future<bool> checkAppUpdate({bool silent = true}) async {
    try {
      final res = await http
          .get(
            Uri.parse('https://api.github.com/repos/mchipta/DeloEst-app-Android/releases/latest'),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (j['tag_name'] ?? '').toString().trim();
      final name = (j['name'] ?? tag).toString().trim();
      var dl = (j['html_url'] ?? 'https://github.com/mchipta/DeloEst-app-Android/releases/latest').toString();
      if (j['assets'] is List) {
        for (final a in (j['assets'] as List)) {
          if (a is Map && (a['browser_download_url'] ?? '').toString().endsWith('.apk')) {
            dl = a['browser_download_url'].toString();
            break;
          }
        }
      }
      if (tag.isEmpty) return false;
      final seenTag = prefs.getString('seen_release_tag') ?? '';
      if (seenTag.isEmpty) {
        // Первый запуск этой сборки — запоминаем текущий релиз как базовый
        await prefs.setString('seen_release_tag', tag);
        updateTag = tag;
        updateUrl = dl;
        updateName = name;
        notifyListeners();
        return !silent;
      }
      updateTag = tag;
      updateUrl = dl;
      updateName = name;
      notifyListeners();
      if (tag != seenTag) {
        final sm = msgKey.currentState;
        if (sm != null) {
          sm.hideCurrentSnackBar();
          sm.showSnackBar(SnackBar(
            duration: const Duration(seconds: 8),
            content: Text('Доступно обновление приложения ($name)'),
            action: SnackBarAction(
              label: 'Скачать APK',
              onPressed: () {
                prefs.setString('seen_release_tag', tag);
                launchUrl(Uri.parse(dl), mode: LaunchMode.externalApplication);
              },
            ),
          ));
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadAds() async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final j = await Api.call('ads');
      final list = (j['ads'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      ads = list.map(Ad.fromJson).toList();
      final slim = list.map((m) => <String, dynamic>{...m, 'phone': ''}).toList();
      await prefs.setString('ads', jsonEncode(slim));
    } catch (e) {
      loadError = fail(e);
    }
    loading = false;
    notifyListeners();
  }

  String fail(Object e) {
    final m = e is ApiError ? e.message : 'Что-то пошло не так. Попробуйте ещё раз';
    if (m == 'auth') {
      setUser(null);
      return 'Войдите в аккаунт';
    }
    return m;
  }

  // стеклянная панель: приложение рисуется под системной полосой навигации
  static void applyEdgeToEdge(bool on) {
    if (on) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    }
  }

  Future<void> setFeedMode(int m) async {
    if (m == feedMode) return;
    feedMode = m;
    notifyListeners();
    await prefs.setInt('feed_mode', m);
  }

  Future<void> setNavTransparent(bool v) async {
    navTransparent = v;
    await prefs.setBool('nav_transparent', v);
    notifyListeners();
  }

  Future<void> setMessageNotificationsEnabled(bool enabled) async {
    messageNotificationsEnabled = enabled;
    await prefs.setBool('messages_notifications', enabled);
    if (enabled) requestPushPermission();
    notifyListeners();
  }

  Future<void> setTimeZone(String zone) async {
    timeZone = zone;
    await prefs.setString('timezone', zone);
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    await prefs.setString('theme', m == ThemeMode.dark ? 'dark' : m == ThemeMode.light ? 'light' : 'system');
    notifyListeners();
  }

  void goTab(int t) {
    tab = t;
    if (t == 3) cabTick++;
    if (t == 4) msgTick++;
    notifyListeners();
  }

  void bumpCab() {
    cabTick++;
    notifyListeners();
  }
}
