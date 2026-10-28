import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'auth.dart';
import 'map_page.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

/// Фото в форме: уже загруженное (id) или выбранное на телефоне (файл)
class _Ph {
  final String? id;
  final XFile? file;
  const _Ph.id(this.id) : file = null;
  const _Ph.file(this.file) : id = null;
}

class PostScreen extends StatefulWidget {
  final Ad? edit;
  final bool embedded;
  const PostScreen({super.key, this.edit, this.embedded = true});
  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  // шаги: 0 «Что нужно», 1 «Детали», 2 «Готово»
  int step = 0;
  int type = 0;
  final title = TextEditingController();
  final payA = TextEditingController();
  final city = TextEditingController();
  final addr = TextEditingController(); // адрес для карты
  double? lat, lng;
  final desc = TextEditingController();
  final phone = TextEditingController();
  final _scroll = ScrollController();
  String cat = kCats.first.name;
  String unit = 'h';
  String payRaw = '';
  List<_Ph> photos = [];
  bool showPhone = true;
  bool busy = false;
  String status = '';
  String? err, eTitle, eDesc, ePay, ePhone;
  bool cityAuto = false; // город подставлен автоматически
  bool _restored = false; // показали «черновик восстановлен»
  bool _quiet = false; // программная запись в поля: не сохранять и не перерисовывать
  String _pid = '';
  Timer? _saveT;

