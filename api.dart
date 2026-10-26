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

  static Future<Map<String, dynamic>> call(String a, [Map<String, dynamic>? data]) async {
    final body = jsonEncode(<String, dynamic>{'a': a, 't': token, 'dev': deviceName, 'ip': ip, 'geo': geo, ...?data});
    late http.Response res;
    try {
      res = await http
          .post(Uri.parse(apiUrl),
              headers: {'Content-Type': 'text/plain;charset=utf-8'}, body: body)
          .timeout(const Duration(seconds: 60));
      // Apps Script отвечает редиректом — Dart не следует ему для POST, делаем вручную
      var hops = 0;
      while ({301, 302, 303, 307, 308}.contains(res.statusCode) &&
          res.headers['location'] != null &&
          hops < 5) {
        res = await http
            .get(Uri.parse(res.headers['location']!))
            .timeout(const Duration(seconds: 60));
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
