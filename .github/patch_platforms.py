#!/usr/bin/env python3
"""Uruchamiany raz po `flutter create`: nazwa, uprawnienia (aparat, mikrofon, mowa), stały klucz podpisu, Face ID."""
import glob, re, sys

def edit(path, pairs):
    s = open(path, encoding='utf-8').read()
    for old, new in pairs:
        if old not in s:
            sys.exit(f'PATCH FAILED: {path}: nie znaleziono {old!r}')
        s = s.replace(old, new, 1)
    open(path, 'w', encoding='utf-8').write(s)
    print('patched', path)

# --- Android: podpis i id ---
g = 'android/app/build.gradle.kts'
s = open(g, encoding='utf-8').read()
s = re.sub(r'applicationId = "[^"]+"', 'applicationId = "pl.dziennik.talerza"', s, count=1)
s = re.sub(r'minSdk = flutter\.minSdkVersion', 'minSdk = maxOf(flutter.minSdkVersion, 24)', s, count=1)
if 'signingConfigs.getByName("debug")' not in s or 'buildTypes {' not in s:
    sys.exit('PATCH FAILED: build.gradle.kts ma inny układ')
s = s.replace('    buildTypes {', '''    // Stały klucz w (prywatnym) repo – każda nowa wersja instaluje się jako aktualizacja.
    signingConfigs {
        create("dziennik") {
            storeFile = file("../../.github/dziennik.jks")
            storePassword = "dziennik123"
            keyAlias = "dziennik"
            keyPassword = "dziennik123"
        }
    }

    buildTypes {''', 1)
s = s.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("dziennik")\n            isMinifyEnabled = false\n            isShrinkResources = false')
open(g, 'w', encoding='utf-8').write(s)
print('patched', g)
# klucz zostaje w .github/ (android/.gitignore pomija *.jks)

m = 'android/app/src/main/AndroidManifest.xml'
s = open(m, encoding='utf-8').read()
s = re.sub(r'android:label="[^"]*"', 'android:label="Dziennik talerza"', s, count=1)
s = re.sub(r'(<manifest[^>]*>)', r'''\1
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>''', s, count=1)
# rozpoznawanie mowy (Android 11+ wymaga deklaracji usługi)
if '<queries>' in s:
    s = s.replace('<queries>', '''<queries>
        <intent>
            <action android:name="android.speech.RecognitionService"/>
        </intent>''', 1)
else:
    s = s.replace('</manifest>', '''    <queries>
        <intent>
            <action android:name="android.speech.RecognitionService"/>
        </intent>
    </queries>
</manifest>''', 1)
open(m, 'w', encoding='utf-8').write(s)
print('patched', m)

acts = glob.glob('android/app/src/main/kotlin/**/MainActivity.kt', recursive=True)
if not acts:
    sys.exit('PATCH FAILED: brak MainActivity.kt')
for a in acts:
    s = open(a, encoding='utf-8').read()
    s = s.replace('io.flutter.embedding.android.FlutterActivity', 'io.flutter.embedding.android.FlutterFragmentActivity')
    s = re.sub(r':\s*FlutterActivity\(\)', ': FlutterFragmentActivity()', s)
    open(a, 'w', encoding='utf-8').write(s)
    print('patched', a)

# --- iOS ---
p = 'ios/Runner/Info.plist'
s = open(p, encoding='utf-8').read()
s = re.sub(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)', r'\1Dziennik talerza\2', s, count=1)
s = re.sub(r'(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)', r'\1Dziennik talerza\2', s, count=1)
idx = s.rfind('</dict>')
extra = {
    'NSFaceIDUsageDescription': 'Face ID chroni dostęp do Twojego dziennika.',
    'NSCameraUsageDescription': 'Aparat służy do robienia zdjęć posiłków.',
    'NSPhotoLibraryUsageDescription': 'Dostęp do zdjęć pozwala dodać posiłek z galerii.',
    'NSMicrophoneUsageDescription': 'Mikrofon służy do dyktowania wpisów.',
    'NSSpeechRecognitionUsageDescription': 'Rozpoznawanie mowy zamienia dyktowane wpisy na tekst.',
}
s = s[:idx] + ''.join(f'\t<key>{k}</key>\n\t<string>{v}</string>\n' for k, v in extra.items()) + s[idx:]
open(p, 'w', encoding='utf-8').write(s)
print('patched', p)