  bool get _isEdit => widget.edit != null;
  int get _count => photos.length;
  String get _draftKey => 'draft_$_pid';

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      type = e.type == kTypes[1] ? 1 : 0;
      title.text = e.title;
      final pp = payParse(e.pay);
      unit = pp.p;
      payRaw = pp.raw;
      payA.text = grp(pp.a);
      city.text = e.city;
      addr.text = e.addr;
      lat = e.lat;
      lng = e.lng;
      desc.text = e.desc;
      phone.text = fmtPhone(e.phone);
      showPhone = e.phone.isNotEmpty;
      cat = kCats.any((c) => c.name == e.category) ? e.category : kCats.last.name;
      photos = [for (final id in e.imgs) _Ph.id(id)];
    }
    for (final c in [title, payA, city, addr, desc, phone]) {
      c.addListener(_touch);
    }
    S.i.addListener(_sync);
    if (widget.embedded && !_isEdit) S.i.postBack = _back;
    _sync();
  }

  @override
  void dispose() {
    S.i.removeListener(_sync);
    if (widget.embedded && !_isEdit) S.i.postBack = null;
    if (_saveT?.isActive ?? false) _saveNow();
    _saveT?.cancel();
    for (final c in [title, payA, city, addr, desc, phone]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  // ---------- черновик и автозаполнение ----------

  void _sync() {
    if (phone.text.isEmpty && S.i.phone.isNotEmpty) {
      _quiet = true;
      phone.text = fmtPhone(S.i.phone);
      _quiet = false;
    }
    if (_isEdit) return;
    final cur = S.i.logged ? (S.i.pid.isEmpty ? 'x' : S.i.pid) : '';
    if (cur == _pid) return;
    final prev = _pid;
    _pid = cur;
    if (prev.isNotEmpty) _resetFields(); // сменился пользователь или вышли из аккаунта
    if (cur.isNotEmpty) {
      _loadDraft();
      _autoCity();
    }
  }

  void _touch() {
    if (_quiet || !mounted) return;
    setState(() {});
    _saveSoon();
  }

  void _set(VoidCallback f) {
    setState(f);
    _saveSoon();
  }

  void _saveSoon() {
    if (_isEdit || _quiet || _pid.isEmpty) return;
    _saveT?.cancel();
    _saveT = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  void _saveNow() {
    if (_isEdit || _pid.isEmpty) return;
    final empty = title.text.trim().isEmpty && desc.text.trim().isEmpty && payA.text.trim().isEmpty;
    if (empty) {
      S.i.prefs.remove(_draftKey);
      return;
    }
    S.i.prefs.setString(
        _draftKey,
        jsonEncode({
          'type': type,
          'title': title.text,
          'cat': cat,
          'unit': unit,
          'pay': payA.text,
          'city': cityAuto ? '' : city.text,
          'addr': addr.text,
          'lat': lat,
          'lng': lng,
          'desc': desc.text,
          'phone': phone.text,
          'showPhone': showPhone,
          'step': step,
        }));
  }

  void _loadDraft() {
    final raw = S.i.prefs.getString(_draftKey);
    if (raw == null) return;
    _quiet = true;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      String s(String k) => (m[k] ?? '').toString();
      if (s('title').trim().isEmpty && s('desc').trim().isEmpty && s('pay').trim().isEmpty) return;
      type = m['type'] == 1 ? 1 : 0;
      title.text = s('title');
      desc.text = s('desc');
      payA.text = grp(s('pay'));
      if (s('city').isNotEmpty) {
        city.text = s('city');
        cityAuto = false;
      }
      addr.text = s('addr');
      lat = m['lat'] is num ? (m['lat'] as num).toDouble() : null;
      lng = m['lng'] is num ? (m['lng'] as num).toDouble() : null;
      if (kCats.any((c) => c.name == s('cat'))) cat = s('cat');
      if (kPayUnits.any((u) => u[0] == s('unit'))) unit = s('unit');
      showPhone = m['showPhone'] != false;
      if (s('phone').isNotEmpty) phone.text = s('phone');
      final st = m['step'];
      step = st is int ? (st < 0 ? 0 : (st > 2 ? 2 : st)) : 0;
      _restored = true;
    } catch (_) {
      // битый черновик просто игнорируем
    } finally {
      _quiet = false;
    }
  }

  /// Город из последнего объявления пользователя (или последнего опубликованного на этом телефоне)
  void _autoCity() {
    if (city.text.trim().isNotEmpty) return;
    var c = S.i.prefs.getString('last_city') ?? '';
    if (c.isEmpty && S.i.pid.isNotEmpty) {
      for (final a in S.i.ads) {
        if (a.pid == S.i.pid && a.city.trim().isNotEmpty) {
          c = a.city.trim();
          break;
        }
      }
    }
    if (c.isEmpty) return;
    _quiet = true;
    city.text = c;
    _quiet = false;
    cityAuto = true;
  }

  void _resetFields() {
    _quiet = true;
    title.clear();
    payA.clear();
    desc.clear();
    city.clear();
    addr.clear();
    lat = lng = null;
    _quiet = false;
    type = 0;
    unit = 'h';
    payRaw = '';
    cat = kCats.first.name;
    photos = [];
    showPhone = true;
    step = 0;
    err = eTitle = eDesc = ePay = ePhone = null;
    status = '';
    cityAuto = false;
    _restored = false;
    if (mounted) setState(() {});
  }

  void _clearDraft() {
    _saveT?.cancel();
    if (_pid.isNotEmpty) S.i.prefs.remove(_draftKey);
  }

  // ---------- шаги ----------

  void _toTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  bool _check(int s) {
    switch (s) {
      case 0:
        if (title.text.trim().length < 3) {
          eTitle = 'Укажите заголовок — не короче 3 символов';
          return false;
        }
        eTitle = null;
        return true;
      case 1:
        var ok = true;
        final dl = desc.text.trim().length;
        if (dl < 10) {
          eDesc = 'Опишите подробнее — не короче 10 символов (сейчас $dl)';
          ok = false;
        } else {
          eDesc = null;
        }
        if (payStr(payA.text, unit, payRaw).isEmpty) {
          ePay = 'Укажите сумму или выберите «Договорная»';
          ok = false;
        } else {
          ePay = null;
        }
        return ok;
      default:
        if (!showPhone) {
          ePhone = null;
          return true;
        }
        final ph = normPhone(phone.text);
        if (ph.isEmpty) {
          ePhone = 'Введите номер или выберите «Только чат»';
          return false;
        }
        if (!phoneComplete(ph)) {
          ePhone = 'Проверьте номер телефона';
          return false;
        }
        ePhone = null;
        return true;
    }
  }

  void _next() {
    FocusScope.of(context).unfocus();
    var ok = true;
    setState(() {
      ok = _check(step);
      if (ok) step++;
    });
    if (ok) _toTop();
    _saveSoon();
  }

  bool _back() {
    if (step == 0) return false;
    FocusScope.of(context).unfocus();
    setState(() => step--);
    _toTop();
    _saveSoon();
    return true;
  }

  void _go(int s) {
    if (s == step) return;
    FocusScope.of(context).unfocus();
    if (s < step) {
      setState(() => step = s);
    } else {
      for (var k = step; k < s; k++) {
        var ok = true;
        setState(() => ok = _check(k));
        if (!ok) {
          setState(() => step = k);
          _toTop();
          return;
        }
      }
      setState(() => step = s);
    }
    _toTop();
    _saveSoon();
  }

  // ---------- шаблоны, фото ----------

  Future<void> _useTpl(Tpl t) async {
    if (title.text.trim().isNotEmpty || desc.text.trim().isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Заменить введённый заголовок и описание шаблоном?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Заменить')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      title.text = t.title;
      desc.text = t.desc;
      eTitle = null;
      eDesc = null;
    });
  }

  Future<void> _pick() async {
    if (_count >= 5) {
      toast(context, 'Не больше 5 фото');
      return;
    }
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: pal(context).card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Сделать фото'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Выбрать из галереи'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ]),
      ),
    );
    if (src == null) return;
    final pk = ImagePicker();
    try {
      if (src == ImageSource.camera) {
        final x = await pk.pickImage(source: ImageSource.camera, maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
        if (x != null) setState(() => photos.add(_Ph.file(x)));
      } else {
        final xs = await pk.pickMultiImage(maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
        setState(() {
          for (final x in xs) {
            if (_count < 5) photos.add(_Ph.file(x));
          }
        });
      }
    } catch (_) {
      if (mounted) toast(context, 'Не удалось получить фото');
    }
  }

  Future<String> _upload(XFile x) async {
    final bytes = await x.readAsBytes();
    final d = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    if (d.length > 1800000) throw ApiError('Фото слишком большое. Выберите другое');
    final j = await Api.call('upimg', {'data': d});
    return j['id'].toString();
  }

  Future<bool> _riskOk(String text) async {
    final m = riskRe.firstMatch(text);
    if (m == null) return true;
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Проверьте текст объявления'),
        content: Text(
            'В тексте есть «${m.group(0)}». Мошенники часто просят деньги вперёд, поэтому такие объявления вызывают недоверие и на них жалуются. Лучше написать, что оплата после работы.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Изменить текст')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Всё равно опубликовать')),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    for (var s = 0; s < 3; s++) {
      var ok = true;
      setState(() => ok = _check(s));
      if (!ok) {
        setState(() => step = s);
        _toTop();
        return;
      }
    }
    final t = title.text.trim(), d = desc.text.trim();
    final ph = normPhone(phone.text);
    final pay = payStr(payA.text, unit, payRaw);
    if (!await _riskOk('$t $pay $d')) return;
    setState(() {
      busy = true;
      err = null;
    });
    try {
      final all = <String>[];
      final total = photos.where((x) => x.file != null).length;
      var n = 0;
      for (final x in photos) {
        if (x.id != null) {
          all.add(x.id!);
        } else {
          n++;
          if (mounted) setState(() => status = 'Загружаем фото $n из $total…');
          all.add(await _upload(x.file!));
        }
      }
      if (addr.text.trim().isNotEmpty && lat == null && city.text.trim().isNotEmpty) {
        // адрес написан, но метку не ставили — пробуем найти сами
        final g = await Geo.search('${city.text.trim()}, ${addr.text.trim()}', limit: 1);
        if (g != null && g.isNotEmpty) {
          lat = double.parse(g.first.lat.toStringAsFixed(5));
          lng = double.parse(g.first.lng.toStringAsFixed(5));
        }
      }
      if (mounted) setState(() => status = 'Публикуем…');
      final data = <String, dynamic>{
        'type': kTypes[type],
        'title': t,
        'category': cat,
        'pay': pay,
        'city': city.text.trim(),
        'addr': addr.text.trim(),
        'lat': lat,
        'lng': lng,
        'desc': d,
        'phone': (!showPhone || ph.isEmpty) ? '' : '+$ph',
        'nophone': !showPhone || ph.isEmpty, // «Только чат»: сервер не подставляет номер из профиля
        'imgs': all,
      };
      if (_isEdit) {
        data['id'] = widget.edit!.id;
        await Api.call('edit', data);
      } else {
        await Api.call('add', data);
      }
      if (city.text.trim().isNotEmpty) await S.i.prefs.setString('last_city', city.text.trim());
      await S.i.loadAds();
      S.i.bumpCab();
      if (!mounted) return;
      if (_isEdit) {
        toast(context, 'Сохранено');
        Navigator.pop(context, true);
      } else {
        _clearDraft();
        _resetFields();
        _autoCity();
        S.i.goTab(1);
        toast(context, 'Объявление опубликовано');
      }
    } catch (e) {
      if (mounted) setState(() => err = S.i.fail(e));
    }
    if (mounted) setState(() => busy = false);
  }

  // ---------- интерфейс ----------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !widget.embedded,
            title: Text(_isEdit ? 'Редактирование' : 'Новое объявление'),
          ),
          body: S.i.logged
              ? _form(context, pal(context))
              : const NeedAuth(
                  icon: Icons.add_circle_outline,
                  title: 'Разместите объявление',
                  text: 'Нужен исполнитель или хотите предложить услуги? Войдите, чтобы разместить объявление.'),
        );
      },
    );
  }

  InputDecoration _d(BuildContext c, {String? hint, String? error}) {
    final p = pal(c);
    OutlineInputBorder ob(Color col, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: col, width: w));
    return deco(c, null, hint: hint).copyWith(
      errorText: error,
      errorStyle: TextStyle(color: p.dng, fontWeight: FontWeight.w600),
      errorBorder: ob(p.dng),
      focusedErrorBorder: ob(p.dng, 1.6),
    );
  }

  Widget _label(Pal p, String t, {String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(t, style: TextStyle(fontWeight: FontWeight.w800, color: p.tx, fontSize: 16)),
          if (hint != null) Flexible(child: Text('  $hint', style: TextStyle(color: p.mu, fontSize: 12.5))),
        ]),
      );

  Widget _helper(Pal p, String hint, [String? counter]) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(hint, style: TextStyle(fontSize: 12, color: p.mu, height: 1.3))),
          if (counter != null) Padding(padding: const EdgeInsets.only(left: 8), child: Text(counter, style: TextStyle(fontSize: 12, color: p.mu))),
        ]),
      );

  Widget _choice(Pal p, {required bool sel, required VoidCallback onTap, required Widget child, EdgeInsets? pad, Alignment? align}) {
    return Tap(
      onTap: onTap,
      scale: .98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: align,
        padding: pad ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? p.ac.withOpacity(.12) : p.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? p.ac : p.bd, width: sel ? 1.6 : 1),
        ),
        child: child,
      ),
    );
  }

  Widget _stepper(Pal p) {
    const labels = ['Что нужно', 'Детали', 'Готово'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 15),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 2.5,
                  decoration: BoxDecoration(color: i <= step ? p.ac : p.bd, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _go(i),
            child: SizedBox(
              width: 72,
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: i <= step ? LinearGradient(colors: [p.ac, p.ac2]) : null,
                    color: i <= step ? null : p.card,
                    border: i <= step ? null : Border.all(color: p.bd, width: 1.5),
                  ),
                  child: i < step
                      ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                      : Text('${i + 1}',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: i <= step ? Colors.white : p.mu)),
                ),
                const SizedBox(height: 5),
                Text(labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(fontSize: 11.5, fontWeight: i == step ? FontWeight.w800 : FontWeight.w600, color: i == step ? p.tx : p.mu)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _form(BuildContext context, Pal p) {
    return ListView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 28 + (widget.embedded ? navPad(context) : 0)),
      children: [
        _stepper(p),
        if (_restored && step == 0 && !_isEdit) _draftBanner(p),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(step),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: step == 0 ? _step0(context, p) : step == 1 ? _step1(context, p) : _step2(context, p),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (err != null)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(err!, style: TextStyle(color: p.dng, fontWeight: FontWeight.w600))),
        if (busy && status.isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(status, style: TextStyle(color: p.mu))),
        _nav(p),
      ],
    );
  }

  Widget _draftBanner(Pal p) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: p.ac.withOpacity(.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.ac.withOpacity(.35)),
        ),
        child: Row(children: [
          Icon(Icons.edit_note_rounded, color: p.ac, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text('Восстановили ваш черновик', style: TextStyle(color: p.tx, fontWeight: FontWeight.w600, fontSize: 13.5))),
          TextButton(
            onPressed: () {
              _clearDraft();
              _resetFields();
              _autoCity();
              setState(() {});
            },
            child: Text('Начать заново', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800)),
          ),
        ]),
      );

  Widget _nav(Pal p) {
    final last = step == 2;
    return Row(children: [
      if (step > 0) ...[
        SizedBox(width: 112, child: OutBtn('Назад', onTap: busy ? null : () => _back())),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: last ? GradBtn(_isEdit ? 'Сохранить' : 'Опубликовать', busy: busy, onTap: _submit) : GradBtn('Далее', onTap: _next),
      ),
    ]);
  }

  // ----- шаг 1: что нужно -----

  List<Widget> _step0(BuildContext context, Pal p) {
    final tpls = kTpls.where((t) => t.cat == cat && t.type == type).toList();
    Widget typeBtn(int i, String name, String sub, IconData ic) {
      final sel = type == i;
      return _choice(
        p,
        sel: sel,
        onTap: () => _set(() => type = i),
        pad: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic, size: 26, color: sel ? p.ac : p.mu),
          const SizedBox(height: 8),
          Text(name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: p.tx, height: 1.15)),
          const SizedBox(height: 3),
          Text(sub, style: TextStyle(fontSize: 12, color: p.mu, height: 1.2)),
        ]),
      );
    }

    return [
      _label(p, 'Что вы хотите?'),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: typeBtn(0, kTypes[0], 'Нужна помощь с задачей', Icons.person_search_rounded)),
          const SizedBox(width: 10),
          Expanded(child: typeBtn(1, kTypes[1], 'Хочу найти заказы', Icons.handyman_outlined)),
        ]),
      ),
      _label(p, 'Категория'),
      LayoutBuilder(builder: (c, box) {
        final w = (box.maxWidth - 8) / 2;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in kCats)
            SizedBox(
              width: w,
              height: 62,
              child: _choice(
                p,
                sel: cat == k.name,
                align: Alignment.centerLeft,
                pad: const EdgeInsets.symmetric(horizontal: 12),
                onTap: () => _set(() => cat = k.name),
                child: Row(children: [
                  Icon(k.icon, size: 20, color: cat == k.name ? p.ac : p.mu),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(k.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, height: 1.15, fontWeight: cat == k.name ? FontWeight.w800 : FontWeight.w600, color: p.tx)),
                  ),
                ]),
              ),
            ),
        ]);
      }),
      if (tpls.isNotEmpty) ...[
        _label(p, 'Быстрый старт', hint: 'подставим заголовок и описание'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in tpls)
            Tap(
              onTap: () => _useTpl(t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.bd)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome_rounded, size: 15, color: p.ac),
                  const SizedBox(width: 6),
                  Text(t.name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.tx)),
                ]),
              ),
            ),
        ]),
      ],
      _label(p, 'Заголовок'),
      TextField(contextMenuBuilder: appContextMenu, 
        controller: title,
        maxLength: 90,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(color: p.tx),
        onChanged: (_) {
          if (eTitle != null) setState(() => eTitle = null);
        },
        decoration: _d(context, hint: 'Например: Нужны грузчики на 3 часа', error: eTitle).copyWith(counterText: ''),
      ),
      _helper(p, 'Коротко и понятно: что нужно сделать и когда', '${title.text.length}/90'),
    ];
  }

  // ----- шаг 2: детали -----

  List<Widget> _step1(BuildContext context, Pal p) {
    final hideAmount = unit == 'n' || unit == 'x';
    final lab = {for (final u in kPayUnits) u[0]: u[1]};
    final order = ['n', 't', 'h', 'd', 'm', if (unit == 'x') 'x'];
    return [
      _label(p, 'Фото', hint: 'до 5 штук, любой размер'),
      _photosRow(p),
      _label(p, 'Описание'),
      TextField(contextMenuBuilder: appContextMenu, 
        controller: desc,
        minLines: 5,
        maxLines: 10,
        maxLength: 2000,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(color: p.tx),
        onChanged: (_) {
          if (eDesc != null) setState(() => eDesc = null);
        },
        decoration: _d(context, hint: 'Что сделать, где, когда', error: eDesc).copyWith(counterText: ''),
      ),
      _helper(p, 'Напишите адрес или район, объём работы и когда нужно', '${desc.text.length}/2000'),
      _label(p, 'Оплата'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final u in order)
          _choice(
            p,
            sel: unit == u,
            onTap: () => _set(() {
              unit = u;
              ePay = null;
            }),
            pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(u == 'x' ? 'Как было: $payRaw' : lab[u] ?? u,
                style: TextStyle(fontSize: 13.5, fontWeight: unit == u ? FontWeight.w800 : FontWeight.w600, color: p.tx)),
          ),
      ]),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: hideAmount
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(contextMenuBuilder: appContextMenu, 
                  controller: payA,
                  keyboardType: TextInputType.number,
                  inputFormatters: [GroupFormatter()],
                  style: TextStyle(color: p.tx),
                  onChanged: (_) {
                    if (ePay != null) setState(() => ePay = null);
                  },
                  decoration: _d(context, hint: 'Сумма', error: ePay).copyWith(suffixText: '₽', suffixStyle: TextStyle(color: p.mu, fontWeight: FontWeight.w700)),
                ),
              ),
      ),
      _label(p, 'Город'),
      CityField(
        controller: city,
        decoration: _d(context, hint: 'Начните вводить город'),
        onChanged: (_) => cityAuto = false,
      ),
      if (cityAuto && city.text.trim().isNotEmpty) _helper(p, 'Подставили город из вашего прошлого объявления — его можно изменить'),
      AddrField(
        controller: addr,
        lat: lat,
        lng: lng,
        city: () => city.text,
        onGeo: (la, ln) => _set(() {
          lat = la;
          lng = ln;
        }),
      ),
    ];
  }

  Widget _photosRow(Pal p) {
    final hint = photos.isEmpty
        ? 'Первое фото станет обложкой объявления'
        : photos.length > 1
            ? 'Первое фото — обложка. Задержите палец на фото и перетащите, чтобы поменять порядок'
            : 'Это фото будет обложкой объявления';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (photos.isNotEmpty)
          Flexible(
            child: SizedBox(
              height: 84,
              child: ReorderableListView(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                proxyDecorator: (child, i, a) => Material(color: Colors.transparent, child: child),
                onReorder: (o, n) => setState(() {
                  if (n > o) n -= 1;
                  photos.insert(n, photos.removeAt(o));
                }),
                children: [
                  for (var i = 0; i < photos.length; i++)
                    ReorderableDelayedDragStartListener(
                      key: ObjectKey(photos[i]),
                      index: i,
                      child: Padding(padding: const EdgeInsets.only(right: 8), child: _photoTile(p, photos[i], i)),
                    ),
                ],
              ),
            ),
          ),
        if (photos.length < 5)
          GestureDetector(
            onTap: _pick,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.bd)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_a_photo_outlined, color: p.mu),
                const SizedBox(height: 4),
                Text('Добавить', style: TextStyle(fontSize: 11, color: p.mu, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
      ]),
      _helper(p, hint),
    ]);
  }

  Widget _photoTile(Pal p, _Ph ph, int i) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ph.id != null
                ? CachedNetworkImage(imageUrl: imgUrl(ph.id!, 200), fit: BoxFit.cover, placeholder: (c, u) => Container(color: p.bg2))
                : Image.file(File(ph.file!.path), fit: BoxFit.cover, cacheWidth: 300),
          ),
        ),
        if (i == 0)
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
              child: const Text('Обложка', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
        Positioned(
          right: 4,
          top: 4,
          child: GestureDetector(
            onTap: () => setState(() => photos.removeAt(i)),
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 15, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }


  // ----- шаг 3: контакты и предпросмотр -----

  List<Widget> _step2(BuildContext context, Pal p) {
    Widget seg(int i, String text, IconData ic) {
      final sel = (showPhone ? 0 : 1) == i;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _set(() {
            showPhone = i == 0;
            ePhone = null;
          }),
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ic, size: 18, color: sel ? p.ac : p.mu),
              const SizedBox(width: 7),
              Flexible(
                child: Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: sel ? p.tx : p.mu)),
              ),
            ]),
          ),
        ),
      );
    }

    return [
      _label(p, 'Как с вами связаться'),
      Container(
        height: 52,
        decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd)),
        child: Stack(children: [
          // подсветка выбранного варианта плавно переезжает
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: showPhone ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: .5,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.ac.withOpacity(.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.ac.withOpacity(.55), width: 1.2),
                  ),
                ),
              ),
            ),
          ),
          Row(children: [
            seg(0, 'Показать номер', Icons.phone_outlined),
            seg(1, 'Только чат', Icons.chat_bubble_outline_rounded),
          ]),
        ]),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: showPhone
            ? Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(contextMenuBuilder: appContextMenu, 
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [PhoneFormatter()],
                  style: TextStyle(color: p.tx),
                  onChanged: (_) {
                    if (ePhone != null) setState(() => ePhone = null);
                  },
                  decoration: _d(context, hint: '+7 (999) 123-45-67', error: ePhone),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: _helper(p, 'Номер не будет виден в объявлении — вам смогут написать в чате приложения'),
                ),
              ),
      ),
      _label(p, 'Так увидят ваше объявление'),
      _preview(context, p),
      _helper(p, 'Всё верно? Если нужно что-то поменять, вернитесь кнопкой «Назад»'),
    ];
  }

  Widget _preview(BuildContext context, Pal p) {
    final t = title.text.trim();
    final pay = payStr(payA.text, unit, payRaw);
    final d = desc.text.trim();
    const thumb = 92.0;
    Widget ph() => Container(
          decoration: BoxDecoration(
            color: Color.alphaBlend(p.ac.withOpacity(.07), p.bg2),
            border: Border.all(color: p.bd),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(catIcon(cat), size: thumb * .35, color: p.ac.withOpacity(.75)),
        );
    Widget cover;
    if (photos.isEmpty) {
      cover = ph();
    } else {
      final f = photos.first;
      cover = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(fit: StackFit.expand, children: [
          f.id != null
              ? CachedNetworkImage(imageUrl: imgUrl(f.id!, 300), fit: BoxFit.cover, placeholder: (c, u) => Container(color: p.bg2), errorWidget: (c, u, e) => ph())
              : Image.file(File(f.file!.path), fit: BoxFit.cover, cacheWidth: 300),
          if (photos.length > 1)
            Positioned(
              right: 5,
              bottom: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.photo_camera_outlined, size: 11, color: Colors.white),
                  const SizedBox(width: 3),
                  Text('${photos.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ]),
      );
    }
    final ph0 = normPhone(phone.text);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDeco(p, r: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: thumb, height: thumb, child: cover),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 5, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
                typeTag(context, kTypes[type]),
                Container(
                  constraints: const BoxConstraints(maxWidth: 132),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.bd)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(catIcon(cat), size: 12, color: p.mu),
                    const SizedBox(width: 3),
                    Flexible(child: Text(cat, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: p.mu, fontWeight: FontWeight.w600))),
                  ]),
                ),
              ]),
              const SizedBox(height: 6),
              Text(t.isEmpty ? 'Заголовок объявления' : t,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.18, color: t.isEmpty ? p.mu : p.tx)),
              const SizedBox(height: 4),
              Text(pay.isEmpty ? 'Сумма не указана' : pay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: pay.isEmpty ? p.mu : p.ok)),
              const SizedBox(height: 4),
              Wrap(spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Icon(Icons.place_outlined, size: 13, color: p.mu),
                Text(city.text.trim().isEmpty ? 'Город не указан' : city.text.trim(),
                    style: TextStyle(fontSize: 12, color: p.mu), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('· только что', style: TextStyle(fontSize: 12, color: p.mu)),
              ]),
              if (d.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(d, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, height: 1.25, color: p.mu)),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Divider(height: 1, color: p.bd),
        const SizedBox(height: 10),
        Row(children: [
          Icon(showPhone ? Icons.phone_outlined : Icons.chat_bubble_outline_rounded, size: 16, color: p.mu),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              showPhone ? (ph0.isEmpty ? 'Телефон не указан' : fmtPhone(phone.text)) : 'Связь только через чат',
              style: TextStyle(fontSize: 12.5, color: p.mu, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ]),
    );
  }
}
