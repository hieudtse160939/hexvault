"""Run cycles from the user's sheets in art_src/raw/runs/<hero>_run.png.

Each sheet is AI-made (Gemini) pixel art on a flat dark background: one row of
8 run frames facing right, sometimes with a ground line, plus a watermark in
the bottom-right corner. For each sheet we:

1. flood-fill the background from the border (coarse 1/3 grid), drop the
   watermark, ground lines and specks;
2. split the row into 8 frames: connected components assigned to the frame
   whose cell holds their centre; components spanning two cells (a ponytail
   touching the next figure) are cut at the emptiest column between them;
3. downscale every frame by one factor chosen so the hero is as tall as its
   standing sprite, with a palette shared by all 8 frames (no flicker), dark
   outlines snapped to ink, despeckle, 1 px ink outline;
4. place frames on the 128 px hero canvas: torso centred on x, feet on a
   common ground line so airborne frames stay higher.

Raw files are never modified.
"""
from __future__ import annotations

import os

import numpy as np
from PIL import Image

import ref_heroes as rh

ROOT = rh.ROOT
RUNS = os.path.join(ROOT, "art_src", "raw", "runs")
FRAMES = 8
COARSE = 3
# These sheets are lossless PNGs with a perfectly flat background, so a tight
# tolerance keeps very dark clothing (Sable's outfit) intact.
BG_TOL = 18


def sheet_path(hid: str) -> str:
    return os.path.join(RUNS, f"{hid}_run.png")


def available(hid: str) -> bool:
    return os.path.exists(sheet_path(hid))


def _flood_bg(near_bg: np.ndarray) -> np.ndarray:
    h, w = near_bg.shape
    seen = np.zeros((h, w), dtype=bool)
    stack = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y, x] or not near_bg[y, x]:
            continue
        seen[y, x] = True
        stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return seen


def _label(mask: np.ndarray) -> tuple[np.ndarray, int]:
    h, w = mask.shape
    lab = np.zeros((h, w), dtype=np.int32)
    n = 0
    for y0 in range(h):
        for x0 in range(w):
            if not mask[y0, x0] or lab[y0, x0]:
                continue
            n += 1
            stack = [(x0, y0)]
            while stack:
                x, y = stack.pop()
                if x < 0 or y < 0 or x >= w or y >= h or lab[y, x] or not mask[y, x]:
                    continue
                lab[y, x] = n
                stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return lab, n


