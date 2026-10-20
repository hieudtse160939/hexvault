"""Normalise externally made art (AI generators, hand-drawn PNGs) into Hexvault HD assets.

Pipeline (pixel-art-studio's cleanup, then Hexvault's contract):
  raw PNG  -> art_src/raw/<id>.png         (copied once, never overwritten)
           -> key out a solid background (flood fill from the corners)
           -> recover true pixel scale     (Sprite.from_png scale="auto")
           -> harden alpha, despeckle, dedupe colours, dehalo
           -> lock to the HD master palette
           -> optional ink outline
           -> art_src/processed/<id>.png + <id>.json (config, prompt, stats)
Entries listed in art_src/external.json are added to assets/manifest.json by
tools/artgen/build.py like any generated sheet, so the same validation and
QA apply.

Usage:
  python tools/artgen/import_external.py <png> --id hero_x --frame 96x96 \
      --anims idle:6,run:8 --fps idle:6,run:12 [--prompt "..."] [--source "gpt-image-2"] [--outline]

The sheet must already be laid out as rows of frames (one row per animation).
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "pixel-art-studio", "scripts"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "hd"))

from canvas import palette_rgb  # noqa: E402
from pixelstudio import Sprite  # noqa: E402

RAW = os.path.join(ROOT, "art_src", "raw")
PROCESSED = os.path.join(ROOT, "art_src", "processed")
INDEX = os.path.join(ROOT, "art_src", "external.json")


def _pairs(spec: str, cast=int) -> dict:
    out = {}
    for part in filter(None, spec.split(",")):
        k, v = part.split(":")
        out[k.strip()] = cast(v)
    return out


def key_out_background(path: str, out: str, tol: int = 24) -> int:
    """Flood-fill from the four corners, clearing pixels close to the corner colour.

    Only reaches background connected to the border, so same-coloured details
    inside the sprite survive. Returns the number of cleared pixels."""
    from PIL import Image

    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    ref = px[0, 0]
    if ref[3] == 0:
        im.save(out)
        return 0
    seen = bytearray(w * h)
    stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    cleared = 0
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
            continue
        seen[y * w + x] = 1
        c = px[x, y]
        if max(abs(c[i] - ref[i]) for i in range(3)) > tol:
            continue
        px[x, y] = (0, 0, 0, 0)
        cleared += 1
        stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    im.save(out)
    return cleared


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("png")
    ap.add_argument("--id", required=True, help="manifest key, e.g. hero_ember")
    ap.add_argument("--frame", required=True, help="frame size WxH at final resolution, e.g. 96x96")
    ap.add_argument("--anims", required=True, help="name:frames,... in row order")
    ap.add_argument("--fps", default="", help="name:fps,...")
    ap.add_argument("--loop", default="idle,run", help="looping animation names")
    ap.add_argument("--scale", default="auto", help="pixel scale of the input ('auto', int or float)")
    ap.add_argument("--outline", action="store_true", help="add the 1 px ink outline")
    ap.add_argument("--keep-bg", action="store_true", help="do not key out a solid background")
    ap.add_argument("--prompt", default="")
    ap.add_argument("--source", default="external")
    args = ap.parse_args()

    os.makedirs(RAW, exist_ok=True)
    os.makedirs(PROCESSED, exist_ok=True)
    raw_path = os.path.join(RAW, args.id + ".png")
    if not os.path.exists(raw_path):
        shutil.copyfile(args.png, raw_path)
    fw, fh = (int(v) for v in args.frame.lower().split("x"))
    anims = _pairs(args.anims)

    work = os.path.join(PROCESSED, args.id + ".work.png")
    cleared = 0 if args.keep_bg else key_out_background(raw_path, work)
    if args.keep_bg:
        shutil.copyfile(raw_path, work)
    sp = Sprite.from_png(work, scale=args.scale if args.scale == "auto" else float(args.scale))
    before = sp.stats(print_=False)
    pal = ["#%02x%02x%02x" % c for c in sorted(palette_rgb())]
    sp.clean(palette=pal, despeckle_min=2, dedupe_tol=10, dehalo=True)
    if args.outline:
        sp.outline("#14101e", where="outside")
    after = sp.stats(print_=False)
    rows, cols = len(anims), max(anims.values())
    if sp.w < fw * cols or sp.h < fh * rows:
        print(f"ERROR: recovered image {sp.w}x{sp.h} is smaller than {cols}x{rows} frames of {fw}x{fh}")
        return 1
    out_png = os.path.join(PROCESSED, args.id + ".png")
    sp.save_png(out_png)
    os.remove(work)
    meta = {
        "id": args.id, "frame_w": fw, "frame_h": fh, "anims": anims,
        "fps": _pairs(args.fps), "loop": [s for s in args.loop.split(",") if s],
        "source": args.source, "prompt": args.prompt, "raw": os.path.relpath(raw_path, ROOT).replace(os.sep, "/"),
        "pipeline": {"scale": args.scale, "detected_scale": getattr(sp, "detected_scale", 1),
                     "background_pixels_cleared": cleared, "despeckle_min": 2, "dedupe_tol": 10, "dehalo": True, "palette": "hd", "outline": args.outline},
        "stats_before": before, "stats_after": after, "qa": "pending",
    }
    with open(os.path.join(PROCESSED, args.id + ".json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1, default=str)
    index = {}
    if os.path.exists(INDEX):
        with open(INDEX, encoding="utf-8") as f:
            index = json.load(f)
    index[args.id] = os.path.relpath(os.path.join(PROCESSED, args.id + ".json"), ROOT).replace(os.sep, "/")
    with open(INDEX, "w", encoding="utf-8") as f:
        json.dump(index, f, indent=1, sort_keys=True)
    print(f"processed {args.id}: {out_png}  colours {before.get('colors_used')} -> {after.get('colors_used')}")
    print("Run python tools/artgen/build.py, then python tools/check.py; set qa to 'pass' in the json after review.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
