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
  String cid = '';

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
    final cached = p.getString('ads');
    if (cached != null) {
      try {
        i.ads = (jsonDecode(cached) as List)
            .map((e) => Ad.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }
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
    notifyListeners();
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

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    await prefs.setString('theme', m == ThemeMode.dark ? 'dark' : m == ThemeMode.light ? 'light' : 'system');
    notifyListeners();
  }

  void goTab(int t) {
    tab = t;
    if (t == 2) cabTick++;
    notifyListeners();
  }

  void bumpCab() {
    cabTick++;
    notifyListeners();
  }
}
