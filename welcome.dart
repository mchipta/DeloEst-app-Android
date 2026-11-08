import 'package:flutter/material.dart';
import 'map_page.dart';
import 'near.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

/// Первый запуск: один вопрос «Где вы ищете?». Город сохраняется как «Регион для поиска».
class WelcomeRegionPage extends StatefulWidget {
  final VoidCallback onDone;
  const WelcomeRegionPage({super.key, required this.onDone});
  @override
  State<WelcomeRegionPage> createState() => _WelcomeRegionPageState();
}

class _WelcomeRegionPageState extends State<WelcomeRegionPage> {
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
    // геолокацию (для расстояния до объявлений) запрашиваем уже после выбора города
    Near.i.auto().then((_) => Near.i.fill(S.i.ads), onError: (_) {});
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final has = _c.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: p.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Logo(size: 46),
              const SizedBox(width: 12),
              Text('Дело', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: p.tx)),
              const GradText('Есть', size: 24),
            ]),
            const SizedBox(height: 44),
            Text('Где вы ищете?', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: p.tx, letterSpacing: -.8, height: 1.1)),
            const SizedBox(height: 10),
            Text('Покажем подработки и услуги рядом с вами. Город можно сменить в любой момент в настройках.',
                style: TextStyle(fontSize: 15.5, color: p.mu, height: 1.4)),
            const SizedBox(height: 28),
            CityField(
              controller: _c,
              decoration: deco(context, 'Город или регион', prefix: Icon(Icons.place_outlined, color: p.mu)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Tap(
              onTap: _busy ? null : _locate,
              scale: .98,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd)),
                child: Row(children: [
                  Icon(Icons.my_location_rounded, color: p.ac, size: 21),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Определить автоматически', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.tx))),
                  if (_busy) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.ac)),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            GradBtn('Продолжить', radius: 18, onTap: has ? () => _done(skip: false) : null),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => _done(skip: true),
                child: Text('Пропустить, искать везде', style: TextStyle(color: p.mu, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
