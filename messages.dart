import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ad_page.dart';
import 'api.dart';
import 'auth.dart';
import 'models.dart';
import 'review.dart';
import 'profile.dart';
import 'state.dart';
import 'skeleton.dart';
import 'theme.dart';
import 'util.dart';
import 'voice.dart';
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

final _cardRe = RegExp(r'(?:\d[ -]?){13,19}');

// Опасное в переписке: просьба о предоплате, коды из СМС, данные карты, чужие ссылки
String? chatRisk(String text) {
  final t = text.toLowerCase();
  if (_cardRe.hasMatch(t) || t.contains('cvv') || t.contains('cvc') || t.contains('код из смс') || t.contains('код из sms') || t.contains('код подтверждения')) {
    return 'Не называйте коды из СМС и данные карты: так действуют мошенники.';
  }
  if (t.contains('предоплат') || t.contains('перевед') || t.contains('переведи') || t.contains('на карту') || t.contains('залог')) {
    return 'Просят деньги вперёд? Не переводите предоплату незнакомым, платите после работы.';
  }
  if (RegExp(r'https?://|t\.me/|bit\.ly').hasMatch(t) && !t.contains('mchipta.github.io')) {
    return 'Осторожно со ссылками: не вводите по ним данные карты и пароли.';
  }
  return null;
}

