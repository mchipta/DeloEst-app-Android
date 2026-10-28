// Иконки сайта (тот же набор линейных SVG 24×24, обводка 2), чтобы приложение и сайт выглядели одинаково.
// Файл создан из спрайта index.html. Использование: Ico('chat', size: 22, color: p.ac)
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

const Map<String, String> _body = {
  'bell': '<path d="M6 9a6 6 0 0 1 12 0c0 6 2.5 7.5 2.5 7.5h-17S6 15 6 9zM10 20a2 2 0 0 0 4 0"/>',
  'bello': '<path d="M8.5 4.6A6 6 0 0 1 18 9c0 3 .7 4.9 1.5 6M6 9c0 6-2.5 7.5-2.5 7.5H15M10 20a2 2 0 0 0 4 0M3 3l18 18"/>',
  'logo': '<rect x="3" y="3" width="18" height="18" rx="6"/><path d="M8 12l3 3 5-6"/>',
  'search': '<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>',
  'sun': '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  'moon': '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>',
  'build': '<path d="M3 21l8-8M13 4l7 7-3 3-7-7zM6 3l4 4"/>',
  'truck': '<path d="M3 6h11v10H3zM14 9h4l3 3v4h-7"/><circle cx="7" cy="18" r="2"/><circle cx="17" cy="18" r="2"/>',
  'spark': '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8zM19 17v4M17 19h4"/>',
  'box': '<path d="M3 8l9-5 9 5v8l-9 5-9-5zM3 8l9 5 9-5M12 13v8"/>',
  'leaf': '<path d="M5 19c0-9 5-14 15-14 0 10-5 15-14 15zM5 19l8-8"/>',
  'book': '<path d="M4 4h16v14H6a2 2 0 0 0-2 2zM8 8h8M8 12h5"/>',
  'laptop': '<path d="M4 5h16v10H4zM2 19h20"/>',
  'gear': '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>',
  'party': '<path d="M5 21l4-12 8 8zM14 4l1 3M19 9l3 1M17 2l.5 2"/>',
  'more': '<circle cx="5" cy="12" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="19" cy="12" r="1.5"/>',
  'user': '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  'shield': '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6zM9 12l2 2 4-4"/>',
  'bolt': '<path d="M13 2L4 14h7l-1 8 9-12h-7z"/>',
  'chat': '<path d="M4 5h16v11H9l-5 4z"/>',
  'pin': '<path d="M12 21s7-6 7-12a7 7 0 0 0-14 0c0 6 7 12 7 12z"/><circle cx="12" cy="9" r="2"/>',
  'mail': '<path d="M3 5h18v14H3zM3 6l9 7 9-7"/>',
  'phone': '<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z"/>',
  'play': '<path d="M8 5v14l11-7z"/>',
  'pause': '<path d="M7 5h4v14H7zM13 5h4v14h-4z"/>',
  'mic': '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>',
  'sliders': '<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="17" r="2"/>',
  'grid': '<rect x="4" y="4" width="6" height="6" rx="1.5"/><rect x="14" y="4" width="6" height="6" rx="1.5"/><rect x="4" y="14" width="6" height="6" rx="1.5"/><rect x="14" y="14" width="6" height="6" rx="1.5"/>',
  'star': '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z"/>',
  'plus': '<path d="M12 5v14M5 12h14"/>',
  'home': '<path d="M3 11l9-8 9 8M5 10v10h14V10"/>',
  'arrow': '<path d="M5 12h14M13 6l6 6-6 6"/>',
  'clock': '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  'monitor': '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/>',
  'share': '<path d="M12 15V3M8 7l4-4 4 4M7 11H6a1 1 0 0 0-1 1v8a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-8a1 1 0 0 0-1-1h-1"/>',
  'download': '<path d="M12 3v12M8 11l4 4 4-4M5 21h14"/>',
  'work': '<rect x="3" y="7" width="18" height="13" rx="2.5"/><path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/>',
  'bolt2': '<path fill="currentColor" stroke="none" d="M11 21h-1l1-7H7.5c-.58 0-.57-.32-.38-.66.19-.34.05-.08.07-.12C8.48 10.94 10.42 7.54 13 3h1l-1 7h3.5c.49 0 .56.33.47.51l-.07.15C12.96 17.55 11 21 11 21z"/>',
  'sendo': '<path fill="currentColor" stroke="none" d="M4.01 6.03l7.51 3.22-7.52-1 .01-2.22m7.5 8.72L4 17.97v-2.22l7.51-1M2.01 3L2 10l15 2-15 2 .01 7L23 12 2.01 3z"/>',
  'sendr': '<path fill="currentColor" stroke="none" d="M3.4 20.4l17.45-7.48c.81-.35.81-1.49 0-1.84L3.4 3.6c-.66-.29-1.39.2-1.39.91L2 9.12c0 .5.37.93.87.99L17 12 2.87 13.88c-.5.07-.87.5-.87 1l.01 4.61c0 .71.73 1.2 1.39.91z"/>',
  'open': '<path d="M14 4h6v6M20 4l-9 9"/><path d="M18 14v4a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4"/>',
  'eyeoff': '<path d="M3 3l18 18"/><path d="M10.6 6.1A9.8 9.8 0 0 1 12 6c6.4 0 10 6 10 6a17 17 0 0 1-3.2 3.9M6.6 7.7A17 17 0 0 0 2 12s3.6 7 10 7a9.9 9.9 0 0 0 4.2-.9"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
  'pub': '<path d="M5 4h14M12 20V9M7 13l5-5 5 5"/>',
  'nodes': '<circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="M8.6 13.5l6.8 4M15.4 6.5l-6.8 4"/>',
  'logout': '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="M16 17l5-5-5-5M21 12H9"/>',
  'admin': '<path d="M12 3l7 3v5c0 4.5-3 8.2-7 9.5C8 19.2 5 15.5 5 11V6z"/><circle cx="12" cy="10" r="1.8"/><path d="M8.9 15a3.4 3.4 0 0 1 6.2 0"/>',
  'mobile': '<rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/>',
  'send': '<path d="M22 2L11 13M22 2l-7 20-4-9-9-4z"/>',
  'vk': '<path d="M2.5 8.5l3.5 7 3.5-7M13.5 8.5v7M19.5 8.5L15 12l4.5 3.5"/>',
  'heart': '<path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/>',
  'check': '<path d="M5 12.5l4.5 4.5L19 7"/>',
  'alert': '<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.5M12 16.5v.1"/>',
  'eye': '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  'calendar': '<rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
  'camera': '<path d="M4 8h3l1.5-2h7L17 8h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>',
  'edit': '<path d="M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4"/>',
  'trash': '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
  'x': '<path d="M6 6l12 12M18 6L6 18"/>',
  'copy': '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V6a2 2 0 0 1 2-2h9"/>',
};

class Ico extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const Ico(this.name, {super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? const Color(0xFF000000);
    final body = _body[name] ?? _body['more']!;
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$body</svg>';
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      theme: SvgTheme(currentColor: c),
    );
  }
}
