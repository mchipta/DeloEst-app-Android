import 'package:flutter/material.dart';

const kTypes = ['Нужен исполнитель', 'Предлагаю услуги'];

class Cat {
  final String name;
  final IconData icon;
  const Cat(this.name, this.icon);
}

const kCats = <Cat>[
  Cat('Строительство и ремонт', Icons.construction),
  Cat('Грузчики и переезд', Icons.local_shipping_outlined),
  Cat('Уборка', Icons.cleaning_services_outlined),
  Cat('Курьеры и доставка', Icons.inventory_2_outlined),
  Cat('Сад и огород', Icons.yard_outlined),
  Cat('Репетиторство', Icons.menu_book_outlined),
  Cat('Компьютеры и IT', Icons.laptop_mac),
  Cat('Ремонт техники', Icons.build_outlined),
  Cat('Мероприятия', Icons.celebration_outlined),
  Cat('Прочее', Icons.more_horiz),
];

IconData catIcon(String name) {
  for (final c in kCats) {
    if (c.name == name) return c.icon;
  }
  return Icons.more_horiz;
}

// Цвет категории: те же шесть оттенков, что и на сайте (по порядку категорий)
const kCatHues = <Color>[
  Color(0xFFF08A24),
  Color(0xFF2F9BFF),
  Color(0xFFA26BFF),
  Color(0xFF22B573),
  Color(0xFFE8508F),
  Color(0xFF14B8C4),
];

Color catHue(String name) {
  for (var i = 0; i < kCats.length; i++) {
    if (kCats[i].name == name) return kCatHues[i % kCatHues.length];
  }
  return kCatHues[0];
}

double? _dbl(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.'));
}

/// «Город, адрес» одной строкой
String adLoc(Ad a) => [a.city.trim(), a.addr.trim()].where((e) => e.isNotEmpty).join(', ');

int _int(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse((v ?? '').toString()) ?? 0;
}

class Ad {
  final String id, author, type, title, category, pay, city, desc, status, phone, pid;
  final String addr; // адрес для карты
  final double? lat, lng; // координаты метки (если указаны)
  final int ts, views, opens, rc;
  final int payAmt, need, up, upd, dn, since; // сумма, нужно людей, «поднято», обновлено, выполнено работ, на сервисе с
  final String payType, when, dur; // тип оплаты (hour/day/job/neg), дата и время работы, длительность
  final bool urgent;
  final bool ver;
  final bool innOk;
  final bool autoRenew;
  final Map<String, dynamic> dailyStats;
  final double rt;
  final List<String> imgs;

  Ad({
    required this.id,
    required this.author,
    required this.type,
    required this.title,
    required this.category,
    required this.pay,
    required this.city,
    required this.desc,
    required this.status,
    required this.phone,
    required this.pid,
    required this.ts,
    required this.views,
    required this.opens,
    required this.rc,
    required this.ver,
    required this.rt,
    required this.imgs,
    this.addr = '',
    this.lat,
    this.lng,
    this.payAmt = 0,
    this.need = 0,
    this.up = 0,
    this.upd = 0,
    this.dn = 0,
    this.since = 0,
    this.payType = '',
    this.when = '',
    this.dur = '',
    this.urgent = false,
    this.innOk = false,
    this.autoRenew = false,
    this.dailyStats = const {},
  });

  factory Ad.fromJson(Map<String, dynamic> j) {
    String s(String k) => (j[k] ?? '').toString();
    final im = j['imgs'];
    final ds = j['dailyStats'];
    return Ad(
      id: s('id'),
      author: s('author'),
      type: s('type'),
      title: s('title'),
      category: s('category'),
      pay: s('pay'),
      city: s('city'),
      desc: s('desc'),
      status: s('status'),
      phone: s('phone'),
      pid: s('pid'),
      ts: _int(j['ts']),
      views: _int(j['views']),
      opens: _int(j['opens']),
      rc: _int(j['rc']),
      ver: j['ver'] == true,
      rt: j['rt'] is num ? (j['rt'] as num).toDouble() : 0,
      imgs: im is List ? im.map((e) => e.toString()).toList() : <String>[],
      addr: s('addr'),
      lat: _dbl(j['lat']),
      lng: _dbl(j['lng']),
      payAmt: _int(j['payAmt']),
      need: _int(j['need']),
      up: _int(j['up']) > 0 ? _int(j['up']) : _int(j['ts']),
      upd: _int(j['upd']) > 0 ? _int(j['upd']) : _int(j['ts']),
      dn: _int(j['dn']),
      since: _int(j['since']),
      payType: s('payType'),
      when: s('when'),
      dur: s('dur'),
      urgent: j['urgent'] == true,
      innOk: j['innOk'] == true,
      autoRenew: j['autoRenew'] == true,
      dailyStats: ds is Map ? Map<String, dynamic>.from(ds) : const {},
    );
  }
}

