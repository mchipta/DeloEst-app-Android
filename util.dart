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
