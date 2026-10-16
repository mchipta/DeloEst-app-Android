import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'admin.dart';
import 'api.dart';
import 'info.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

class FieldSpec {
  final String label;
  final String initial;
  final bool secret;
  final bool multi;
  final TextInputType? type;
  const FieldSpec(this.label, {this.initial = '', this.secret = false, this.multi = false, this.type});
}

Future<List<String>?> askFields(BuildContext context, String title, List<FieldSpec> fields,
    {String ok = 'Сохранить', String? hint}) {
  return showDialog<List<String>>(
    context: context,
    builder: (c) => _FieldsDialog(title: title, fields: fields, ok: ok, hint: hint),
  );
}

class _FieldsDialog extends StatefulWidget {
  final String title, ok;
  final String? hint;
  final List<FieldSpec> fields;
  const _FieldsDialog({required this.title, required this.fields, required this.ok, this.hint});
  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  late final List<TextEditingController> cs = [for (final f in widget.fields) TextEditingController(text: f.initial)];

  @override
  void dispose() {
    for (final c in cs) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return AlertDialog(
      backgroundColor: p.card,
      title: Text(widget.title, style: TextStyle(color: p.tx, fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (widget.hint != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(widget.hint!, style: TextStyle(color: p.mu))),
          for (var i = 0; i < widget.fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: cs[i],
                obscureText: widget.fields[i].secret,
                keyboardType: widget.fields[i].type,
                minLines: widget.fields[i].multi ? 3 : 1,
                maxLines: widget.fields[i].multi ? 5 : 1,
                autocorrect: !widget.fields[i].secret,
                style: TextStyle(color: p.tx),
                decoration: deco(context, widget.fields[i].label),
              ),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Отмена', style: TextStyle(color: p.mu))),
        TextButton(
          onPressed: () => Navigator.pop(context, [for (final c in cs) c.text.trim()]),
          child: Text(widget.ok, style: TextStyle(color: p.ac, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class SettingsBody extends StatefulWidget {
  final bool profileOnly;
  const SettingsBody({super.key, this.profileOnly = false});
  @override
  State<SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<SettingsBody> {
  bool busy = false;
  String _iconStyle = 'orange';
  static const _iconChannel = MethodChannel('ru.deloest.delo_est/launcher_icon');
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) { if (mounted) setState(() => _iconStyle = prefs.getString('launcher_icon_style') ?? 'orange'); });
  }
  Future<void> _setIcon(String style) async {
    try {
      await _iconChannel.invokeMethod('setLauncherIcon', style);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('launcher_icon_style', style);
      if (mounted) setState(() => _iconStyle = style);
      if (mounted) toast(context, 'Иконка приложения изменена');
    } on PlatformException catch (e) {
      if (mounted) toast(context, 'Не удалось изменить иконку: ${e.message ?? 'ошибка Android'}');
    } catch (_) {
      if (mounted) toast(context, 'Не удалось изменить иконку. Проверьте сборку Android.');
    }
  }
  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  Future<void> _run(Future<void> Function() f) async {
    setState(() => busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _avatar() async {
    final has = (S.i.user?['avatar'] ?? '').toString().isNotEmpty;
    final act = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: pal(context).card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Сделать фото'), onTap: () => Navigator.pop(c, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Выбрать из галереи'), onTap: () => Navigator.pop(c, 'gallery')),
          if (has) ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Удалить фото'), onTap: () => Navigator.pop(c, 'remove')),
        ]),
      ),
    );
    if (act == null) return;
    await _run(() async {
      var data = '';
      if (act != 'remove') {
        final x = await ImagePicker().pickImage(
            source: act == 'camera' ? ImageSource.camera : ImageSource.gallery,
            maxWidth: 200,
            maxHeight: 200,
            imageQuality: 60);
        if (x == null) return;
        final bytes = await x.readAsBytes();
        final low = x.path.toLowerCase();
        final mime = low.endsWith('.png') ? 'png' : low.endsWith('.webp') ? 'webp' : 'jpeg';
        data = 'data:image/$mime;base64,${base64Encode(bytes)}';
        if (data.length > 40000) throw ApiError('Фото слишком большое. Выберите другое');
      }
      await Api.call('avatar', {'data': data});
      await S.i.patchUser({'avatar': data});
      if (mounted) toast(context, data.isEmpty ? 'Фото удалено' : 'Фото обновлено');
    });
  }

  Future<void> _name() async {
    final r = await askFields(context, 'Имя', [FieldSpec('Ваше имя', initial: S.i.name)]);
    if (r == null) return;
    await _run(() async {
      final j = await Api.call('chName', {'name': r[0]});
      await S.i.patchUser({'name': j['name']});
      S.i.loadAds();
      if (mounted) toast(context, 'Имя изменено');
    });
  }

  Future<void> _phone() async {
    final r = await askFields(context, 'Телефон', [FieldSpec('Номер телефона', initial: fmtPhone(S.i.phone), type: TextInputType.phone)]);
    if (r == null) return;
    await _run(() async {
      if (normPhone(r[0]).length != 11) throw ApiError('Введите номер телефона полностью');
      final j = await Api.call('chPhone', {'phone': '+${normPhone(r[0])}'});
      await S.i.patchUser({'phone': j['phone']});
      if (mounted) toast(context, 'Телефон изменён');
    });
  }

  Future<void> _email() async {
    final r = await askFields(context, 'Новая почта', [FieldSpec('Адрес почты', type: TextInputType.emailAddress)],
        ok: 'Получить код', hint: 'Сейчас вы входите с ${S.i.login}. Пришлём код на новый адрес.');
    if (r == null) return;
    final em = r[0].toLowerCase();
    if (!_emailRe.hasMatch(em)) {
      toast(context, 'Укажите настоящий адрес почты');
      return;
    }
    var sent = false;
    await _run(() async {
      await Api.call('sendCode', {'email': em, 'kind': 'chg'});
      sent = true;
    });
    if (!sent || !mounted) return;
    final c = await askFields(
        context,
        'Подтверждение',
        [FieldSpec('Код из письма', type: TextInputType.number), FieldSpec('Текущий пароль', secret: true)],
        ok: 'Изменить',
        hint: 'Код отправлен на $em');
    if (c == null) return;
    await _run(() async {
      final j = await Api.call('chEmail', {
        'email': em,
        'code': c[0],
        'old': sha256Hex('${S.i.login}:${c[1]}'),
        'hash': sha256Hex('$em:${c[1]}'),
      });
      await S.i.patchUser({'login': j['login'], 'pid': j['pid']});
      if (mounted) toast(context, 'Почта изменена. Теперь входите с $em');
    });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Выйти')),
        ],
      ),
    );
    if (ok == true) {
      await S.i.setUser(null);
      S.i.loadAds();
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _tile(Pal p, IconData icon, String title, String value, VoidCallback f, {Color? color}) {
    return GestureDetector(
      onTap: busy ? null : f,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: cardDeco(p, r: 16),
        child: Row(children: [
          Icon(icon, color: color ?? p.ac, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: color ?? p.tx)),
              if (value.isNotEmpty) Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontSize: 13.5)),
            ]),
          ),
          Icon(Icons.chevron_right, color: p.mu),
        ]),
      ),
    );
  }

  Widget _iconChoice(Pal p, String style, String title, String asset, Color accent) => InkWell(
        onTap: busy ? null : () => _setIcon(style),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _iconStyle == style ? accent.withOpacity(.10) : p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _iconStyle == style ? accent : p.bd, width: _iconStyle == style ? 1.8 : 1),
          ),
          child: Column(children: [
            Image.asset(asset, width: 58, height: 58, fit: BoxFit.contain),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_iconStyle == style) Icon(Icons.check_circle_rounded, color: accent, size: 16),
              if (_iconStyle == style) const SizedBox(width: 5),
              Text(title, style: TextStyle(color: p.tx, fontWeight: FontWeight.w800, fontSize: 13.5)),
            ]),
          ]),
        ),
      );

  Widget _label(Pal p, String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: p.mu)),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        final p = pal(context);
        final av = (S.i.user?['avatar'] ?? '').toString();
        final tm = S.i.themeMode;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (busy) LinearProgressIndicator(color: p.ac, backgroundColor: p.bd, minHeight: 3),
          if (widget.profileOnly) GestureDetector(
            onTap: busy ? null : _avatar,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDeco(p),
              child: Row(children: [
                Stack(children: [
                  Avatar(S.i.name, data: av, size: 64),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: p.card, shape: BoxShape.circle, border: Border.all(color: p.bd)),
                      child: Icon(Icons.photo_camera_outlined, size: 15, color: p.ac),
                    ),
                  ),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Нажмите, чтобы сменить фото профиля', style: TextStyle(color: p.ac, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
          if (widget.profileOnly) ...[
            _label(p, 'ДАННЫЕ ПРОФИЛЯ'),
            _tile(p, Icons.person_outline, 'Имя', S.i.name, _name),
            _tile(p, Icons.mail_outline, 'Почта', S.i.login.contains('@') ? S.i.login : '—', _email),
            _tile(p, Icons.call_outlined, 'Телефон', S.i.phone.isEmpty ? '—' : fmtPhone(S.i.phone), _phone),
          ],
          if (!widget.profileOnly) ...[
          _label(p, 'ВНЕШНИЙ ВИД'),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Тема применяется ко всему приложению и меняется только здесь.',
                style: TextStyle(color: p.mu, fontSize: 13)),
          ),
          Row(children: [
            for (final t in [
              [ThemeMode.system, 'Системная'],
              [ThemeMode.light, 'Светлая'],
              [ThemeMode.dark, 'Тёмная'],
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => S.i.setTheme(t[0] as ThemeMode),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: tm == t[0] ? LinearGradient(colors: [p.ac, p.ac2]) : null,
                        color: tm == t[0] ? null : p.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tm == t[0] ? Colors.transparent : p.bd),
                      ),
                      child: Text(t[1] as String,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tm == t[0] ? Colors.white : p.tx)),
                    ),
                  ),
                ),
              ),
          ]),
          _label(p, 'ИКОНКА ПРИЛОЖЕНИЯ'),
          Text('Выберите вариант значка на экране телефона.', style: TextStyle(color: p.mu, fontSize: 13)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _iconChoice(p, 'orange', 'Апельсин', 'assets/icon_orange.png', const Color(0xFFFF6A2A))),
            const SizedBox(width: 10),
            Expanded(child: _iconChoice(p, 'purple', 'Фиолет', 'assets/icon_purple.png', const Color(0xFF7C5CFF))),
          ]),
          const SizedBox(height: 4),
          _label(p, 'УВЕДОМЛЕНИЯ'),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: cardDeco(p, r: 16),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.notifications_none_rounded, color: p.ac),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Уведомления о сообщениях', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: p.tx)),
                const SizedBox(height: 3),
                Text('Оповещение внутри приложения, когда приходят новые сообщения.', style: TextStyle(color: p.mu, fontSize: 12.5, height: 1.3)),
              ])),
              Switch(
                value: S.i.messageNotificationsEnabled,
                activeColor: p.ac,
                onChanged: (v) { S.i.setMessageNotificationsEnabled(v); },
              ),
            ]),
          ),
          if (S.i.mutedChats.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: cardDeco(p, r: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Уведомления отключены для диалогов', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 6),
                for (final entry in S.i.mutedChats.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Expanded(child: Text(entry.value.isEmpty ? 'Пользователь' : entry.value, style: TextStyle(color: p.mu, fontSize: 13.5))),
                      TextButton(
                        onPressed: () { S.i.setChatMuted(entry.key, entry.value, false); },
                        child: Text('Включить', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800)),
                      ),
                    ]),
                  ),
              ]),
            ),
          _label(p, 'ЧАСОВОЙ ПОЯС'),
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: cardDeco(p, r: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('По нему показывается время сообщений и объявлений.', style: TextStyle(color: p.mu, fontSize: 13, height: 1.35)),
              const SizedBox(height: 10),
              PickerField(
                label: 'Часовой пояс',
                sheetTitle: 'Часовой пояс',
                value: kSiteTimeZones.any((z) => z[0] == S.i.timeZone) ? S.i.timeZone : '',
                items: [for (final z in kSiteTimeZones) PickItem(z[0], z[1])],
                onChanged: (v) => S.i.setTimeZone(v),
              ),
            ]),
          ),
          ],
        ]);
      },
    );
  }
}

