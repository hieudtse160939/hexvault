"""Hero sprites from the user's reference sheet (art_src/raw/heroes_reference.png).

The sheet is upscaled, slightly soft AI pixel art: 12 heroes in one idle pose
each, two rows in roster order. This module turns it into game sheets:

1. find each hero (background flood-filled from the crop border, so dark
   clothing inside the silhouette is kept);
2. block-downscale by one shared factor (median colour per block, binary
   alpha), so every hero has the same pixel density;
3. per-hero adaptive palette (<= 52 colours), despeckle, 1 px ink outline;
4. animate the single pose by cut-out puppeting: breathing, a bouncing run
   with a leg scissor, a dash lean, a skill crouch + glow, hurt recoil and a
   fall-over death. Feet stay on the frame's ground line (manifest pivot).

The raw file is never modified. Everything is deterministic.
"""
from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(ROOT, "art_src", "raw", "heroes_reference.png")
PROCESSED = os.path.join(ROOT, "art_src", "processed")

# Roster order on the sheet: row 1 then row 2, left to right.
ORDER = ["ranger", "warden", "hexer", "tinker", "duelist", "pyromancer",
         "cryomancer", "stormcaller", "necromancer", "assassin", "paladin", "artillerist"]
# Skill glow colour per hero (RGB), to match its kit / skill.
GLOW = {
    "ranger": (255, 226, 138), "warden": (180, 255, 240), "hexer": (227, 184, 255), "tinker": (180, 255, 240),
    "duelist": (255, 154, 162), "pyromancer": (255, 226, 138), "cryomancer": (224, 248, 255),
    "stormcaller": (227, 184, 255), "necromancer": (180, 255, 240), "assassin": (227, 184, 255),
    "paladin": (255, 226, 138), "artillerist": (255, 226, 138),
}

SCALE = 3.3          # source px per art px (shared by all heroes)
FRAME = 128
CX, GROUND = 64, 112
PIVOT = (CX, GROUND)
INK = (20, 16, 30, 255)
BG_TOL = 34
MAX_COLOURS = 52

FPS = {"idle": 6, "run": 12, "dash": 16, "skill": 12, "hurt": 12, "death": 9}
LOOP = {"idle": True, "run": True, "dash": True, "skill": False, "hurt": False, "death": False}


def available() -> bool:
    return os.path.exists(RAW)


# --- extraction ----------------------------------------------------------------------
def _boxes(rgb: np.ndarray, bg: np.ndarray) -> list[tuple[int, int, int, int]]:
    mask = np.abs(rgb - bg).sum(-1) > BG_TOL + 2
    h, w = mask.shape
    rows = mask.any(1)
    bands, inb, y0 = [], False, 0
    for y in range(h + 1):
        on = y < h and rows[y]
        if on and not inb:
            y0, inb = y, True
        elif not on and inb:
            if y - y0 > 50:
                bands.append((y0, y))
            inb = False
    out = []
    for (b0, b1) in bands:
        cols = mask[b0:b1].any(0)
        x0, last, gap = None, 0, 0
        runs = []
        for x in range(w):
            if cols[x]:
                if x0 is None:
                    x0 = x
                last, gap = x, 0
            elif x0 is not None:
                gap += 1
                if gap > 60:
                    runs.append((x0, last + 1))
                    x0 = None
        if x0 is not None:
            runs.append((x0, last + 1))
        for (a, b) in runs:
            if b - a > 40:
                ys = np.nonzero(mask[b0:b1, a:b].any(1))[0]
                out.append((a, b0 + int(ys[0]), b, b0 + int(ys[-1]) + 1))
    return out


def _foreground(crop: np.ndarray, bg: np.ndarray) -> np.ndarray:
    """Pixels not reachable from the crop border through background-coloured pixels."""
    near_bg = np.abs(crop - bg).sum(-1) <= BG_TOL
    h, w = near_bg.shape
    seen = np.zeros((h, w), dtype=bool)
    stack = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y, x] or not near_bg[y, x]:
            continue
        seen[y, x] = True
        stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return ~seen


def _downscale(crop: np.ndarray, fg: np.ndarray) -> Image.Image:
    h, w = fg.shape
    tw, th = int(math.ceil(w / SCALE)), int(math.ceil(h / SCALE))
    out = np.zeros((th, tw, 4), dtype=np.uint8)
    for ty in range(th):
        y0, y1 = int(round(ty * SCALE)), min(h, int(round((ty + 1) * SCALE)))
        for tx in range(tw):
            x0, x1 = int(round(tx * SCALE)), min(w, int(round((tx + 1) * SCALE)))
            f = fg[y0:y1, x0:x1]
            if f.size == 0 or f.mean() < 0.5:
                continue
            # centre-weighted: use the inner part of the block when it is foreground
            px = crop[y0:y1, x0:x1][f]
            out[ty, tx, :3] = np.median(px, axis=0).astype(np.uint8)
            out[ty, tx, 3] = 255
    return Image.fromarray(out, "RGBA")


