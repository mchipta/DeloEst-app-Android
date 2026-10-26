import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

// Мост к Android: запись голоса (MediaRecorder) и воспроизведение (MediaPlayer)
class Voice {
  static const _ch = MethodChannel('ru.deloest.delo_est/voice');

  // 'ok' — запись пошла, 'denied' — нет доступа к микрофону, иначе ошибка
  static Future<String> start() async {
    try {
      return (await _ch.invokeMethod<String>('start')) ?? 'error';
    } catch (_) {
      return 'error';
    }
  }

  static Future<Map<String, dynamic>?> stop() async {
    try {
      final r = await _ch.invokeMethod<Map<dynamic, dynamic>>('stop');
      return r == null ? null : Map<String, dynamic>.from(r);
    } catch (_) {
      return null;
    }
  }

  static Future<void> cancel() async {
    try {
      await _ch.invokeMethod('cancel');
    } catch (_) {}
  }

  static Future<bool> play(String path) async {
    try {
      return (await _ch.invokeMethod<bool>('play', path)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> pause() async {
    try {
      await _ch.invokeMethod('pause');
    } catch (_) {}
  }

  static Future<void> resume() async {
    try {
      await _ch.invokeMethod('resume');
    } catch (_) {}
  }

  static Future<void> stopPlay() async {
    try {
      await _ch.invokeMethod('stopPlay');
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> state() async {
    try {
      final r = await _ch.invokeMethod<Map<dynamic, dynamic>>('state');
      return r == null ? <String, dynamic>{} : Map<String, dynamic>.from(r);
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}

String voiceTime(int ms) {
  final s = (ms / 1000).round().clamp(0, 99 * 60);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

// Один общий проигрыватель: в каждый момент звучит только одно голосовое
class VoicePlayer extends ChangeNotifier {
  static final VoicePlayer i = VoicePlayer._();
  VoicePlayer._();

  final Map<String, String> cache = {}; // id записи -> файл на телефоне
  String id = '';
  bool playing = false;
  bool loading = false;
  bool started = false;
  int pos = 0;
  int dur = 0;
  Timer? _t;

  Future<void> toggle(String audId, void Function(String) onError) async {
    if (id == audId && started) {
      if (playing) {
        await Voice.pause();
        playing = false;
      } else {
        final st = await Voice.state();
        if (st['done'] == true) {
          final path = cache[audId];
          if (path == null || !await Voice.play(path)) {
            await stop();
            return;
          }
        } else {
          await Voice.resume();
        }
        playing = true;
      }
      notifyListeners();
      return;
    }
    await stop();
    id = audId;
    loading = true;
    notifyListeners();
    try {
      var path = cache[audId];
      if (path == null || !File(path).existsSync()) path = await _download(audId);
      if (id != audId) return; // успели переключиться на другое
      final ok = await Voice.play(path);
      if (!ok) throw ApiError('Не удалось воспроизвести запись');
      if (id != audId) return;
      started = true;
      playing = true;
      loading = false;
      _poll();
      notifyListeners();
    } catch (e) {
      final m = e is ApiError ? e.message : S.i.fail(e);
      await stop();
      onError(m);
    }
  }

  Future<String> _download(String audId) async {
    final j = await Api.call('getaud', {'id': audId});
    final bytes = base64Decode((j['data'] ?? '').toString());
    final mime = (j['mime'] ?? '').toString();
    final ext = mime.contains('webm')
        ? 'webm'
        : mime.contains('ogg')
            ? 'ogg'
            : mime.contains('mpeg')
                ? 'mp3'
                : (mime.contains('aac') && !mime.contains('mp4'))
                    ? 'aac'
                    : 'm4a';
    final f = File('${Directory.systemTemp.path}/vc_$audId.$ext');
    await f.writeAsBytes(bytes, flush: true);
    cache[audId] = f.path;
    return f.path;
  }

  void _poll() {
    _t?.cancel();
    _t = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (id.isEmpty || !started) return;
      final st = await Voice.state();
      if (id.isEmpty) return;
      if (st['done'] == true) {
        await stop();
        return;
      }
      pos = (st['pos'] as num?)?.toInt() ?? pos;
      dur = (st['dur'] as num?)?.toInt() ?? dur;
      playing = st['playing'] == true;
      notifyListeners();
    });
  }

  Future<void> stop() async {
    _t?.cancel();
    final had = id.isNotEmpty;
    id = '';
    playing = false;
    loading = false;
    started = false;
    pos = 0;
    dur = 0;
    if (had) await Voice.stopPlay();
    notifyListeners();
  }
}

// Голосовое сообщение в пузыре чата: кнопка, полоса прогресса и время
class VoiceBubble extends StatefulWidget {
  final String aud; // «id|секунды»
  final bool mine;
  final Color fg;
  const VoiceBubble({super.key, required this.aud, required this.mine, required this.fg});
  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  late String _id;
  late int _sec;
  List<double> _bars = const [];

  @override
  void initState() {
    super.initState();
    _parse();
    VoicePlayer.i.addListener(_on);
  }

  void _parse() {
    final parts = widget.aud.split('|');
    _id = parts.first;
    _sec = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    // «волна» у каждой записи своя, но всегда одинаковая: считаем её из id
    var h = _id.hashCode & 0x7fffffff;
    _bars = List<double>.generate(26, (_) {
      h = (h * 1103515245 + 12345) & 0x7fffffff;
      return 7.0 + ((h >> 8) % 19);
    });
  }

  @override
  void didUpdateWidget(VoiceBubble old) {
    super.didUpdateWidget(old);
    if (old.aud != widget.aud) _parse();
  }

  @override
  void dispose() {
    VoicePlayer.i.removeListener(_on);
    super.dispose();
  }

  void _on() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final vp = VoicePlayer.i;
    final active = vp.id == _id;
    final playing = active && vp.playing;
    final loading = active && vp.loading;
    final total = (active && vp.dur > 0) ? vp.dur : _sec * 1000;
    final pos = active ? vp.pos : 0;
    final frac = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
    final shown = (active && vp.started && pos > 0) ? pos : total;
    final btnBg = widget.mine ? Colors.white : p.ac;
    final btnFg = widget.mine ? p.ac : Colors.white;
    return SizedBox(
      width: 220,
      child: Row(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: loading
              ? null
              : () => vp.toggle(_id, (m) {
                    if (mounted) toast(context, m);
                  }),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: btnBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: loading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: btnFg))
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, key: ValueKey(playing), color: btnFg, size: 28),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 28,
            child: Row(children: [
              for (var k = 0; k < _bars.length; k++)
                Expanded(
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 3,
                      height: _bars[k],
                      decoration: BoxDecoration(
                        color: k < (frac * _bars.length).round() ? widget.fg : widget.fg.withOpacity(.32),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Text(voiceTime(shown), style: TextStyle(fontSize: 12.5, color: widget.fg.withOpacity(.9))),
      ]),
    );
  }
}

// Красная точка записи с расходящимся кольцом
class RecDot extends StatefulWidget {
  final Color color;
  const RecDot({super.key, required this.color});
  @override
  State<RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<RecDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(alignment: Alignment.center, children: [
            Transform.scale(
              scale: 1 + t * 1.1,
              child: Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.color.withOpacity((1 - t) * .45), shape: BoxShape.circle)),
            ),
            Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
          ]);
        },
      ),
    );
  }
}

// «Эквалайзер» во время записи
class RecEq extends StatefulWidget {
  final Color color;
  const RecEq({super.key, required this.color});
  @override
  State<RecEq> createState() => _RecEqState();
}

class _RecEqState extends State<RecEq> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 22,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
          for (var k = 0; k < 5; k++)
            Container(
              width: 4,
              height: 6 + 14 * (0.5 + 0.5 * math.sin((_c.value * 2 * math.pi) + k * 1.3)),
              decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
            ),
        ]),
      ),
    );
  }
}
