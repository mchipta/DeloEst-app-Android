import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

/// Редактор «О себе»: короткая строка, навыки, прайс-лист и фото работ
class AboutEditor extends StatefulWidget {
  final Map<String, dynamic> data;
  const AboutEditor({super.key, required this.data});
  @override
  State<AboutEditor> createState() => _AboutEditorState();
}

class _AboutEditorState extends State<AboutEditor> {
  late final _bio = TextEditingController(text: (widget.data['bio'] ?? '').toString());
  late final _prices = TextEditingController(text: (widget.data['prices'] ?? '').toString());
  final _skill = TextEditingController();
  late List<String> _skills = (widget.data['skills'] is List ? widget.data['skills'] as List : <dynamic>[]).map((e) => e.toString()).toList();
  late List<String> _photos = (widget.data['portfolio'] is List ? widget.data['portfolio'] as List : <dynamic>[]).map((e) => e.toString()).toList();
  bool _busy = false;

  @override
  void dispose() {
    _bio.dispose();
    _prices.dispose();
    _skill.dispose();
    super.dispose();
  }

  void _addSkill() {
    final t = _skill.text.replaceAll(RegExp(r'[|,]'), ' ').trim();
    if (t.length < 2) return;
    if (_skills.length >= 8) {
      toast(context, 'Не больше 8 навыков');
      return;
    }
    if (!_skills.contains(t)) setState(() => _skills.add(t.length > 24 ? t.substring(0, 24) : t));
    _skill.clear();
  }

  Future<void> _pick() async {
    if (_photos.length >= 12) {
      toast(context, 'Не больше 12 фото');
      return;
    }
    try {
      final xs = await ImagePicker().pickMultiImage(maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
      if (xs.isEmpty || !mounted) return;
      setState(() => _busy = true);
      for (final x in xs.take(12 - _photos.length)) {
        final bytes = await x.readAsBytes();
        final d = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        if (d.length > 1800000) throw ApiError('Фото слишком большое. Выберите другое');
        final j = await Api.call('upimg', {'data': d});
        _photos.add(j['id'].toString());
      }
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, S.i.fail(e), err: true);
      }
    }
  }

  Future<void> _save() async {
    _addSkill();
    setState(() => _busy = true);
    try {
      await Api.call('about', {'bio': _bio.text.trim(), 'skills': _skills, 'prices': _prices.text.trim()});
      await Api.call('portfolio', {'ids': _photos});
      if (!mounted) return;
      toast(context, 'Профиль сохранён');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, S.i.fail(e), err: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    Widget head(String t, [String? sub]) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.tx)),
            if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: TextStyle(color: p.mu, fontSize: 13))),
          ]),
        );
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(backgroundColor: p.bg, foregroundColor: p.tx, elevation: 0, title: const Text('О себе', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Stack(children: [
        ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 0, 16, 110 + MediaQuery.of(context).viewInsets.bottom),
          children: [
            head('Коротко о вас', 'Одна строка под именем: чем занимаетесь, опыт, район'),
            TextField(contextMenuBuilder: appContextMenu, controller: _bio, maxLength: 200, minLines: 1, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: deco(context, 'Например: Грузчик с опытом 5 лет, свой транспорт')),
            head('Навыки', 'Чем можете помочь, до 8 штук'),
            if (_skills.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in _skills)
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                      decoration: BoxDecoration(color: p.ac.withOpacity(.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: p.ac.withOpacity(.4))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(s, style: TextStyle(color: p.ac, fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const SizedBox(width: 4),
                        GestureDetector(onTap: () => setState(() => _skills.remove(s)), child: Icon(Icons.close_rounded, size: 17, color: p.ac)),
                      ]),
                    ),
                ]),
              ),
            Row(children: [
              Expanded(
                child: TextField(
                  contextMenuBuilder: appContextMenu,
                  controller: _skill,
                  maxLength: 24,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addSkill(),
                  decoration: deco(context, 'Навык, например: сборка мебели').copyWith(counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              Tap(
                onTap: _addSkill,
                scale: .94,
                child: Container(width: 50, height: 50, decoration: BoxDecoration(color: p.ac, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.add_rounded, color: Colors.white)),
              ),
            ]),
            head('Цены на услуги', 'Каждая услуга с новой строки: «Сборка шкафа — от 800 ₽»'),
            TextField(contextMenuBuilder: appContextMenu, controller: _prices, maxLength: 800, minLines: 3, maxLines: 8, decoration: deco(context, 'Сборка шкафа — от 800 ₽\nПереезд, 2 грузчика — 500 ₽/час')),
            head('Фото работ', '${_photos.length} из 12'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Stack(fit: StackFit.expand, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedNetworkImage(imageUrl: imgUrl(_photos[i], 300), fit: BoxFit.cover)),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(i)),
                        child: Container(width: 26, height: 26, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 16, color: Colors.white)),
                      ),
                    ),
                  ]),
                if (_photos.length < 12)
                  Tap(
                    onTap: _busy ? null : _pick,
                    scale: .96,
                    child: Container(
                      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.bd)),
                      child: Icon(Icons.add_photo_alternate_outlined, size: 30, color: p.ac),
                    ),
                  ),
              ],
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
            child: GradBtn('Сохранить', radius: 18, busy: _busy, onTap: _busy ? null : _save),
          ),
        ),
      ]),
    );
  }
}