// То, что нельзя отправлять самому: номер карты и коды
bool chatRiskOut(String text) {
  final t = text.toLowerCase();
  return _cardRe.hasMatch(t) || t.contains('cvv') || t.contains('cvc') || t.contains('код из смс') || t.contains('код из sms') || t.contains('код подтверждения');
}

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
  String _folder = 'all'; // all · unread · cust · exec · arch
  Set<String> _pins = {}, _arch = {}; // закреплённые и архивные чаты (хранятся на устройстве)
  String? err;
  int _tick = -1;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    S.i.addListener(_onState);
    S.i.messagesOpen = !widget.embedded;
    final pr = S.i.prefs;
    _pins = (pr.getStringList('chat_pins') ?? const <String>[]).toSet();
    _arch = (pr.getStringList('chat_arch') ?? const <String>[]).toSet();
    // список открывается сразу из памяти устройства, а свежий подтягивается следом
    final cache = pr.getString('dlg_cache');
    if (cache != null && S.i.logged) {
      try {
        list = (jsonDecode(cache) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        loaded = list.isNotEmpty;
      } catch (_) {}
    }
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
      S.i.prefs.setString('dlg_cache', jsonEncode(l.take(60).toList()));
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
          appBar: AppBar(
            title: const Text('Сообщения'),
            automaticallyImplyLeading: !widget.embedded,
            actions: S.i.logged
                ? [
                    IconButton(
                      tooltip: 'Поиск по сообщениям',
                      icon: Icon(Icons.search_rounded, color: p.ac),
                      onPressed: () {
                        haptic();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MsgSearchPage()));
                      },
                    ),
                  ]
                : null,
          ),
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
                        Skeleton(child: Column(children: List.generate(6, (_) => const DialogSkeleton()))),
                      if (err != null && !loaded)
                        Padding(padding: const EdgeInsets.all(24), child: Text(err!, textAlign: TextAlign.center, style: TextStyle(color: p.mu))),
                      if (loaded && list.isNotEmpty)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(children: [
                            for (final f in const [['all', 'Все'], ['unread', 'Непрочитанные'], ['cust', 'Я заказчик'], ['exec', 'Я исполнитель']]) ...[
                              _filterChip(p, f[1], _folder == f[0], () => setState(() => _folder = f[0])),
                              const SizedBox(width: 8),
                            ],
                            if (_arch.isNotEmpty) _filterChip(p, 'Архив · ${_arch.length}', _folder == 'arch', () => setState(() => _folder = 'arch')),
                          ]),
                        ),
                      if (loaded && list.isEmpty)
                        EmptyState(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Диалогов пока нет',
                          text: 'Откройте объявление и нажмите «Написать» — переписка появится здесь.',
                          button: 'Найти объявление',
                          onTap: () => S.i.goTab(1)),
                      if (loaded && list.isNotEmpty && _shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(_folder == 'unread' ? 'Непрочитанных сообщений нет' : _folder == 'arch' ? 'Архив пуст' : 'В этой папке пока ничего нет',
                              textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 15)),
                        ),
                      for (final d in _shown) _dismiss(p, d),
                    ],
                  ),
                ),
        );
      },
    );
  }

  String _k(Map<String, dynamic> d) => '${d['pid']}|${d['ad']}';

  // Архивный чат возвращается в общий список, как только в нём появляется новое сообщение
  bool _isArch(Map<String, dynamic> d) => _arch.contains(_k(d)) && _n(d['n']) == 0;

  List<Map<String, dynamic>> get _shown {
    final l = list.where((d) {
      switch (_folder) {
        case 'unread':
          return !_isArch(d) && _n(d['n']) > 0;
        case 'cust':
          return !_isArch(d) && d['own'] == true;
        case 'exec':
          return !_isArch(d) && d['own'] != true && (d['ad'] ?? '').toString().isNotEmpty;
        case 'arch':
          return _isArch(d);
        default:
          return !_isArch(d);
      }
    }).toList();
    return [...l.where((d) => _pins.contains(_k(d))), ...l.where((d) => !_pins.contains(_k(d)))];
  }

  void _togglePin(Map<String, dynamic> d) {
    setState(() => _pins.contains(_k(d)) ? _pins.remove(_k(d)) : _pins.add(_k(d)));
    S.i.prefs.setStringList('chat_pins', _pins.toList());
  }

  void _toggleArch(Map<String, dynamic> d) {
    setState(() {
      _arch.contains(_k(d)) ? _arch.remove(_k(d)) : _arch.add(_k(d));
      if (_arch.isEmpty && _folder == 'arch') _folder = 'all';
    });
    S.i.prefs.setStringList('chat_arch', _arch.toList());
  }

  // Долгое нажатие на чат: закрепить, в архив, удалить
  Future<void> _chatMenu(Map<String, dynamic> d) async {
    haptic();
    final p = pal(context);
    final pinned = _pins.contains(_k(d)), arch = _arch.contains(_k(d));
    final act = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        padding: EdgeInsets.fromLTRB(8, 10, 8, 10 + MediaQuery.of(c).viewPadding.bottom),
        decoration: BoxDecoration(color: p.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 42, height: 4, margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: p.bd, borderRadius: BorderRadius.circular(4))),
          ListTile(leading: Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, color: p.tx), title: Text(pinned ? 'Открепить' : 'Закрепить'), onTap: () => Navigator.pop(c, 'pin')),
          ListTile(leading: Icon(arch ? Icons.unarchive_outlined : Icons.archive_outlined, color: p.tx), title: Text(arch ? 'Вернуть из архива' : 'В архив'), onTap: () => Navigator.pop(c, 'arch')),
          ListTile(leading: Icon(Icons.delete_outline_rounded, color: p.dng), title: Text('Удалить переписку', style: TextStyle(color: p.dng)), onTap: () => Navigator.pop(c, 'del')),
        ]),
      ),
    );
    if (!mounted || act == null) return;
    if (act == 'pin') _togglePin(d);
    if (act == 'arch') _toggleArch(d);
    if (act == 'del') {
      final pid = (d['pid'] ?? '').toString(), ad = (d['ad'] ?? '').toString();
      if (await _delChat(context, pid, (d['name'] ?? '').toString(), ad: ad) && mounted) {
        setState(() => list.removeWhere((x) => _k(x) == _k(d)));
        S.i.refreshUnread();
      }
    }
  }

  Widget _filterChip(Pal p, String label, bool on, VoidCallback f) => Tap(
        onTap: () {
          haptic();
          f();
        },
        scale: .96,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(color: on ? p.tx : p.bg2, borderRadius: BorderRadius.circular(14)),
          child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: on ? p.bg : p.tx)),
        ),
      );

  // Свайп влево удаляет переписку (только у вас)
  Widget _dismiss(Pal p, Map<String, dynamic> d) {
    final pid = (d['pid'] ?? '').toString(), ad = (d['ad'] ?? '').toString();
    return Dismissible(
      key: ValueKey('dlg-$pid-$ad'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          haptic();
          _toggleArch(d);
          return false;
        }
        return _delChat(context, pid, (d['name'] ?? '').toString(), ad: ad);
      },
      onDismissed: (_) {
        setState(() => list.removeWhere((x) => (x['pid'] ?? '').toString() == pid && (x['ad'] ?? '').toString() == ad));
        S.i.refreshUnread();
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(left: 24),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: p.ac, borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_arch.contains(_k(d)) ? Icons.unarchive_outlined : Icons.archive_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(_arch.contains(_k(d)) ? 'Вернуть' : 'В архив', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(color: p.dng, borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Text('Удалить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
      ),
      child: _item(p, d),
    );
  }

  // Объявление в списке диалогов: компактная «таблетка» с фото и ценой (как на сайте)
  Widget _adChip(Pal p, Map<String, dynamic> d) {
    final gone = d['adg'] == true;
    final title = (d['adt'] ?? '').toString();
    final noAd = !gone && title.isEmpty && (d['ad'] ?? '').toString().isEmpty;
    final muted = gone || noAd;
    final pay = muted ? '' : payF((d['adp'] ?? '').toString());
    final img = (d['adi'] ?? '').toString();
    final cat = (d['adc'] ?? '').toString();
    final label = gone ? 'Объявление удалено' : (noAd ? 'Без объявления' : (title.isEmpty ? 'Объявление' : title));
    Widget thumb;
    if (img.isNotEmpty && !muted) {
      thumb = CachedNetworkImage(
        imageUrl: imgUrl(img, 80),
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: p.card),
        errorWidget: (_, __, ___) => Icon(cat.isEmpty ? Icons.sell_outlined : catIcon(cat), size: 12, color: p.ac),
      );
    } else {
      thumb = Icon(muted || cat.isEmpty ? Icons.sell_outlined : catIcon(cat), size: 12, color: muted ? p.mu : p.ac);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
          decoration: BoxDecoration(
            color: muted ? p.bg2 : Color.alphaBlend(p.ac.withOpacity(.09), p.bg2),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: muted ? p.bd : Color.alphaBlend(p.ac.withOpacity(.18), p.bd)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 22,
              height: 22,
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.card, shape: BoxShape.circle),
              child: thumb,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted ? p.mu : p.tx, fontSize: 12.5, fontWeight: muted ? FontWeight.w500 : FontWeight.w600)),
            ),
            if (pay.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(pay, maxLines: 1, style: TextStyle(color: p.tx, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _item(Pal p, Map<String, dynamic> d) {
    final n = _n(d['n']);
    final text = (d['text'] ?? '').toString();
    final draft = (S.i.prefs.getString('draft_${d['pid']}_${d['ad']}') ?? '').trim();
    return GestureDetector(
      onLongPress: () => _chatMenu(d),
      onTap: () async {
        haptic();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              pid: (d['pid'] ?? '').toString(),
              name: (d['name'] ?? '').toString(),
              avatar: (d['avatar'] ?? '').toString(),
              ver: d['ver'] == true,
              adId: (d['ad'] ?? '').toString(),
            ),
          ),
        );
        _load(silent: true);
        S.i.refreshUnread();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: cardDeco(p, r: 16),
        child: Row(children: [
          Avatar((d['name'] ?? '').toString(), data: (d['avatar'] ?? '').toString(), size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                // имя занимает всё свободное место, поэтому дата всегда прижата к правому краю
                Expanded(
                  child: Row(children: [
                    Flexible(
                      child: Text((d['name'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.tx)),
                    ),
                    if (d['ver'] == true) ...[const SizedBox(width: 5), Icon(Icons.verified, size: 16, color: p.ok)],
                  ]),
                ),
                const SizedBox(width: 8),
                if (_pins.contains(_k(d))) ...[Icon(Icons.push_pin_rounded, size: 14, color: p.mu), const SizedBox(width: 4)],
                Text(siteListTime(_n(d['ts']), S.i.timeZone), style: TextStyle(color: p.mu, fontSize: 11.5)),
              ]),
              const SizedBox(height: 2),
              _adChip(p, d),
              const SizedBox(height: 2),
              draft.isNotEmpty
                  ? Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Черновик: ', style: TextStyle(color: p.dng, fontWeight: FontWeight.w700)),
                        TextSpan(text: draft),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.mu, fontSize: 14))
                  : Text('${d['mine'] == true ? 'Вы: ' : ''}${text.isEmpty ? 'Фото' : text}',
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

// Удаление переписки только у себя: подтверждение и запрос на сервер
Future<bool> _delChat(BuildContext context, String pid, String name, {String ad = ''}) async {
  final p = pal(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: p.card,
      title: Text('Удалить переписку?', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800)),
      content: Text(
        'Переписка с ${name.isEmpty ? 'пользователем' : name}${ad.isEmpty ? '' : ' по этому объявлению'} исчезнет только у вас, у собеседника она останется.',
        style: TextStyle(color: p.mu, height: 1.35),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Отмена', style: TextStyle(color: p.mu))),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Удалить', style: TextStyle(color: p.dng, fontWeight: FontWeight.w800))),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await Api.call('delChat', {'with': pid, if (ad.isNotEmpty) 'ad': ad});
    return true;
  } catch (e) {
    if (context.mounted) toast(context, S.i.fail(e), err: true);
    return false;
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
  final FocusNode _fn = FocusNode();
  String? _editId; // id сообщения, которое сейчас редактируется
  Timer? _timer;
  bool loaded = false, online = false, typing = false, busy = false, polling = false;
  int seen = 0, lastTs = 0;
  String name = '', avatar = '';
  bool ver = false;
  bool _muted = false;
  bool _emoji = false;
  bool _chipsOff = false;
  bool _safeOff = false;
  bool _rec = false;
  int _recMs = 0;
  DateTime? _recAt;
  Timer? _recT;
  String? err;
  Map<String, dynamic>? adCard; // карточка объявления, по которому идёт диалог
  Map<String, dynamic>? rv; // можно ли оценить собеседника (после выполненной работы) и какую оценку уже поставили
  Map<String, dynamic>? _reply; // сообщение, на которое отвечаем
  String deal = ''; // статус отклика по этому объявлению: '' · new · chosen · done · rejected
  Map<String, dynamic>? choice; // выбор исполнителя (только у автора объявления): st — none/new/chosen/done, rid — id отклика
  DateTime _lastTyping = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _chipsOff = S.i.chipsHidden(widget.pid);
    _safeOff = S.i.safeHidden(widget.pid);
    S.i.chatOpen++;
    name = widget.name;
    avatar = widget.avatar;
    ver = widget.ver;
    _muted = S.i.isChatMuted(widget.pid);
    _ctl.text = S.i.prefs.getString(_draftKey) ?? '';
    _poll(first: true);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void dispose() {
    S.i.chatOpen--;
    _timer?.cancel();
    _recT?.cancel();
    if (_rec) Voice.cancel();
    VoicePlayer.i.stop();
    _ctl.dispose();
    _fn.dispose();
    super.dispose();
  }

  String get _draftKey => 'draft_${widget.pid}_${widget.adId}';

  Future<void> _poll({bool first = false}) async {
    if (polling) return;
    polling = true;
    try {
      final j = await Api.call('thread', {
        'with': widget.pid,
        if (widget.adId.isNotEmpty) 'ad': widget.adId,
        if (!first && lastTs > 0) 'after': lastTs,
      });
      if (!mounted) return;
      final o = j['other'] is Map ? Map<String, dynamic>.from(j['other'] as Map) : <String, dynamic>{};
      final incoming = (j['msgs'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final sts = j['sts'] is Map ? Map<String, dynamic>.from(j['sts'] as Map) : <String, dynamic>{};
      final chg = j['chg'] is Map ? Map<String, dynamic>.from(j['chg'] as Map) : <String, dynamic>{};
      var lostEdit = false;
      setState(() {
        online = j['on'] == true;
        typing = j['ty'] == true;
        seen = _n(j['seen']);
        if (j['ad'] is Map) adCard = Map<String, dynamic>.from(j['ad'] as Map);
        if (j.containsKey('choice')) choice = j['choice'] is Map ? Map<String, dynamic>.from(j['choice'] as Map) : null;
        if (j['rv'] is Map) rv = Map<String, dynamic>.from(j['rv'] as Map);
        if (j['deal'] != null) deal = j['deal'].toString();
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
        // изменённые и удалённые сообщения (в том числе у собеседника)
        for (final e in chg.entries) {
          final i = msgs.indexWhere((x) => x['id'].toString() == e.key);
          if (i < 0 || e.value is! Map) continue;
          final c = Map<String, dynamic>.from(e.value as Map);
          final m = msgs[i];
          if (c['g'] != null) {
            if (m['gone'] != true) {
              _wipe(m);
              if (_editId == e.key) {
                _editId = null;
                _ctl.clear();
                lostEdit = true;
              }
            }
          } else if (_n(c['ed']) != _n(m['ed'])) {
            m['text'] = (c['t'] ?? '').toString();
            m['ed'] = _n(c['ed']);
          }
          if (c['g'] == null && c['rx'] is Map) m['rx'] = Map<String, dynamic>.from(c['rx'] as Map);
        }
        msgs.sort((a, b) => _n(a['ts']).compareTo(_n(b['ts'])));
        for (final m in msgs) {
          if (!m['id'].toString().startsWith('tmp') && _n(m['ts']) > lastTs) lastTs = _n(m['ts']);
        }
        loaded = true;
        err = null;
      });
      if (lostEdit && mounted) toast(context, 'Собеседник удалил это сообщение', err: true);
    } catch (e) {
      final m = S.i.fail(e);
      if (mounted && !loaded) setState(() => err = m);
    }
    polling = false;
  }

  void _onChanged(String _) {
    final now = DateTime.now();
    if (_editId == null && now.difference(_lastTyping).inSeconds >= 3) {
      _lastTyping = now;
      Api.call('typing', {'with': widget.pid}).then((_) {}, onError: (_) {});
    }
    // недописанное сообщение запоминаем: оно останется в чате и покажется в списке диалогов
    if (_editId == null) {
      final t = _ctl.text.trim();
      t.isEmpty ? S.i.prefs.remove(_draftKey) : S.i.prefs.setString(_draftKey, _ctl.text);
    }
    setState(() {});
  }

  Future<void> _send({List<String> imgs = const []}) async {
    if (_editId != null && imgs.isEmpty) return _saveEdit();
    final text = _ctl.text.trim();
    if (text.isEmpty && imgs.isEmpty) return;
    if (text.isNotEmpty && chatRiskOut(text)) {
      final p = pal(context);
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: p.card,
          title: Text('Это безопасно отправлять?', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800)),
          content: Text('В сообщении похоже на номер карты или код из СМС. Такие данные нельзя передавать никому: так действуют мошенники.', style: TextStyle(color: p.mu, height: 1.35)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Не отправлять', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800))),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Всё равно отправить', style: TextStyle(color: p.mu))),
          ],
        ),
      );
      if (go != true) return;
    }
    final tmp = 'tmp${DateTime.now().microsecondsSinceEpoch}';
    final rpl = _reply;
    setState(() {
      msgs.add({
        'id': tmp,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'mine': true,
        'text': text,
        'st': 'p',
        'img': imgs,
        'ad': widget.adId,
        'adt': '',
        if (rpl != null) 'rp': {'id': rpl['id'], 'mine': rpl['mine'] == true, 't': _replyText(rpl)},
      });
      _reply = null;
    });
    _ctl.clear();
    S.i.prefs.remove(_draftKey);
    try {
      final j = await Api.call('send', {
        'with': widget.pid,
        'text': text,
        'imgs': imgs,
        'defer': 1,
        if (rpl != null) 'reply': rpl['id'],
        if (widget.adId.isNotEmpty) 'adId': widget.adId,
      });
      final sid = (j['id'] ?? '').toString();
      Api.call('notify', {'id': sid}).then((_) {}, onError: (_) {}); // push собеседнику уходит отдельно, отправитель не ждёт
      if (!mounted) return;
      setState(() {
        msgs.removeWhere((x) => x['id'] == tmp);
        if (!msgs.any((x) => x['id'] == sid)) {
          msgs.add({'id': sid, 'ts': _n(j['ts']), 'mine': true, 'text': text, 'st': '', 'img': imgs, 'ad': widget.adId, 'adt': ''});
        }
        msgs.sort((a, b) => _n(a['ts']).compareTo(_n(b['ts'])));
      });
    } catch (e) {
      final m = S.i.fail(e);
      if (!mounted) return;
      setState(() => msgs.removeWhere((x) => x['id'] == tmp));
      _ctl.text = text;
      toast(context, m, err: true);
    }
  }

  // ---------- Изменить / удалить сообщение (как в Telegram) ----------
  void _wipe(Map<String, dynamic> m) {
    m['gone'] = true;
    m['text'] = '';
    m['img'] = <dynamic>[];
    m['aud'] = '';
    m['ed'] = 0;
  }

  Future<void> _msgMenu(Map<String, dynamic> m, Offset pos) async {
    if (m['gone'] == true || m['id'].toString().startsWith('tmp')) return;
    final mine = m['mine'] == true;
    final text = (m['text'] ?? '').toString();
    final aud = (m['aud'] ?? '').toString();
    final p = pal(context);
    Widget row(IconData ic, String t, Color c) => Row(children: [
          Icon(ic, size: 20, color: c),
          const SizedBox(width: 12),
          Text(t, style: TextStyle(fontWeight: FontWeight.w600, color: c)),
        ]);
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        enabled: false,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final e in const ['👍', '❤️', '😂', '😮', '🙏', '✅'])
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context, 'rx:$e'),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: Text(e, style: const TextStyle(fontSize: 24))),
            ),
        ]),
      ),
      PopupMenuItem(value: 'reply', child: row(Icons.reply_rounded, 'Ответить', p.tx)),
      if (text.isNotEmpty) PopupMenuItem(value: 'copy', child: row(Icons.copy_rounded, 'Копировать', p.tx)),
      if (mine && aud.isEmpty) PopupMenuItem(value: 'edit', child: row(Icons.edit_outlined, 'Изменить', p.tx)),
      if (mine) PopupMenuItem(value: 'del', child: row(Icons.delete_outline_rounded, 'Удалить', p.dng)),
    ];
    if (items.isEmpty) return;
    final size = MediaQuery.of(context).size;
    final act = await showMenu<String>(
      context: context,
      color: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, size.width - pos.dx, size.height - pos.dy),
      items: items,
    );
    if (!mounted || act == null) return;
    if (act.startsWith('rx:')) {
      await _react(m, act.substring(3));
    } else if (act == 'reply') {
      setState(() {
        _reply = m;
        _editId = null;
      });
      _fn.requestFocus();
    } else if (act == 'copy') {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) toast(context, 'Скопировано');
    } else if (act == 'edit') {
      _startEdit(m);
    } else if (act == 'del') {
      await _delMsg(m);
    }
  }

  String _replyText(Map<String, dynamic> m) {
    if (m['gone'] == true) return 'Сообщение удалено';
    final t = (m['text'] ?? '').toString();
    if (t.isNotEmpty) return t.length > 90 ? t.substring(0, 90) : t;
    if (m['img'] is List && (m['img'] as List).isNotEmpty) return 'Фото';
    if ((m['aud'] ?? '').toString().isNotEmpty) return 'Голосовое сообщение';
    return '';
  }

  // Реакция: ставим сразу, на сервере сохраняем следом; повторная такая же снимает
  Future<void> _react(Map<String, dynamic> m, String e) async {
    final old = m['rx'] is Map ? Map<String, dynamic>.from(m['rx'] as Map) : <String, dynamic>{'me': '', 'th': ''};
    final cur = (old['me'] ?? '').toString();
    final next = cur == e ? '' : e;
    setState(() => m['rx'] = {'me': next, 'th': (old['th'] ?? '').toString()});
    try {
      await Api.call('react', {'id': m['id'], 'e': next});
    } catch (err) {
      if (!mounted) return;
      setState(() => m['rx'] = old);
      toast(context, S.i.fail(err), err: true);
    }
  }

  void _startEdit(Map<String, dynamic> m) {
    setState(() {
      _reply = null;
      _editId = m['id'].toString();
      _emoji = false;
    });
    _ctl.text = (m['text'] ?? '').toString();
    _ctl.selection = TextSelection.collapsed(offset: _ctl.text.length);
    _fn.requestFocus();
  }

  void _cancelEdit() {
    setState(() => _editId = null);
    _ctl.clear();
  }

  Future<void> _saveEdit() async {
    final id = _editId;
    if (id == null) return;
    final i = msgs.indexWhere((x) => x['id'].toString() == id);
    if (i < 0) {
      _cancelEdit();
      return;
    }
    final m = msgs[i];
    final text = _ctl.text.trim();
    final hasImg = m['img'] is List && (m['img'] as List).isNotEmpty;
    if (m['gone'] == true) {
      _cancelEdit();
      toast(context, 'Сообщение уже удалено', err: true);
      return;
    }
    if (text.isEmpty && !hasImg) {
      toast(context, 'Введите текст сообщения', err: true);
      return;
    }
    if (text == (m['text'] ?? '').toString()) {
      _cancelEdit();
      return;
    }
    setState(() => busy = true);
    try {
      final j = await Api.call('editMsg', {'id': id, 'text': text});
      if (!mounted) return;
      setState(() {
        m['text'] = (j['text'] ?? text).toString();
        m['ed'] = _n(j['ed']) > 0 ? _n(j['ed']) : DateTime.now().millisecondsSinceEpoch;
        _editId = null;
        busy = false;
      });
      _ctl.clear();
    } catch (e) {
      final msg = S.i.fail(e);
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, msg, err: true);
    }
  }

  Future<void> _delMsg(Map<String, dynamic> m) async {
    final p = pal(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: p.card,
        title: Text('Удалить сообщение?', style: TextStyle(color: p.tx, fontWeight: FontWeight.w800)),
        content: Text(
          'Сообщение исчезнет и у вас, и у собеседника: вместо него останется надпись «Сообщение удалено».',
          style: TextStyle(color: p.mu, height: 1.35),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Отмена', style: TextStyle(color: p.mu))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Удалить', style: TextStyle(color: p.dng, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final id = m['id'].toString();
    try {
      await Api.call('delMsg', {'id': id});
      if (!mounted) return;
      setState(() {
        _wipe(m);
        if (_editId == id) {
          _editId = null;
          _ctl.clear();
        }
      });
      toast(context, 'Сообщение удалено');
    } catch (e) {
      final msg = S.i.fail(e);
      if (mounted) toast(context, msg, err: true);
    }
  }

  Widget _editBar(Pal p) {
    final i = msgs.indexWhere((x) => x['id'].toString() == _editId);
    final t = i < 0 ? '' : (msgs[i]['text'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: p.card.withOpacity(.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.bd),
        ),
        child: Row(children: [
          Icon(Icons.edit_outlined, size: 20, color: p.ac),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Редактирование', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800, fontSize: 13)),
              Text(t.isEmpty ? 'Фото' : t, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontSize: 13.5)),
            ]),
          ),
          IconButton(onPressed: _cancelEdit, icon: Icon(Icons.close_rounded, color: p.mu), tooltip: 'Отменить'),
        ]),
      ),
    );
  }

  final GlobalKey _barKey = GlobalKey();
  double _barH = 80; // высота плавающей панели ввода: список сообщений уходит под неё

  void _addEmoji(String e) {
    final text = _ctl.text;
    final sel = _ctl.selection;
    final s = sel.isValid && sel.start >= 0 ? sel.start : text.length;
    final en = sel.isValid && sel.end >= 0 ? sel.end : text.length;
    _ctl.value = TextEditingValue(
      text: text.replaceRange(s, en, e),
      selection: TextSelection.collapsed(offset: s + e.length),
    );
    _onChanged(_ctl.text);
  }

  Widget _emojiPanel(Pal p) => Container(
        height: 236,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: p.bd)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: GridView.count(
            crossAxisCount: 8,
            padding: const EdgeInsets.all(8),
            children: [
              for (final e in kEmoji)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () { haptic(); _addEmoji(e); },
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 26))),
                ),
            ],
          ),
        ),
      );

  Future<void> _startVoice() async {
    if (_rec || busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await VoicePlayer.i.stop();
    final r = await Voice.start();
    if (!mounted) return;
    if (r == 'denied') {
      toast(context, 'Разрешите доступ к микрофону в настройках телефона');
      return;
    }
    if (r != 'ok') {
      toast(context, 'Не удалось начать запись');
      return;
    }
    _recAt = DateTime.now();
    setState(() {
      _rec = true;
      _emoji = false;
      _recMs = 0;
    });
    _recT?.cancel();
    _recT = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || !_rec) return;
      final ms = DateTime.now().difference(_recAt!).inMilliseconds;
      setState(() => _recMs = ms);
      if (ms >= 120000) _finishVoice(true);
    });
  }

  Future<void> _finishVoice(bool send) async {
    if (!_rec) return;
    _recT?.cancel();
    setState(() => _rec = false);
    if (!send) {
      await Voice.cancel();
      return;
    }
    final r = await Voice.stop();
    if (!mounted) return;
    final ms = (r?['ms'] as num?)?.toInt() ?? 0;
    final path = (r?['path'] ?? '').toString();
    if (r == null || path.isEmpty || ms < 700) {
      if (path.isNotEmpty) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
      toast(context, 'Слишком короткое сообщение');
      return;
    }
    await _sendVoice(path, (ms / 1000).round().clamp(1, 180));
  }

  Future<void> _sendVoice(String path, int dur) async {
    setState(() => busy = true);
    try {
      final bytes = await File(path).readAsBytes();
      final up = await Api.call('upaud', {'data': base64Encode(bytes), 'mime': 'audio/mp4', 'dur': dur});
      final id = (up['id'] ?? '').toString();
      final j = await Api.call('send', {
        'with': widget.pid,
        'text': '',
        'imgs': <String>[],
        'aud': {'id': id, 'dur': dur},
        'defer': 1,
        if (widget.adId.isNotEmpty) 'adId': widget.adId,
      });
      VoicePlayer.i.cache[id] = path;
      final sid = (j['id'] ?? '').toString();
      Api.call('notify', {'id': sid}).then((_) {}, onError: (_) {});
      if (!mounted) return;
      setState(() {
        if (!msgs.any((x) => x['id'] == sid)) {
          msgs.add({'id': sid, 'ts': _n(j['ts']), 'mine': true, 'text': '', 'st': '', 'img': <String>[], 'aud': '$id|$dur', 'ad': widget.adId, 'adt': ''});
        }
        msgs.sort((a, b) => _n(a['ts']).compareTo(_n(b['ts'])));
      });
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e), err: true);
    }
    if (mounted) setState(() => busy = false);
  }

  Widget _recRow(Pal p) => Row(key: const ValueKey('rec'), children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _finishVoice(false),
          child: SizedBox(width: 44, height: 44, child: Icon(Icons.delete_outline_rounded, color: p.dng)),
        ),
        const SizedBox(width: 2),
        RecDot(color: p.dng),
        const SizedBox(width: 8),
        Text(voiceTime(_recMs), style: TextStyle(color: p.tx, fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(width: 12),
        RecEq(color: p.ac),
        const SizedBox(width: 8),
        Expanded(child: Text('Идёт запись…', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontSize: 13))),
        GestureDetector(
          onTap: () => _finishVoice(true),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [p.ac, p.ac2]), shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 21),
          ),
        ),
      ]);

  Future<void> _attach() async {
    final p = pal(context);
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
        toast(context, m, err: true);
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
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'block') {
                await toggleUserBlock(context, pid: widget.pid, name: name);
              }
              if (v == 'del') {
                if (await _delChat(context, widget.pid, name, ad: widget.adId) && mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (c) => [
              PopupMenuItem(
                value: 'block',
                child: menuRow(c, Icons.visibility_off_outlined, S.i.isBlocked(widget.pid) ? 'Разблокировать' : 'Заблокировать'),
              ),
              PopupMenuItem(value: 'del', child: menuRow(c, Icons.delete_outline_rounded, 'Удалить переписку')),
            ],
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
      body: Column(children: [
        if (adCard != null) _adHeader(p),
        if (adCard != null && widget.adId.isNotEmpty && deal != 'rejected' && (choice != null || deal.isNotEmpty)) _dealCard(p),
        if (!_safeOff) _safeBanner(p),
        Expanded(child: Stack(children: [
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
            if (S.i.chatQuickSuggestionsEnabled && !_chipsOff && _editId == null) _quick(p),
            if (_editId != null) _editBar(p),
            if (_reply != null) _replyStrip(p),
            _input(p),
            if (_emoji) _emojiPanel(p),
          ]),
        ),
      ])),
      ]),
    );
  }

  Widget _tick(Pal p, String st) {
    if (st == 'p') return Icon(Icons.schedule, size: 14, color: Colors.white70);
    if (st == '1') return const Icon(Icons.done_all, size: 16, color: Colors.white);
    if (st == 'd') return const Icon(Icons.done_all, size: 16, color: Colors.white60);
    return const Icon(Icons.check, size: 15, color: Colors.white60);
  }

  void _openAd() {
    final c = adCard;
    if (c == null || c['gone'] == true) return;
    final id = (c['id'] ?? '').toString();
    Ad? found;
    for (final a in S.i.ads) {
      if (a.id == id) found = a;
    }
    if (found == null && c['full'] is Map) found = Ad.fromJson(Map<String, dynamic>.from(c['full'] as Map));
    final target = found;
    if (target != null) Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: target)));
  }

  // «Выбрать исполнителем» прямо в чате; потом — «Работа выполнена» (после неё можно оставить отзыв)
  Future<void> _choose() async {
    haptic();
    try {
      final r = await Api.call('chooseChat', {'ad': widget.adId, 'pid': widget.pid});
      if (mounted) {
        setState(() => choice = {'can': true, 'st': r['st'] ?? 'chosen', 'rid': r['rid'] ?? ''});
        toast(context, 'Исполнитель выбран. Ему отправлено уведомление');
        S.i.bumpCab();
      }
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e), err: true);
    }
  }

  // Окно «Оцените работу»
  Future<void> _rate() async {
    final r = await showReviewSheet(context, pid: widget.pid, name: name);
    if (r > 0 && mounted) setState(() => rv = {'can': true, 'mine': r});
  }

  Future<void> _finish() async {
    haptic();
    try {
      await Api.call('fin', {'rid': choice!['rid']});
      if (mounted) {
        setState(() {
          choice = {...choice!, 'st': 'done'};
          rv = {'can': true, 'mine': (rv?['mine'] as num?)?.toInt() ?? 0};
        });
        toast(context, 'Работа отмечена выполненной');
        S.i.bumpCab();
        _rate(); // сразу предлагаем оценить работу
      }
    } catch (e) {
      if (mounted) toast(context, S.i.fail(e), err: true);
    }
  }

  // Сделка по шагам: Обсуждаем → Исполнитель выбран → Выполнено → Отзыв. Справа от шагов одно действие.
  Widget _dealCard(Pal p) {
    final st = (choice?['st'] ?? '').toString();
    final isDone = deal == 'done' || st == 'done';
    final isChosen = isDone || deal == 'chosen' || st == 'chosen';
    final mine = (rv?['mine'] as num?)?.toInt() ?? 0;
    final reached = [true, isChosen, isDone, mine > 0];
    final cur = reached.indexOf(false); // первый ещё не пройденный шаг; -1 — всё пройдено
    const labels = ['Обсуждаем', 'Исполнитель', 'Выполнено', 'Отзыв'];
    final owner = choice != null && choice!['can'] == true;
    String? act;
    VoidCallback? f;
    if (owner && !isChosen) {
      act = 'Выбрать исполнителем';
      f = _choose;
    } else if (owner && isChosen && !isDone) {
      act = 'Работа выполнена';
      f = _finish;
    } else if (isDone) {
      act = mine > 0 ? 'Изменить отзыв' : 'Оценить работу';
      f = _rate;
    }

    Widget step(int i) {
      final on = reached[i], now = i == cur;
      final line = (bool filled) => Expanded(child: Container(height: 2, color: filled ? p.ac : p.bd));
      return Expanded(
        child: Column(children: [
          Row(children: [
            i == 0 ? const Expanded(child: SizedBox()) : line(reached[i]),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                gradient: on ? LinearGradient(colors: [p.ac, p.ac2]) : null,
                shape: BoxShape.circle,
                border: on ? null : Border.all(color: now ? p.ac : p.bd, width: now ? 2 : 1.4),
              ),
              child: on ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : (now ? Center(child: Container(width: 7, height: 7, decoration: BoxDecoration(color: p.ac, shape: BoxShape.circle))) : null),
            ),
            i == 3 ? const Expanded(child: SizedBox()) : line(reached[i + 1]),
          ]),
          const SizedBox(height: 4),
          Text(labels[i], maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: now || on ? FontWeight.w800 : FontWeight.w600, color: now ? p.ac : (on ? p.tx : p.mu))),
        ]),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: p.bg2, border: Border(bottom: BorderSide(color: p.bd))),
      child: Column(children: [
        Row(children: [for (var i = 0; i < 4; i++) step(i)]),
        if (act != null) ...[
          const SizedBox(height: 8),
          Tap(
            onTap: () {
              haptic();
              f!();
            },
            scale: .98,
            child: Container(
              width: double.infinity,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.ac.withOpacity(.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: p.ac.withOpacity(.45))),
              child: Text(act, style: TextStyle(color: p.ac, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _adHeader(Pal p) {
    final c = adCard!;
    final gone = c['gone'] == true;
    final closed = !gone && (c['status'] ?? '').toString() != 'open';
    final img = (c['img'] ?? '').toString();
    final pay = payF((c['pay'] ?? '').toString());
    final catName = (c['category'] ?? '').toString();
    final priceText = gone ? 'Объявление удалено' : (pay.isEmpty ? 'Договорная' : pay);
    final muted = gone || closed;
    final ph = Container(
      color: Color.alphaBlend(p.ac.withOpacity(.13), p.card),
      child: Icon(gone || catName.isEmpty ? Icons.sell_outlined : catIcon(catName), color: p.ac.withOpacity(.85), size: 26),
    );
    return GestureDetector(
      onTap: gone ? null : _openAd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(color: p.card, border: Border(bottom: BorderSide(color: p.bd))),
        child: Row(children: [
          Container(
            width: 58,
            height: 58,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: img.isEmpty || gone
                ? ph
                : ColorFiltered(
                    colorFilter: closed
                        ? const ColorFilter.matrix(<double>[
                            .6, .3, .1, 0, 0,
                            .6, .3, .1, 0, 0,
                            .6, .3, .1, 0, 0,
                            0, 0, 0, .75, 0,
                          ])
                        : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                    child: CachedNetworkImage(
                      imageUrl: imgUrl(img, 200),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: p.bg2),
                      errorWidget: (_, __, ___) => ph,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(priceText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, height: 1.15, color: muted ? p.mu : p.tx)),
              const SizedBox(height: 3),
              Text(gone ? 'Оно больше недоступно' : (c['title'] ?? '').toString(),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: p.mu)),
              if (closed) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.bd)),
                  child: Text('Снято с публикации', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.mu)),
                ),
              ],
            ]),
          ),
          if (!gone) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: p.bg2, shape: BoxShape.circle),
              child: Icon(Icons.chevron_right_rounded, color: p.ac, size: 22),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _bubble(Pal p, Map<String, dynamic> m) {
    final body = _bubbleBody(p, m);
    final mine = m['mine'] == true, gone = m['gone'] == true;
    final text = (m['text'] ?? '').toString();
    final risk = (mine || gone) ? null : chatRisk(text);
    final rx = gone ? null : _rxChips(p, m);
    final extras = gone ? <Widget>[] : _smartExtras(p, text, mine);
    if (risk == null && rx == null && extras.isEmpty) return body;
    return Column(children: [
      body,
      if (rx != null) rx,
      ...extras,
      if (risk != null)
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            decoration: BoxDecoration(color: const Color(0xFFFFB400).withOpacity(.14), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFB400).withOpacity(.5))),
            child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, size: 17, color: Color(0xFFE09A00)),
              const SizedBox(width: 7),
              Flexible(child: Text(risk, style: TextStyle(fontSize: 12.5, height: 1.3, color: p.tx, fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
    ]);
  }

  // Цитата в ответе: кому и на что
  Widget _quote(Pal p, Map<String, dynamic> rp, bool mine) {
    final c = mine ? Colors.white : p.ac;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(color: c.withOpacity(.16), borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: c, width: 3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(rp['mine'] == true ? 'Вы' : name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: mine ? Colors.white : p.ac)),
          Text((rp['t'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: mine ? Colors.white : p.tx)),
        ]),
      ),
    );
  }

  // Реакции под сообщением: свои и собеседника
  Widget? _rxChips(Pal p, Map<String, dynamic> m) {
    final rx = m['rx'] is Map ? Map<String, dynamic>.from(m['rx'] as Map) : null;
    if (rx == null) return null;
    final me = (rx['me'] ?? '').toString(), th = (rx['th'] ?? '').toString();
    if (me.isEmpty && th.isEmpty) return null;
    final chips = <List<String>>[
      if (me.isNotEmpty && me == th) [me, '2'] else ...[if (me.isNotEmpty) [me, ''], if (th.isNotEmpty) [th, '']],
    ];
    return Align(
      alignment: m['mine'] == true ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final c in chips)
            Container(
              margin: const EdgeInsets.only(left: 4, right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.bd)),
              child: Text(c[1].isEmpty ? c[0] : '${c[0]} ${c[1]}', style: TextStyle(fontSize: 14, color: p.tx)),
            ),
        ]),
      ),
    );
  }

  // Ссылка на объявление превращается в карточку; телефон и адрес — в быстрые действия
  List<Widget> _smartExtras(Pal p, String text, bool mine) {
    if (text.isEmpty) return const [];
    final out = <Widget>[];
    final idm = RegExp(r'#/ad/([A-Za-z0-9_-]+)').firstMatch(text);
    Ad? ad;
    if (idm != null) {
      for (final a in S.i.ads) {
        if (a.id == idm.group(1)) {
          ad = a;
          break;
        }
      }
    }
    if (ad != null) {
      final a = ad;
      out.add(Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Tap(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: a))),
          scale: .98,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.bd)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52,
                height: 52,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: p.ac.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
                child: a.imgs.isNotEmpty
                    ? CachedNetworkImage(imageUrl: imgUrl(a.imgs.first, 200), fit: BoxFit.cover, errorWidget: (c, u, e) => Icon(catIcon(a.category), color: p.ac))
                    : Icon(catIcon(a.category), color: p.ac),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: p.tx)),
                  const SizedBox(height: 2),
                  Text([adPay(a), a.city].where((e) => e.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.mu)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: p.mu),
            ]),
          ),
        ),
      ));
    }
    final chips = <Widget>[];
    final ph = RegExp(r'(?:\+7|8)[\s(\-]*\d{3}[\s)\-]*\d{3}[\s\-]*\d{2}[\s\-]*\d{2}').firstMatch(text);
    if (ph != null) {
      final digits = ph.group(0)!.replaceAll(RegExp(r'[^0-9+]'), '');
      chips.add(_actChip(p, Icons.phone_outlined, 'Позвонить', () => launchUrl(Uri.parse('tel:${digits.startsWith('8') ? '+7${digits.substring(1)}' : digits}'))));
    }
    final ad2 = RegExp(r'(?:ул\.?|улица|проспект|пр-т|переулок|бульвар|шоссе|мкр\.?)\s+[А-ЯЁа-яё0-9\-\. ]{2,30}', caseSensitive: false).firstMatch(text);
    if (ad2 != null) {
      final q = ad2.group(0)!.trim();
      chips.add(_actChip(p, Icons.map_outlined, 'На карте', () => launchUrl(Uri.parse('https://yandex.ru/maps/?text=${Uri.encodeComponent(q)}'), mode: LaunchMode.externalApplication)));
    }
    if (chips.isNotEmpty) {
      out.add(Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(padding: const EdgeInsets.only(bottom: 4), child: Wrap(spacing: 6, children: chips)),
      ));
    }
    return out;
  }

  Widget _actChip(Pal p, IconData ic, String label, VoidCallback f) => Tap(
        onTap: f,
        scale: .96,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: p.ac.withOpacity(.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: p.ac.withOpacity(.4))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 16, color: p.ac),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: p.ac, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      );

  Widget _bubbleBody(Pal p, Map<String, dynamic> m) {
    final mine = m['mine'] == true;
    final text = (m['text'] ?? '').toString();
    final imgs = m['img'] is List ? (m['img'] as List).map((e) => e.toString()).toList() : <String>[];
    final aud = (m['aud'] ?? '').toString();
    final fg = mine ? Colors.white : p.tx;
    if (m['gone'] == true) {
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.bd),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.delete_outline_rounded, size: 16, color: p.mu),
              const SizedBox(width: 6),
              Text('Сообщение удалено', style: TextStyle(color: p.mu, fontSize: 15, fontStyle: FontStyle.italic)),
            ]),
            const SizedBox(height: 2),
            Text(stamp(_n(m['ts'])), style: TextStyle(fontSize: 11, color: p.mu)),
          ]),
        ),
      );
    }
    final edited = _n(m['ed']) > 0;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTapUp: (d) => _msgMenu(m, d.globalPosition),
        onLongPressStart: (d) => _msgMenu(m, d.globalPosition),
        child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          gradient: mine ? LinearGradient(colors: [p.ac, p.ac2]) : null,
          color: mine ? null : p.card,
          border: mine ? null : Border.all(color: p.bd),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 18 : 5),
            bottomRight: Radius.circular(mine ? 5 : 18),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (m['rp'] is Map) _quote(p, Map<String, dynamic>.from(m['rp'] as Map), mine),
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
          if (aud.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 2), child: VoiceBubble(aud: aud, mine: mine, fg: fg)),
          if (text.isNotEmpty)
            Align(alignment: Alignment.centerLeft, child: Text(text, style: TextStyle(color: fg, fontSize: 15.5, height: 1.3))),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (edited) Text('изменено  ', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: mine ? Colors.white70 : p.mu)),
            Text(stamp(_n(m['ts'])), style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : p.mu)),
            if (mine) ...[const SizedBox(width: 4), _tick(p, (m['st'] ?? '').toString())],
          ]),
        ]),
      ),
      ),
    );
  }

  void _hideChips() {
    S.i.hideChips(widget.pid);
    if (mounted) setState(() => _chipsOff = true);
  }

  void _hideSafe() {
    S.i.hideSafe(widget.pid);
    if (mounted) setState(() => _safeOff = true);
  }

  // Быстрые фразы: ряд чипов с прокруткой и постоянной кнопкой «закрыть» справа
  Widget _quick(Pal p) {
    return SizedBox(
      height: 46,
      child: Row(children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 5, 4, 5),
            children: [
              for (final q in kQuick)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tap(
                    onTap: () {
                      _hideChips();
                      _ctl.text = q;
                      _send();
                    },
                    scale: .95,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.ac.withOpacity(.10),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: p.ac.withOpacity(.38)),
                      ),
                      child: Text(q, style: TextStyle(fontSize: 13.5, color: p.tx, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 14, left: 2),
          child: Tap(
            onTap: _hideChips,
            scale: .9,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: p.card, shape: BoxShape.circle, border: Border.all(color: p.bd)),
              child: Icon(Icons.close_rounded, size: 18, color: p.mu),
            ),
          ),
        ),
      ]),
    );
  }

  // Предупреждение про предоплату: закрывается навсегда для этого собеседника
  Widget _safeBanner(Pal p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
      height: 36,
      decoration: BoxDecoration(color: p.ac2.withOpacity(.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: p.ac.withOpacity(.25))),
      child: Row(children: [
        Icon(Icons.shield_outlined, size: 17, color: p.ac),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _safeSheet,
            child: Text('Не переводите предоплату · Подробнее', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.tx, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _hideSafe,
          child: SizedBox(width: 36, height: 36, child: Icon(Icons.close_rounded, size: 18, color: p.mu)),
        ),
      ]),
    );
  }

  // Четыре правила безопасной сделки
  void _safeSheet() {
    final p = pal(context);
    const tips = [
      [Icons.payments_outlined, 'Платите после работы', 'Не переводите предоплату и залог незнакомым.'],
      [Icons.sms_failed_outlined, 'Коды и пароли — только вам', 'Никому не называйте коды из СМС, пароли и CVC-код карты.'],
      [Icons.link_off_rounded, 'Не переходите по чужим ссылкам', 'Общайтесь в чате ДелоЕсть и не уходите в сомнительные мессенджеры.'],
      [Icons.flag_outlined, 'Нашли обман — пожаловайтесь', 'Заблокируйте человека в меню чата и сообщите нам.'],
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 18 + MediaQuery.of(c).viewPadding.bottom),
        decoration: BoxDecoration(color: p.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: p.bd, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 14),
          Text('Безопасная сделка', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: p.tx, letterSpacing: -.3)),
          const SizedBox(height: 12),
          for (final t in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: p.ac.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Icon(t[0] as IconData, size: 20, color: p.ac)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t[1] as String, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: p.tx)),
                    const SizedBox(height: 2),
                    Text(t[2] as String, style: TextStyle(color: p.mu, fontSize: 13.5, height: 1.3)),
                  ]),
                ),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _replyStrip(Pal p) {
    final r = _reply!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.bd)),
      child: Row(children: [
        Container(width: 3, height: 32, decoration: BoxDecoration(color: p.ac, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r['mine'] == true ? 'Ответ себе' : 'Ответ: $name', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800, fontSize: 12.5)),
            Text(_replyText(r), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontSize: 13)),
          ]),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _reply = null),
          child: SizedBox(width: 36, height: 36, child: Icon(Icons.close_rounded, size: 18, color: p.mu)),
        ),
      ]),
    );
  }

  Widget _input(Pal p) {
    final can = _ctl.text.trim().isNotEmpty || _editId != null;
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                child: _rec ? _recRow(p) : Row(key: const ValueKey('in'), crossAxisAlignment: CrossAxisAlignment.end, children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: busy
                      ? const Padding(padding: EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2.4))
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _editId != null ? null : () { haptic(); _attach(); },
                          child: Icon(Icons.attach_file_rounded, color: p.mu),
                        ),
                ),
                SizedBox(
                  width: 40,
                  height: 44,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      haptic();
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() => _emoji = !_emoji);
                    },
                    child: Icon(_emoji ? Icons.keyboard_alt_outlined : Icons.emoji_emotions_outlined, color: _emoji ? p.ac : p.mu),
                  ),
                ),
                Expanded(
                  child: TextField(contextMenuBuilder: appContextMenu, 
                    controller: _ctl,
                    focusNode: _fn,
                    onTap: () {
                      if (_emoji) setState(() => _emoji = false);
                    },
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
                  onTap: () { haptic(); if (can) _send(); else _startVoice(); },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [p.ac, p.ac2]), shape: BoxShape.circle),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: Icon(can ? Icons.send_rounded : Icons.mic_rounded, key: ValueKey(can), color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Набор смайликов для чата
const List<String> kEmoji = [
  '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇', '🙂', '😉', '😍', '🥰', '😘', '😋',
  '😎', '🤩', '🥳', '🤗', '🤔', '😏', '😌', '😴', '😢', '😭', '😤', '😡', '🙄', '😬', '😱', '🤝',
  '👍', '👎', '👌', '✌️', '🤞', '👏', '🙌', '🙏', '💪', '👋', '🤙', '👀', '❤️', '🧡', '💛', '💚',
  '💙', '💜', '🖤', '💔', '🔥', '✨', '⭐', '🎉', '💯', '✅', '❌', '⚠️', '❓', '❗', '💰', '💵',
  '💳', '📞', '📍', '🕒', '📅', '🚗', '🚚', '🏠', '🔧', '🛠️', '🔨', '🧹', '🧰', '📦', '🎁', '🍕',
  '☕', '🌞', '🌧️', '🐶', '🐱',
];


// ---------- Поиск по сообщениям ----------
class MsgSearchPage extends StatefulWidget {
  const MsgSearchPage({super.key});
  @override
  State<MsgSearchPage> createState() => _MsgSearchPageState();
}

class _MsgSearchPageState extends State<MsgSearchPage> {
  final _q = TextEditingController();
  Timer? _deb;
  List<Map<String, dynamic>> res = [];
  bool busy = false, done = false;
  String? err;
  int _seq = 0;

  @override
  void dispose() {
    _deb?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _deb?.cancel();
    if (v.trim().length < 2) {
      setState(() {
        res = [];
        done = false;
        err = null;
      });
      return;
    }
    _deb = Timer(const Duration(milliseconds: 450), _run);
  }

  Future<void> _run() async {
    final q = _q.text.trim();
    final my = ++_seq;
    setState(() {
      busy = true;
      err = null;
    });
    try {
      final j = await Api.call('msgSearch', {'q': q});
      if (!mounted || my != _seq) return;
      setState(() {
        res = (j['list'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        done = true;
      });
    } catch (e) {
      if (mounted && my == _seq) setState(() => err = S.i.fail(e));
    }
    if (mounted && my == _seq) setState(() => busy = false);
  }

  // Слово из запроса выделяем в тексте найденного сообщения
  Widget _hit(Pal p, String text) {
    final q = _q.text.trim().toLowerCase();
    final i = q.isEmpty ? -1 : text.toLowerCase().indexOf(q);
    if (i < 0) return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mu, fontSize: 14));
    final a = (i - 24).clamp(0, i);
    return Text.rich(
      TextSpan(style: TextStyle(color: p.mu, fontSize: 14), children: [
        TextSpan(text: (a > 0 ? '…' : '') + text.substring(a, i)),
        TextSpan(text: text.substring(i, i + q.length), style: TextStyle(color: p.ac, fontWeight: FontWeight.w800)),
        TextSpan(text: text.substring(i + q.length)),
      ]),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _q,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _run(),
          style: TextStyle(color: p.tx, fontSize: 17),
          decoration: InputDecoration(hintText: 'Поиск по сообщениям', hintStyle: TextStyle(color: p.mu), border: InputBorder.none),
        ),
        actions: [
          if (_q.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close_rounded, color: p.mu),
              onPressed: () {
                _q.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        if (busy) Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: p.ac))),
        if (err != null) Padding(padding: const EdgeInsets.all(24), child: Text(err!, textAlign: TextAlign.center, style: TextStyle(color: p.mu))),
        if (!busy && done && res.isEmpty && err == null)
          const EmptyState(icon: Icons.search_off_rounded, title: 'Ничего не найдено', text: 'Попробуйте другое слово или часть слова.'),
        if (!done && !busy) const EmptyState(icon: Icons.manage_search_rounded, title: 'Найдите нужное сообщение', text: 'Введите хотя бы 2 буквы: ищем по тексту всех ваших переписок.'),
        for (final r in res)
          Tap(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatPage(pid: (r['pid'] ?? '').toString(), name: (r['name'] ?? '').toString(), avatar: (r['avatar'] ?? '').toString(), adId: (r['ad'] ?? '').toString())),
            ),
            scale: .99,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: cardDeco(p, r: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text((r['name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.tx, fontWeight: FontWeight.w800, fontSize: 15))),
                  Text(siteListTime((r['ts'] as num?)?.toInt() ?? 0, S.i.timeZone), style: TextStyle(color: p.mu, fontSize: 12)),
                ]),
                if ((r['adt'] ?? '').toString().isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text((r['adt']).toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.ac, fontSize: 12.5, fontWeight: FontWeight.w600))),
                const SizedBox(height: 4),
                _hit(p, ((r['mine'] == true) ? 'Вы: ' : '') + (r['text'] ?? '').toString()),
              ]),
            ),
          ),
      ]),
    );
  }
}
