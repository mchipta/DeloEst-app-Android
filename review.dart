import 'package:flutter/material.dart';
import 'api.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

/// Окно «Оцените работу»: звёзды и короткий отзыв. Возвращает оценку (1–5), если отзыв отправлен, иначе 0.
Future<int> showReviewSheet(BuildContext context, {required String pid, String name = ''}) async {
  Map<String, dynamic> d;
  try {
    d = await Api.call('profile', {'pid': pid});
  } catch (e) {
    if (context.mounted) toast(context, S.i.fail(e), err: true);
    return 0;
  }
  if (!context.mounted) return 0;
  if (d['can'] != true) {
    toast(context, 'Отзыв можно оставить после выполненной работы');
    return 0;
  }
  final mine = d['mine'] is Map ? Map<String, dynamic>.from(d['mine'] as Map) : null;
  final r = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReviewSheet(
      pid: pid,
      name: (d['name'] ?? name).toString(),
      stars: (mine?['rating'] as num?)?.toInt() ?? 0,
      text: (mine?['text'] ?? '').toString(),
    ),
  );
  return r ?? 0;
}

class _ReviewSheet extends StatefulWidget {
  final String pid, name, text;
  final int stars;
  const _ReviewSheet({required this.pid, required this.name, required this.stars, required this.text});
  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int _stars = widget.stars;
  late final _txt = TextEditingController(text: widget.text);
  bool _busy = false;

  static const _words = ['', 'Ужасно', 'Плохо', 'Нормально', 'Хорошо', 'Отлично'];

  @override
  void dispose() {
    _txt.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_stars < 1) {
      toast(context, 'Поставьте оценку звёздами');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.call('rate', {'pid': widget.pid, 'rating': _stars, 'text': _txt.text.trim()});
      if (!mounted) return;
      toast(context, 'Спасибо за отзыв!');
      Navigator.pop(context, _stars);
    } catch (e) {
      if (mounted) {
        toast(context, S.i.fail(e), err: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final edit = widget.stars > 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.of(context).viewPadding.bottom),
        decoration: BoxDecoration(color: p.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: p.bd, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 16),
          Text(edit ? 'Ваш отзыв' : 'Как прошла работа?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: p.tx, letterSpacing: -.3)),
          const SizedBox(height: 2),
          Text(widget.name.isEmpty ? 'Оцените работу' : 'Оцените работу: ${widget.name}', style: TextStyle(color: p.mu, fontSize: 14)),
          const SizedBox(height: 14),
          Row(children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () {
                  haptic();
                  setState(() => _stars = i);
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 42, color: const Color(0xFFFFB400)),
                ),
              ),
            const SizedBox(width: 6),
            Text(_words[_stars], style: TextStyle(color: p.mu, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          TextField(
            contextMenuBuilder: appContextMenu,
            controller: _txt,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: deco(context, 'Как всё прошло? (необязательно)'),
          ),
          const SizedBox(height: 6),
          GradBtn(edit ? 'Сохранить отзыв' : 'Отправить отзыв', radius: 18, busy: _busy, onTap: _busy ? null : _send),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, 0),
              child: Text('Позже', style: TextStyle(color: p.mu, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}