def _quantize(img: Image.Image) -> Image.Image:
    a = np.array(img)
    alpha = a[..., 3] > 0
    rgb = Image.fromarray(a[..., :3], "RGB")
    q = rgb.quantize(colors=MAX_COLOURS, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGB")
    out = np.zeros_like(a)
    out[..., :3] = np.array(q)
    out[..., 3] = np.where(alpha, 255, 0)
    out[~alpha] = 0
    return Image.fromarray(out, "RGBA")


def _snap_dark_to_ink(img: Image.Image, limit: int = 58) -> Image.Image:
    """The sheet's own outlines blur into many near-black shades when
    downscaled; snap them all to the shared ink colour (clean 1 px lines)."""
    a = np.array(img)
    op = a[..., 3] > 0
    dark = op & (a[..., :3].max(-1) < limit)
    a[dark] = INK
    return Image.fromarray(a, "RGBA")


def _despeckle(img: Image.Image, passes: int = 2) -> Image.Image:
    for _ in range(passes):
        img = _despeckle_once(img)
    return img


def _despeckle_once(img: Image.Image) -> Image.Image:
    a = np.array(img)
    h, w = a.shape[:2]
    key = (a[..., 0].astype(np.int64) << 16) | (a[..., 1].astype(np.int64) << 8) | a[..., 2]
    op = a[..., 3] > 0
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if not op[y, x]:
                continue
            nb = [(y + dy, x + dx) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            if not all(op[p] for p in nb):
                continue
            ks = [key[p] for p in nb]
            best = max(set(ks), key=ks.count)
            if key[y, x] in ks and ks.count(best) < 3:
                continue
            if best != key[y, x] and ks.count(best) >= (3 if key[y, x] in ks else 2):
                p = nb[ks.index(best)]
                a[y, x] = a[p]
                key[y, x] = best
    return Image.fromarray(a, "RGBA")


def _outline(img: Image.Image) -> Image.Image:
    a = np.array(img)
    op = a[..., 3] > 0
    pad = np.pad(op, 1)
    ring = (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]) & ~op
    a[ring] = INK
    return Image.fromarray(a, "RGBA")


def extract() -> dict[str, Image.Image]:
    """Clean 1x sprite per hero id (no frame padding yet)."""
    src = Image.open(RAW).convert("RGB")
    rgb = np.array(src).astype(np.int32)
    bg = np.median(np.concatenate([rgb[:12, :12].reshape(-1, 3), rgb[-12:, -12:].reshape(-1, 3)]), axis=0)
    boxes = _boxes(rgb, bg)
    if len(boxes) != len(ORDER):
        raise SystemExit(f"ref_heroes: expected {len(ORDER)} heroes on the sheet, found {len(boxes)}")
    out = {}
    for hid, (x0, y0, x1, y1) in zip(ORDER, boxes):
        m = 6
        crop = rgb[max(0, y0 - m):y1 + m, max(0, x0 - m):x1 + m]
        fg = _foreground(crop, bg)
        small = _downscale(crop, fg)
        small = _despeckle(_snap_dark_to_ink(_quantize(small)))
        bb = small.getbbox()
        small = small.crop(bb)
        # pad by 1 for the outline
        padded = Image.new("RGBA", (small.width + 2, small.height + 2), (0, 0, 0, 0))
        padded.paste(small, (1, 1))
        out[hid] = _outline(padded)
    return out


# --- puppeting -----------------------------------------------------------------------
def _place(sprite: Image.Image, dx: int = 0, dy: int = 0) -> Image.Image:
    f = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    f.alpha_composite(sprite, (CX - sprite.width // 2 + dx, GROUND - sprite.height + dy))
    return f


def _bands(sprite: Image.Image) -> tuple[int, int]:
    """Rows where the head ends and the legs begin (fractions of the height)."""
    h = sprite.height
    return int(h * 0.48), int(h * 0.80)


def _shift_rows(sprite: Image.Image, fn) -> Image.Image:
    """Shift each row horizontally by fn(row) px (integer), keeping the canvas size."""
    a = np.array(sprite)
    out = np.zeros_like(a)
    w = a.shape[1]
    for y in range(a.shape[0]):
        s = int(round(fn(y)))
        if s >= 0:
            out[y, s:] = a[y, :w - s] if s else a[y]
        else:
            out[y, :w + s] = a[y, -s:]
    return Image.fromarray(out, "RGBA")


def _pad(sprite: Image.Image, px: int = 8) -> Image.Image:
    p = Image.new("RGBA", (sprite.width + 2 * px, sprite.height), (0, 0, 0, 0))
    p.paste(sprite, (px, 0))
    return p


def _drop_upper(sprite: Image.Image, rows: int, at: int) -> Image.Image:
    """Squash: the part above row `at` slides down by `rows` over the legs."""
    if rows <= 0:
        return sprite
    a = np.array(sprite)
    out = np.zeros_like(a)
    out[at:] = a[at:]
    upper = a[:at]
    region = out[rows:at + rows]
    m = upper[..., 3] > 0
    region[m] = upper[m]
    return Image.fromarray(out, "RGBA")


def _tint(sprite: Image.Image, rgb: tuple[int, int, int], k: float) -> Image.Image:
    a = np.array(sprite).astype(np.float32)
    op = a[..., 3] > 0
    for i in range(3):
        a[..., i] = np.where(op, a[..., i] * (1 - k) + rgb[i] * k, a[..., i])
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def _sparkles(frame: Image.Image, cx: int, cy: int, r: float, rgb, phase: float) -> Image.Image:
    a = np.array(frame)
    for k in range(8):
        ang = k / 8 * math.tau + phase
        x, y = int(cx + math.cos(ang) * r), int(cy + math.sin(ang) * r)
        if 0 <= x < FRAME and 0 <= y < FRAME and a[y, x, 3] == 0:
            a[y, x] = (*rgb, 255)
    return Image.fromarray(a, "RGBA")


def _rotate90_back(sprite: Image.Image) -> Image.Image:
    """Lying on the back: rotate 90 degrees (exact, no resampling) so the head points left."""
    return sprite.transpose(Image.Transpose.ROTATE_90)


def animate(hid: str, sprite: Image.Image) -> dict[str, list[Image.Image]]:
    head_end, legs = _bands(sprite)
    h = sprite.height
    glow = GLOW.get(hid, (255, 226, 138))
    sp = _pad(sprite)
    # idle: breathing (upper body sinks 1 px), head follows a frame later
    idle = []
    for b in (0, 0, 1, 1, 1, 0):
        idle.append(_place(_drop_upper(sp, b, legs)))
    # run: bounce + leg scissor (feet rows sheared forward / back) + slight forward lean
    run = []
    for i in range(8):
        ph = i / 8 * math.tau
        bob = -int(round(abs(math.sin(ph)) * 2))
        sc = math.cos(ph) * 3.0

        def shear(y, sc=sc):
            if y >= legs:
                t = (y - legs) / max(h - legs, 1)
                return sc * (t * 2 - 0.4)
            return (legs - y) / legs * 1.5  # lean into the run
        run.append(_place(_shift_rows(sp, shear), dy=bob))
    # dash: strong lean, trailing feet
    dash = []
    for i in range(4):
        lean = 4 + (i % 2)
        dash.append(_place(_shift_rows(sp, lambda y, lean=lean: (legs - y) / legs * lean if y < legs else -((y - legs) / max(h - legs, 1)) * 3), dy=-1))
    # skill: crouch, rise with a glow, hold, recover
    skill = []
    for i, (sq, up, g) in enumerate(((2, 0, 0.0), (1, -1, 0.3), (0, -3, 0.7), (0, -3, 1.0), (0, -1, 0.5), (0, 0, 0.0))):
        f = _place(_drop_upper(sp, sq, legs), dy=up)
        if g > 0:
            f = _sparkles(f, CX + sprite.width // 2 - 2, GROUND - int(h * 0.55) + up, 8 + 6 * g, glow, g * 2)
        skill.append(f)
    # hurt: recoil back with a red flash, then recover
    hurt = [
        _place(_shift_rows(sp, lambda y: -(legs - y) / legs * 3 if y < legs else 0), dx=-2),
        _place(_shift_rows(sp, lambda y: -(legs - y) / legs * 1.5 if y < legs else 0), dx=-1),
        _place(sp),
    ]
    # death: stagger back, knees, fall onto the back, lie still
    lying = _rotate90_back(sprite)
    death = [
        _place(_shift_rows(sp, lambda y: -(legs - y) / legs * 3 if y < legs else 0), dx=-1),
        _place(_drop_upper(_shift_rows(sp, lambda y: -(legs - y) / legs * 5 if y < legs else 0), 3, legs), dx=-2),
        _place(_drop_upper(_shift_rows(sp, lambda y: -(legs - y) / legs * 9 if y < legs else 0), 6, legs), dx=-3),
    ]
    tilt = lying.resize((lying.width, lying.height), Image.NEAREST)
    fall = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    fall.alpha_composite(tilt, (CX - tilt.width // 2, GROUND - tilt.height - 3))
    death.append(fall)
    rest = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    rest.alpha_composite(lying, (CX - lying.width // 2, GROUND - lying.height))
    death += [rest, rest, rest, rest]
    return {"idle": idle, "run": run, "dash": dash, "skill": skill, "hurt": hurt, "death": death}


def build_all() -> dict[str, dict[str, list[Image.Image]]]:
    sprites = extract()
    os.makedirs(PROCESSED, exist_ok=True)
    for hid, s in sprites.items():
        s.save(os.path.join(PROCESSED, f"hero_{hid}_ref.png"))
    return {hid: animate(hid, s) for hid, s in sprites.items()}


if __name__ == "__main__":
    s = extract()
    for k, v in s.items():
        print(k, v.size)
