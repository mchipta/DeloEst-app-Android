import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ad_page.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

// Карты — OpenStreetMap (бесплатно, без ключей). Поиск адресов — Nominatim (тоже OSM).

// плитки Esri World Street Map (на данных OpenStreetMap и др.) — без ключа
const _tileUrl = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
const _pkg = 'ru.deloest.app';
const _moscow = LatLng(55.7558, 37.6173);

class GeoHit {
  final String name;
  final double lat, lng;
  const GeoHit(this.name, this.lat, this.lng);
}

class Geo {
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  static Future<void> _queue = Future.value();
  static final Map<String, List<double>?> _city = {};
  static bool _loaded = false;

  static String _key(String c) => c.trim().toLowerCase().replaceAll('ё', 'е');

  // Nominatim просит не чаще 1 запроса в секунду — ставим запросы в очередь
  static Future<List<GeoHit>?> search(String q, {int limit = 5}) {
    final c = Completer<List<GeoHit>?>();
    _queue = _queue.then((_) async {
      final wait = _last.add(const Duration(milliseconds: 1100)).difference(DateTime.now());
      if (wait > Duration.zero) await Future.delayed(wait);
      _last = DateTime.now();
      var r = await _nominatim(q, limit);
      r ??= await _photon(q, limit); // запасной геокодер, если Nominatim не ответил
      c.complete(r);
    });
    return c.future;
  }

