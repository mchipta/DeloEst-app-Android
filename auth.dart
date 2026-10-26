import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

enum AMode { login, reg, regCode, reset, resetCode }

/// Страна для номера телефона: флаг, код, длина номера без кода и разбивка на группы
class Country {
  final String name, flag, code;
  final int len;
  final List<int> groups;
  final String example;
  const Country(this.name, this.flag, this.code, this.len, this.groups, this.example);
}

const kCountries = <Country>[
  Country('Россия', '🇷🇺', '7', 10, [3, 3, 2, 2], '(900) 000-00-00'),
  Country('Беларусь', '🇧🇾', '375', 9, [2, 3, 2, 2], '(29) 123-45-67'),
  Country('Казахстан', '🇰🇿', '7', 10, [3, 3, 2, 2], '(700) 000-00-00'),
  Country('Узбекистан', '🇺🇿', '998', 9, [2, 3, 2, 2], '(90) 123-45-67'),
];

/// Национальная часть номера без кода страны; понимает вставку «+7…», «8…», «+375…»
String _nat(String v, Country c) {
  var d = v.replaceAll(RegExp(r'\D'), '');
  if (c.code == '7') {
    if (d.length > c.len && (d.startsWith('7') || d.startsWith('8'))) d = d.substring(1);
  } else if (d.startsWith(c.code) && d.length > c.len) {
    d = d.substring(c.code.length);
  }
  return d.length > c.len ? d.substring(0, c.len) : d;
}

String _mask(String d, List<int> g) {
  final b = StringBuffer();
  var i = 0;
  for (var k = 0; k < g.length && i < d.length; k++) {
    final end = i + g[k] > d.length ? d.length : i + g[k];
    final part = d.substring(i, end);
    if (k == 0) {
      b.write('($part');
      if (part.length == g[0]) b.write(')');
    } else {
      b.write(k == 1 ? ' ' : '-');
      b.write(part);
    }
    i = end;
  }
  return b.toString();
}

class _PhoneMask extends TextInputFormatter {
  final Country c;
  const _PhoneMask(this.c);
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    var d = _nat(n.text, c);
    final od = o.text.replaceAll(RegExp(r'\D'), '');
    final nd = n.text.replaceAll(RegExp(r'\D'), '');
    // стёрли только скобку или дефис: убираем и последнюю цифру, чтобы удаление не «застревало»
    if (n.text.length < o.text.length && nd == od && d.isNotEmpty) d = d.substring(0, d.length - 1);
    final t = _mask(d, c.groups);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  AMode m = AMode.login;
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  final code = TextEditingController();
  Country country = kCountries.first;
  bool busy = false;
  bool show = false;
  String? err;
  String? info;

  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  String get _em => email.text.trim().toLowerCase();

