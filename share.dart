import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'util.dart';
import 'widgets.dart';

// Поделиться объявлением: системное окно «Поделиться», в нём любые приложения на телефоне
Future<void> showShare(BuildContext context, Ad ad) async {
  final url = '$kSiteUrl#/ad/${ad.id}';
  final text = [
    ad.title,
    [adPay(ad), ad.city].where((e) => e.isNotEmpty).join(' · '),
    'Объявление на ДелоЕсть — подработка рядом с домом',
  ].join('\n');
  try {
    await Share.share('$text\n$url', subject: ad.title);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: '$text\n$url'));
    if (context.mounted) toast(context, 'Ссылка скопирована');
  }
}
