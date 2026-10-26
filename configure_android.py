"""Настройка сгенерированного Android-проекта (запускается из папки shell).

Что делает:
  1. добавляет разрешения INTERNET, RECORD_AUDIO, POST_NOTIFICATIONS и запросы для звонков/ссылок;
  2. ставит название приложения «ДелоЕсть»;
  3. создаёт алиас значка (оранжевый);
  4. пишет MainActivity с MethodChannel 'ru.deloest.delo_est/launcher_icon', 'ru.deloest.delo_est/notify' (системные Push-уведомления), ярлыками значка и записью/воспроизведением голоса.
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
    '<uses-permission android:name="android.permission.RECORD_AUDIO"/>\n'
    '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
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
    '            <meta-data android:name="android.app.shortcuts" android:resource="@xml/shortcuts"/>\n'
    '        </activity-alias>\n'
)
aliases = '\n' + alias % dict(n='OrangeLauncher', en='true', ic='icon_orange')
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
for name in ('icon_orange',):
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

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingShortcut: String? = null

    // --- голосовые сообщения ---
    private var rec: MediaRecorder? = null
    private var recFile: File? = null
    private var recStart = 0L
    private var pendingPerm: MethodChannel.Result? = null
    private val reqAudio = 4711
    private val reqNotif = 4712
    private var player: MediaPlayer? = null
    private var playDone = false
    private var notifSeq = 100

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingShortcut = intent?.getStringExtra("shortcut")
        ensureNotifChannel()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val s = intent.getStringExtra("shortcut")
        if (s != null) pendingShortcut = s
    }

    override fun onDestroy() {
        releaseRec()
        releasePlayer()
        super.onDestroy()
    }

    private fun ensureNotifChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                "deloest_push",
                "Уведомления ДелоЕсть",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Сообщения, отклики и важные оповещения сервиса ДелоЕсть"
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(ch)
        }
    }

    private fun showSystemNotif(title: String, body: String, shortcut: String?) {
        if (Build.VERSION.SDK_INT >= 33) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), reqNotif)
                return
            }
        }
        ensureNotifChannel()
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (!shortcut.isNullOrEmpty()) putExtra("shortcut", shortcut)
        }
        val piFlags = if (Build.VERSION.SDK_INT >= 23)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        val pi = PendingIntent.getActivity(this, notifSeq, intent, piFlags)
        val builder = NotificationCompat.Builder(this, "deloest_push")
            .setSmallIcon(R.drawable.icon_orange)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pi)
        try {
            NotificationManagerCompat.from(this).notify(notifSeq++, builder.build())
        } catch (e: Exception) { }
    }

    private fun releaseRec() {
        try { rec?.release() } catch (e: Exception) { }
        rec = null
    }

    private fun releasePlayer() {
        try { player?.release() } catch (e: Exception) { }
        player = null
        playDone = false
    }

    private fun startRec(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            pendingPerm = result
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), reqAudio)
            return
        }
        doStartRec(result)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == reqAudio) {
            val r = pendingPerm
            pendingPerm = null
            if (r != null) {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) doStartRec(r)
                else r.success("denied")
            }
        }
    }

    private fun doStartRec(result: MethodChannel.Result) {
        try {
            releaseRec()
            val f = File(cacheDir, "rec_" + System.currentTimeMillis() + ".m4a")
            val r = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(this) else MediaRecorder()
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioChannels(1)
            r.setAudioSamplingRate(22050)
            r.setAudioEncodingBitRate(32000)
            r.setOutputFile(f.absolutePath)
            r.prepare()
            r.start()
            rec = r
            recFile = f
            recStart = System.currentTimeMillis()
            result.success("ok")
        } catch (e: Exception) {
            releaseRec()
            result.error("REC_FAILED", e.message, null)
        }
    }

    private fun stopRec(result: MethodChannel.Result) {
        val r = rec
        val f = recFile
        if (r == null || f == null) {
            result.success(null)
            return
        }
        val ms = System.currentTimeMillis() - recStart
        try {
            r.stop()
            releaseRec()
            result.success(mapOf("path" to f.absolutePath, "ms" to ms))
        } catch (e: Exception) {
            releaseRec()
            try { f.delete() } catch (x: Exception) { }
            result.success(null)
        }
    }

    private fun cancelRec(result: MethodChannel.Result) {
        val f = recFile
        try { rec?.stop() } catch (e: Exception) { }
        releaseRec()
        try { f?.delete() } catch (e: Exception) { }
        recFile = null
        result.success(true)
    }

    private fun play(path: String, result: MethodChannel.Result) {
        try {
            releasePlayer()
            val mp = MediaPlayer()
            mp.setDataSource(path)
            mp.setOnCompletionListener { playDone = true }
            mp.prepare()
            mp.start()
            player = mp
            playDone = false
            result.success(true)
        } catch (e: Exception) {
            releasePlayer()
            result.error("PLAY_FAILED", e.message, null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ru.deloest.delo_est/notify")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "request" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), reqNotif)
                        }
                        result.success(true)
                    }
                    "show" -> {
                        val args = call.arguments as? Map<*, *>
                        val title = (args?.get("title") as? String) ?: "ДелоЕсть"
                        val body = (args?.get("body") as? String) ?: ""
                        val sc = args?.get("shortcut") as? String
                        showSystemNotif(title, body, sc)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ru.deloest.delo_est/voice")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> startRec(result)
                    "stop" -> stopRec(result)
                    "cancel" -> cancelRec(result)
                    "play" -> play((call.arguments as? String) ?: "", result)
                    "pause" -> {
                        try { player?.pause() } catch (e: Exception) { }
                        result.success(true)
                    }
                    "resume" -> {
                        try { player?.start() } catch (e: Exception) { }
                        result.success(true)
                    }
                    "stopPlay" -> {
                        releasePlayer()
                        result.success(true)
                    }
                    "state" -> {
                        val mp = player
                        if (mp == null) {
                            result.success(mapOf("playing" to false, "pos" to 0, "dur" to 0, "done" to true))
                        } else {
                            try {
                                result.success(mapOf("playing" to mp.isPlaying, "pos" to mp.currentPosition, "dur" to mp.duration, "done" to playDone))
                            } catch (e: Exception) {
                                result.success(mapOf("playing" to false, "pos" to 0, "dur" to 0, "done" to true))
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ru.deloest.delo_est/shortcut")
            .setMethodCallHandler { call, result ->
                if (call.method == "take") {
                    val s = pendingShortcut
                    pendingShortcut = null
                    result.success(s)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ru.deloest.delo_est/launcher_icon")
            .setMethodCallHandler { call, result ->
                if (call.method != "setLauncherIcon") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val style = call.arguments as? String ?: "orange"
                val pm = packageManager
                val orange = ComponentName(this, "%(pkg)s.OrangeLauncher")
                try {
                    pm.setComponentEnabledSetting(
                        orange,
                        if (style == "orange") PackageManager.COMPONENT_ENABLED_STATE_ENABLED
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


# 6. Ярлыки при долгом нажатии на значок
res_dir = Path('android/app/src/main/res')
(res_dir / 'xml').mkdir(parents=True, exist_ok=True)
(res_dir / 'values').mkdir(parents=True, exist_ok=True)

shortcuts = [
    ('post', 'Разместить', 'Разместить объявление',
     'M19,13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z'),
    ('search', 'Поиск', 'Найти подработку',
     'M15.5,14h-0.79l-0.28,-0.27C15.41,12.59 16,11.11 16,9.5 16,5.91 13.09,3 9.5,3S3,5.91 3,9.5 5.91,16 9.5,16c1.61,0 3.09,-0.59 4.23,-1.57l0.27,0.28v0.79l5,4.99L20.49,19l-4.99,-5zM9.5,14C7.01,14 5,11.99 5,9.5S7.01,5 9.5,5 14,7.01 14,9.5 11.99,14 9.5,14z'),
    ('messages', 'Сообщения', 'Сообщения',
     'M20,2H4c-1.1,0 -2,0.9 -2,2v18l4,-4h14c1.1,0 2,-0.9 2,-2V4c0,-1.1 -0.9,-2 -2,-2zM20,16H5.17L4,17.17V4h16v12z'),
]
strings = ['<?xml version="1.0" encoding="utf-8"?>', '<resources>']
sc_xml = ['<?xml version="1.0" encoding="utf-8"?>',
          '<shortcuts xmlns:android="http://schemas.android.com/apk/res/android">']
for key, short, long_, path in shortcuts:
    (res / ('sc_%s.xml' % key)).write_text(
        '<vector xmlns:android="http://schemas.android.com/apk/res/android" '
        'android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">'
        '<path android:fillColor="#FFFF6B3D" android:pathData="%s"/></vector>' % path, encoding='utf-8')
    strings.append('    <string name="sc_%s_s">%s</string>' % (key, short))
    strings.append('    <string name="sc_%s_l">%s</string>' % (key, long_))
    sc_xml += [
        '    <shortcut android:shortcutId="%s" android:enabled="true" android:icon="@drawable/sc_%s"' % (key, key),
        '        android:shortcutShortLabel="@string/sc_%s_s" android:shortcutLongLabel="@string/sc_%s_l">' % (key, key),
        '        <intent android:action="android.intent.action.VIEW" android:targetPackage="%s" android:targetClass="%s.MainActivity">' % (pkg, pkg),
        '            <extra android:name="shortcut" android:value="%s"/>' % key,
        '        </intent>',
        '    </shortcut>',
    ]
strings.append('</resources>')
sc_xml.append('</shortcuts>')
(res_dir / 'values' / 'shortcut_strings.xml').write_text('\n'.join(strings) + '\n', encoding='utf-8')
(res_dir / 'xml' / 'shortcuts.xml').write_text('\n'.join(sc_xml) + '\n', encoding='utf-8')

print('Android настроен: пакет %s, значок, уведомления, ярлыки, MainActivity' % pkg)
