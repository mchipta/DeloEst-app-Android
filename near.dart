import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'map_page.dart';
import 'models.dart';
import 'state.dart';

// «Рядом со мной»: координаты хранятся только на телефоне, на сервер не отправляются.
// У объявления с меткой расстояние точное, без метки — до центра города (со значком ≈).

enum NearResult { ok, denied, forever, off, fail }

String nearMsg(NearResult r) {
  switch (r) {
    case NearResult.off:
      return 'Включите геолокацию на телефоне';
    case NearResult.denied:
    case NearResult.forever:
      return 'Разрешите доступ к геолокации в настройках приложения';
    case NearResult.fail:
      return 'Не удалось определить место. Проверьте GPS и интернет';
    case NearResult.ok:
      return '';
  }
}

double kmBetween(LatLng a, LatLng b) {
  const r = math.pi / 180;
  final dl = (b.latitude - a.latitude) * r;
  final dn = (b.longitude - a.longitude) * r;
  final sa = math.sin(dl / 2);
  final sb = math.sin(dn / 2);
  final s = sa * sa + math.cos(a.latitude * r) * math.cos(b.latitude * r) * sb * sb;
  return 12742 * math.asin(math.min(1.0, math.sqrt(s)));
}

String kmText(double k) {
  if (k < 1) {
    final mt = ((k * 1000) / 50).round() * 50;
    return '${mt < 50 ? 50 : mt} м';
  }
  if (k < 10) {
    final v = (k * 10).round() / 10;
    final s = v == v.roundToDouble() ? v.round().toString() : v.toString().replaceAll('.', ',');
    return '$s км';
  }
  return '${k.round()} км';
}

class Dist {
  final double km;
  final bool approx;
  const Dist(this.km, this.approx);
  String get label => '${approx ? '≈ ' : ''}${kmText(km)}';
}

class Near extends ChangeNotifier {
  static final Near i = Near._();
  Near._();

  LatLng? _pos;
  double acc = 0;
  int ts = 0;
  bool busy = false;
  bool _loaded = false;
  bool _filling = false;

  void _load() {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = S.i.prefs.getStringList('near_pos');
      if (raw != null && raw.length == 3) {
        final t = int.tryParse(raw[2]) ?? 0;
        if (DateTime.now().millisecondsSinceEpoch - t < 86400000) {
          _pos = LatLng(double.parse(raw[0]), double.parse(raw[1]));
          ts = t;
        }
      }
    } catch (_) {}
  }

  LatLng? get pos {
    _load();
    return _pos;
  }

  bool get has => pos != null;

  void _set(Position p) {
    final la = double.parse(p.latitude.toStringAsFixed(3));
    final ln = double.parse(p.longitude.toStringAsFixed(3));
    _pos = LatLng(la, ln);
    acc = p.accuracy;
    ts = DateTime.now().millisecondsSinceEpoch;
    try {
      S.i.prefs.setStringList('near_pos', ['$la', '$ln', '$ts']);
      S.i.prefs.remove('near_asked');
    } catch (_) {}
    notifyListeners();
  }

  /// Определить место (при необходимости покажет системный запрос разрешения)
  Future<NearResult> locate() async {
    _load();
    if (busy) return NearResult.fail;
    busy = true;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return NearResult.off;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return NearResult.forever;
      if (perm == LocationPermission.denied || perm == LocationPermission.unableToDetermine) {
        try {
          await S.i.prefs.setInt('near_asked', DateTime.now().millisecondsSinceEpoch);
        } catch (_) {}
        return NearResult.denied;
      }
      try {
        final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 12),
        );
        _set(p);
        return NearResult.ok;
      } catch (_) {
        final l = await Geolocator.getLastKnownPosition();
        if (l != null) {
          _set(l);
          return NearResult.ok;
        }
        return NearResult.fail;
      }
    } catch (_) {
      return NearResult.fail;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Автоматически при открытии «Поиска»: если доступ уже есть — тихо обновляем,
  /// если ещё не спрашивали — система покажет запрос (после отказа не чаще раза в 3 дня)
  Future<void> auto() async {
    _load();
    if (busy) return;
    if (_pos != null && DateTime.now().millisecondsSinceEpoch - ts < 300000) return;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.deniedForever) return;
      if (perm == LocationPermission.denied) {
        final asked = S.i.prefs.getInt('near_asked') ?? 0;
        if (asked > 0 && DateTime.now().millisecondsSinceEpoch - asked < 259200000) return;
      }
    } catch (_) {
      return;
    }
    await locate();
  }

  Dist? dist(Ad a) {
    final me = pos;
    if (me == null) return null;
    var p = adPoint(a);
    var ap = false;
    if (p == null) {
      final c = a.city.trim().isEmpty ? null : Geo.cityCached(a.city);
      if (c == null) return null;
      p = c;
      ap = true;
    }
    return Dist(kmBetween(me, p), ap);
  }

  double kmOr(Ad a) => dist(a)?.km ?? 1e9;

  /// Центры городов для объявлений без метки (кэшируются, не больше 10 новых запросов за раз)
  Future<void> fill(Iterable<Ad> ads) async {
    if (!has || _filling) return;
    _filling = true;
    var n = 0;
    var changed = false;
    try {
      for (final a in ads) {
        if (adPoint(a) != null || a.city.trim().isEmpty || Geo.hasCity(a.city)) continue;
        if (n >= 10) break;
        n++;
        await Geo.city(a.city);
        changed = true;
      }
    } catch (_) {}
    _filling = false;
    if (changed) notifyListeners();
  }
}
