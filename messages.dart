import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'ad_page.dart';
import 'api.dart';
import 'auth.dart';
import 'models.dart';
import 'profile.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

const kQuick = [
  'Здравствуйте! Ещё актуально?',
  'Когда нужно приступить?',
  'Какая оплата?',
  'Где это находится?',
  'Могу сегодня',
  'Договорились, спасибо!',
];

int _n(dynamic v) => v is num ? v.toInt() : int.tryParse((v ?? '').toString()) ?? 0;

String stamp(int ts) => siteChatStamp(ts, S.i.timeZone);

// ---------- Список диалогов ----------
class MessagesPage extends StatefulWidget {
  // embedded = true: страница живёт во вкладке нижнего меню (без кнопки «назад»)
  final bool embedded;
  const MessagesPage({super.key, this.embedded = false});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<Map<String, dynamic>> list = [];
  bool loading = false;
  bool loaded = false;
  String? err;
  int _tick = -1;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    S.i.addListener(_onState);
    S.i.messagesOpen = !widget.embedded;
    _t = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && _isCurrent && S.i.logged) _load(silent: true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _onState());
  }

  @override
  void dispose() {
    S.i.removeListener(_onState);
    S.i.messagesOpen = false;
    _t?.cancel();
    super.dispose();
  }

  bool get _isCurrent =>
      widget.embedded ? S.i.tab == 4 : (ModalRoute.of(context)?.isCurrent ?? false);

  void _onState() {
    if (!mounted) return;
    if (widget.embedded) S.i.messagesOpen = S.i.tab == 4;
    if (!S.i.logged) {
      if (list.isNotEmpty || loaded) {
        setState(() {
          list = [];
          loaded = false;
        });
      }
      _tick = -1;
      return;
    }
    if (_isCurrent && (S.i.msgTick != _tick || !loaded)) {
      _tick = S.i.msgTick;
      _load();
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        loading = true;
        err = null;
      });
    }
    try {
      final j = await Api.call('dialogs');
      final l = (j['list'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) {
        setState(() {
          list = l;
          loaded = true;
          err = null;
        });
      }
      S.i.refreshUnread();
    } catch (e) {
      final m = S.i.fail(e);
      if (mounted && !silent) setState(() => err = m);
    }
    if (mounted && loading) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S.i,
      builder: (context, _) {
        final p = pal(context);
        return Scaffold(
          appBar: AppBar(title: const Text('Сообщения'), automaticallyImplyLeading: !widget.embedded),
          body: !S.i.logged
              ? const NeedAuth(
                  icon: Icons.chat_bubble_outline,
                  title: 'Ваши сообщения',
                  text: 'Войдите, чтобы переписываться с заказчиками и исполнителями.')
              : RefreshIndicator(
                  color: p.ac,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 6, 16, 20 + (widget.embedded ? navPad(context) : 0)),
                    children: [
                      if (loading && !loaded)
                        Padding(padding: const EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: p.ac))),
                      if (err != null && !loaded)
                        Padding(padding: const EdgeInsets.all(24), child: Text(err!, textAlign: TextAlign.center, style: TextStyle(color: p.mu))),
                      if (loaded && list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text('Диалогов пока нет.\nОткройте объявление и нажмите «Написать».',
                              textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 15)),
                        ),
                      for (final d in list) _item(p, d),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _item(Pal p, Map<String, dynamic> d) {
    final n = _n(d['n']);
    final text = (d['text'] ?? '').toString();
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              pid: (d['pid'] ?? '').toString(),
              name: (d['name'] ?? '').toString(),
              avatar: (d['avatar'] ?? '').toString(),
              ver: d['ver'] == true,
            ),
          ),
        );
        _load(silent: true);
        S.i.refreshUnread();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: cardDeco(p, r: 16),
        child: Row(children: [
          Avatar((d['name'] ?? '').toString(), data: (d['avatar'] ?? '').toString(), size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text((d['name'] ?? '').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.tx)),
                ),
                if (d['ver'] == true) ...[const SizedBox(width: 5), Icon(Icons.verified, size: 16, color: p.ok)],
                const Spacer(),
                Text(siteListTime(_n(d['ts']), S.i.timeZone), style: TextStyle(color: p.mu, fontSize: 11.5)),
              ]),
              const SizedBox(height: 3),
              Text('${d['mine'] == true ? 'Вы: ' : ''}${text.isEmpty ? 'Фото' : text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: n > 0 ? p.tx : p.mu, fontWeight: n > 0 ? FontWeight.w700 : FontWeight.w500, fontSize: 14)),
            ]),
          ),
          if (S.i.isChatMuted((d['pid'] ?? '').toString())) ...[
            const SizedBox(width: 6),
            Icon(Icons.notifications_off_outlined, size: 17, color: p.mu),
          ],
          if (n > 0) ...[
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [p.ac, p.ac2]),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('$n', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ---------- Переписка ----------
class ChatPage extends StatefulWidget {
  final String pid, name, avatar, adId;
  final bool ver;
  const ChatPage({super.key, required this.pid, required this.name, this.avatar = '', this.ver = false, this.adId = ''});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Map<String, dynamic>> msgs = [];
  final _ctl = TextEditingController();
  Timer? _timer;
  bool loaded = false, online = false, typing = false, busy = false, polling = false;
  int seen = 0, lastTs = 0;
  String name = '', avatar = '';
  bool ver = false;
  bool _muted = false;
  String? err;
  DateTime _lastTyping = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    S.i.chatOpen++;
    name = widget.name;
    avatar = widget.avatar;
    ver = widget.ver;
    _muted = S.i.isChatMuted(widget.pid);
    _poll(first: true);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void dispose() {
    S.i.chatOpen--;
    _timer?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _poll({bool first = false}) async {
    if (polling) return;
    polling = true;
    try {
      final j = await Api.call('thread', {
        'with': widget.pid,
        if (!first && lastTs > 0) 'after': lastTs,
      });
      if (!mounted) return;
      final o = j['other'] is Map ? Map<String, dynamic>.from(j['other'] as Map) : <String, dynamic>{};
      final incoming = (j['msgs'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final sts = j['sts'] is Map ? Map<String, dynamic>.from(j['sts'] as Map) : <String, dynamic>{};
      setState(() {
        online = j['on'] == true;
        typing = j['ty'] == true;
        seen = _n(j['seen']);
        if (o.isNotEmpty) {
          name = (o['name'] ?? name).toString();
          ver = o['ver'] == true;
          final av = (o['avatar'] ?? '').toString();
          if (av.isNotEmpty) avatar = av;
        }
        for (final m in incoming) {
          if (!msgs.any((x) => x['id'] == m['id'])) msgs.add(m);
        }
        for (final m in msgs) {
          final id = m['id'].toString();
          if (sts.containsKey(id)) m['st'] = sts[id];
        }
        msgs.sort((a, b) => _n(a['ts']).compareTo(_n(b['ts'])));
        for (final m in msgs) {
          if (!m['id'].toString().startsWith('tmp') && _n(m['ts']) > lastTs) lastTs = _n(m['ts']);
        }
        loaded = true;
        err = null;
      });
    } catch (e) {
      final m = S.i.fail(e);
      if (mounted && !loaded) setState(() => err = m);
    }
    polling = false;
  }

  void _onChanged(String _) {
    final now = DateTime.now();
    if (now.difference(_lastTyping).inSeconds >= 3) {
      _lastTyping = now;
      Api.call('typing', {'with': widget.pid}).then((_) {}, onError: (_) {});
    }
    setState(() {});
  }

  Future<void> _send({List<String> imgs = const []}) async {
    final text = _ctl.text.trim();
    if (text.isEmpty && imgs.isEmpty) return;
    final withAd = widget.adId.isNotEmpty && !msgs.any((x) => x['ad'] == widget.adId);
    final tmp = 'tmp${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      msgs.add({
        'id': tmp,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'mine': true,
        'text': text,
        'st': 'p',
        'img': imgs,
        'ad': '',
        'adt': '',
      });
    });
    _ctl.clear();
    try {
      final j = await Api.call('send', {
        'with': widget.pid,
        'text': text,
        'imgs': imgs,
        if (withAd) 'adId': widget.adId,
      });
      if (!mounted) return;
      final sid = (j['id'] ?? '').toString();
      setState(() {
        msgs.removeWhere((x) => x['id'] == tmp);
        if (!msgs.any((x) => x['id'] == sid)) {
          msgs.add({'id': sid, 'ts': _n(j['ts']), 'mine': true, 'text': text, 'st': '', 'img': imgs, 'ad': withAd ? widget.adId : '', 'adt': ''});
        }
        msgs.sort((a, b) => _n(a['ts']).compareTo(_n(b['ts'])));
      });
    } catch (e) {
      final m = S.i.fail(e);
      if (!mounted) return;
      setState(() => msgs.removeWhere((x) => x['id'] == tmp));
      _ctl.text = text;
      toast(context, m);
    }
  }

  final GlobalKey _barKey = GlobalKey();
  double _barH = 80; // высота плавающей панели ввода: список сообщений уходит под неё

  Future<void> _attach() async {
    final p = pal(context);
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.photo_camera_outlined, color: p.ac),
            title: const Text('Сделать фото'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library_outlined, color: p.ac),
            title: const Text('Выбрать из галереи'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
          const SizedBox(height: 6),
        ]),
      ),
    );
    if (src == null) return;
    try {
      final pk = ImagePicker();
      final List<XFile> xs;
      if (src == ImageSource.camera) {
        final x = await pk.pickImage(source: ImageSource.camera, maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
        xs = x == null ? <XFile>[] : [x];
      } else {
        xs = await pk.pickMultiImage(maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
      }
      if (xs.isEmpty) return;
      setState(() => busy = true);
      final ids = <String>[];
      for (final x in xs.take(5)) {
        final bytes = await x.readAsBytes();
        final d = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        if (d.length > 1800000) throw ApiError('Фото слишком большое. Выберите другое');
        final j = await Api.call('upimg', {'data': d});
        ids.add(j['id'].toString());
      }
      if (mounted) setState(() => busy = false);
      await _send(imgs: ids);
    } catch (e) {
      final m = S.i.fail(e);
      if (mounted) {
        setState(() => busy = false);
        toast(context, m);
      }
    }
  }

  String get _status {
    if (typing) return 'печатает…';
    if (online) return 'в сети';
    if (seen > 0) return 'был(а) ${ago(seen)}';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final rev = msgs.reversed.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final h = _barKey.currentContext?.size?.height;
      if (mounted && h != null && (h - _barH).abs() > 1) setState(() => _barH = h);
    });
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        actions: [
          IconButton(
            tooltip: _muted ? 'Включить уведомления от пользователя' : 'Выключить уведомления от пользователя',
            onPressed: () {
              final next = !_muted;
              setState(() => _muted = next);
              S.i.setChatMuted(widget.pid, name, next);
              toast(context, next ? 'Уведомления от пользователя выключены' : 'Уведомления от пользователя включены');
            },
            icon: Icon(_muted ? Icons.notifications_off_outlined : Icons.notifications_active_outlined, color: _muted ? p.mu : p.ac),
          ),
        ],
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => ProfilePage(pid: widget.pid, name: name))),
          child: Row(children: [
            Avatar(name, data: avatar, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.tx))),
                  if (ver) ...[const SizedBox(width: 5), Icon(Icons.verified, size: 16, color: p.ok)],
                ]),
                if (_status.isNotEmpty)
                  Text(_status, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: (online || typing) ? p.ok : p.mu)),
              ]),
            ),
          ]),
        ),
      ),
      body: Stack(children: [
        Positioned.fill(
          child: !loaded
              ? Center(child: err != null ? Text(err!, style: TextStyle(color: p.mu)) : CircularProgressIndicator(color: p.ac))
              : msgs.isEmpty
                  ? Center(child: Text('Напишите первое сообщение', style: TextStyle(color: p.mu, fontSize: 15)))
                  : ListView.builder(
                      reverse: true,
                      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + _barH),
                      itemCount: rev.length,
                      itemBuilder: (c, i) => _bubble(p, rev[i]),
                    ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(key: _barKey, mainAxisSize: MainAxisSize.min, children: [
            if (S.i.chatQuickSuggestionsEnabled) _quick(p),
            _input(p),
          ]),
        ),
      ]),
    );
  }

  Widget _tick(Pal p, String st) {
    if (st == 'p') return Icon(Icons.schedule, size: 14, color: Colors.white70);
    if (st == '1') return const Icon(Icons.done_all, size: 16, color: Colors.white);
    if (st == 'd') return const Icon(Icons.done_all, size: 16, color: Colors.white60);
    return const Icon(Icons.check, size: 15, color: Colors.white60);
  }

  Widget _bubble(Pal p, Map<String, dynamic> m) {
    final mine = m['mine'] == true;
    final text = (m['text'] ?? '').toString();
    final imgs = m['img'] is List ? (m['img'] as List).map((e) => e.toString()).toList() : <String>[];
    final adt = (m['adt'] ?? '').toString();
    final fg = mine ? Colors.white : p.tx;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          gradient: mine ? LinearGradient(colors: [p.ac, p.ac2]) : null,
          color: mine ? null : p.card,
          border: mine ? null : Border.all(color: p.bd),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 5),
            bottomRight: Radius.circular(mine ? 5 : 18),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (adt.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: (mine ? Colors.white : p.bg2).withOpacity(mine ? .2 : 1), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.link, size: 14, color: fg),
                const SizedBox(width: 4),
                Flexible(child: Text(adt, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: fg, fontWeight: FontWeight.w600))),
              ]),
            ),
          if (imgs.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: text.isEmpty ? 2 : 6),
              child: Wrap(spacing: 4, runSpacing: 4, children: [
                for (var i = 0; i < imgs.length; i++)
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoViewer(ids: imgs, index: i))),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: imgs.length == 1 ? 200 : 96,
                        height: imgs.length == 1 ? 200 : 96,
                        child: CachedNetworkImage(
                          imageUrl: imgUrl(imgs[i], 400),
                          fit: BoxFit.cover,
                          placeholder: (c, u) => Container(color: p.bg2),
                          errorWidget: (c, u, e) => Container(color: p.bg2, child: Icon(Icons.broken_image_outlined, color: p.mu)),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          if (text.isNotEmpty)
            Align(alignment: Alignment.centerLeft, child: Text(text, style: TextStyle(color: fg, fontSize: 15.5, height: 1.3))),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(stamp(_n(m['ts'])), style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : p.mu)),
            if (mine) ...[const SizedBox(width: 4), _tick(p, (m['st'] ?? '').toString())],
          ]),
        ]),
      ),
    );
  }

  Widget _quick(Pal p) {
    return Container(
      color: Colors.transparent,
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: [
          for (final q in kQuick)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  _ctl.text = q;
                  _send();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.bd)),
                  child: Text(q, style: TextStyle(fontSize: 13, color: p.tx, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          GestureDetector(
            onTap: () => S.i.setChatQuickSuggestionsEnabled(false),
            child: Container(width: 32, alignment: Alignment.center,
              decoration: BoxDecoration(color: p.bg2, shape: BoxShape.circle, border: Border.all(color: p.bd)),
              child: Icon(Icons.close_rounded, size: 17, color: p.mu)),
          ),
        ],
      ),
    );
  }

  Widget _input(Pal p) {
    final can = _ctl.text.trim().isNotEmpty;
    // плавающая стеклянная панель: вокруг ничего нет, под ней прокручиваются сообщения
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 5, 5, 5),
              decoration: BoxDecoration(
                color: p.card.withOpacity(.74),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: p.bd),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: busy
                      ? const Padding(padding: EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2.4))
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _attach,
                          child: Icon(Icons.attach_file_rounded, color: p.mu),
                        ),
                ),
                Expanded(
                  child: TextField(contextMenuBuilder: appContextMenu, 
                    controller: _ctl,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 1000,
                    onChanged: _onChanged,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: p.tx),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Сообщение',
                      hintStyle: TextStyle(color: p.mu),
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: can ? _send : null,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [p.ac, p.ac2]), shape: BoxShape.circle),
                    child: Opacity(opacity: can ? 1 : .45, child: const Icon(Icons.send_rounded, color: Colors.white, size: 21)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