const Map<String, Map<String, String>> kCatPriceHints = {
  'Строительство и ремонт': {'h': '600–1 500 ₽/час', 'd': '3 500–7 000 ₽/день', 't': '2 000–15 000 ₽ за задачу'},
  'Грузчики и переезд': {'h': '500–900 ₽/час', 'd': '3 000–5 000 ₽/день', 't': '1 500–6 000 ₽ за задачу'},
  'Уборка': {'h': '400–800 ₽/час', 'd': '2 500–4 500 ₽/день', 't': '2 000–5 000 ₽ за задачу'},
  'Курьеры и доставка': {'h': '350–600 ₽/час', 'd': '2 500–4 500 ₽/день', 't': '400–1 500 ₽ за задачу'},
  'Сад и огород': {'h': '400–800 ₽/час', 'd': '2 500–4 500 ₽/день', 't': '1 500–5 000 ₽ за задачу'},
  'Репетиторство': {'h': '600–1 500 ₽/час', 'd': '2 000–4 000 ₽/день', 't': '800–2 000 ₽ за занятие'},
  'Компьютеры и IT': {'h': '700–1 800 ₽/час', 'd': '3 500–8 000 ₽/день', 't': '1 000–10 000 ₽ за задачу'},
  'Ремонт техники': {'h': '600–1 400 ₽/час', 'd': '3 000–6 000 ₽/день', 't': '1 200–5 000 ₽ за ремонт'},
  'Мероприятия': {'h': '500–1 500 ₽/час', 'd': '3 000–7 000 ₽/день', 't': '2 000–10 000 ₽ за задачу'},
  'Прочее': {'h': '400–900 ₽/час', 'd': '2 500–4 500 ₽/день', 't': '1 000–4 000 ₽ за задачу'},
};

String? catPriceHint(String cat, String unit) {
  if (unit == 'n' || unit == 'x') return null;
  final m = kCatPriceHints[cat] ?? kCatPriceHints['Прочее']!;
  return m[unit] ?? m['t'];
}

String payF(String v) {
  final t = v.trim();
  if (t.isEmpty) return 'Договорная';
  if (RegExp(r'^\d[\d\s.,]*$').hasMatch(t)) return '$t ₽';
  return t;
}

String ago(int ts) {
  if (ts <= 0) return '';
  final t = DateTime.fromMillisecondsSinceEpoch(ts);
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'только что';
  if (d.inMinutes < 60) return '${d.inMinutes} мин. назад';
  if (d.inHours < 24) return '${d.inHours} ч. назад';
  if (d.inDays == 1) return 'вчера';
  if (d.inDays < 7) return '${d.inDays} дн. назад';
  return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';
}

String plural(int n, String one, String few, String many) {
  final a = n % 10, b = n % 100;
  if (a == 1 && b != 11) return one;
  if (a >= 2 && a <= 4 && (b < 12 || b > 14)) return few;
  return many;
}

// Типы оплаты: код для сервера и подпись
const kPayTypes = <List<String>>[
  ['hour', 'За час'],
  ['day', 'За день'],
  ['job', 'За задачу'],
  ['month', 'За месяц'],
  ['neg', 'Договорная'],
];

String payTypeLabel(String t) => kPayTypes.firstWhere((e) => e[0] == t, orElse: () => ['', ''])[1];

/// Оплата для карточки: «1 500 ₽/час»; для старых объявлений берём текст как есть
String adPay(Ad a) {
  if (a.payType == 'neg') return 'Договорная';
  if (a.payAmt > 0) {
    final n = a.payAmt.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
    final suf = a.payType == 'hour' ? '/час' : a.payType == 'day' ? '/день' : a.payType == 'job' ? ' за задачу' : a.payType == 'month' ? '/месяц' : '';
    return '$n ₽$suf';
  }
  return payF(a.pay);
}

/// Сумма для сортировки и фильтра: из числа, а у старых объявлений — из текста
int adAmt(Ad a) {
  if (a.payAmt > 0) return a.payAmt;
  final m = RegExp(r'\d[\d\s]*').firstMatch(a.pay);
  return m == null ? 0 : int.tryParse(m.group(0)!.replaceAll(RegExp(r'\s'), '')) ?? 0;
}

DateTime? adWhen(Ad a) => a.when.isEmpty ? null : DateTime.tryParse(a.when);

/// «Сегодня, 18:00», «Завтра», «12 ноя, 09:30» + длительность и число людей
String adWhenLabel(Ad a) {
  final d = adWhen(a);
  if (d == null) return '';
  final now = DateTime.now(), t0 = DateTime(now.year, now.month, now.day), d0 = DateTime(d.year, d.month, d.day);
  final diff = d0.difference(t0).inDays;
  const mon = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
  final day = diff == 0 ? 'Сегодня' : diff == 1 ? 'Завтра' : '${d.day} ${mon[d.month - 1]}';
  final time = a.when.contains('T') ? ', ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}' : '';
  return '$day$time';
}

String adNeedLabel(Ad a) => a.need > 1 ? 'Нужно ${a.need} ${plural(a.need, 'человек', 'человека', 'человек')}' : '';

/// Сколько на сервисе: «на сервисе с 28 окт 2026»
String sinceLabel(int ts) {
  if (ts <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  const mon = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
  return 'на сервисе с ${d.day} ${mon[d.month - 1]} ${d.year}';
}
