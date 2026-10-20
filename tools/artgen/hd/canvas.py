"""HD pixel canvas: part-based drawing with directional cel shading.

Every shape is drawn as a *part*: a boolean mask plus a colour ramp from
palette.RAMPS. The canvas keeps, per pixel, which ramp and which shade index
it uses, so later passes can relight it consistently:

- shading: a part is lit from the top-left. For each pixel we measure how far
  it is from the part's lit edges vs. its shadow edges (run lengths inside the
  mask) and map that ratio onto ramp bands - the "shifted shape" cel recipe
  from pixel-art-studio/references/techniques.md, done per part so a sleeve
  over a coat shades as its own form (no pillow shading);
- selout: where a new part covers an older one, the new part's edge pixels
  become its darkest shade (lit-side edges one step lighter);
- cast shadow: older parts just below / right of a new part drop one shade;
- outline: a 1 px ink outline around the whole silhouette at the end.

All output pixels are fully opaque or fully transparent and come from the
HD palette, which tools/validate_assets.py and tools/asset_qa.py enforce.
"""
from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np
from PIL import Image

from palette import FIXED, RAMPS

# Light comes from the top-left; vertical light dominates in top-down view.
LIGHT_V = 0.7
LIGHT_H = 0.3

# Band tables: (upper bound of light ratio t, ramp index). t = 0 on the lit
# edge, 1 on the shadow edge. Index 5 is reserved for specular spots.
# Dome forms map Lambert light (1 = facing the light) to ramp indices:
# (lower bound of light, index), checked from the top.
DOME: dict[str, list[tuple[float, int]]] = {
    "round": [(0.93, 4), (0.70, 3), (0.42, 2), (-1.0, 1)],
    "cloth": [(0.95, 4), (0.66, 3), (0.38, 2), (-1.0, 1)],
    "skin": [(0.94, 4), (0.62, 3), (0.36, 2), (-1.0, 1)],
    "metal": [(0.96, 5), (0.86, 4), (0.62, 3), (0.38, 1), (-1.0, 2)],
    "plate": [(0.92, 4), (0.62, 3), (0.40, 2), (-1.0, 1)],
}
DOME_FLAT = {"plate": 0.55}

FORMS: dict[str, list[tuple[float, int]]] = {
    "flat": [(0.10, 4), (0.86, 3), (1.01, 2)],
    "bands": [(0.14, 5), (0.34, 4), (0.60, 2), (0.84, 1), (1.01, 2)],
    "soft": [(0.30, 3), (0.80, 2), (1.01, 1)],
    "glow": [(0.40, 5), (1.01, 4)],
}


def hex_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


RAMP_NAMES: list[str] = list(RAMPS.keys())
RAMP_RGB: list[list[tuple[int, int, int]]] = [[hex_rgb(c) for c in RAMPS[n]] for n in RAMP_NAMES]
RAMP_INDEX: dict[str, int] = {n: i for i, n in enumerate(RAMP_NAMES)}
FIXED_RGB: dict[str, tuple[int, int, int]] = {k: hex_rgb(v) for k, v in FIXED.items()}

# ramp id used for "fixed" colours (ink, glow...) stored on the canvas
FIXED_BASE = 1000
FIXED_NAMES: list[str] = list(FIXED.keys())


def palette_rgb() -> set[tuple[int, int, int]]:
    out = {c for r in RAMP_RGB for c in r}
    out |= set(FIXED_RGB.values())
    return out


# --- mask builders ------------------------------------------------------------
def _grid(w: int, h: int) -> tuple[np.ndarray, np.ndarray]:
    ys, xs = np.mgrid[0:h, 0:w]
    return xs + 0.5, ys + 0.5


def ellipse(w: int, h: int, cx: float, cy: float, rx: float, ry: float, rot: float = 0.0) -> np.ndarray:
    x, y = _grid(w, h)
    dx, dy = x - cx, y - cy
    if rot:
        c, s = math.cos(-rot), math.sin(-rot)
        dx, dy = dx * c - dy * s, dx * s + dy * c
    return (dx / max(rx, 0.3)) ** 2 + (dy / max(ry, 0.3)) ** 2 <= 1.0


def capsule(w: int, h: int, x0: float, y0: float, x1: float, y1: float, r0: float, r1: float | None = None) -> np.ndarray:
    """Tapered capsule from (x0,y0) radius r0 to (x1,y1) radius r1."""
    r1 = r0 if r1 is None else r1
    x, y = _grid(w, h)
    vx, vy = x1 - x0, y1 - y0
    ll = vx * vx + vy * vy
    if ll < 1e-6:
        return (x - x0) ** 2 + (y - y0) ** 2 <= r0 * r0
    t = np.clip(((x - x0) * vx + (y - y0) * vy) / ll, 0.0, 1.0)
    px, py = x0 + t * vx, y0 + t * vy
    r = r0 + (r1 - r0) * t
    return (x - px) ** 2 + (y - py) ** 2 <= r * r