class ProfileEditPage extends StatelessWidget {
  const ProfileEditPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Изменить профиль')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: cardDeco(p, r: 18),
            child: Row(children: [
              Icon(Icons.info_outline, color: p.ac),
              const SizedBox(width: 10),
              Expanded(child: Text('Измените фото, имя, почту или номер телефона.', style: TextStyle(color: p.mu, height: 1.35))),
            ]),
          ),
          const SizedBox(height: 12),
          SettingsBody(profileOnly: true),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: const [SettingsBody(), BottomLinks(business: true, title: 'ПРОЧЕЕ')]),
    );
  }
}

Future<void> confirmLogout(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Выйти из аккаунта?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Выйти')),
      ],
    ),
  );
  if (ok == true) {
    await S.i.setUser(null);
    S.i.loadAds();
  }
}

Future<void> showLeadForm(BuildContext context) async {
  final r = await askFields(
      context,
      'Для бизнеса',
      [
        FieldSpec('Имя', initial: S.i.name),
        FieldSpec('Телефон', initial: S.i.phone, type: TextInputType.phone),
        const FieldSpec('Что нужно?', multi: true),
      ],
      ok: 'Отправить',
      hint: 'Оставьте заявку, мы свяжемся с вами.');
  if (r == null || !context.mounted) return;
  if (r[1].replaceAll(RegExp(r'\D'), '').length < 8) {
    toast(context, 'Укажите телефон');
    return;
  }
  try {
    await Api.call('lead', {'name': r[0], 'phone': r[1], 'msg': r[2]});
    if (context.mounted) toast(context, 'Заявка отправлена');
  } catch (e) {
    if (context.mounted) toast(context, S.i.fail(e));
  }
}

