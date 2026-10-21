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
import ref_heroes  # noqa: E402
import enemies  # noqa: E402
import font  # noqa: E402
import items  # noqa: E402
import world  # noqa: E402
from px import Canvas, sheet, strip  # noqa: E402

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "hd"))
import hd_registry  # noqa: E402
import weapons as hd_weapons  # noqa: E402
import tiles as hd_tiles  # noqa: E402
import icons as hd_icons  # noqa: E402
import guild as hd_guild  # noqa: E402
import ui_art  # noqa: E402
from canvas import sheet as hd_sheet  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(ROOT, "assets")

manifest: dict = {"version": 2, "sprites": {}, "images": {}}


def _save(img: Image.Image, rel: str) -> str:
    path = os.path.join(ASSETS, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Only rewrite when pixels change: PNG bytes differ between Pillow
    # versions even for identical images, which would churn every asset.
    if os.path.exists(path):
        with Image.open(path) as old:
            same = old.size == img.size and old.convert("RGBA").tobytes() == img.convert("RGBA").tobytes()
        if same:
            return "res://assets/" + rel.replace(os.sep, "/")
    img.save(path, optimize=False)
    return "res://assets/" + rel.replace(os.sep, "/")


def _digest(img: Image.Image) -> str:
    return hashlib.sha256(img.tobytes()).hexdigest()[:16]


def _hd_import_settings(rel: str) -> None:
    """HD sheets are often drawn below 1:1 (small windows), so give them mipmaps.

    Godot keeps the [params] of an existing .import file and fills in the rest
    on the next import; 16 px art keeps the defaults (no mipmaps)."""
    path = os.path.join(ASSETS, rel) + ".import"
    if os.path.exists(path):
        return
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
                "[params]\n\ncompress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=true\n")


def _kind(rel: str) -> str:
    return rel.split("/")[1] if rel.startswith("sprites/") else rel.split("/")[0]


def add_sheet(key: str, rel: str, anims: dict[str, list[Canvas]], fps: dict | int,
              loop: dict | bool = True, pivot=None, hd: dict | None = None) -> None:
    """hd: for HD sheets, {"density", "version", "source"}; anims then hold PIL images."""
    img, meta = hd_sheet(anims) if hd else sheet(anims)
    res = _save(img, rel)
    for name, m in meta["anims"].items():
        m["fps"] = fps.get(name, 8) if isinstance(fps, dict) else fps
        m["loop"] = loop.get(name, False) if isinstance(loop, dict) else loop
    entry = {"path": res, "frame_w": meta["frame_w"], "frame_h": meta["frame_h"],
             "anims": meta["anims"], "sha": _digest(img), "type": _kind(rel),
             "density": 1, "palette": "master16", "version": 1, "source": "procedural: tools/artgen"}
    if hd:
        _hd_import_settings(rel)
        entry.update({"density": hd["density"], "palette": "hd", "version": hd["version"], "source": hd["source"]})
    if pivot:
        entry["pivot"] = list(pivot)
    manifest["sprites"][key] = entry