  void _mode(AMode x) => setState(() {
        m = x;
        err = null;
        info = null;
      });

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      busy = true;
      err = null;
    });
    try {
      await f();
    } catch (e) {
      if (mounted) setState(() => err = S.i.fail(e));
    }
    if (mounted) setState(() => busy = false);
  }

  bool _check(bool ok, String msg) {
    if (!ok) setState(() => err = msg);
    return ok;
  }

  Future<void> _submit() async {
    switch (m) {
      case AMode.login:
        final id = email.text.trim();
        final byMail = id.contains('@');
        if (!_check(byMail ? _emailRe.hasMatch(_em) : normPhone(id).length >= 11 && normPhone(id).length <= 15, 'Введите почту или номер телефона')) return;
        if (!_check(pass.text.isNotEmpty, 'Введите пароль')) return;
        await _run(() async {
          final Map<String, dynamic> j;
          if (byMail) {
            j = await Api.call('login', {'login': _em, 'hash': sha256Hex('$_em:${pass.text}')});
          } else {
            // вход по номеру: сервер сам находит аккаунт и считает хеш
            j = await Api.call('login', {'login': normPhone(id), 'pw': pass.text, 'hash': ''});
          }
          await _finish(j);
        });
        break;
      case AMode.reg:
        final nat = _nat(phone.text, country);
        if (!_check(name.text.trim().length >= 2, 'Введите имя')) return;
        if (!_check(nat.length == country.len, 'Укажите номер телефона полностью')) return;
        if (!_check(_emailRe.hasMatch(_em), 'Укажите настоящий адрес почты')) return;
        if (!_check(pass.text.length >= 6, 'Пароль — не короче 6 символов')) return;
        await _run(() async {
          await Api.call('sendCode', {'email': _em, 'kind': 'reg'});
          code.clear();
          setState(() {
            m = AMode.regCode;
            info = 'Код отправлен на $_em';
          });
        });
        break;
      case AMode.regCode:
        if (!_check(code.text.trim().length >= 4, 'Введите код из письма')) return;
        await _run(() async {
          final j = await Api.call('reg', {
            'login': _em,
            'hash': sha256Hex('$_em:${pass.text}'),
            'name': name.text.trim(),
            'phone': '+${country.code} ${_nat(phone.text, country)}', // как на сайте: «+375 291234567»
            'code': code.text.trim(),
          });
          await _finish(j);
        });
        break;
      case AMode.reset:
        if (!_check(_emailRe.hasMatch(_em), 'Укажите почту аккаунта')) return;
        await _run(() async {
          await Api.call('sendCode', {'email': _em, 'kind': 'reset'});
          code.clear();
          pass.clear();
          setState(() {
            m = AMode.resetCode;
            info = 'Если такой аккаунт есть, код отправлен на $_em';
          });
        });
        break;
      case AMode.resetCode:
        if (!_check(code.text.trim().length >= 4, 'Введите код из письма')) return;
        if (!_check(pass.text.length >= 6, 'Пароль — не короче 6 символов')) return;
        await _run(() async {
          await Api.call('reset', {
            'email': _em,
            'code': code.text.trim(),
            'hash': sha256Hex('$_em:${pass.text}'),
          });
          pass.clear();
          setState(() {
            m = AMode.login;
            info = 'Пароль изменён. Теперь войдите с новым паролем';
          });
        });
        break;
    }
  }

  Future<void> _finish(Map<String, dynamic> j) async {
    await S.i.setUser(j);
    S.i.loadAds();
    if (mounted) {
      toast(context, 'Добро пожаловать, ${S.i.name}!');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final titles = {
      AMode.login: 'Вход',
      AMode.reg: 'Регистрация',
      AMode.regCode: 'Подтверждение почты',
      AMode.reset: 'Сброс пароля',
      AMode.resetCode: 'Новый пароль',
    };
    final btn = {
      AMode.login: 'Войти',
      AMode.reg: 'Получить код',
      AMode.regCode: 'Создать аккаунт',
      AMode.reset: 'Получить код',
      AMode.resetCode: 'Сохранить пароль',
    };
    final isCode = m == AMode.regCode || m == AMode.resetCode;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          const Align(alignment: Alignment.centerLeft, child: Logo(size: 48)),
          const SizedBox(height: 16),
          Text(titles[m]!, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.tx)),
          const SizedBox(height: 6),
          Text(
              m == AMode.login
                  ? 'Войдите, чтобы откликаться и размещать объявления'
                  : m == AMode.reg
                      ? 'Создайте аккаунт — это займёт минуту'
                      : m == AMode.reset
                          ? 'Пришлём код на вашу почту'
                          : 'Введите код из письма',
              style: TextStyle(color: p.mu, fontSize: 15)),
          const SizedBox(height: 20),
          if (m == AMode.reg) ...[
            _field(name, 'Имя', icon: Icons.person_outline, cap: TextCapitalization.words),
            _phoneRow(p),
          ],
          if (!isCode)
            _field(email, m == AMode.login ? 'Почта или телефон' : 'Почта', icon: Icons.mail_outline, type: m == AMode.login ? TextInputType.emailAddress : TextInputType.emailAddress),
          if (isCode) _field(code, 'Код из письма', icon: Icons.pin_outlined, type: TextInputType.number),
          if (m == AMode.login || m == AMode.reg || m == AMode.resetCode)
            _field(pass, m == AMode.resetCode ? 'Новый пароль' : 'Пароль', icon: Icons.lock_outline, secret: true),
          if (info != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(info!, style: TextStyle(color: p.ok, fontWeight: FontWeight.w600))),
          if (err != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(err!, style: TextStyle(color: p.dng, fontWeight: FontWeight.w600))),
          GradBtn(btn[m]!, busy: busy, onTap: _submit),
          const SizedBox(height: 10),
          if (m == AMode.login) ...[
            Center(child: TextButton(onPressed: () => _mode(AMode.reset), child: Text('Забыли пароль?', style: TextStyle(color: p.mu)))),
            Center(child: TextButton(onPressed: () => _mode(AMode.reg), child: Text('Нет аккаунта? Зарегистрироваться', style: TextStyle(color: p.ac, fontWeight: FontWeight.w700)))),
          ] else
            Center(child: TextButton(onPressed: () => _mode(AMode.login), child: Text('Назад ко входу', style: TextStyle(color: p.ac, fontWeight: FontWeight.w700)))),
        ]),
      ),
    );
  }

  void _setCountry(Country c) {
    final nat = _nat(phone.text, country);
    setState(() {
      country = c;
      phone.text = _mask(_nat(nat, c), c.groups);
    });
  }

  Future<void> _pickCountry() async {
    final p = pal(context);
    FocusScope.of(context).unfocus();
    final c = await showModalBottomSheet<Country>(
      context: context,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Text('Страна номера', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.tx)),
          const SizedBox(height: 6),
          for (final k in kCountries)
            ListTile(
              leading: Text(k.flag, style: const TextStyle(fontSize: 28)),
              title: Text(k.name,
                  style: TextStyle(fontSize: 16, fontWeight: k.name == country.name ? FontWeight.w800 : FontWeight.w600, color: k.name == country.name ? p.ac : p.tx)),
              trailing: Text('+${k.code}', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: k.name == country.name ? p.ac : p.mu)),
              onTap: () => Navigator.pop(ctx, k),
            ),
          const SizedBox(height: 6),
        ]),
      ),
    );
    if (c != null) _setCountry(c);
  }

  Widget _phoneRow(Pal p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: _pickCountry,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.bd)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(country.flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Text('+${country.code}', style: TextStyle(color: p.tx, fontWeight: FontWeight.w700, fontSize: 15.5)),
              Icon(Icons.keyboard_arrow_down_rounded, color: p.mu),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            contextMenuBuilder: appContextMenu,
            controller: phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [_PhoneMask(country)],
            autocorrect: false,
            style: TextStyle(color: p.tx),
            decoration: deco(context, null, hint: country.example).copyWith(constraints: const BoxConstraints(minHeight: 56)),
          ),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label,
      {IconData? icon, bool secret = false, TextInputType? type, String? hint, TextCapitalization cap = TextCapitalization.none}) {
    final p = pal(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(contextMenuBuilder: appContextMenu, 
        controller: c,
        obscureText: secret && !show,
        keyboardType: type,
        textCapitalization: cap,
        autocorrect: false,
        enableSuggestions: !secret,
        style: TextStyle(color: p.tx),
        decoration: deco(
          context,
          label,
          hint: hint,
          prefix: icon == null ? null : Icon(icon, color: p.mu),
          suffix: secret
              ? IconButton(
                  icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: p.mu),
                  onPressed: () => setState(() => show = !show))
              : null,
        ),
      ),
    );
  }
}

// Заглушка для экранов, которые доступны только после входа
class NeedAuth extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const NeedAuth({super.key, required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: p.bg2, shape: BoxShape.circle, border: Border.all(color: p.bd)),
            child: Icon(icon, size: 38, color: p.ac),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.tx)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 15)),
          const SizedBox(height: 20),
          SizedBox(
            width: 260,
            child: GradBtn('Войти или создать аккаунт',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage()))),
          ),
        ]),
      ),
    );
  }
}
