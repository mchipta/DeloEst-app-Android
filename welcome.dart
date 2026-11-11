import 'package:flutter/material.dart';
import 'map_page.dart';
import 'near.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

/// После входа в аккаунт: один вопрос «Где вы ищете?» в нижней шторке. Город сохраняется как «Регион для поиска».
/// Закрыли шторку или нажали «Пропустить»: ищем везде и больше не спрашиваем.
Future<void> showRegionSheet(BuildContext context) async {
  final p = pal(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: p.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _RegionSheet(),
  );
  if (!S.i.regionChosen) await S.i.setRegion('', '', true);
}

class _RegionSheet extends StatefulWidget {
  const _RegionSheet();
  @override
  State<_RegionSheet> createState() => _RegionSheetState();
}

class _RegionSheetState extends State<_RegionSheet> {
  final _c = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    haptic();
    setState(() => _busy = true);
    final r = await Near.i.locate();
    String? city;
    final pos = Near.i.pos;
    if (r == NearResult.ok && pos != null) city = await Geo.reverseCity(pos.latitude, pos.longitude);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (city != null) _c.text = city;
    });
    if (r != NearResult.ok) {
      toast(context, nearMsg(r), err: true);
    } else if (city == null) {
      toast(context, 'Не удалось определить город. Введите его вручную', err: true);
    }
  }

  Future<void> _done({required bool skip}) async {
    haptic();
    final city = skip ? '' : _c.text.trim();
    await S.i.setRegion(city, city.isEmpty ? '' : '50', true);
    Near.i.auto().then((_) => Near.i.fill(S.i.ads), onError: (_) {});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final has = _c.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 4, 22, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [p.ac, p.ac2], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(17),
              boxShadow: [BoxShadow(color: p.ac.withOpacity(.3), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.place_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 14),
          Text('Где вы ищете?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: p.tx, letterSpacing: -.5, height: 1.1)),
          const SizedBox(height: 8),
          Text('Покажем подработки и услуги рядом с вами. Город можно сменить в любой момент в настройках.',
              style: TextStyle(fontSize: 15, color: p.mu, height: 1.4)),
          const SizedBox(height: 18),
          CityField(
            controller: _c,
            decoration: deco(context, 'Город или регион', prefix: Icon(Icons.place_outlined, color: p.mu)),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Tap(
            onTap: _busy ? null : _locate,
            scale: .98,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd)),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: p.ac.withOpacity(.14), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.my_location_rounded, color: p.ac, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Определить автоматически', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: p.tx)),
                    Text('Нужен доступ к геолокации', style: TextStyle(fontSize: 12.5, color: p.mu)),
                  ]),
                ),
                if (_busy) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.ac)),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          GradBtn('Продолжить', radius: 18, onTap: has ? () => _done(skip: false) : null),
          Center(
            child: TextButton(
              onPressed: () => _done(skip: true),
              child: Text('Пропустить, искать везде', style: TextStyle(color: p.mu, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}
