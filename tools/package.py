"""Export and package release builds.

Usage:
  python tools/package.py windows      # export release exe + zip it
  python tools/package.py android      # export debug APK
  python tools/package.py ios          # export Xcode project (macOS only)
  python tools/package.py all

Uses GODOT_BIN or the portable Godot in .tools/ (see tools/godot_bin.py).
Writes into build/ (gitignored). Prints sizes and SHA-256 of every artifact.
"""
from __future__ import annotations

import hashlib
import os
import platform
import subprocess
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.dirname(__file__))
from godot_bin import godot_bin  # noqa: E402

GODOT = godot_bin()
VERSION = "0.9.0"

PLAYER_README = """HEXVAULT {v} - Windows x64
==========================

Run Hexvault.exe. Keep Hexvault.pck in the same folder.

Controls: WASD move, mouse aim, left click shoot, right click / Q skill,
Space dash, Tab swap weapon, E interact, R reload, M map, Esc pause.
Xbox / PlayStation gamepads are supported.

Saves: %APPDATA%\\Hexvault\\profile.save (+ .bak backup)
Settings: %APPDATA%\\Hexvault\\settings.save
Everything works offline. No account needed.
"""


def sha(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def export(preset: str, out: str, debug: bool = False) -> None:
    os.makedirs(os.path.dirname(os.path.join(ROOT, out)), exist_ok=True)
    flag = "--export-debug" if debug else "--export-release"
    r = subprocess.run([GODOT, "--headless", "--path", ROOT, flag, preset, out], cwd=ROOT,
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    errors = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith("ERROR") or "SCRIPT ERROR" in l]
    if r.returncode != 0 or not os.path.exists(os.path.join(ROOT, out)):
        print((r.stdout + r.stderr)[-4000:])
        raise SystemExit(f"export of {preset} failed (exit {r.returncode})")
    for e in errors:
        print("  ", e)


def report(path: str) -> None:
    print(f"  {os.path.relpath(path, ROOT)}  {os.path.getsize(path) / 1e6:.1f} MB  sha256={sha(path)[:16]}...")


def windows() -> None:
    export("Windows Desktop", "build/windows/Hexvault.exe")
    z = os.path.join(ROOT, "build", f"Hexvault-{VERSION}-windows-x64.zip")
    with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for name in ("Hexvault.exe", "Hexvault.pck"):
            zf.write(os.path.join(ROOT, "build", "windows", name), f"Hexvault/{name}")
        zf.writestr("Hexvault/README.txt", PLAYER_README.format(v=VERSION))
    print("windows:")
    report(z)


def android() -> None:
    export("Android", "build/android/hexvault-debug.apk", debug=True)
    print("android (debug):")
    report(os.path.join(ROOT, "build", "android", "hexvault-debug.apk"))


def ios() -> None:
    if platform.system() != "Darwin":
        print("ios: skipped - the iOS export needs macOS + Xcode (see BUILD_GUIDE.md)")
        return
    export("iOS", "build/ios/Hexvault.ipa")
    print("ios:")
    report(os.path.join(ROOT, "build", "ios", "Hexvault.ipa"))


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "all"
    for t, fn in (("windows", windows), ("android", android), ("ios", ios)):
        if target in (t, "all"):
            fn()
