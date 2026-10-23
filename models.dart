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
  final bool ver;
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
  });

  factory Ad.fromJson(Map<String, dynamic> j) {
    String s(String k) => (j[k] ?? '').toString();
    final im = j['imgs'];
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
    );
  }
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
