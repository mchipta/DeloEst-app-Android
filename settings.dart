import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'admin.dart';
import 'api.dart';
import 'info.dart';
import 'legal.dart';
import 'models.dart';
import 'near.dart';
import 'map_page.dart';
import 'messages.dart';
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
  final int? maxLen;
  final bool digitsOnly;
  const FieldSpec(this.label, {this.initial = '', this.secret = false, this.multi = false, this.type, this.maxLen, this.digitsOnly = false});
}

Future<List<String>?> askFields(BuildContext context, String title, List<FieldSpec> fields,
    {String ok = 'Сохранить', String? hint, Future<void> Function(List<String>)? onSubmit}) {
  return showDialog<List<String>>(
    context: context,
    builder: (c) => _FieldsDialog(title: title, fields: fields, ok: ok, hint: hint, onSubmit: onSubmit),
  );
}

class _FieldsDialog extends StatefulWidget {
  final String title, ok;
  final String? hint;
  final List<FieldSpec> fields;
  final Future<void> Function(List<String>)? onSubmit;
  const _FieldsDialog({required this.title, required this.fields, required this.ok, this.hint, this.onSubmit});
  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  late final List<TextEditingController> cs = [for (final f in widget.fields) TextEditingController(text: f.initial)];
  bool _busy = false;
  String? _err;

