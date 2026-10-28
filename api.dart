import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

// Тот же сервер (Google Apps Script), что и у сайта — данные общие.
const apiUrl =
    'https://script.google.com/macros/s/AKfycbwSe1I-p3TTpHsFWpC3RAg7ZhaI5t_hbOwOoghcOwf7O117Bzl7oy3E3nRIfWoydcBN/exec';

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => message;
}

String sha256Hex(String s) => sha256.convert(utf8.encode(s)).toString();

class Api {
  static const String url = apiUrl;
  static String? token;
  static String deviceName = 'Android · Приложение ДелоЕсть';
  static String ip = '';
  static String geo = '';

  // IP и страна нужны только для списка «Устройства и сеансы»; сервер Apps Script их сам не видит
  static Future<void> loadNetInfo() async {
    try {
      final r = await http.get(Uri.parse('https://ipwho.is/')).timeout(const Duration(seconds: 10));
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      if (j['success'] != false && j['ip'] != null) {
        ip = j['ip'].toString();
        geo = [j['country'], j['city']].where((e) => e != null && e.toString().isNotEmpty).join(', ');
      }
    } catch (_) {}
  }

  // Одно общее соединение: не тратим время на новое подключение при каждом запросе
  static final http.Client _client = http.Client();
  // Запросы только на чтение можно безопасно повторить, если сервер Apps Script «просыпается» или занят
  static const _safe = {'ads', 'pushes', 'unread', 'dialogs', 'thread', 'profile', 'site', 'legal', 'posts'};

  static Future<Map<String, dynamic>> call(String a, [Map<String, dynamic>? data]) async {
    final retry = _safe.contains(a) ? 2 : 0;
    ApiError? last;
    for (var attempt = 0; attempt <= retry; attempt++) {
      if (attempt > 0) await Future.delayed(Duration(milliseconds: 1200 * attempt));
      try {
        return await _once(a, data);
      } on ApiError catch (e) {
        last = e;
        final m = e.message.toLowerCase();
        final transient = m.contains('нет соединения') || m.contains('некорректно') || m.contains('lock') || m.contains('блокир');
        if (!transient) rethrow;
      }
    }
    throw last ?? ApiError('Нет соединения. Проверьте интернет');
  }

  static Future<Map<String, dynamic>> _once(String a, Map<String, dynamic>? data) async {
    final body = jsonEncode(<String, dynamic>{'a': a, 't': token, 'dev': deviceName, 'ip': ip, 'geo': geo, ...?data});
    late http.Response res;
    try {
      res = await _client
          .post(Uri.parse(apiUrl),
              headers: {'Content-Type': 'text/plain;charset=utf-8'}, body: body)
          .timeout(const Duration(seconds: 40));
      // Apps Script отвечает редиректом — Dart не следует ему для POST, делаем вручную
      var hops = 0;
      while ({301, 302, 303, 307, 308}.contains(res.statusCode) &&
          res.headers['location'] != null &&
          hops < 5) {
        res = await _client
            .get(Uri.parse(res.headers['location']!))
            .timeout(const Duration(seconds: 40));
        hops++;
      }
    } catch (_) {
      throw ApiError('Нет соединения. Проверьте интернет');
    }
    late Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiError('Сервер ответил некорректно. Попробуйте ещё раз');
    }
    if (j['ok'] != true) {
      throw ApiError((j['err'] ?? 'Ошибка').toString());
    }
    return j;
  }
}