def _frames_mask(rgb: np.ndarray) -> list[np.ndarray]:
    """Coarse foreground masks (1/COARSE resolution), one per frame, left to right."""
    h, w = rgb.shape[:2]
    border = np.concatenate([rgb[:20].reshape(-1, 3), rgb[-20:].reshape(-1, 3), rgb[:, :20].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    coarse = rgb[::COARSE, ::COARSE].astype(np.int32)
    near = np.abs(coarse - bg).sum(-1) <= BG_TOL
    # ground lines: rows where dark pixels run across most of the sheet
    dark = coarse.max(-1) < 60
    for y in range(coarse.shape[0]):
        if dark[y].mean() > 0.5:
            near[y] |= dark[y]
    fg = ~_flood_bg(near)
    lab, n = _label(fg)
    ch, cw = fg.shape
    keep = np.zeros_like(fg)
    comps = []
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        area = len(xs)
        bw, bh = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
        cx, cy = xs.mean(), ys.mean()
        if area < 12:
            continue                                     # specks
        if bh <= 6 and bw > cw * 0.2:
            continue                                     # ground line
        if cx > cw * 0.9 and cy > ch * 0.8:
            continue                                     # watermark corner
        keep |= lab == i
        comps.append((i, xs.min(), xs.max(), cx, area))
    xs_all = np.nonzero(keep.any(0))[0]
    x0, x1 = xs_all.min(), xs_all.max() + 1
    cell = (x1 - x0) / FRAMES
    col_mass = keep.sum(0).astype(np.float32)
    # cut columns: emptiest column near each cell border
    cuts = [x0]
    for k in range(1, FRAMES):
        c = int(x0 + k * cell)
        lo, hi = int(c - cell * 0.3), int(c + cell * 0.3)
        cuts.append(lo + int(np.argmin(col_mass[lo:hi])))
    cuts.append(x1)
    masks = [np.zeros_like(fg) for _ in range(FRAMES)]
    for (i, cmin, cmax, cx, area) in comps:
        m = lab == i
        if cmax - cmin + 1 < cell * 1.15:
            k = min(FRAMES - 1, max(0, int(np.searchsorted(cuts, cx, side="right")) - 1))
            masks[k] |= m
        else:
            for k in range(FRAMES):
                part = m.copy()
                part[:, :cuts[k]] = False
                part[:, cuts[k + 1]:] = False
                masks[k] |= part
    return masks


def build(hid: str, target_height: int) -> list[Image.Image]:
    rgb = np.array(Image.open(sheet_path(hid)).convert("RGB"))
    masks = _frames_mask(rgb)
    boxes = []
    for m in masks:
        ys, xs = np.nonzero(m)
        boxes.append((xs.min() * COARSE, ys.min() * COARSE, (xs.max() + 1) * COARSE, (ys.max() + 1) * COARSE))
    heights = sorted(b[3] - b[1] for b in boxes)
    scale = float(np.median(heights)) / max(target_height, 1)
    ground = max(b[3] for b in boxes)
    smalls = []
    for m, (bx0, by0, bx1, by1) in zip(masks, boxes):
        crop = rgb[by0:by1, bx0:bx1].astype(np.int32)
        full = np.repeat(np.repeat(m, COARSE, 0), COARSE, 1)[by0:by1, bx0:bx1]
        smalls.append((rh._downscale(crop, full, scale), by1))
    # one palette for all frames
    strip = Image.new("RGBA", (sum(s.width for s, _ in smalls), max(s.height for s, _ in smalls)), (0, 0, 0, 0))
    x = 0
    for s, _ in smalls:
        strip.paste(s, (x, 0))
        x += s.width
    a = np.array(strip)
    alpha = a[..., 3] > 0
    pal_img = Image.fromarray(a[..., :3], "RGB").quantize(colors=rh.MAX_COLOURS, method=Image.Quantize.FASTOCTREE,
                                                          dither=Image.Dither.NONE)
    out = []
    x = 0
    for s, bottom in smalls:
        q = Image.fromarray(a[:, x:x + s.width, :3], "RGB").quantize(palette=pal_img, dither=Image.Dither.NONE).convert("RGB")
        fr = np.zeros((strip.height, s.width, 4), dtype=np.uint8)
        fr[..., :3] = np.array(q)
        fr[..., 3] = np.where(alpha[:, x:x + s.width], 255, 0)
        fr[fr[..., 3] == 0] = 0
        x += s.width
        img = Image.fromarray(fr, "RGBA")
        img = rh._despeckle(rh._snap_dark_to_ink(img))
        bb = img.getbbox()
        img = img.crop(bb)
        padded = Image.new("RGBA", (img.width + 2, img.height + 2), (0, 0, 0, 0))
        padded.paste(img, (1, 1))
        img = rh._outline(padded)
        # anchor: torso centre (rows 35-70 % of the frame) on CX, feet on the shared ground
        op = np.array(img)[..., 3] > 0
        hh = op.shape[0]
        band = op[int(hh * 0.35):int(hh * 0.7)]
        cx = float(np.nonzero(band)[1].mean()) if band.any() else img.width / 2
        lift = int(round((ground - bottom) / scale))
        frame = Image.new("RGBA", (rh.FRAME, rh.FRAME), (0, 0, 0, 0))
        frame.alpha_composite(img, (int(round(rh.CX - cx)), rh.GROUND - img.height - lift))
        out.append(frame)
    return out


if __name__ == "__main__":
    import sys
    for hid in sys.argv[1:] or ["duelist"]:
        fr = build(hid, 84)
        print(hid, [f.getbbox() for f in fr])
