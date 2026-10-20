"""Regenerate every Hexvault sprite + assets/manifest.json.

Usage:  python tools/artgen/build.py
Deterministic: the same source always produces byte-identical PNGs.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import characters  # noqa: E402
import enemies  # noqa: E402
import font  # noqa: E402
import items  # noqa: E402
import world  # noqa: E402
from px import Canvas, sheet, strip  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(ROOT, "assets")

manifest: dict = {"version": 1, "sprites": {}, "images": {}}


def _save(img: Image.Image, rel: str) -> str:
    path = os.path.join(ASSETS, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=False)
    return "res://assets/" + rel.replace(os.sep, "/")


def _digest(img: Image.Image) -> str:
    return hashlib.sha256(img.tobytes()).hexdigest()[:16]


def add_sheet(key: str, rel: str, anims: dict[str, list[Canvas]], fps: dict | int,
              loop: dict | bool = True, pivot=None) -> None:
    img, meta = sheet(anims)
    res = _save(img, rel)
    for name, m in meta["anims"].items():
        m["fps"] = fps.get(name, 8) if isinstance(fps, dict) else fps
        m["loop"] = loop.get(name, False) if isinstance(loop, dict) else loop
    entry = {"path": res, "frame_w": meta["frame_w"], "frame_h": meta["frame_h"],
             "anims": meta["anims"], "sha": _digest(img)}
    if pivot:
        entry["pivot"] = list(pivot)
    manifest["sprites"][key] = entry


def add_image(key: str, rel: str, c: Canvas | Image.Image) -> None:
    img = c.img if isinstance(c, Canvas) else c
    res = _save(img, rel)
    manifest["images"][key] = {"path": res, "w": img.width, "h": img.height, "sha": _digest(img)}


def app_icon(size: int) -> Image.Image:
    base = Canvas(32, 32)
    base.rect(0, 0, 31, 31, "night")
    base.ellipse(15.5, 15.5, 14, 14, "vio0")
    base.ring(15.5, 15.5, 14.5, "teal1")
    hero = characters.draw_hero(characters.HEROES["ranger"])
    base.blit(hero, 8, 6)
    for k, (x, y) in enumerate(((5, 7), (25, 9), (6, 24), (26, 23))):
        base.px(x, y, "teal3" if k % 2 else "amber3")
    return base.img.resize((size, size), Image.NEAREST)


def main() -> None:
    # heroes
    for hid, spec in characters.HEROES.items():
        add_sheet(f"hero_{hid}", f"sprites/heroes/{hid}.png", characters.build(spec),
                  characters.FPS, characters.LOOP)
    # enemies + boss
    for eid, fn in enemies.SHEETS.items():
        add_sheet(f"enemy_{eid}", f"sprites/enemies/{eid}.png", fn(), enemies.FPS, enemies.LOOP)
    # turret summon
    add_sheet("turret", "sprites/props/turret.png", items.turret_sheet(), 4, True)
    # props
    for pid, (anims, fps) in world.props().items():
        add_sheet(f"prop_{pid}", f"sprites/props/{pid}.png", anims, fps,
                  {k: k in ("idle",) for k in anims})
    # weapons
    for wid, fn in items.WEAPONS.items():
        add_sheet(f"weapon_{wid}", f"sprites/weapons/{wid}.png", {"idle": [fn()]}, 1, True, items.WEAPON_PIVOT)
    # projectiles / pickups
    for pid, frames in items.PROJECTILES.items():
        add_sheet(f"proj_{pid}", f"sprites/projectiles/{pid}.png", {"idle": frames}, 10, True)
    for pid, frames in items.PICKUPS.items():
        add_sheet(f"pickup_{pid}", f"sprites/pickups/{pid}.png", {"idle": frames}, 8, True)
    # fx
    for fid, (frames, fps) in items.FX.items():
        add_sheet(f"fx_{fid}", f"sprites/fx/{fid}.png", {"idle": frames}, fps, False)
    # tiles
    tiles = world.tileset()
    cols = 8
    atlas = Image.new("RGBA", (16 * cols, 16 * ((len(tiles) + cols - 1) // cols)), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        atlas.paste(t.img, ((i % cols) * 16, (i // cols) * 16))
    add_image("tiles_dungeon", "tiles/dungeon.png", atlas)
    # ui
    for k, c in items.ui_icons().items():
        add_image(f"icon_{k}", f"ui/icons/{k}.png", c)
    for k, c in items.touch_icons().items():
        add_image(f"touch_{k}", f"ui/touch/{k}.png", c)
    # font
    os.makedirs(os.path.join(ASSETS, "fonts"), exist_ok=True)
    font.build(os.path.join(ASSETS, "fonts", "hexvault.png"), os.path.join(ASSETS, "fonts", "hexvault.fnt"),
               "hexvault.png")
    # icons (project root icon + platform sizes)
    add_image("app_icon", "icon/icon.png", app_icon(256))
    add_image("app_icon_192", "icon/icon_192.png", app_icon(192))
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.paste(app_icon(256), (88, 88))
    add_image("app_icon_fg", "icon/adaptive_fg.png", fg)
    bgc = Canvas(1, 1); bgc.px(0, 0, "night")
    add_image("app_icon_bg", "icon/adaptive_bg.png", bgc.img.resize((432, 432), Image.NEAREST))
    add_image("app_icon_1024", "icon/icon_1024.png", app_icon(1024))

    with open(os.path.join(ASSETS, "manifest.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
        f.write("\n")
    print(f"sprites={len(manifest['sprites'])} images={len(manifest['images'])}")


if __name__ == "__main__":
    main()
