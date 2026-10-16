from pathlib import Path
import re
import shutil

manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text()
text = text.replace(
    '<application',
    '<uses-permission android:name="android.permission.INTERNET"/>\n'
    '    <queries><intent><action android:name="android.intent.action.DIAL"/>'
    '<data android:scheme="tel"/></intent></queries>\n    <application',
    1,
)
text = text.replace('android:label="delo_est"', 'android:label="ДелоЕсть"')
pattern = r'(<activity\b[^>]*android:name="[^"]*MainActivity"[^>]*>)(.*?)(</activity>)'
match = re.search(pattern, text, re.S)
if not match:
    raise SystemExit('MainActivity not found in AndroidManifest.xml')
body = re.sub(
    r'\s*<intent-filter>\s*<action android:name="android.intent.action.MAIN"\s*/>'
    r'\s*<category android:name="android.intent.category.LAUNCHER"\s*/>\s*</intent-filter>',
    '', match.group(2), flags=re.S,
)
text = text[:match.start()] + match.group(1) + body + match.group(3) + text[match.end():]
aliases = '''
        <activity-alias android:name=".OrangeLauncher" android:enabled="true" android:exported="true" android:icon="@drawable/icon_orange" android:label="ДелоЕсть" android:targetActivity=".MainActivity"><intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter></activity-alias>
        <activity-alias android:name=".PurpleLauncher" android:enabled="false" android:exported="true" android:icon="@drawable/icon_purple" android:label="ДелоЕсть" android:targetActivity=".MainActivity"><intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter></activity-alias>
'''
text = text.replace('</application>', aliases + '    </application>')
manifest.write_text(text)

res = Path('android/app/src/main/res/drawable')
res.mkdir(parents=True, exist_ok=True)
shutil.copy('assets/icon_orange.png', res / 'icon_orange.png')
shutil.copy('assets/icon_purple.png', res / 'icon_purple.png')

kotlin = Path('android/app/src/main/kotlin/ru/deloest/delo_est/MainActivity.kt')
kotlin.parent.mkdir(parents=True, exist_ok=True)
kotlin.write_text('''package ru.deloest.delo_est

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ru.deloest.delo_est/launcher_icon").setMethodCallHandler { call, result ->
      if (call.method != "setLauncherIcon") { result.notImplemented(); return@setMethodCallHandler }
      val style = call.arguments as? String ?: "orange"
      val pm = packageManager
      val orange = ComponentName(this, "$packageName.OrangeLauncher")
      val purple = ComponentName(this, "$packageName.PurpleLauncher")
      try {
        pm.setComponentEnabledSetting(orange, if (style == "orange") PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
        pm.setComponentEnabledSetting(purple, if (style == "purple") PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
        result.success(true)
      } catch (e: Exception) { result.error("ICON_CHANGE_FAILED", e.message, null) }
    }
  }
}
''')
print('Android manifest, launcher aliases and MainActivity configured')