  Future<void> _submit() async {
    final vals = [for (final c in cs) c.text.trim()];
    if (widget.onSubmit == null) {
      Navigator.pop(context, vals);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await widget.onSubmit!(vals);
      if (mounted) Navigator.pop(context, vals);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = S.i.fail(e);
        });
      }
    }
  }

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
              child: TextField(contextMenuBuilder: appContextMenu, 
                controller: cs[i],
                obscureText: widget.fields[i].secret,
                keyboardType: widget.fields[i].type,
                enabled: !_busy,
                maxLength: widget.fields[i].maxLen,
                inputFormatters: [if (widget.fields[i].digitsOnly) FilteringTextInputFormatter.digitsOnly],
                minLines: widget.fields[i].multi ? 3 : 1,
                maxLines: widget.fields[i].multi ? 5 : 1,
                autocorrect: !widget.fields[i].secret,
                style: TextStyle(color: p.tx),
                decoration: deco(context, widget.fields[i].label).copyWith(counterText: ''),
              ),
            ),
          if (_err != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(_err!, style: TextStyle(color: p.dng, fontSize: 13))),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text('Отмена', style: TextStyle(color: p.mu))),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.ac))
              : Text(widget.ok, style: TextStyle(color: p.ac, fontWeight: FontWeight.w800)),
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
  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  Future<void> _run(Future<void> Function() f) async {
    setState(() => busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e), err: true);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _avatar() async {
    final has = (S.i.user?['avatar'] ?? '').toString().isNotEmpty;
    final act = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: pal(context).card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
      if (!phoneComplete(normPhone(r[0]))) throw ApiError('Введите номер телефона полностью');
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
      onTap: busy ? null : () { haptic(); f(); },
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

  Widget _label(Pal p, String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: p.tx)),
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
            onTap: busy ? null : () { haptic(); _avatar(); },
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
            _label(p, 'Данные профиля'),
            _tile(p, Icons.person_outline, 'Имя', S.i.name, _name),
            _tile(p, Icons.mail_outline, 'Почта', S.i.login.contains('@') ? S.i.login : '—', _email),
            _tile(p, Icons.call_outlined, 'Телефон', S.i.phone.isEmpty ? '—' : fmtPhone(S.i.phone), _phone),
          ],
          if (!widget.profileOnly) ...[
          _label(p, 'Поиск'),
          _tile(p, Icons.place_outlined, 'Регион для поиска', S.i.regionCity.isEmpty ? 'Все города' : S.i.regionCity,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegionPage()))),
          _label(p, 'Внешний вид и цвет акцента'),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: cardDeco(p, r: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(11)),
                  child: Icon(Icons.palette_outlined, color: p.ac, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Тема и акцент', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: p.tx)),
                    Text('Тёмная по умолчанию, 5 фирменных акцентов', style: TextStyle(color: p.mu, fontSize: 12.5)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                for (final t in [
                  [ThemeMode.dark, 'Тёмная'],
                  [ThemeMode.light, 'Светлая'],
                  [ThemeMode.system, 'Авто'],
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => S.i.setTheme(t[0] as ThemeMode),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: tm == t[0] ? LinearGradient(colors: [p.ac, p.ac2]) : null,
                            color: tm == t[0] ? null : p.bg2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tm == t[0] ? Colors.transparent : p.bd),
                          ),
                          child: Text(t[1] as String,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: tm == t[0] ? Colors.white : p.tx)),
                        ),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                for (var i = 0; i < Pal.accents.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == Pal.accents.length - 1 ? 0 : 8),
                      child: GestureDetector(
                        onTap: () => S.i.setAccent(i),
                        child: Column(children: [
                          Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(colors: [Pal.accents[i][1] as Color, Pal.accents[i][2] as Color], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              border: Border.all(color: S.i.accentIdx == i ? p.tx : Colors.transparent, width: 2),
                            ),
                            child: S.i.accentIdx == i ? const Icon(Icons.check_rounded, size: 20, color: Colors.white) : null,
                          ),
                          const SizedBox(height: 5),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(Pal.accents[i][0] as String,
                                maxLines: 1,
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: S.i.accentIdx == i ? p.tx : p.mu)),
                          ),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
          _label(p, 'Нижняя панель'),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: cardDeco(p, r: 16),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.blur_on_rounded, color: p.ac),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Прозрачная панель', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: p.tx)),
                const SizedBox(height: 3),
                Text('Нижнее меню становится стеклянным: экран просвечивает сквозь него с мягким размытием.', style: TextStyle(color: p.mu, fontSize: 12.5, height: 1.3)),
              ])),
              Switch(
                value: S.i.navTransparent,
                activeColor: p.ac,
                onChanged: (v) { S.i.setNavTransparent(v); },
              ),
            ]),
          ),
          _label(p, 'Приватность номера'),
          _privacyCard(p),
          _label(p, 'Уведомления и «Не беспокоить»'),
          _notifCard(p),
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
          if (S.i.logged) ...[
            _label(p, 'Самозанятость и безопасность'),
            _innCard(p),
            const _DevicesCard(),
            _securityActionsCard(p),
          ],
          if (S.i.blockedUsers.isNotEmpty) ...[
            _label(p, 'Чёрный список'),
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: cardDeco(p, r: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Заблокированные пользователи не могут писать вам и откликаться на ваши объявления.',
                    style: TextStyle(color: p.mu, fontSize: 12.5)),
                const SizedBox(height: 8),
                for (final entry in S.i.blockedUsers.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(Icons.block_rounded, size: 17, color: p.dng),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.value.isEmpty ? 'Пользователь' : entry.value, style: TextStyle(color: p.tx, fontWeight: FontWeight.w700, fontSize: 14))),
                      TextButton(
                        onPressed: () => S.i.setBlocked(entry.key, entry.value, false),
                        child: Text('Разблокировать', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800)),
                      ),
                    ]),
                  ),
              ]),
            ),
          ],
          _label(p, 'Часовой пояс'),
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: cardDeco(p, r: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Определять автоматически', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                      S.i.timeZone.isEmpty ? 'Сейчас: ${deviceZoneLabel()}' : 'По нему показывается время сообщений и объявлений.',
                      style: TextStyle(color: p.mu, fontSize: 13, height: 1.35),
                    ),
                  ]),
                ),
                Switch(
                  value: S.i.timeZone.isEmpty,
                  activeColor: p.ac,
                  onChanged: (on) => S.i.setTimeZone(on ? '' : deviceZoneId()),
                ),
              ]),
              if (S.i.timeZone.isNotEmpty) ...[
                const SizedBox(height: 10),
                PickerField(
                  label: 'Часовой пояс',
                  sheetTitle: 'Часовой пояс',
                  value: kSiteTimeZones.any((z) => z[0] == S.i.timeZone) ? S.i.timeZone : '',
                  items: [for (final z in kSiteTimeZones.skip(1)) PickItem(z[0], z[1])],
                  onChanged: (v) => S.i.setTimeZone(v),
                ),
              ],
            ]),
          ),
          ],
        ]);
      },
    );
  }

  Widget _savedSearchesCard(Pal p) {
    final list = S.i.ss;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(p, r: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bookmark_outline_rounded, color: p.ac, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Сохранённые поиски (${list.length})', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: p.tx))),
        ]),
        const SizedBox(height: 6),
        if (list.isEmpty)
          Text('Сохраняйте частые запросы в поиске — мы пришлём уведомление о новых объявлениях.', style: TextStyle(color: p.mu, fontSize: 12.5))
        else
          for (final s in list)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      S.i.pendingSearch = s;
                      Navigator.pop(context);
                      S.i.goTab(1);
                    },
                    child: Text(ssLabel(s), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.tx, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 18, color: p.mu),
                  onPressed: () => S.i.delSS(s),
                ),
              ]),
            ),
      ]),
    );
  }

  Widget _privacyCard(Pal p) {
    final cur = S.i.phonePrivacy;
    final opts = const [
      ['all', 'Всем вошедшим', 'Номер виден авторизованным пользователям'],
      ['reply', 'По откликам', 'Номер открывается после отклика на объявление'],
      ['chat', 'Только чат', 'Связь только через сообщения внутри сервиса'],
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(p, r: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < opts.length; i++) ...[
          if (i > 0) Divider(height: 14, color: p.bd),
          Tap(
            onTap: () => S.i.setPhonePrivacy(opts[i][0]),
            scale: .99,
            child: Row(children: [
              Icon(
                cur == opts[i][0] ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: cur == opts[i][0] ? p.ac : p.mu,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(opts[i][1], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: p.tx)),
                  Text(opts[i][2], style: TextStyle(color: p.mu, fontSize: 12.5)),
                ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _notifCard(Pal p) {
    final nt = S.i.notifTypes;
    Widget row(String k, String title, String sub) => Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: p.tx)),
              Text(sub, style: TextStyle(color: p.mu, fontSize: 12)),
            ]),
          ),
          Switch(
            value: nt[k] != false,
            activeColor: p.ac,
            onChanged: (v) => S.i.setNotifType(k, v),
          ),
        ]);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(p, r: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Push-уведомления', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: p.tx)),
              Text('Главный переключатель уведомлений на телефоне', style: TextStyle(color: p.mu, fontSize: 12.5)),
            ]),
          ),
          Switch(
            value: S.i.messageNotificationsEnabled,
            activeColor: p.ac,
            onChanged: (v) => S.i.setMessageNotificationsEnabled(v),
          ),
        ]),
        Divider(height: 16, color: p.bd),
        row('msg', 'Новые сообщения', 'Личные сообщения и предложения задач'),
        row('reply', 'Отклики на объявления', 'Новые отклики и смена статуса'),
        row('ss', 'Сохранённые поиски', 'Новые объявления по вашим фильтрам'),
        row('rev', 'Новые отзывы', 'Оценки и ответы на отзывы'),
        Divider(height: 16, color: p.bd),
        Row(children: [
          Icon(Icons.bedtime_outlined, color: S.i.dndOn ? p.ac : p.mu, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Не беспокоить (${S.i.dndFrom} – ${S.i.dndTo})', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: p.tx)),
              Text('Без звуковых уведомлений в ночные часы', style: TextStyle(color: p.mu, fontSize: 12)),
            ]),
          ),
          Switch(
            value: S.i.dndOn,
            activeColor: p.ac,
            onChanged: (v) => S.i.setDnd(on: v),
          ),
        ]),
      ]),
    );
  }

  Widget _innCard(Pal p) {
    final inn = (S.i.user?['inn'] ?? '').toString();
    final ok = S.i.user?['innOk'] == true && inn.length == 12;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(p, r: 16),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: (ok ? p.ok : p.ac).withOpacity(.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.verified_user_outlined, color: ok ? p.ok : p.ac, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ok ? 'Самозанятый · ИНН $inn' : 'Статус самозанятого (ИНН)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: p.tx)),
            Text(ok ? 'Значок «Самозанятый» отображается в вашем профиле' : 'Подтвердите 12-значный ИНН для значка доверия в профиле', style: TextStyle(color: p.mu, fontSize: 12.5)),
          ]),
        ),
        TextButton(
          onPressed: () async {
            String msg = 'Статус обновлён';
            final r = await askFields(context, 'Проверка ИНН самозанятого', [
              FieldSpec('ИНН (12 цифр)', initial: inn, type: TextInputType.number, maxLen: 12, digitsOnly: true),
            ], ok: 'Проверить', hint: 'Проверим контрольную сумму ФНС и статус плательщика НПД.', onSubmit: (v) async {
              if (v[0].length != 12) throw Exception('ИНН должен содержать ровно 12 цифр');
              final res = await Api.call('verifyInn', {'inn': v[0]});
              await S.i.patchUser({'inn': res['inn'] ?? '', 'innOk': res['innOk'] == true});
              msg = res['msg']?.toString() ?? msg;
            });
            if (r == null || !mounted) return;
            setState(() {});
            toast(context, msg);
          },
          child: Text(ok ? 'Изменить' : 'Подтвердить', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  // Чат поддержки живёт в «Сообщениях», как в Авито: отсюда просто открываем его
  Future<void> _openSupportSheet() async {
    await _run(() async {
      final j = await Api.call('dialogs');
      final l = j['list'] is List ? j['list'] as List : const [];
      final d = l.firstWhere((e) => e is Map && e['sup'] == 1, orElse: () => null);
      if (d == null || !mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(pid: d['pid'].toString(), name: 'Поддержка ДелоЕсть', adId: 'support')));
    });
  }

  Widget _securityActionsCard(Pal p) {
    final delAt = (S.i.user?['delAt'] as num?)?.toInt() ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _tile(p, Icons.support_agent_rounded, 'Чат с поддержкой', 'Ответим прямо в приложении', _openSupportSheet),
        _tile(p, Icons.download_outlined, 'Скачать мои данные', 'Файл JSON: профиль, объявления, отзывы', () async {
          await _run(() async {
            final res = await Api.call('exportData');
            final jsonStr = const JsonEncoder.withIndent('  ').convert(res['data'] ?? res);
            try {
              // отдаём файлом: через «Поделиться» его можно сохранить в «Файлы» или отправить себе
              await Share.shareXFiles([XFile.fromData(Uint8List.fromList(utf8.encode(jsonStr)), mimeType: 'application/json', name: 'deloest-data.json')],
                  fileNameOverrides: ['deloest-data.json'], subject: 'Мои данные ДелоЕсть');
            } catch (_) {
              await Clipboard.setData(ClipboardData(text: jsonStr));
              if (mounted) toast(context, 'Не удалось создать файл, данные скопированы в буфер обмена');
            }
          });
        }),
        if (delAt > 0)
          _tile(p, Icons.restore_from_trash_rounded, 'Отменить удаление аккаунта', 'Удаление запланировано на 7 дней', () async {
            await _run(() async {
              await Api.call('cancelDelete');
              await S.i.patchUser({'delAt': 0});
              if (mounted) toast(context, 'Удаление аккаунта отменено');
            });
          }, color: p.ok)
        else
          _tile(p, Icons.delete_forever_outlined, 'Удалить аккаунт', 'Отсрочка 7 дней, можно восстановить', () async {
            final r = await askFields(context, 'Удаление аккаунта', [
              const FieldSpec('Причина удаления (необязательно)'),
            ], ok: 'Запланировать удаление', hint: 'Аккаунт будет удалён через 7 дней. В течение этого срока удаление можно отменить.');
            if (r == null) return;
            await _run(() async {
              final res = await Api.call('deleteAccount', {'reason': r[0]});
              await S.i.patchUser({'delAt': res['delAt'] ?? DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch});
              if (mounted) toast(context, 'Удаление аккаунта запланировано через 7 дней');
            });
          }, color: p.dng),
    ]);
  }
}

