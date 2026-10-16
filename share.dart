import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';

// Поделиться объявлением: Telegram, WhatsApp, ВКонтакте, копировать ссылку (как на сайте)
Future<void> showShare(BuildContext context, Ad ad) async {
  final p = pal(context);
  final url = '$kSiteUrl#/ad/${ad.id}';
  final text = [
    ad.title,
    [payF(ad.pay), ad.city].where((e) => e.isNotEmpty).join(' · '),
    'Объявление на ДелоЕсть — подработка рядом с домом',
  ].join('\n');
  final enc = Uri.encodeComponent;

  Future<void> open(String u) async {
    try {
      await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) toast(context, 'Не удалось открыть');
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: p.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Поделиться объявлением', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.tx)),
          ),
        ),
        ListTile(
          leading: const BrandIcon('tg', size: 36),
          title: const Text('Telegram'),
          onTap: () {
            Navigator.pop(c);
            open('https://t.me/share/url?url=${enc(url)}&text=${enc(text)}');
          },
        ),
        ListTile(
          leading: const BrandIcon('wa', size: 36),
          title: const Text('WhatsApp'),
          onTap: () {
            Navigator.pop(c);
            open('https://wa.me/?text=${enc('$text\n$url')}');
          },
        ),
        ListTile(
          leading: const BrandIcon('vk', size: 36),
          title: const Text('ВКонтакте'),
          onTap: () {
            Navigator.pop(c);
            open('https://vk.com/share.php?url=${enc(url)}&title=${enc(ad.title)}');
          },
        ),
        ListTile(
          leading: Icon(Icons.copy_rounded, color: p.ac),
          title: const Text('Копировать ссылку'),
          onTap: () async {
            Navigator.pop(c);
            await Clipboard.setData(ClipboardData(text: '$text\n$url'));
            if (context.mounted) toast(context, 'Ссылка скопирована');
          },
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}
