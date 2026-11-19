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
# Application 100 % hors ligne : aucune permission réseau.
edit("android/app/src/main/AndroidManifest.xml",
     lambda s: re.sub(r'android:label="[^"]*"', f'android:label="{NAME}"', s, count=1))


def gradle(s):
    s = s.replace("minSdk = flutter.minSdkVersion", "minSdk = maxOf(24, flutter.minSdkVersion)")
    s = s.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion Math.max(24, flutter.minSdkVersion)")
    return s


edit("android/app/build.gradle.kts", gradle)
edit("android/app/build.gradle", gradle)

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
