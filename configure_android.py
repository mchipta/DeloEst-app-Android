"""Настройка сгенерированного Android-проекта (запускается из папки shell).

Что делает:
  1. добавляет разрешение INTERNET и запросы для звонков/ссылок;
  2. ставит название приложения «ДелоЕсть»;
  3. создаёт два алиаса значка (оранжевый и фиолетовый) для выбора иконки в настройках;
  4. пишет MainActivity с MethodChannel 'ru.deloest.delo_est/launcher_icon'.
Любая ошибка останавливает сборку с понятным сообщением.
"""
import re
import shutil
import sys
import xml.dom.minidom
from pathlib import Path


def die(msg):
    print('::error::' + msg)
    sys.exit(1)


manifest = Path('android/app/src/main/AndroidManifest.xml')
if not manifest.exists():
    die('AndroidManifest.xml не найден: скрипт нужно запускать из папки shell')
text = manifest.read_text(encoding='utf-8')

if 'OrangeLauncher' in text:
    print('Уже настроено, пропускаю')
    sys.exit(0)

# 1. Разрешения и запросы
perm = (
    '<uses-permission android:name="android.permission.INTERNET"/>\n'
    '    <queries>\n'
    '        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>\n'
    '        <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>\n'
    '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n'
    '    </queries>\n'
    '    <application'
)
if '<application' not in text:
    die('В манифесте нет тега <application>')
text = text.replace('<application', perm, 1)

# 2. Название
text = re.sub(r'android:label="[^"]*"', 'android:label="ДелоЕсть"', text, count=1)

# 3. Снимаем LAUNCHER с MainActivity и вешаем его на алиасы
pattern = r'(<activity\b[^>]*android:name="[^"]*MainActivity"[^>]*>)(.*?)(</activity>)'
m = re.search(pattern, text, re.S)
if not m:
    die('MainActivity не найдена в AndroidManifest.xml')
body, n = re.subn(
    r'\s*<intent-filter>\s*<action android:name="android.intent.action.MAIN"\s*/>'
    r'\s*<category android:name="android.intent.category.LAUNCHER"\s*/>\s*</intent-filter>',
    '', m.group(2), flags=re.S)
if n != 1:
    die('Не удалось найти LAUNCHER-фильтр у MainActivity')
text = text[:m.start()] + m.group(1) + body + m.group(3) + text[m.end():]

alias = (
    '        <activity-alias android:name=".%(n)s" android:enabled="%(en)s" android:exported="true" '
    'android:icon="@drawable/%(ic)s" android:label="ДелоЕсть" android:targetActivity=".MainActivity">\n'
    '            <intent-filter>\n'
    '                <action android:name="android.intent.action.MAIN"/>\n'
    '                <category android:name="android.intent.category.LAUNCHER"/>\n'
    '            </intent-filter>\n'
    '        </activity-alias>\n'
)
aliases = '\n' + alias % dict(n='OrangeLauncher', en='true', ic='icon_orange') \
    + alias % dict(n='PurpleLauncher', en='false', ic='icon_purple')
if '</application>' not in text:
    die('В манифесте нет </application>')
text = text.replace('</application>', aliases + '    </application>', 1)

try:
    xml.dom.minidom.parseString(text.encode('utf-8'))
except Exception as e:
    die('Получился некорректный AndroidManifest.xml: %s' % e)
manifest.write_text(text, encoding='utf-8')

# 4. Картинки значков
res = Path('android/app/src/main/res/drawable')
res.mkdir(parents=True, exist_ok=True)
for name in ('icon_orange', 'icon_purple'):
    src = Path('assets/%s.png' % name)
    if not src.exists():
        die('Нет файла %s' % src)
    shutil.copy(src, res / (name + '.png'))

# 5. MainActivity (берём пакет из того, что создал flutter create)
main_dir = Path('android/app/src/main')
found = list(main_dir.rglob('MainActivity.kt')) + list(main_dir.rglob('MainActivity.java'))
if not found:
    die('MainActivity не найдена в android/app/src/main')
old = found[0]
pm = re.search(r'^\s*package\s+([\w.]+)', old.read_text(encoding='utf-8'), re.M)
if not pm:
    die('Не удалось определить package у MainActivity')
pkg = pm.group(1)
kt = old.with_suffix('.kt')
if old.suffix == '.java':
    old.unlink()

kt.write_text('''package %(pkg)s

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ru.deloest.delo_est/launcher_icon")
            .setMethodCallHandler { call, result ->
                if (call.method != "setLauncherIcon") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val style = call.arguments as? String ?: "orange"
                val pm = packageManager
                val orange = ComponentName(this, "%(pkg)s.OrangeLauncher")
                val purple = ComponentName(this, "%(pkg)s.PurpleLauncher")
                try {
                    pm.setComponentEnabledSetting(
                        orange,
                        if (style == "orange") PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                    pm.setComponentEnabledSetting(
                        purple,
                        if (style == "purple") PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ICON_CHANGE_FAILED", e.message, null)
                }
            }
    }
}
''' % dict(pkg=pkg), encoding='utf-8')

print('Android настроен: пакет %s, алиасы значков, MainActivity' % pkg)