class _DevicesCard extends StatefulWidget {
  const _DevicesCard();
  @override
  State<_DevicesCard> createState() => _DevicesCardState();
}

class _DevicesCardState extends State<_DevicesCard> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await Api.call('devices');
      final raw = j['list'];
      if (mounted && raw is List) {
        setState(() {
          _list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _kill({String? id, bool allOther = false}) async {
    setState(() => _busy = true);
    try {
      final j = await Api.call('killDevice', {
        if (id != null) 'id': id,
        if (allOther) 'allOther': true,
      });
      final raw = j['list'];
      if (mounted && raw is List) {
        setState(() {
          _list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
      if (mounted) {
        toast(context, allOther ? 'Остальные сеансы завершены' : 'Сеанс на устройстве завершён');
      }
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e), err: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final hasOthers = _list.any((d) => d['cur'] != true);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(p, r: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Активные устройства, на которых выполнен вход в ваш аккаунт.',
          style: TextStyle(color: p.mu, fontSize: 12.5, height: 1.35),
        ),
        const SizedBox(height: 10),
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: p.ac))),
          )
        else if (_list.isEmpty)
          Text('Текущее устройство активно', style: TextStyle(color: p.tx, fontWeight: FontWeight.w700, fontSize: 13.5))
        else
          for (var i = 0; i < _list.length; i++) ...[
            if (i > 0) Divider(height: 14, color: p.bd),
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(11)),
                child: Icon(
                  (_list[i]['dev'] ?? '').toString().toLowerCase().contains('android') ||
                          (_list[i]['dev'] ?? '').toString().toLowerCase().contains('iphone')
                      ? Icons.smartphone_rounded
                      : Icons.laptop_mac_rounded,
                  color: _list[i]['cur'] == true ? p.ok : p.ac,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        (_list[i]['dev'] ?? 'Устройство').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.tx, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    if (_list[i]['cur'] == true) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.ok.withOpacity(.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text('Это устройство', style: TextStyle(color: p.ok, fontWeight: FontWeight.w800, fontSize: 10.5)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Builder(builder: (_) {
                    final cur = _list[i]['cur'] == true;
                    var ipT = (_list[i]['ip'] ?? '').toString();
                    var geoT = (_list[i]['geo'] ?? '').toString();
                    if (cur && ipT.isEmpty) ipT = Api.ip;
                    if (cur && geoT.isEmpty) geoT = Api.geo;
                    final line = [if (ipT.isNotEmpty) ipT, if (geoT.isNotEmpty) geoT].join(' · ');
                    return Text(line.isEmpty ? 'IP и страна не определены' : line, style: TextStyle(color: p.mu, fontSize: 12));
                  }),
                  Text(
                    _list[i]['cur'] == true
                        ? 'В сети сейчас'
                        : 'Активность: ${ago((_list[i]['ts'] as num?)?.toInt() ?? 0)}',
                    style: TextStyle(color: p.mu, fontSize: 12),
                  ),
                ]),
              ),
              if (_list[i]['cur'] != true)
                TextButton(
                  onPressed: _busy ? null : () => _kill(id: (_list[i]['id'] ?? '').toString()),
                  child: Text('Завершить', style: TextStyle(color: p.dng, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
            ]),
          ],
        if (hasOthers) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy ? null : () => _kill(allOther: true),
              icon: Icon(Icons.logout_rounded, size: 17, color: p.dng),
              label: Text(
                'Завершить все остальные сеансы',
                style: TextStyle(color: p.dng, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ],
      ]),
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
            decoration: cardDeco(p, r: 16),
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
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: const [SettingsBody(), BottomLinks(business: true, title: 'Прочее')]),
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
    if (context.mounted) toast(context, S.i.fail(e), err: true);
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
          _MenuRow(Icons.description_outlined, 'Документы', 'Оферта, политика, согласие на данные',
              () => openLegal(context, 'offer')),
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
            decoration: cardDeco(p, r: 16),
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) _row(p, rows[i], i == rows.length - 1),
            ]),
          ),
        ]);
      },
    );
  }
}

