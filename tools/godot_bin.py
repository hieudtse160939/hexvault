"""Locate the Godot 4.7.2 binary for the current platform.

Order: $GODOT_BIN, then the portable copy in .tools/ for this OS.
See BUILD_GUIDE.md section 1 for how .tools/ is populated.
"""
from __future__ import annotations

import os
import platform

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
VERSION = "4.7.2-stable"

_CANDIDATES = {
    "Windows": [f"Godot_v{VERSION}_win64_console.exe", f"Godot_v{VERSION}_win64.exe"],
    "Linux": [f"Godot_v{VERSION}_linux.x86_64", f"Godot_v{VERSION}_linux.arm64"],
    "Darwin": ["Godot.app/Contents/MacOS/Godot"],
}


def godot_bin() -> str:
    env = os.environ.get("GODOT_BIN")
    if env:
        return env
    names = _CANDIDATES.get(platform.system(), [])
    for n in names:
        p = os.path.join(ROOT, ".tools", n)
        if os.path.exists(p):
            return p
    # Fall back to the first expected name so error messages point at the right file.
    return os.path.join(ROOT, ".tools", names[0] if names else "godot")
