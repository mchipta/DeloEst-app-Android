import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'models.dart';

class S extends ChangeNotifier {
  static final S i = S._();
  S._();

  late SharedPreferences prefs;
  Map<String, dynamic>? user;
  List<Ad> ads = [];
  bool loading = false;
  String? loadError;
  ThemeMode themeMode = ThemeMode.system;
  int tab = 0;
  int cabTick = 0;
  int msgTick = 0;
  int unread = 0;
  bool messagesOpen = false;
  bool messageNotificationsEnabled = true;
  bool chatQuickSuggestionsEnabled = true;
  String timeZone = '';
  VoidCallback? openMessages;
  Set<String> fav = {};
  Map<String, String> mutedChats = {};
  List<Map<String, String>> ss = [];
  Map<String, String>? pendingSearch;
  String cid = '';
  Timer? _timer;
  bool _unreadInit = false;
  int chatOpen = 0;
  static final msgKey = GlobalKey<ScaffoldMessengerState>();

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    i.prefs = p;
    final u = p.getString('user');
    if (u != null) {
      try {
        i.user = Map<String, dynamic>.from(jsonDecode(u) as Map);
        Api.token = i.user!['t'] as String?;
      } catch (_) {
        i.user = null;
      }
    }
    i.messageNotificationsEnabled = p.getBool('messages_notifications') ?? true;
    i.chatQuickSuggestionsEnabled = p.getBool('chat_quick_suggestions') ?? true;
    i.timeZone = p.getString('timezone') ?? '';
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
      try { i.mutedChats = Map<String, String>.from(jsonDecode(muted) as Map); } catch (_) {}
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
    i._timer = Timer.periodic(const Duration(seconds: 20), (_) => i.refreshUnread());
    i.refreshUnread();
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
    }
    notifyListeners();
    if (j != null) refreshUnread();
  }

  Future<void> patchUser(Map<String, dynamic> m) async {
    if (user == null) return;
    user = <String, dynamic>{...user!, ...m};
    await prefs.setString('user', jsonEncode(user));
    notifyListeners();
  }

  bool isFav(String id) => fav.contains(id);

  bool isChatMuted(String pid) => mutedChats.containsKey(pid);

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

  Future<void> setMessageNotificationsEnabled(bool enabled) async {
    messageNotificationsEnabled = enabled;
    await prefs.setBool('messages_notifications', enabled);
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
    notifyListeners();
  }

  void bumpCab() {
    cabTick++;
    notifyListeners();
  }
}
