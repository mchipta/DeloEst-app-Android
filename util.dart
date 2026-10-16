import 'package:flutter/services.dart';

const kAppVersion = '1.3';
const kSiteUrl = 'https://mchipta.github.io/delo-est/';

String digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

// 8XXXXXXXXXX и 10 цифр приводим к 7XXXXXXXXXX
String normPhone(String v) {
  var d = digitsOnly(v);
  if (d.length == 11 && d.startsWith('8')) d = '7${d.substring(1)}';
  if (d.length == 10) d = '7$d';
  return d;
}

// +7 (999) 123-45-67
String fmtPhone(String v) {
  final d = digitsOnly(v);
  if (d.isEmpty) return '';
  var s = d;
  if (s.startsWith('8')) {
    s = '7${s.substring(1)}';
  } else if (!s.startsWith('7')) {
    s = '7$s';
  }
  if (s.length > 11) s = s.substring(0, 11);
  final r = s.substring(1);
  var out = '+7';
  if (r.isNotEmpty) out += ' (${r.substring(0, r.length < 3 ? r.length : 3)}';
  if (r.length >= 3) out += ')';
  if (r.length > 3) out += ' ${r.substring(3, r.length < 6 ? r.length : 6)}';
  if (r.length > 6) out += '-${r.substring(6, r.length < 8 ? r.length : 8)}';
  if (r.length > 8) out += '-${r.substring(8)}';
  return out;
}

class PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldV, TextEditingValue newV) {
    var d = digitsOnly(newV.text);
    if (newV.text.length < oldV.text.length && digitsOnly(oldV.text) == d && d.isNotEmpty) {
      d = d.substring(0, d.length - 1);
    }
    final t = fmtPhone(d);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

// 12 500
String grp(String s) {
  final d = digitsOnly(s);
  final t = d.length > 9 ? d.substring(0, 9) : d;
  final b = StringBuffer();
  for (var i = 0; i < t.length; i++) {
    if (i > 0 && (t.length - i) % 3 == 0) b.write(' ');
    b.write(t[i]);
  }
  return b.toString();
}

class GroupFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldV, TextEditingValue newV) {
    final t = grp(newV.text);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

const kPayUnits = [
  ['h', 'За час'],
  ['d', 'За день'],
  ['t', 'За задачу'],
  ['m', 'За месяц'],
  ['n', 'Договорная'],
];

class PayParts {
  final String p, a, raw;
  const PayParts(this.p, this.a, [this.raw = '']);
}

PayParts payParse(String s) {
  final t = s.trim();
  if (t.isEmpty) return const PayParts('h', '');
  if (RegExp(r'^договор', caseSensitive: false).hasMatch(t)) return const PayParts('n', '');
  final m = RegExp(r'^(\d[\d\s]*?)\s*(?:₽|руб\.?|р\.?)?\s*(?:(?:/|за|в)\s*(час|день|задачу|месяц|мес))?$',
          caseSensitive: false)
      .firstMatch(t);
  if (m == null) return PayParts('x', '', t);
  final w = (m.group(2) ?? '').toLowerCase();
  final u = w == 'час' ? 'h' : w == 'день' ? 'd' : w.startsWith('мес') ? 'm' : 't';
  return PayParts(u, digitsOnly(m.group(1) ?? ''));
}

String payStr(String a, String p, String raw) {
  final d = digitsOnly(a);
  if (p == 'n') return 'Договорная';
  if (p == 'x') return raw;
  if (d.isEmpty) return '';
  final n = grp(d);
  return p == 'h' ? '$n ₽/час' : p == 'd' ? '$n ₽/день' : p == 'm' ? '$n ₽/месяц' : '$n ₽ за задачу';
}

// первое число в строке оплаты (для фильтра и сортировки)
double? payNum(String pay) {
  final m = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(pay.replaceAll(RegExp(r'\s'), ''));
  if (m == null) return null;
  return double.tryParse(m.group(0)!.replaceAll(',', '.'));
}

final riskRe = RegExp(
    r'предоплат|аванс|задаток|залог|вперёд|вперед|на карту|перевод на|переведи|вложени|взнос|регистрационн\S* сбор|комисси',
    caseSensitive: false);

class Tpl {
  final String name;
  final int type;
  final String title, cat, desc;
  const Tpl(this.name, this.type, this.title, this.cat, this.desc);
}

const kTpls = <Tpl>[
  Tpl('Грузчики', 0, 'Нужны грузчики на 3 часа', 'Грузчики и переезд',
      'Нужно перенести мебель и вещи.\nОткуда и куда: …\nЭтаж, есть ли лифт: …\nЧто переносить: …\nОплата наличными после работы.'),
  Tpl('Уборка квартиры', 0, 'Нужна уборка квартиры', 'Уборка',
      'Нужно сделать уборку в квартире.\nПлощадь: … м²\nЧто входит: полы, пыль, кухня, санузел\nКогда удобно: …\nОплата после работы.'),
  Tpl('Раздача листовок', 0, 'Нужен человек раздавать листовки', 'Прочее',
      'Нужно раздать листовки.\nГде: …\nКогда и сколько часов: …\nКоличество листовок: …\nОплата по окончании работы.'),
  Tpl('Курьер на день', 0, 'Нужен курьер на день', 'Курьеры и доставка',
      'Нужно доставить заказы по городу.\nСколько адресов и маршрут: …\nКогда: …\nНужен ли свой транспорт: …\nОплата в конце смены.'),
  Tpl('Предлагаю уборку', 1, 'Сделаю уборку в вашем доме', 'Уборка',
      'Аккуратно уберу квартиру или дом.\nОпыт: …\nКогда могу: …\nРайон: …\nОплата после работы.'),
  Tpl('Предлагаю грузчиков', 1, 'Грузчики: помогу с переездом', 'Грузчики и переезд',
      'Помогу перенести мебель и вещи.\nОпыт: …\nСколько нас: …\nКогда могу: …\nОплата после работы.'),
];

String ssLabel(Map<String, String> s) {
  final parts = <String>[
    s['q'] ?? '',
    s['type'] ?? '',
    s['cat'] ?? '',
    s['city'] ?? '',
    (s['min'] ?? '').isEmpty ? '' : 'от ${s['min']} ₽',
    (s['max'] ?? '').isEmpty ? '' : 'до ${s['max']} ₽',
    s['sort'] == 'hi' ? 'дороже' : s['sort'] == 'lo' ? 'дешевле' : '',
  ].where((e) => e.isNotEmpty).toList();
  return parts.join(' · ');
}


// Настройки часового пояса из веб-версии. Все доступные зоны сайта — российские
// зоны без сезонного перевода часов, поэтому их действующие смещения заданы явно.
const kSiteTimeZones = <List<String>>[
  ['', 'Как на устройстве'],
  ['Europe/Kaliningrad', 'Калининград (UTC+2)'],
  ['Europe/Moscow', 'Москва (UTC+3)'],
  ['Europe/Samara', 'Самара (UTC+4)'],
  ['Asia/Yekaterinburg', 'Екатеринбург (UTC+5)'],
  ['Asia/Omsk', 'Омск (UTC+6)'],
  ['Asia/Krasnoyarsk', 'Красноярск (UTC+7)'],
  ['Asia/Irkutsk', 'Иркутск (UTC+8)'],
  ['Asia/Yakutsk', 'Якутск (UTC+9)'],
  ['Asia/Vladivostok', 'Владивосток (UTC+10)'],
  ['Asia/Magadan', 'Магадан (UTC+11)'],
  ['Asia/Kamchatka', 'Камчатка (UTC+12)'],
];

int? _siteZoneHours(String zone) {
  const offsets = <String, int>{
    'Europe/Kaliningrad': 2,
    'Europe/Moscow': 3,
    'Europe/Samara': 4,
    'Asia/Yekaterinburg': 5,
    'Asia/Omsk': 6,
    'Asia/Krasnoyarsk': 7,
    'Asia/Irkutsk': 8,
    'Asia/Yakutsk': 9,
    'Asia/Vladivostok': 10,
    'Asia/Magadan': 11,
    'Asia/Kamchatka': 12,
  };
  return offsets[zone];
}

DateTime siteDate(int ts, String zone) {
  final offset = _siteZoneHours(zone);
  if (offset == null) return DateTime.fromMillisecondsSinceEpoch(ts).toLocal();
  return DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true).add(Duration(hours: offset));
}

String siteDateTime(int ts, String zone) {
  if (ts <= 0) return '';
  final d = siteDate(ts, zone);
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  final hour = d.hour.toString().padLeft(2, '0');
  final minute = d.minute.toString().padLeft(2, '0');
  return '$day.$month.${d.year}, $hour:$minute';
}

String siteChatStamp(int ts, String zone) {
  if (ts <= 0) return '';
  final d = siteDate(ts, zone);
  final now = zone.isEmpty ? DateTime.now() : siteDate(DateTime.now().millisecondsSinceEpoch, zone);
  final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  if (d.year == now.year && d.month == now.month && d.day == now.day) return hm;
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} $hm';
}


String siteListTime(int ts, String zone) {
  if (ts <= 0) return '';
  final d = siteDate(ts, zone);
  final now = zone.isEmpty ? DateTime.now() : siteDate(DateTime.now().millisecondsSinceEpoch, zone);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  if (diff == 0) return hm;
  if (diff == 1) return 'вчера';
  if (diff > 1 && diff < 6) {
    const weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    return weekdays[d.weekday - 1];
  }
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${(d.year % 100).toString().padLeft(2, '0')}';
}
