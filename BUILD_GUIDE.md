# Hexvault — Build Guide

Engine: **Godot 4.7.2-stable** (official build `ed1daf0bf`), GDScript, GL Compatibility renderer.
Do not upgrade the engine without re-running `python tools/check.py` and a full export.

## 1. Toolchain setup (one time)

| Need | Used for | Where it lives |
| --- | --- | --- |
| Godot 4.7.2 editor (win64) | editing, tests, exports | `.tools/` (gitignored, *portable* via `.tools/_sc_`) |
| Godot 4.7.2 export templates | all exports | `.tools/editor_data/export_templates/4.7.2.stable/` |
| Python 3.10+ with Pillow + numpy | regenerating art/audio, tooling | system |
| ffmpeg (optional) | encoding music to OGG | system PATH |
| Android SDK (platform-tools + build-tools 35+) | Android export | e.g. `%LOCALAPPDATA%\Android\Sdk` |
| JDK 17+ | Android signing (`apksigner`) | e.g. Android Studio's `jbr` |
| macOS + Xcode 16+ | iOS | a Mac |

Download Godot exactly as was done for this project (checksums verified against the
release's `SHA512-SUMS.txt`):

```bash
mkdir -p .tools && cd .tools
B=https://github.com/godotengine/godot/releases/download/4.7.2-stable
curl -LO $B/SHA512-SUMS.txt
curl -LO $B/Godot_v4.7.2-stable_win64.exe.zip
curl -LO $B/Godot_v4.7.2-stable_export_templates.tpz
grep -E "win64.exe.zip|export_templates.tpz" SHA512-SUMS.txt | grep -v mono | sha512sum -c -
unzip Godot_v4.7.2-stable_win64.exe.zip
touch _sc_                                   # self-contained: settings stay in .tools/editor_data
mkdir -p editor_data/export_templates/4.7.2.stable
unzip Godot_v4.7.2-stable_export_templates.tpz -d tpl && mv tpl/templates/* editor_data/export_templates/4.7.2.stable/
```

Other platforms: use the matching Godot 4.7.2 editor binary; the project files are identical.

## 2. Day-to-day commands

```bash
python tools/artgen/build.py        # regenerate all sprites + assets/manifest.json (deterministic)
python tools/audiogen/build.py      # regenerate SFX (wav) and music (ogg)
python tools/validate_assets.py     # palette / alpha / frame checks on every asset
python tools/check.py               # assets + headless import + all unit/integration tests
python tools/package.py windows     # export + zip Windows
python tools/package.py android     # export debug APK
```

Run the game from source: `.tools/Godot_v4.7.2-stable_win64.exe --path .`
(open the editor with `-e`). Debug-only flags after `--`:
`--smoke-dungeon` (jump into a run), `--smoke-quit` (quit after 3 s via the real shutdown
path), `--tour=<abs dir>` (automated screenshot tour + frame timing report).

## 3. Windows (x64)

Preset: **Windows Desktop** in `export_presets.cfg` (x86_64, icon, version info; tests and
debug scripts excluded).

```bash
python tools/package.py windows
# -> build/windows/Hexvault.exe + Hexvault.pck
# -> build/Hexvault-0.9.0-windows-x64.zip   (exe + pck + README.txt)
```

Verified on this machine (Windows 11, Godot 4.7.2): export succeeds; the exported exe and the
exe extracted from the ZIP into an empty folder both boot into a dungeon run and exit with
code 0 and no errors in `%APPDATA%\Hexvault\logs`. Not yet verified on a separate clean PC —
the build only needs an OpenGL 3.3 capable GPU driver; no runtime installers are required.

Optional: code-sign `Hexvault.exe` with `signtool` before distribution (SmartScreen).

## 4. Android

Preset: **Android** — package `com.hexvault.game`, landscape (sensor), immersive mode,
arm64-v8a + x86_64, adaptive launcher icons, no Gradle build.

### Editor settings (already done in `.tools/editor_data/editor_settings-4.7.tres`)
```
export/android/android_sdk_path = "<Android SDK>"
export/android/java_sdk_path    = "<JDK root, e.g. Android Studio/jbr>"
export/android/debug_keystore   = "<repo>/.tools/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
```
Create the debug keystore once (it is gitignored):
```bash
keytool -genkeypair -keystore .tools/debug.keystore -storepass android -alias androiddebugkey \
  -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```

### Debug APK
```bash
python tools/package.py android        # -> build/android/hexvault-debug.apk
adb install -r build/android/hexvault-debug.apk
adb shell monkey -p com.hexvault.game -c android.intent.category.LAUNCHER 1
```

### Release (do this separately — never commit secrets)
1. Create an upload/release keystore **outside the repo**:
   `keytool -genkeypair -keystore ~/keys/hexvault-release.jks -alias hexvault -keyalg RSA -keysize 2048 -validity 10000`
2. Provide credentials through environment variables (Godot 4 reads these at export time):
   ```bash
   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/keys/hexvault-release.jks
   export GODOT_ANDROID_KEYSTORE_RELEASE_USER=hexvault
   export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...   # from your secret store
   ```
3. Bump `version/code` in the Android preset, then
   `.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Android" build/android/hexvault.aab`
   (set `gradle_build/export_format` to AAB and enable the Gradle build for Play Store uploads;
   that additionally requires the Android build template: *Project > Install Android Build Template*).

`export_presets.cfg` intentionally contains no keystore paths or passwords; `*.keystore`,
`*.jks` and `export_credentials.cfg` are gitignored.

## 5. iOS

Preset: **iOS** — bundle id `com.hexvault.game`, iPhone + iPad, 1024 px App Store icon.
**An iOS build cannot be produced on Windows.** Required:

1. A Mac with Xcode (16 or newer) and the Godot 4.7.2 macOS editor + the same export templates.
2. An Apple Developer account. Set the team in the preset:
   `application/app_store_team_id = "ABCDE12345"` (export aborts with
   *"App Store Team ID not specified."* without it).
3. A signing certificate + provisioning profile for `com.hexvault.game`
   (Xcode automatic signing is easiest).
4. Export: `godot --headless --path . --export-release "iOS" build/ios/Hexvault.ipa`
   — Godot writes an **Xcode project** next to the output; open `build/ios/Hexvault.xcodeproj`,
   select the team, build to a device, then *Product > Archive* for TestFlight / App Store.
5. Test touch controls, notch safe areas (handled by `SafeArea`), and app suspend/resume
   (the game auto-pauses and saves on `NOTIFICATION_APPLICATION_PAUSED`).

Status: preset configured and committed; **no iOS build has been produced or tested**
(no macOS host available).

## 6. Continuous integration (suggested)

`tools/check.py` is CI-ready (exit code 0/1). A GitHub Actions job can download Godot 4.7.2
the same way as section 1 (use the Linux binary), run `python tools/check.py`, then
`--export-release "Windows Desktop"` (cross-exporting Windows from Linux works with the
templates; icon/version resources are written natively by Godot 4.7).

## Android without the Android SDK (blocked network, CI containers)

`dl.google.com` may be unreachable, so the SDK build-tools cannot be installed. The exporter only
needs `adb` (to exist) and `apksigner`; `tools/android/apksigner_v2.py` is a small apksigner
replacement that signs with APK Signature Scheme v2 (valid on Android 7.0+, Godot 4's minimum).

```bash
mkdir -p .tools/android/sdk/build-tools/35.0.0 .tools/android/sdk/platform-tools
printf '#!/bin/sh\nexec python3 "$PWD/tools/android/apksigner_v2.py" "$@"\n' > .tools/android/sdk/build-tools/35.0.0/apksigner
printf '#!/bin/sh\nexit 0\n' > .tools/android/sdk/platform-tools/adb
chmod +x .tools/android/sdk/build-tools/35.0.0/apksigner .tools/android/sdk/platform-tools/adb
keytool -genkeypair -storetype PKCS12 -keystore .tools/android/debug.keystore -storepass android \
  -keypass android -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug"
# Editor settings (.tools/editor_data/editor_settings-4.7.tres):
#   export/android/android_sdk_path = "<repo>/.tools/android/sdk"
#   export/android/debug_keystore   = "<repo>/.tools/android/debug.keystore"
#   export/android/debug_keystore_user = "androiddebugkey", debug_keystore_pass = "android"
python tools/package.py android        # -> build/Hexvault-<ver>-android-debug.apk
python tools/android/apksigner_v2.py verify build/Hexvault-<ver>-android-debug.apk
```
Android templates come from the export template .tpz (`templates/android_debug.apk`, `android_release.apk`).
Debug builds only; a release keystore must never be committed.