def add_image(key: str, rel: str, c: Canvas | Image.Image) -> None:
    img = c.img if isinstance(c, Canvas) else c
    res = _save(img, rel)
    manifest["images"][key] = {"path": res, "w": img.width, "h": img.height, "sha": _digest(img),
                               "type": _kind(rel), "density": 1, "version": 1, "source": "procedural: tools/artgen"}


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
    # heroes: HD sheets where a design exists, 16 px otherwise. The 16 px sheet
    # is always kept as hero_<id>_16 (title screen icon, app icon, fallbacks).
    ref = ref_heroes.build_all() if ref_heroes.available() else {}
    for hid, anims in ref.items():
        add_sheet(f"hero_{hid}", f"sprites/heroes/ref/{hid}.png", anims, ref_heroes.FPS, ref_heroes.LOOP,
                  pivot=ref_heroes.PIVOT, hd={"density": hd_registry.DENSITY, "version": 1,
                                              "source": "external: art_src/raw/heroes_reference.png via tools/artgen/ref_heroes.py"})
        manifest["sprites"][f"hero_{hid}"]["palette"] = "ref"
    for hid, spec in characters.HEROES.items():
        add_sheet(f"hero_{hid}_16", f"sprites/heroes/{hid}_16.png", characters.build(spec),
                  characters.FPS, characters.LOOP)
        mod = hd_registry.HEROES.get(hid)
        if hid in ref:
            continue
        if mod is not None:
            add_sheet(f"hero_{hid}", f"sprites/heroes/hd/{hid}.png", mod.animations(), mod.FPS, mod.LOOP,
                      pivot=mod.PIVOT, hd={"density": hd_registry.DENSITY, "version": mod.SPEC["version"], "source": mod.SPEC["source"]})
        else:
            add_sheet(f"hero_{hid}", f"sprites/heroes/{hid}.png", characters.build(spec),
                      characters.FPS, characters.LOOP)
    # enemies + boss
    for eid, fn in enemies.SHEETS.items():
        mod = hd_registry.ENEMIES.get(eid)
        if mod is not None:
            add_sheet(f"enemy_{eid}", f"sprites/enemies/hd/{eid}.png", mod.animations(), mod.FPS, mod.LOOP,
                      pivot=mod.PIVOT, hd={"density": hd_registry.DENSITY, "version": mod.SPEC["version"],
                                           "source": mod.SPEC["source"]})
        else:
            add_sheet(f"enemy_{eid}", f"sprites/enemies/{eid}.png", fn(), enemies.FPS, enemies.LOOP)
    # heroes that only exist in HD (no 16 px ancestor)
    for hid, mod in hd_registry.HEROES.items():
        if hid in characters.HEROES or hid in ref:
            continue
        add_sheet(f"hero_{hid}", f"sprites/heroes/hd/{hid}.png", mod.animations(), mod.FPS, mod.LOOP,
                  pivot=mod.PIVOT, hd={"density": hd_registry.DENSITY, "version": mod.SPEC["version"],
                                       "source": mod.SPEC["source"]})
    # HD skill icons
    for iid, fn in hd_icons.ICONS.items():
        add_image(f"icon_{iid}", f"ui/icons/hd/{iid}.png", fn().image())
        _hd_import_settings(f"ui/icons/hd/{iid}.png")
        manifest["images"][f"icon_{iid}"].update({"density": hd_registry.DENSITY, "palette": "hd",
                                                  "source": "procedural: tools/artgen/hd/icons.py"})
    # Adventurers' Guild: furniture, training dummy, equipment icons
    gsrc = {"density": hd_registry.DENSITY, "version": 1, "source": "procedural: tools/artgen/hd/guild.py"}
    for gid, (fn, pv) in hd_guild.PROPS.items():
        art = fn().image()
        framed = Image.new("RGBA", (art.width + 4, art.height + 4), (0, 0, 0, 0))  # 2 px QA margin
        framed.paste(art, (2, 2))
        add_sheet(f"guild_{gid}", f"sprites/props/hd/guild_{gid}.png", {"idle": [framed]}, 1, True,
                  (pv[0] + 2, pv[1] + 2), hd=gsrc)
    def _framed(img):
        out = Image.new("RGBA", (img.width + 4, img.height + 4), (0, 0, 0, 0))
        out.paste(img, (2, 2))
        return out
    add_sheet("guild_fireplace", "sprites/props/hd/guild_fireplace.png",
              {"idle": [_framed(hd_guild.fireplace(f).image()) for f in range(4)]}, 8, True,
              (hd_guild.FIREPLACE_PIVOT[0] + 2, hd_guild.FIREPLACE_PIVOT[1] + 2), hd=gsrc)
    for did, fn in list(hd_guild.DECALS.items()) + list(hd_guild.OVERHEAD.items()):
        d_img = _framed(fn().image())
        add_sheet(f"guild_{did}", f"sprites/props/hd/guild_{did}.png", {"idle": [d_img]}, 1, True,
                  (d_img.width // 2, d_img.height // 2), hd=gsrc)
    add_sheet("guild_dummy", "sprites/props/hd/guild_dummy.png", hd_guild.dummy_anims(), {"idle": 1, "hit": 14},
              {"idle": True, "hit": False}, hd_guild.DUMMY_PIVOT, hd=gsrc)
    for iid, fn in hd_guild.ICONS.items():
        add_image(f"icon_{iid}", f"ui/icons/hd/{iid}.png", fn().image())
        _hd_import_settings(f"ui/icons/hd/{iid}.png")
        manifest["images"][f"icon_{iid}"].update({"density": hd_registry.DENSITY, "palette": "hd",
                                                  "source": "procedural: tools/artgen/hd/guild.py"})
    # ornate Guild UI pieces (9-patch textures, UI pixel size)
    for uid, uimg in ui_art.all_images().items():
        add_image(uid, f"ui/frames/{uid}.png", uimg)
        manifest["images"][uid].update({"margin": ui_art.UI_MARGINS[uid], "source": "procedural: tools/artgen/ui_art.py"})
    # externally made art normalised by import_external.py (art_src/external.json)
    ext_index = os.path.join(ROOT, "art_src", "external.json")
    if os.path.exists(ext_index):
        with open(ext_index, encoding="utf-8") as f:
            for key, meta_rel in sorted(json.load(f).items()):
                with open(os.path.join(ROOT, meta_rel), encoding="utf-8") as mf:
                    em = json.load(mf)
                src = Image.open(os.path.join(ROOT, "art_src", "processed", key + ".png")).convert("RGBA")
                fw, fh = em["frame_w"], em["frame_h"]
                anims = {name: [src.crop((i * fw, row * fh, (i + 1) * fw, (row + 1) * fh)) for i in range(n)]
                         for row, (name, n) in enumerate(em["anims"].items())}
                add_sheet(key, f"sprites/external/{key}.png", anims, em.get("fps", {}) or 8,
                          {k: k in em.get("loop", []) for k in em["anims"]},
                          hd={"density": hd_registry.DENSITY, "version": 1, "source": "external: " + em["source"]})
    # turret summon
    add_sheet("turret", "sprites/props/turret.png", items.turret_sheet(), 4, True)
    # props
    for pid, (anims, fps) in world.props().items():
        add_sheet(f"prop_{pid}", f"sprites/props/{pid}.png", anims, fps,
                  {k: k in ("idle",) for k in anims})
    # weapons
    for wid in list(items.WEAPONS) + [w for w in hd_weapons.WEAPONS if w not in items.WEAPONS]:
        fn = items.WEAPONS.get(wid)
        hdw = hd_weapons.WEAPONS.get(wid)
        if hdw is None:
            add_sheet(f"weapon_{wid}", f"sprites/weapons/{wid}.png", {"idle": [fn()]}, 1, True, items.WEAPON_PIVOT)
            continue
        w_anims = hdw["anims"]() if "anims" in hdw else {"idle": [hdw["draw"]().image()]}
        add_sheet(f"weapon_{wid}", f"sprites/weapons/hd/{wid}.png", w_anims, 1, True,
                  hd_weapons.PIVOT, hd={"density": hd_registry.DENSITY, "version": hdw["version"],
                                        "source": "procedural: tools/artgen/hd/weapons.py"})
        manifest["sprites"][f"weapon_{wid}"]["muzzle"] = list(hdw["muzzle"])
    # projectiles / pickups
    for pid, frames in items.PROJECTILES.items():
        add_sheet(f"proj_{pid}", f"sprites/projectiles/{pid}.png", {"idle": frames}, 10, True)
    for pid, frames in items.PICKUPS.items():
        add_sheet(f"pickup_{pid}", f"sprites/pickups/{pid}.png", {"idle": frames}, 8, True)
    # fx
    for fid, (frames, fps) in items.FX.items():
        add_sheet(f"fx_{fid}", f"sprites/fx/{fid}.png", {"idle": frames}, fps, False)
    # tiles: HD atlas (64 px per 16-unit cell); index order = scripts/world/tiles.gd
    add_image("tiles_dungeon", "tiles/dungeon_hd.png", hd_tiles.atlas())
    _hd_import_settings("tiles/dungeon_hd.png")
    manifest["images"]["tiles_dungeon"].update({"density": hd_registry.DENSITY, "palette": "hd", "version": 1,
                                                "source": "procedural: tools/artgen/hd/tiles.py",
                                                "tile": 16 * hd_registry.DENSITY})
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