  static Future<List<GeoHit>?> _nominatim(String q, int limit) async {
    try {
      final r = await http.get(
        Uri.https('nominatim.openstreetmap.org', '/search', {
          'format': 'jsonv2',
          'limit': '$limit',
          'accept-language': 'ru',
          'countrycodes': 'ru,by,kz,uz',
          'q': q,
        }),
        headers: {
          'User-Agent': 'DeloEst/1.0 (https://mchipta.github.io/delo-est/; michipta@ya.ru)',
          'Referer': 'https://mchipta.github.io/delo-est/',
        },
      ).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as List;
      return [
        for (final e in j)
          GeoHit((e['display_name'] ?? '').toString(), double.tryParse('${e['lat']}') ?? 0, double.tryParse('${e['lon']}') ?? 0),
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<List<GeoHit>?> _photon(String q, int limit) async {
    try {
      final r = await http.get(
        Uri.https('photon.komoot.io', '/api/', {'q': q, 'limit': '$limit'}),
        headers: {'User-Agent': 'DeloEst/1.0 (https://mchipta.github.io/delo-est/)'},
      ).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final feats = (jsonDecode(utf8.decode(r.bodyBytes))['features'] as List?) ?? [];
      final out = <GeoHit>[];
      for (final f in feats) {
        final co = f['geometry']?['coordinates'] as List?;
        if (co == null || co.length < 2) continue;
        final pr = (f['properties'] as Map?) ?? {};
        final parts = <String>[];
        for (final k in ['name', 'street', 'housenumber', 'city', 'state', 'country']) {
          final v = (pr[k] ?? '').toString().trim();
          if (v.isNotEmpty && !parts.contains(v)) parts.add(v);
        }
        out.add(GeoHit(parts.join(', '), (co[1] as num).toDouble(), (co[0] as num).toDouble()));
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  static void _load() {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = S.i.prefs.getString('geo_city');
      if (raw != null) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
          _city[k] = v is List ? [(v[0] as num).toDouble(), (v[1] as num).toDouble()] : null;
        });
      }
    } catch (_) {}
  }

  static bool hasCity(String c) {
    _load();
    return _city.containsKey(_key(c));
  }

  /// Центр города (для объявлений без точного адреса); результат запоминается на телефоне
  static Future<LatLng?> city(String c) async {
    _load();
    final k = _key(c);
    if (_city.containsKey(k)) {
      final v = _city[k];
      return v == null ? null : LatLng(v[0], v[1]);
    }
    final r = await search(c, limit: 1);
    if (r == null) return null; // нет сети — не запоминаем неудачу
    _city[k] = r.isEmpty ? null : [r[0].lat, r[0].lng];
    try {
      await S.i.prefs.setString('geo_city', jsonEncode(_city));
    } catch (_) {}
    final v = _city[k];
    return v == null ? null : LatLng(v[0], v[1]);
  }
}

LatLng? adPoint(Ad a) {
  final la = a.lat, ln = a.lng;
  if (la == null || ln == null) return null;
  if (la.abs() > 90 || ln.abs() > 180) return null;
  return LatLng(la, ln);
}

// небольшой сдвиг, чтобы метки «по городу» не лежали ровно друг на друге
LatLng _jit(LatLng c, String id) {
  var h = 0;
  for (final u in id.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return LatLng(c.latitude + ((h % 1000) / 1000 - .5) * .03, c.longitude + (((h ~/ 1000) % 1000) / 1000 - .5) * .04);
}

Widget _tiles(bool dark) {
  final tl = TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _pkg, maxZoom: 19);
  if (!dark) return tl;
  // тёмная тема: инвертируем и обесцвечиваем плитки
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix(<double>[
      -0.30, -0.53, -0.10, 0, 232,
      -0.30, -0.53, -0.10, 0, 232,
      -0.30, -0.53, -0.10, 0, 232,
      0, 0, 0, 1, 0,
    ]),
    child: tl,
  );
}

Widget _attribution() => RichAttributionWidget(
      alignment: AttributionAlignment.bottomLeft,
      attributions: [
        TextSourceAttribution('© Esri, © OpenStreetMap', onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'), mode: LaunchMode.externalApplication)),
      ],
    );

Widget _pin(Color c, {double size = 40}) => Icon(Icons.location_on_rounded, size: size, color: c, shadows: const [Shadow(blurRadius: 5, color: Colors.black45, offset: Offset(0, 1))]);

class _Pt {
  final Ad ad;
  final LatLng p;
  final bool approx;
  const _Pt(this.ad, this.p, this.approx);
}

/// Общая карта: объявления метками, по нажатию — карточка
class MapPage extends StatefulWidget {
  final List<Ad> ads;
  const MapPage({super.key, required this.ads});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _mc = MapController();
  final List<_Pt> _pts = [];
  Ad? _sel;
  bool _ready = false;
  bool _busy = false;
  bool _dead = false;

  @override
  void initState() {
    super.initState();
    for (final a in widget.ads) {
      final p = adPoint(a);
      if (p != null) _pts.add(_Pt(a, p, false));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _approx());
  }

  @override
  void dispose() {
    _dead = true;
    super.dispose();
  }

  // объявления без точного адреса — в центр их города (не больше 8 новых запросов за раз)
  Future<void> _approx() async {
    final rest = [for (final a in widget.ads) if (adPoint(a) == null && a.city.trim().isNotEmpty) a];
    if (rest.isEmpty) return;
    if (mounted) setState(() => _busy = rest.any((a) => !Geo.hasCity(a.city)));
    var look = 0;
    for (final a in rest) {
      if (_dead) return;
      if (!Geo.hasCity(a.city)) {
        if (look >= 8) continue;
        look++;
      }
      final c = await Geo.city(a.city);
      if (_dead) return;
      if (c == null) continue;
      _pts.add(_Pt(a, _jit(c, a.id), true));
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => _busy = false);
    _fit();
  }

  void _fit() {
    if (!_ready || _pts.isEmpty) return;
    try {
      if (_pts.length == 1) {
        _mc.move(_pts.first.p, 14);
      } else {
        _mc.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints([for (final t in _pts) t.p]), padding: const EdgeInsets.all(56), maxZoom: 14));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final exact = _pts.where((t) => !t.approx).length;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.tx,
        elevation: 0,
        title: const Text('Объявления на карте', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _mc,
          options: MapOptions(
            initialCenter: _pts.isNotEmpty ? _pts.first.p : _moscow,
            initialZoom: _pts.isNotEmpty ? 11 : 4,
            minZoom: 3,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onMapReady: () {
              _ready = true;
              _fit();
            },
            onTap: (_, __) => setState(() => _sel = null),
          ),
          children: [
            _tiles(dark),
            MarkerLayer(markers: [
              for (final t in _pts)
                Marker(
                  point: t.p,
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => setState(() => _sel = t.ad),
                    child: _pin(
                      (t.ad.type == kTypes[1] ? p.ac2 : p.ac).withOpacity(t.approx ? .6 : 1),
                      size: _sel?.id == t.ad.id ? 48 : 40,
                    ),
                  ),
                ),
            ]),
            _attribution(),
          ],
        ),
        Positioned(
          top: 10,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: p.card.withOpacity(.94), borderRadius: BorderRadius.circular(12), border: Border.all(color: p.bd)),
            child: Text(
              widget.ads.isEmpty
                  ? 'Нет объявлений'
                  : 'На карте: ${_pts.length} из ${widget.ads.length}${_busy ? ' · ищем города…' : ''}',
              style: TextStyle(color: p.tx, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ),
        if (_pts.length > exact && _sel == null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child: IgnorePointer(
              child: Text('Если адрес не указан, метка стоит в центре города',
                  textAlign: TextAlign.center, style: TextStyle(color: p.mu, fontSize: 12, shadows: [Shadow(color: p.bg, blurRadius: 6)])),
            ),
          ),
        if (_sel != null)
          Positioned(left: 12, right: 12, bottom: 12, child: SafeArea(top: false, child: _card(p, _sel!))),
      ]),
    );
  }

  Widget _card(Pal p, Ad a) {
    return Tap(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad: a))),
      scale: .98,
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.bd),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 84,
              height: 84,
              child: a.imgs.isEmpty
                  ? Container(color: p.bg2, child: Icon(Icons.work_outline_rounded, color: p.mu))
                  : CachedNetworkImage(imageUrl: imgUrl(a.imgs[0], 300), fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: p.bg2)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, height: 1.2, color: p.tx)),
              const SizedBox(height: 3),
              Text(payF(a.pay), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.ok)),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.place_outlined, size: 14, color: p.mu),
                const SizedBox(width: 3),
                Expanded(child: Text(adLoc(a), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.mu))),
              ]),
              const SizedBox(height: 4),
              Text('Открыть объявление →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ac)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Выбор точки: двигаете карту, метка по центру остаётся на месте
class MapPickPage extends StatefulWidget {
  final LatLng start;
  const MapPickPage({super.key, required this.start});
  @override
  State<MapPickPage> createState() => _MapPickPageState();
}

class _MapPickPageState extends State<MapPickPage> {
  late LatLng _c = widget.start;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.tx,
        elevation: 0,
        title: const Text('Где это находится?', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: widget.start,
            initialZoom: 16,
            minZoom: 3,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onPositionChanged: (cam, _) => _c = cam.center,
          ),
          children: [_tiles(dark), _attribution()],
        ),
        // метка по центру: её нижний кончик — выбранная точка
        IgnorePointer(child: Center(child: Padding(padding: const EdgeInsets.only(bottom: 44), child: _pin(p.ac, size: 48)))),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: p.card.withOpacity(.94), borderRadius: BorderRadius.circular(12), border: Border.all(color: p.bd)),
                child: Text('Двигайте карту, чтобы метка встала на нужное место', style: TextStyle(color: p.mu, fontSize: 12.5)),
              ),
              const SizedBox(height: 10),
              GradBtn('Готово', onTap: () => Navigator.pop(context, _c)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Адрес на странице объявления; карта раскрывается по нажатию
class AdMiniMap extends StatefulWidget {
  final Ad ad;
  const AdMiniMap({super.key, required this.ad});
  @override
  State<AdMiniMap> createState() => _AdMiniMapState();
}

class _AdMiniMapState extends State<AdMiniMap> {
  LatLng? _pt;
  bool _approx = false;
  bool _done = false;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    final a = widget.ad;
    _pt = adPoint(a);
    if (_pt != null || a.city.trim().isEmpty) {
      _done = true;
    } else {
      Geo.city(a.city).then((c) {
        if (!mounted) return;
        setState(() {
          _pt = c;
          _approx = c != null;
          _done = true;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.ad;
    final p = pal(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pt = _pt;
    final loc = adLoc(a);
    if (loc.isEmpty && pt == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 14),
      // адрес — нажмите, чтобы открыть карту
      Tap(
        onTap: () => setState(() => _open = !_open),
        scale: .98,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.bd)),
          child: Row(children: [
            Icon(Icons.location_on_outlined, size: 20, color: p.ac),
            const SizedBox(width: 8),
            Expanded(child: Text(loc.isEmpty ? 'Показать на карте' : loc, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.tx))),
            Icon(_open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: p.mu),
          ]),
        ),
      ),
      if (_open) ...[
        const SizedBox(height: 10),
        if (pt == null)
          Container(
            height: 180,
            decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: _done ? Text('Не удалось найти место на карте', style: TextStyle(color: p.mu)) : CircularProgressIndicator(color: p.ac),
          )
        else
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapPage(ads: [a]))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                child: FlutterMap(
                  options: MapOptions(initialCenter: pt, initialZoom: _approx ? 11 : 16, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
                  children: [
                    _tiles(dark),
                    MarkerLayer(markers: [
                      Marker(point: pt, width: 44, height: 44, alignment: Alignment.topCenter, child: _pin((a.type == kTypes[1] ? p.ac2 : p.ac).withOpacity(_approx ? .6 : 1))),
                    ]),
                    _attribution(),
                  ],
                ),
              ),
            ),
          ),
        if (_approx) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Точный адрес не указан — метка показывает центр города', style: TextStyle(fontSize: 12, color: p.mu))),
      ],
    ]);
  }
}

