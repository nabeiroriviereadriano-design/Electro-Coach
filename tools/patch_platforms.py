"""Réglages appliqués aux dossiers générés par `flutter create`."""
import pathlib
import re
import sys

app = pathlib.Path(__file__).resolve().parent.parent / "app"
NAME = "BTS Électro Coach"


def edit(rel, fn):
    p = app / rel
    if not p.exists():
        print(f"(absent) {rel}")
        return
    s = p.read_text(encoding="utf-8")
    n = fn(s)
    if n != s:
        p.write_text(n, encoding="utf-8")
        print(f"modifié  {rel}")


# ---------------------------------------------------------------- Android
# Réseau : uniquement pour vérifier et télécharger les mises à jour sur GitHub.
PERMS = ('    <uses-permission android:name="android.permission.INTERNET"/>\n'
         '    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>\n')
PROVIDER = """
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.updates"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/update_paths"/>
        </provider>
"""


def manifest(s):
    s = re.sub(r'android:label="[^"]*"', f'android:label="{NAME}"', s, count=1)
    if "REQUEST_INSTALL_PACKAGES" not in s:
        s = s.replace("<application", PERMS + "    <application", 1)
    if "FileProvider" not in s:
        s = s.replace("</application>", PROVIDER + "    </application>", 1)
    return s


edit("android/app/src/main/AndroidManifest.xml", manifest)

xml = app / "android/app/src/main/res/xml"
if (app / "android").exists():
    xml.mkdir(parents=True, exist_ok=True)
    (xml / "update_paths.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<paths>\n    <cache-path name="updates" path="updates/"/>\n</paths>\n',
        encoding="utf-8")
    print("écrit    res/xml/update_paths.xml")

# Canal « electro_coach/update » : ouvrir l'installateur d'APK et des liens.
MAIN = """package {pkg}

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {{
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "electro_coach/update").setMethodCallHandler {{ call, result ->
            try {{
                when (call.method) {{
                    "installApk" -> {{
                        val path = call.argument<String>("path")
                        if (path == null) {{
                            result.error("arg", "chemin manquant", null)
                        }} else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {{
                            val settings = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + packageName))
                            settings.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(settings)
                            result.success("permission")
                        }} else {{
                            val uri = FileProvider.getUriForFile(this, packageName + ".updates", File(path))
                            val intent = Intent(Intent.ACTION_VIEW)
                            intent.setDataAndType(uri, "application/vnd.android.package-archive")
                            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success("started")
                        }}
                    }}
                    "openUrl" -> {{
                        val url = call.argument<String>("url") ?: ""
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }}
                    else -> result.notImplemented()
                }}
            }} catch (e: Exception) {{
                result.error("erreur", e.message, null)
            }}
        }}
    }}
}}
"""
for f in (app / "android/app/src/main").rglob("MainActivity.kt") if (app / "android").exists() else []:
    pkg = re.search(r"^package\s+([\w.]+)", f.read_text(encoding="utf-8"), re.M).group(1)
    f.write_text(MAIN.format(pkg=pkg), encoding="utf-8")
    print(f"écrit    {f.relative_to(app)}")


def deps_kts(s):
    if "androidx.core:core" in s:
        return s
    return s.rstrip() + '\n\ndependencies {\n    implementation("androidx.core:core:1.13.1")\n}\n'


def deps_groovy(s):
    if "androidx.core:core" in s:
        return s
    return s.rstrip() + "\n\ndependencies {\n    implementation 'androidx.core:core:1.13.1'\n}\n"


def gradle(s):
    s = s.replace("minSdk = flutter.minSdkVersion", "minSdk = maxOf(24, flutter.minSdkVersion)")
    s = s.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion Math.max(24, flutter.minSdkVersion)")
    return s


edit("android/app/build.gradle.kts", lambda s: deps_kts(gradle(s)))
edit("android/app/build.gradle", lambda s: deps_groovy(gradle(s)))

# ---------------------------------------------------------------- Windows
edit("windows/runner/main.cpp", lambda s: s.replace('L"electro_coach"', 'L"BTS \\u00C9lectro Coach"')
     .replace("Win32Window::Size size(1280, 720);", "Win32Window::Size size(1200, 860);"))


def rc(s):
    for key in ("FileDescription", "ProductName", "InternalName"):
        s = re.sub(r'(VALUE "%s", )"[^"]*"' % key, r'\1"BTS Electro Coach"', s)
    s = re.sub(r'(VALUE "CompanyName", )"[^"]*"', r'\1"ElectroCoach"', s)
    s = re.sub(r'(VALUE "OriginalFilename", )"[^"]*"', r'\1"ElectroCoach.exe"', s)
    s = re.sub(r'(VALUE "LegalCopyright", )"[^"]*"', r'\1"Logiciel libre et gratuit"', s)
    return s


edit("windows/runner/Runner.rc", rc)
edit("windows/CMakeLists.txt", lambda s: re.sub(r'set\(BINARY_NAME "[^"]*"\)', 'set(BINARY_NAME "ElectroCoach")', s))
print("ok")
sys.exit(0)