class _MenuRow {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final Color? color;
  const _MenuRow(this.icon, this.title, this.sub, this.onTap, {this.color});
}

// Одна аккуратная группа строк: Для бизнеса / Поддержка / О сервисе / О приложении / Админ / Выход
class BottomLinks extends StatelessWidget {
  final bool support; // строка «Поддержка» (экран входа)
  final bool business; // строка «Для бизнеса» (настройки)
  final String? title;
  const BottomLinks({super.key, this.support = false, this.business = false, this.title});

  Widget _row(Pal p, _MenuRow r, bool last) {
    final col = r.color;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Tap(
        onTap: r.onTap,
        scale: .99,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.bg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.bd),
              ),
              child: Icon(r.icon, color: col ?? p.ac, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: col ?? p.tx)),
                if (r.sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(r.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontSize: 13)),
                  ),
              ]),
            ),
            Icon(Icons.chevron_right, color: p.mu),
          ]),
        ),
      ),
      if (!last) Divider(height: 1, thickness: 1, indent: 66, color: p.bd),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        final p = pal(context);
        final rows = <_MenuRow>[
          if (business)
            _MenuRow(Icons.business_center_outlined, 'Для бизнеса', 'Оставить заявку', () => showLeadForm(context)),
          if (support)
            _MenuRow(Icons.support_agent, 'Поддержка', 'Напишите или позвоните нам',
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoPage(only: 3, title: 'Поддержка')))),
          _MenuRow(Icons.info_outline, 'О сервисе', 'О нас, вопросы, контакты',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoPage()))),
          _MenuRow(Icons.phone_android, 'О приложении', 'Версия $kAppVersion, разработчик @mchipta',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutAppPage()))),
          if (S.i.logged && S.i.user?['admin'] == true)
            _MenuRow(Icons.admin_panel_settings_outlined, 'Админ-панель', 'Модерация, жалобы, заявки',
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPage()))),
          if (S.i.logged)
            _MenuRow(Icons.logout, 'Выйти из аккаунта', '', () => confirmLogout(context), color: p.dng),
        ];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Text(title!, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: p.mu)),
            )
          else
            const SizedBox(height: 14),
          Container(
            decoration: cardDeco(p, r: 18),
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) _row(p, rows[i], i == rows.length - 1),
            ]),
          ),
        ]);
      },
    );
  }
}