/// Регион для поиска: город и радиус, с которыми по умолчанию открывается лента
class RegionPage extends StatefulWidget {
  const RegionPage({super.key});
  @override
  State<RegionPage> createState() => _RegionPageState();
}

class _RegionPageState extends State<RegionPage> {
  final _c = TextEditingController(text: S.i.regionCity);
  late String _rad = S.i.regionRad;
  late bool _first = S.i.regionFirst;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _city(String v) {
    final had = _c.text.trim().isNotEmpty;
    setState(() {
      if (v.trim().isEmpty) {
        _rad = '';
      }
    });
  }

  Future<void> _locate() async {
    haptic();
    setState(() => _busy = true);
    final r = await Near.i.locate();
    String? city;
    final pos = Near.i.pos;
    if (r == NearResult.ok && pos != null) city = await Geo.reverseCity(pos.latitude, pos.longitude);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (city != null) {
        _c.text = city;
      }
    });
    if (r != NearResult.ok) {
      toast(context, nearMsg(r), err: true);
    } else if (city == null) {
      toast(context, 'Не удалось определить город', err: true);
    }
  }

  Future<void> _save() async {
    await S.i.setRegion(_c.text, '100', true);
    if (!mounted) return;
    toast(context, _c.text.trim().isEmpty ? 'Ищем по всем городам' : 'Регион для поиска: ${_c.text.trim()}');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final hasCity = _c.text.trim().isNotEmpty;

    Widget chip(String t, String v) {
      final on = _rad == v;
      return Tap(
        onTap: () {
          haptic();
          setState(() => _rad = v);
        },
        scale: .96,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: on ? p.ac.withOpacity(.14) : p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? p.ac : p.bd, width: on ? 1.6 : 1),
          ),
          child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: on ? p.ac : p.tx)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.tx,
        elevation: 0,
        title: const Text('Регион для поиска', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(children: [
        ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 8, 16, 110 + MediaQuery.of(context).viewInsets.bottom),
          children: [
            Text('Лента будет открываться с этим городом. Изменить его можно и в фильтрах.', style: TextStyle(color: p.mu, fontSize: 13.5, height: 1.35)),
            const SizedBox(height: 16),
            CityField(
              controller: _c,
              decoration: deco(context, 'Город или регион', prefix: Icon(Icons.place_outlined, color: p.mu)),
              onChanged: _city,
            ),
            const SizedBox(height: 10),
            Tap(
              onTap: _busy ? null : _locate,
              scale: .98,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd)),
                child: Row(children: [
                  Icon(Icons.my_location_rounded, color: p.ac, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Определить автоматически', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.tx))),
                  if (_busy) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.ac)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            if (hasCity)
              TextButton(
                onPressed: () {
                  haptic();
                  setState(() {
                    _c.clear();
                    _rad = '';
                  });
                },
                child: Text('Искать по всем городам', style: TextStyle(color: p.ac, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 22, 16, 12 + MediaQuery.of(context).viewPadding.bottom),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.bg.withOpacity(0), p.bg, p.bg])),
            child: GradBtn('Сохранить', radius: 18, onTap: _save),
          ),
        ),
      ]),
    );
  }
}

