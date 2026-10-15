import 'package:flutter/material.dart';
import 'api.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

enum AMode { login, reg, regCode, reset, resetCode }

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
        if (!_check(byMail ? _emailRe.hasMatch(_em) : normPhone(id).length == 11, 'Введите почту или номер телефона')) return;
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
        final dg = phone.text.replaceAll(RegExp(r'\D'), '').length;
        if (!_check(name.text.trim().length >= 2, 'Введите имя')) return;
        if (!_check(dg >= 8 && dg <= 15, 'Укажите номер телефона')) return;
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
            'phone': normPhone(phone.text).length == 11 ? '+${normPhone(phone.text)}' : phone.text.trim(),
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
            _field(phone, 'Телефон', icon: Icons.call_outlined, type: TextInputType.phone, hint: '+7 900 000-00-00'),
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

  Widget _field(TextEditingController c, String label,
      {IconData? icon, bool secret = false, TextInputType? type, String? hint, TextCapitalization cap = TextCapitalization.none}) {
    final p = pal(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
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