def poly(w: int, h: int, pts: list[tuple[float, float]]) -> np.ndarray:
    """Even-odd filled polygon sampled at pixel centres."""
    x, y = _grid(w, h)
    inside = np.zeros((h, w), dtype=bool)
    n = len(pts)
    for i in range(n):
        xa, ya = pts[i]
        xb, yb = pts[(i + 1) % n]
        if ya == yb:
            continue
        cond = (ya <= y) != (yb <= y)
        xint = xa + (y - ya) * (xb - xa) / (yb - ya)
        inside ^= cond & (x < xint)
    return inside


def rect(w: int, h: int, x0: int, y0: int, x1: int, y1: int) -> np.ndarray:
    m = np.zeros((h, w), dtype=bool)
    m[max(y0, 0):max(y1 + 1, 0), max(x0, 0):max(x1 + 1, 0)] = True
    return m


def shift(m: np.ndarray, dx: int, dy: int) -> np.ndarray:
    out = np.zeros_like(m)
    h, w = m.shape
    xs0, xs1 = max(0, -dx), min(w, w - dx)
    ys0, ys1 = max(0, -dy), min(h, h - dy)
    if xs0 < xs1 and ys0 < ys1:
        out[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = m[ys0:ys1, xs0:xs1]
    return out


def grow(m: np.ndarray, n: int = 1) -> np.ndarray:
    out = m.copy()
    for _ in range(n):
        out = out | shift(out, 1, 0) | shift(out, -1, 0) | shift(out, 0, 1) | shift(out, 0, -1)
    return out


def edge(m: np.ndarray) -> np.ndarray:
    """Pixels of m that touch a non-m pixel (4-neighbourhood)."""
    inner = m & shift(m, 1, 0) & shift(m, -1, 0) & shift(m, 0, 1) & shift(m, 0, -1)
    return m & ~inner


def _runs(m: np.ndarray, axis: int, reverse: bool) -> np.ndarray:
    """Distance (in px, >=1) from each mask pixel to the mask boundary along an axis."""
    a = m if axis == 0 else m.T
    if reverse:
        a = a[::-1]
    out = np.zeros(a.shape, dtype=np.int32)
    run = np.zeros(a.shape[1], dtype=np.int32)
    for i in range(a.shape[0]):
        run = np.where(a[i], run + 1, 0)
        out[i] = run
    if reverse:
        out = out[::-1]
    return out if axis == 0 else out.T


def light_ratio(m: np.ndarray) -> np.ndarray:
    """0 at the lit (top/left) edges of the mask, 1 at the shadow edges."""
    up = _runs(m, 0, False).astype(np.float32)
    down = _runs(m, 0, True).astype(np.float32)
    left = _runs(m, 1, False).astype(np.float32)
    right = _runs(m, 1, True).astype(np.float32)
    tv = (up - 1) / np.maximum(up + down - 2, 1)
    th = (left - 1) / np.maximum(left + right - 2, 1)
    return LIGHT_V * tv + LIGHT_H * th


def distance(m: np.ndarray) -> np.ndarray:
    """Approximate (octagonal) distance from each mask pixel to the outside, >= 1."""
    d = np.zeros(m.shape, dtype=np.float32)
    cur = m.copy()
    k = 0
    while cur.any() and k < 64:
        d += cur
        n4 = cur & shift(cur, 1, 0) & shift(cur, -1, 0) & shift(cur, 0, 1) & shift(cur, 0, -1)
        if k % 2 == 1:
            n4 &= shift(cur, 1, 1) & shift(cur, -1, -1) & shift(cur, 1, -1) & shift(cur, -1, 1)
        cur = n4
        k += 1
    return d


def _blur(a: np.ndarray) -> np.ndarray:
    p = np.pad(a, 1, mode="edge")
    return (p[:-2, :-2] + p[:-2, 1:-1] + p[:-2, 2:] + p[1:-1, :-2] + 2 * p[1:-1, 1:-1]
            + p[1:-1, 2:] + p[2:, :-2] + p[2:, 1:-1] + p[2:, 2:]) / 10.0


# light direction (x right, y down, z toward viewer): top-left, in front
LIGHT = np.array([-0.45, -0.72, 0.53], dtype=np.float32)
LIGHT /= np.linalg.norm(LIGHT)


def dome_light(m: np.ndarray, flat: float = 0.0) -> np.ndarray:
    """Lambert light 0..1 on a pseudo-3D dome raised from the mask's distance field.

    flat > 0 caps the dome (bevelled slab: plates, belts, books).
    """
    d = distance(m)
    r = max(float(d.max()), 1.0)
    if flat > 0:
        cap = max(r * (1.0 - flat), 1.0)
        dd = np.minimum(d, cap)
        hgt = np.sqrt(np.maximum(dd * (2 * cap - dd), 0))
    else:
        hgt = np.sqrt(np.maximum(d * (2 * r - d), 0))
    hgt = _blur(_blur(hgt * m)) 
    gy, gx = np.gradient(hgt)
    n = np.stack([-gx, -gy, np.ones_like(hgt) * 1.1], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return np.clip(n @ LIGHT, 0.0, 1.0)


@dataclass
class PartInfo:
    name: str
    ramp: int


class HDCanvas:
    def __init__(self, w: int, h: int):
        self.w = w
        self.h = h
        self.ramp = np.full((h, w), -1, dtype=np.int32)    # ramp id, FIXED_BASE+i for fixed, -1 empty
        self.shade = np.zeros((h, w), dtype=np.int32)
        self.part = np.full((h, w), -1, dtype=np.int32)
        self.parts: list[PartInfo] = []

    # -- helpers bound to this canvas size --
    def ellipse(self, *a, **k) -> np.ndarray:
        return ellipse(self.w, self.h, *a, **k)

    def capsule(self, *a, **k) -> np.ndarray:
        return capsule(self.w, self.h, *a, **k)

    def poly(self, pts) -> np.ndarray:
        return poly(self.w, self.h, pts)

    def rect(self, x0, y0, x1, y1) -> np.ndarray:
        return rect(self.w, self.h, x0, y0, x1, y1)

    def opaque(self) -> np.ndarray:
        return self.ramp >= 0

    # -- drawing --
    def draw(self, mask: np.ndarray, ramp: str, form: str = "round", bias: int = 0,
             name: str = "", selout: bool = True, cast: bool = True, clip: np.ndarray | None = None,
             light_mask: np.ndarray | None = None) -> np.ndarray:
        """Shade `mask` with `ramp` and paint it over everything drawn before.

        bias shifts every band (+1 lighter, -1 darker: far limbs, recesses).
        light_mask lets a part shade as if it were a bigger form (e.g. a
        sleeve shaded with the whole arm). Returns the painted mask.
        """
        if clip is not None:
            mask = mask & clip
        if not mask.any():
            return mask
        rid = RAMP_INDEX[ramp]
        lm = light_mask if light_mask is not None else mask
        if form in DOME:
            li = dome_light(lm, DOME_FLAT.get(form, 0.0))
            idx = np.full(mask.shape, DOME[form][-1][1], dtype=np.int32)
            for bound, val in reversed(DOME[form]):
                idx = np.where(li >= bound, val, idx)
        else:
            t = light_ratio(lm)
            idx = np.full(mask.shape, FORMS[form][-1][1], dtype=np.int32)
            for bound, val in reversed(FORMS[form]):
                idx = np.where(t < bound, val, idx)
        idx = np.clip(idx + bias, 0, 5)
        below = self.opaque() & ~mask
        pid = len(self.parts)
        self.parts.append(PartInfo(name or ramp, rid))
        if cast:
            # older parts in the shadow of this one get one shade darker
            sh = (shift(mask, 1, 2) | shift(mask, 0, 2)) & below & (self.ramp < FIXED_BASE)
            self.shade = np.where(sh, np.maximum(self.shade - 1, 0), self.shade)
        self.ramp = np.where(mask, rid, self.ramp)
        self.shade = np.where(mask, idx, self.shade)
        self.part = np.where(mask, pid, self.part)
        if selout:
            # shift(below, -dx, -dy)[p] is True when p's neighbour at (dx, dy) is an older part
            dark_nb = shift(below, -1, 0) | shift(below, 0, -1)   # right / below
            lit_nb = shift(below, 1, 0) | shift(below, 0, 1)      # left / above
            e = edge(mask)
            self.shade = np.where(e & dark_nb, 0, self.shade)
            self.shade = np.where(e & lit_nb & ~dark_nb, np.minimum(self.shade, 1), self.shade)
        return mask

    def fill(self, mask: np.ndarray, ramp: str, index: int, name: str = "") -> np.ndarray:
        """Flat single shade (details: stitches, trims, eyes)."""
        if not mask.any():
            return mask
        rid = RAMP_INDEX[ramp]
        pid = len(self.parts)
        self.parts.append(PartInfo(name or ramp, rid))
        self.ramp = np.where(mask, rid, self.ramp)
        self.shade = np.where(mask, int(index), self.shade)
        self.part = np.where(mask, pid, self.part)
        return mask

    def fixed(self, mask: np.ndarray, color: str) -> np.ndarray:
        """Unshaded palette colour from FIXED (ink, glows)."""
        i = FIXED_NAMES.index(color)
        self.ramp = np.where(mask, FIXED_BASE + i, self.ramp)
        self.shade = np.where(mask, 0, self.shade)
        return mask

    def px(self, x: int, y: int, ramp: str, index: int = 0) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            if ramp in FIXED:
                self.ramp[y, x] = FIXED_BASE + FIXED_NAMES.index(ramp)
                self.shade[y, x] = 0
            else:
                self.ramp[y, x] = RAMP_INDEX[ramp]
                self.shade[y, x] = index

    def line(self, x0: float, y0: float, x1: float, y1: float, ramp: str, index: int = 0) -> None:
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.px(x0, y0, ramp, index)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def erase(self, mask: np.ndarray) -> None:
        self.ramp = np.where(mask, -1, self.ramp)
        self.part = np.where(mask, -1, self.part)

    def relight(self, mask: np.ndarray, delta: int) -> None:
        """Shift shades of already-drawn ramp pixels inside mask (rim light, AO)."""
        m = mask & (self.ramp >= 0) & (self.ramp < FIXED_BASE)
        self.shade = np.where(m, np.clip(self.shade + delta, 0, 5), self.shade)

    def outline(self, color: str = "ink") -> None:
        o = self.opaque()
        ring = grow(o, 1) & ~o
        self.fixed(ring, color)

    def despeckle(self, passes: int = 2) -> None:
        """Remove isolated pixels: a pixel whose four neighbours are all opaque
        and all different from it takes the most common neighbour value
        (ramp pixels only; ink and glows are left alone)."""
        for _ in range(passes):
            changed = False
            r, sh = self.ramp, self.shade
            for y in range(1, self.h - 1):
                for x in range(1, self.w - 1):
                    if not (0 <= r[y, x] < FIXED_BASE):
                        continue
                    me = (r[y, x], sh[y, x])
                    nbs = [(r[y + dy, x + dx], sh[y + dy, x + dx]) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
                    if any(n[0] < 0 for n in nbs) or any(n == me for n in nbs):
                        continue
                    cand = [n for n in nbs if 0 <= n[0] < FIXED_BASE]
                    if not cand:
                        continue
                    same_ramp = [n for n in cand if n[0] == me[0]]
                    pool = same_ramp if same_ramp else cand
                    best = max(set(pool), key=pool.count)
                    r[y, x], sh[y, x] = best
                    changed = True
            if not changed:
                break

    # -- export --
    def image(self) -> Image.Image:
        arr = np.zeros((self.h, self.w, 4), dtype=np.uint8)
        for rid in np.unique(self.ramp):
            if rid < 0:
                continue
            m = self.ramp == rid
            if rid >= FIXED_BASE:
                arr[m] = (*FIXED_RGB[FIXED_NAMES[rid - FIXED_BASE]], 255)
                continue
            cols = RAMP_RGB[rid]
            for s in range(6):
                ms = m & (self.shade == s)
                if ms.any():
                    arr[ms] = (*cols[s], 255)
        return Image.fromarray(arr, "RGBA")

    def flip_h(self) -> "HDCanvas":
        out = HDCanvas(self.w, self.h)
        out.ramp = self.ramp[:, ::-1].copy()
        out.shade = self.shade[:, ::-1].copy()
        out.part = self.part[:, ::-1].copy()
        out.parts = list(self.parts)
        return out


def sheet(anims: dict[str, list[Image.Image]]) -> tuple[Image.Image, dict]:
    """Stack animations as rows; frames left to right."""
    first = next(iter(anims.values()))[0]
    fw, fh = first.size
    cols = max(len(v) for v in anims.values())
    img = Image.new("RGBA", (fw * cols, fh * len(anims)), (0, 0, 0, 0))
    meta = {}
    for row, (name, frames) in enumerate(anims.items()):
        for i, f in enumerate(frames):
            assert f.size == (fw, fh), f"{name}: frame size mismatch"
            img.paste(f, (i * fw, row * fh))
        meta[name] = {"row": row, "frames": len(frames)}
    return img, {"frame_w": fw, "frame_h": fh, "anims": meta}