/// Шторка «Где вы ищете?» после первого входа (как на сайте): город, определение по геолокации, «Пропустить»
Future<void> showRegionSheet(BuildContext context) {
  final p = pal(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  final surface = Color.alphaBlend(p.ac.withOpacity(dark ? .12 : .05), p.card);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.6),
    builder: (c) => Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: p.ac.withOpacity(.4), width: 1.2),
        boxShadow: [BoxShadow(color: p.ac.withOpacity(.22), blurRadius: 32, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: const SingleChildScrollView(child: _RegionSheetBody()),
        ),
      ),
    ),
  );
}

class _RegionSheetBody extends StatefulWidget {
  const _RegionSheetBody();
  @override
  State<_RegionSheetBody> createState() => _RegionSheetBodyState();
}

class _RegionSheetBodyState extends State<_RegionSheetBody> {
  final _c = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    haptic();
    setState(() => _busy = true);
    final r = await Near.i.locate();
    String? city;
    final pos = Near.i.pos;
    if (r == NearResult.ok && pos != null) city = await Geo.reverseCity(pos.latitude, pos.longitude);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (city != null) _c.text = city;
    });
    if (r != NearResult.ok) {
      toast(context, nearMsg(r), err: true);
    } else if (city == null) {
      toast(context, 'Не удалось определить город', err: true);
    }
  }

  Future<void> _go(bool skip) async {
    final nav = Navigator.of(context);
    await S.i.setRegion(skip ? '' : _c.text, '100', true);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final has = _c.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: p.mu.withOpacity(.45), borderRadius: BorderRadius.circular(99)))),
        const SizedBox(height: 16),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.ac, p.ac2]),
            borderRadius: BorderRadius.circular(17),
            boxShadow: [BoxShadow(color: p.ac.withOpacity(.4), blurRadius: 22, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.place_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 14),
        Text('Где вы ищете?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: p.tx, letterSpacing: -.4)),
        const SizedBox(height: 6),
        Text('Покажем подработки и услуги рядом с вами. Город можно сменить в любой момент в настройках.',
            style: TextStyle(color: p.mu, fontSize: 14, height: 1.4)),
        const SizedBox(height: 16),
        CityField(
          controller: _c,
          decoration: deco(context, 'Город или регион', prefix: Icon(Icons.place_outlined, color: p.mu)),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Tap(
          onTap: _busy ? null : _locate,
          scale: .98,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: p.bg.withOpacity(.4), borderRadius: BorderRadius.circular(18), border: Border.all(color: p.bd)),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: p.ac.withOpacity(.14), borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.my_location_rounded, color: p.ac, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Определить автоматически', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.tx)),
                  const SizedBox(height: 2),
                  Text('Нужен доступ к геолокации', style: TextStyle(fontSize: 12.5, color: p.mu)),
                ]),
              ),
              if (_busy) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.ac)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        GradBtn('Продолжить', radius: 16, onTap: has ? () => _go(false) : null),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => _go(true),
            child: Text('Пропустить, искать везде', style: TextStyle(color: p.mu, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}