/// Поле «Адрес» в форме объявления: найти адрес, увидеть метку, уточнить на карте
class AddrField extends StatefulWidget {
  final TextEditingController controller;
  final double? lat, lng;
  final String Function() city;
  final void Function(double? lat, double? lng) onGeo;
  const AddrField({super.key, required this.controller, required this.lat, required this.lng, required this.city, required this.onGeo});
  @override
  State<AddrField> createState() => _AddrFieldState();
}

class _AddrFieldState extends State<AddrField> {
  List<GeoHit> _hits = [];
  String? _msg;
  bool _busy = false;

  Future<void> _find() async {
    final a = widget.controller.text.trim(), c = widget.city().trim();
    FocusScope.of(context).unfocus();
    if (c.isEmpty) {
      setState(() => _msg = 'Сначала укажите город выше');
      return;
    }
    if (a.isEmpty) {
      setState(() => _msg = 'Введите улицу и дом');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
      _hits = [];
    });
    final r = await Geo.search('$c, $a');
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) {
      setState(() => _msg = 'Не удалось связаться с картой. Попробуйте ещё раз');
      return;
    }
    if (r.isEmpty) {
      setState(() => _msg = 'Такой адрес не нашли. Проверьте написание или укажите на карте вручную');
      return;
    }
    if (r.length == 1) return _use(r.first);
    setState(() => _hits = r);
  }

  void _use(GeoHit h) {
    setState(() {
      _hits = [];
      _msg = null;
    });
    widget.onGeo(double.parse(h.lat.toStringAsFixed(5)), double.parse(h.lng.toStringAsFixed(5)));
  }

  Future<void> _manual() async {
    LatLng start = _moscow;
    if (widget.lat != null && widget.lng != null) {
      start = LatLng(widget.lat!, widget.lng!);
    } else if (widget.city().trim().isNotEmpty) {
      start = await Geo.city(widget.city()) ?? _moscow;
    }
    if (!mounted) return;
    final r = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (_) => MapPickPage(start: start)));
    if (r == null) return;
    setState(() {
      _hits = [];
      _msg = null;
    });
    widget.onGeo(double.parse(r.latitude.toStringAsFixed(5)), double.parse(r.longitude.toStringAsFixed(5)));
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final has = widget.lat != null && widget.lng != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('Адрес', style: TextStyle(fontWeight: FontWeight.w800, color: p.tx, fontSize: 16)),
          Flexible(child: Text('  необязательно, покажем на карте', style: TextStyle(color: p.mu, fontSize: 12.5))),
        ]),
      ),
      Row(children: [
        Expanded(
          child: TextField(
            controller: widget.controller,
            style: TextStyle(color: p.tx),
            textInputAction: TextInputAction.search,
            onChanged: (_) {
              if (has) widget.onGeo(null, null);
              if (_hits.isNotEmpty || _msg != null) setState(() {
                    _hits = [];
                    _msg = null;
                  });
            },
            onSubmitted: (_) => _find(),
            decoration: deco(context, null, hint: 'Улица и дом, например: Ленина 10'),
          ),
        ),
        const SizedBox(width: 8),
        Tap(
          onTap: _busy ? null : _find,
          scale: .95,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: p.ac.withOpacity(.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: p.ac.withOpacity(.5))),
            alignment: Alignment.center,
            child: _busy
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: p.ac))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.search_rounded, size: 19, color: p.ac),
                    const SizedBox(width: 4),
                    Text('Найти', style: TextStyle(fontWeight: FontWeight.w800, color: p.ac)),
                  ]),
          ),
        ),
      ]),
      if (_msg != null) Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child: Text(_msg!, style: TextStyle(color: p.dng, fontWeight: FontWeight.w600, fontSize: 13))),
      for (final h in _hits)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Tap(
            onTap: () => _use(h),
            scale: .98,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.bd)),
              child: Row(children: [
                Icon(Icons.place_outlined, size: 18, color: p.ac),
                const SizedBox(width: 8),
                Expanded(child: Text(h.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: p.tx))),
              ]),
            ),
          ),
        ),
      if (has) ...[
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 160,
            child: Stack(children: [
              FlutterMap(
                key: ValueKey('${widget.lat},${widget.lng}'),
                options: MapOptions(initialCenter: LatLng(widget.lat!, widget.lng!), initialZoom: 16, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
                children: [
                  _tiles(dark),
                  MarkerLayer(markers: [Marker(point: LatLng(widget.lat!, widget.lng!), width: 44, height: 44, alignment: Alignment.topCenter, child: _pin(p.ac))]),
                  _attribution(),
                ],
              ),
            ]),
          ),
        ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Row(children: [
          Expanded(
            child: Text(
              has ? 'Метка поставлена. Если она стоит не там — уточните на карте' : 'Нажмите «Найти», чтобы поставить метку. Адрес увидят все, кто откроет объявление',
              style: TextStyle(fontSize: 12, color: p.mu, height: 1.3),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: GestureDetector(
          onTap: _manual,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Text(has ? 'Уточнить на карте' : 'Указать на карте вручную', style: TextStyle(color: p.ac, fontWeight: FontWeight.w800, fontSize: 13.5)),
          ),
        ),
      ),
    ]);
  }
}
