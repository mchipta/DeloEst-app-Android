import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'auth.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
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
  final pay = TextEditingController();
  final city = TextEditingController();
  final desc = TextEditingController();
  final phone = TextEditingController();
  String cat = kCats.first.name;
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
      pay.text = e.pay;
      city.text = e.city;
      desc.text = e.desc;
      phone.text = e.phone;
      cat = kCats.any((c) => c.name == e.category) ? e.category : kCats.last.name;
      ids = List<String>.of(e.imgs);
    }
    S.i.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (phone.text.isEmpty && S.i.phone.isNotEmpty) phone.text = S.i.phone;
  }

  @override
  void dispose() {
    S.i.removeListener(_sync);
    super.dispose();
  }

  void _reset() {
    title.clear();
    pay.clear();
    desc.clear();
    type = 0;
    cat = kCats.first.name;
    ids = [];
    picked = [];
    err = null;
    status = '';
  }

  int get _count => ids.length + picked.length;

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

  Future<void> _submit() async {
    final t = title.text.trim(), d = desc.text.trim();
    if (t.length < 3) {
      setState(() => err = 'Укажите заголовок (не короче 3 символов)');
      return;
    }
    if (d.length < 10) {
      setState(() => err = 'Опишите подробнее (не короче 10 символов)');
      return;
    }
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
        'pay': pay.text.trim(),
        'city': city.text.trim(),
        'desc': d,
        'phone': phone.text.trim(),
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
        toast(context, 'Изменения сохранены');
        Navigator.pop(context, true);
      } else {
        setState(_reset);
        S.i.goTab(0);
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

  Widget _label(Pal p, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: p.tx)),
      );

  Widget _f(TextEditingController c, String label,
          {String? hint, int lines = 1, int? max, TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          minLines: lines,
          maxLines: lines == 1 ? 1 : 8,
          maxLength: max,
          keyboardType: type,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: pal(context).tx),
          decoration: deco(context, label, hint: hint),
        ),
      );

  Widget _form(BuildContext context, Pal p) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
      Row(children: [
        for (var i = 0; i < 2; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 0 ? 8 : 0),
              child: GestureDetector(
                onTap: () => setState(() => type = i),
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: type == i ? LinearGradient(colors: [p.ac, p.ac2]) : null,
                    color: type == i ? null : p.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: type == i ? Colors.transparent : p.bd),
                  ),
                  child: Text(kTypes[i],
                      style: TextStyle(fontWeight: FontWeight.w700, color: type == i ? Colors.white : p.tx)),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 14),
      _f(title, 'Заголовок', hint: 'Например: Нужен грузчик на субботу', max: 100),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: cat,
          isExpanded: true,
          dropdownColor: p.card,
          style: TextStyle(color: p.tx, fontSize: 16),
          decoration: deco(context, 'Категория'),
          items: [for (final c in kCats) DropdownMenuItem(value: c.name, child: Text(c.name))],
          onChanged: (v) {
            if (v != null) setState(() => cat = v);
          },
        ),
      ),
      _f(pay, 'Оплата', hint: 'Например: 2000 или «Договорная»'),
      _f(city, 'Город или район'),
      _f(desc, 'Описание', hint: 'Что нужно сделать, когда, какие условия', lines: 5, max: 2000),
      _f(phone, 'Телефон для связи', type: TextInputType.phone),
      _label(p, 'Фото (до 5)'),
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
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.bd),
              ),
              child: Icon(Icons.add_a_photo_outlined, color: p.mu),
            ),
          ),
      ]),
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
