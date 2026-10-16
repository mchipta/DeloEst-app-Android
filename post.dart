import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'auth.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

class PostScreen extends StatefulWidget {
  final Ad? edit;
  final bool embedded;
  const PostScreen({super.key, this.edit, this.embedded = true});
  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  int type = 0;
  final title = TextEditingController();
  final payA = TextEditingController();
  final city = TextEditingController();
  final desc = TextEditingController();
  final phone = TextEditingController();
  String cat = kCats.first.name;
  String unit = 'h';
  String payRaw = '';
  List<String> ids = [];
  List<XFile> picked = [];
  bool busy = false;
  String status = '';
  String? err;

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
      desc.text = e.desc;
      phone.text = fmtPhone(e.phone);
      cat = kCats.any((c) => c.name == e.category) ? e.category : kCats.last.name;
      ids = List<String>.of(e.imgs);
    }
    S.i.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (phone.text.isEmpty && S.i.phone.isNotEmpty) phone.text = fmtPhone(S.i.phone);
  }

  @override
  void dispose() {
    S.i.removeListener(_sync);
    super.dispose();
  }

  void _reset() {
    title.clear();
    payA.clear();
    desc.clear();
    type = 0;
    unit = 'h';
    payRaw = '';
    cat = kCats.first.name;
    ids = [];
    picked = [];
    err = null;
    status = '';
  }

  int get _count => ids.length + picked.length;

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
      type = t.type;
      title.text = t.title;
      cat = t.cat;
      desc.text = t.desc;
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
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
        if (x != null) setState(() => picked.add(x));
      } else {
        final xs = await pk.pickMultiImage(maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
        setState(() {
          for (final x in xs) {
            if (_count < 5) picked.add(x);
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
    final t = title.text.trim(), d = desc.text.trim();
    final ph = normPhone(phone.text);
    final pay = payStr(payA.text, unit, payRaw);
    if (t.length < 3) {
      setState(() => err = 'Укажите заголовок (не короче 3 символов)');
      return;
    }
    if (d.length < 10) {
      setState(() => err = 'Опишите подробнее (не короче 10 символов)');
      return;
    }
    if (ph.isNotEmpty && ph.length < 11) {
      setState(() => err = 'Проверьте номер телефона');
      return;
    }
    if (pay.isEmpty) {
      setState(() => err = 'Укажите сумму или выберите «Договорная»');
      return;
    }
    if (!await _riskOk('$t $pay $d')) return;
    setState(() {
      busy = true;
      err = null;
    });
    try {
      final all = List<String>.of(ids);
      for (var i = 0; i < picked.length; i++) {
        if (mounted) setState(() => status = 'Загружаем фото ${i + 1} из ${picked.length}…');
        all.add(await _upload(picked[i]));
      }
      if (mounted) setState(() => status = 'Публикуем…');
      final data = <String, dynamic>{
        'type': kTypes[type],
        'title': t,
        'category': cat,
        'pay': pay,
        'city': city.text.trim(),
        'desc': d,
        'phone': ph.isEmpty ? '' : '+$ph',
        'imgs': all,
      };
      final editing = widget.edit != null;
      if (editing) {
        data['id'] = widget.edit!.id;
        await Api.call('edit', data);
      } else {
        await Api.call('add', data);
      }
      await S.i.loadAds();
      S.i.bumpCab();
      if (!mounted) return;
      if (editing) {
        toast(context, 'Сохранено');
        Navigator.pop(context, true);
      } else {
        setState(_reset);
        S.i.goTab(1);
        toast(context, 'Объявление опубликовано');
      }
    } catch (e) {
      if (mounted) setState(() => err = S.i.fail(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !widget.embedded,
            title: Text(widget.edit != null ? 'Редактирование' : 'Новое объявление'),
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

  Widget _cityField(Pal p) {
    const cities = <String>[
      'Москва', 'Санкт-Петербург', 'Новосибирск', 'Екатеринбург', 'Казань',
      'Нижний Новгород', 'Челябинск', 'Самара', 'Омск', 'Ростов-на-Дону',
      'Уфа', 'Красноярск', 'Пермь', 'Воронеж', 'Волгоград', 'Краснодар',
      'Тюмень', 'Калининград', 'Саратов', 'Тольятти', 'Ижевск', 'Барнаул',
      'Ульяновск', 'Иркутск', 'Хабаровск', 'Ярославль', 'Владивосток',
      'Махачкала', 'Томск', 'Оренбург', 'Кемерово', 'Рязань', 'Пенза',
      'Липецк', 'Киров', 'Чебоксары', 'Курск', 'Тула', 'Сочи',
    ];
    return RawAutocomplete<String>(
      textEditingController: city,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.length < 2) return const Iterable<String>.empty();
        return cities.where((c) => c.toLowerCase().contains(q)).take(6);
      },
      displayStringForOption: (option) => option,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
        controller: controller, focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        style: TextStyle(color: p.tx),
        decoration: _d(context, hint: 'Начните вводить город'),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(color: Colors.transparent, child: Container(
          constraints: const BoxConstraints(maxHeight: 230),
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 16, offset: const Offset(0, 5))]),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(5), children: [
            for (final option in options) ListTile(
              dense: true, leading: Icon(Icons.location_city_rounded, color: p.ac, size: 20),
              title: Text(option, style: TextStyle(color: p.tx)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () => onSelected(option),
            ),
          ]),
        )),
      ),
    );
  }

  Widget _label(Pal p, String t, {String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 6),
        child: Row(children: [
          Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: p.tx, fontSize: 15)),
          if (hint != null) Text('  $hint', style: TextStyle(color: p.mu, fontSize: 13)),
        ]),
      );

  InputDecoration _d(BuildContext c, {String? hint}) => deco(c, null, hint: hint);

  Widget _form(BuildContext context, Pal p) {
    final hideAmount = unit == 'n' || unit == 'x';
    final units = [for (final u in kPayUnits) DropdownMenuItem(value: u[0], child: Text(u[1]))];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), children: [
      if (widget.edit == null) ...[
        Text('Начните с шаблона: подставим заголовок и описание', style: TextStyle(color: p.mu, fontSize: 13.5)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final t in kTpls)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _useTpl(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.bd)),
                    child: Text(t.name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.tx)),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
      ],
      _label(p, 'Тип'),
      DropdownButtonFormField<int>(
        value: type,
        isExpanded: true,
        dropdownColor: p.card,
        style: TextStyle(color: p.tx, fontSize: 16),
        decoration: _d(context),
        items: [for (var i = 0; i < kTypes.length; i++) DropdownMenuItem(value: i, child: Text(kTypes[i]))],
        onChanged: (v) {
          if (v != null) setState(() => type = v);
        },
      ),
      _label(p, 'Заголовок'),
      TextField(
        controller: title,
        maxLength: 90,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(color: p.tx),
        decoration: _d(context, hint: 'Например: Нужны грузчики на 3 часа').copyWith(counterText: ''),
      ),
      _label(p, 'Категория'),
      DropdownButtonFormField<String>(
        value: cat,
        isExpanded: true,
        dropdownColor: p.card,
        style: TextStyle(color: p.tx, fontSize: 16),
        decoration: _d(context),
        items: [for (final c in kCats) DropdownMenuItem(value: c.name, child: Text(c.name))],
        onChanged: (v) {
          if (v != null) setState(() => cat = v);
        },
      ),
      _label(p, 'Оплата'),
      Row(children: [
        if (!hideAmount)
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextField(
                controller: payA,
                keyboardType: TextInputType.number,
                inputFormatters: [GroupFormatter()],
                style: TextStyle(color: p.tx),
                decoration: _d(context, hint: 'Сумма, ₽'),
              ),
            ),
          ),
        Expanded(
          flex: 6,
          child: DropdownButtonFormField<String>(
            value: unit,
            isExpanded: true,
            dropdownColor: p.card,
            style: TextStyle(color: p.tx, fontSize: 16),
            decoration: _d(context),
            items: [
              ...units,
              if (unit == 'x') DropdownMenuItem(value: 'x', child: Text('Как было: $payRaw', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => unit = v);
            },
          ),
        ),
      ]),
      _label(p, 'Город'),
      TextField(
        controller: city,
        textCapitalization: TextCapitalization.words,
        style: TextStyle(color: p.tx),
        decoration: _d(context),
      ),
      _label(p, 'Описание'),
      TextField(
        controller: desc,
        minLines: 5,
        maxLines: 10,
        maxLength: 2000,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(color: p.tx),
        decoration: _d(context),
      ),
      _label(p, 'Фото', hint: 'до 5 штук, любой размер'),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < ids.length; i++)
          _tile(p, CachedNetworkImage(imageUrl: imgUrl(ids[i], 200), fit: BoxFit.cover), () => setState(() => ids.removeAt(i))),
        for (var i = 0; i < picked.length; i++)
          _tile(p, Image.file(File(picked[i].path), fit: BoxFit.cover), () => setState(() => picked.removeAt(i))),
        if (_count < 5)
          GestureDetector(
            onTap: _pick,
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.bd)),
              child: Icon(Icons.add_a_photo_outlined, color: p.mu),
            ),
          ),
      ]),
      _label(p, 'Телефон для связи'),
      TextField(
        controller: phone,
        keyboardType: TextInputType.phone,
        inputFormatters: [PhoneFormatter()],
        style: TextStyle(color: p.tx),
        decoration: _d(context, hint: '+7 (999) 123-45-67'),
      ),
      const SizedBox(height: 18),
      if (err != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(err!, style: TextStyle(color: p.dng, fontWeight: FontWeight.w600))),
      if (busy && status.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(status, style: TextStyle(color: p.mu))),
      GradBtn(widget.edit != null ? 'Сохранить' : 'Опубликовать', busy: busy, onTap: _submit),
    ]);
  }

  Widget _tile(Pal p, Widget img, VoidCallback remove) {
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(14), child: img)),
        Positioned(
          right: -6,
          top: -6,
          child: GestureDetector(
            onTap: remove,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: p.dng, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 15, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }
}
