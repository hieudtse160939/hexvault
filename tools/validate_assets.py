"""Validate every generated asset against assets/manifest.json.

Checks: file exists, sheet dimensions match frame grid, alpha is binary (no
half-transparent pixels -> no blur), sprite pixels use the master palette,
each animation frame is non-empty. Exit 1 on any failure.
"""
from __future__ import annotations

import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "artgen"))
from px import PAL_RGBA  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def res_to_path(res: str) -> str:
    return os.path.join(ROOT, res.replace("res://", ""))


def main() -> int:
    with open(os.path.join(ROOT, "assets", "manifest.json"), encoding="utf-8") as f:
        m = json.load(f)
    errors: list[str] = []
    checked = 0
    for key, s in m["sprites"].items():
        path = res_to_path(s["path"])
        if not os.path.exists(path):
            errors.append(f"{key}: missing {path}"); continue
        img = Image.open(path).convert("RGBA")
        fw, fh = s["frame_w"], s["frame_h"]
        if img.width % fw or img.height % fh:
            errors.append(f"{key}: {img.size} not a multiple of {fw}x{fh}")
        px = img.load()
        for name, a in s["anims"].items():
            if a["frames"] < 1:
                errors.append(f"{key}.{name}: no frames")
            for i in range(a["frames"]):
                x0, y0 = i * fw, a["row"] * fh
                if x0 + fw > img.width or y0 + fh > img.height:
                    errors.append(f"{key}.{name}[{i}] out of sheet bounds"); continue
                box = img.crop((x0, y0, x0 + fw, y0 + fh))
                if box.getbbox() is None:
                    errors.append(f"{key}.{name}[{i}] is empty")
        for y in range(img.height):
            for x in range(img.width):
                v = px[x, y]
                if v[3] not in (0, 255):
                    errors.append(f"{key}: semi-transparent pixel at {x},{y}"); break
                if v[3] == 255 and v not in PAL_RGBA:
                    errors.append(f"{key}: off-palette colour {v} at {x},{y}"); break
        checked += 1
    for key, s in m["images"].items():
        path = res_to_path(s["path"])
        if not os.path.exists(path):
            errors.append(f"{key}: missing {path}"); continue
        img = Image.open(path)
        if (img.width, img.height) != (s["w"], s["h"]):
            errors.append(f"{key}: size {img.size} != manifest {s['w']}x{s['h']}")
        checked += 1
    fnt = os.path.join(ROOT, "assets", "fonts", "hexvault.fnt")
    if not os.path.exists(fnt):
        errors.append("font missing")
    for e in errors[:50]:
        print("ERROR", e)
    print(f"checked={checked} errors={len(errors)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
