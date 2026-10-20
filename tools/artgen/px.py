"""Tiny deterministic pixel canvas used by every Hexvault art generator.

All drawing is integer-pixel, fully opaque or fully transparent (no
anti-aliasing), so exported sprites stay crisp under nearest filtering.
"""
from __future__ import annotations

import math
from PIL import Image

# Hexvault master palette. Every generated pixel must come from this list
# (validated by tools/validate_assets.py).
PAL = {
    "ink": "#14101e",       # universal outline
    "night": "#2a2140",
    "dusk": "#3d3159",
    "stone0": "#4a4a6a",
    "stone1": "#6b6b8f",
    "stone2": "#9393b5",
    "stone3": "#c4c4dc",
    "floor0": "#22212f",
    "floor1": "#2b2a3a",
    "floor2": "#35344a",
    "floor3": "#403e57",
    "teal0": "#0f5e63",
    "teal1": "#1aa3a0",
    "teal2": "#4fe0d0",
    "teal3": "#b4fff0",
    "amber0": "#7a3e12",
    "amber1": "#c9741d",
    "amber2": "#f2b23a",
    "amber3": "#ffe28a",
    "red0": "#5c1426",
    "red1": "#a3243b",
    "red2": "#e8455a",
    "red3": "#ff9aa2",
    "moss0": "#24502f",
    "moss1": "#3f8a3a",
    "moss2": "#7dc94a",
    "moss3": "#c7f27a",
    "vio0": "#3b1f5e",
    "vio1": "#6c34a8",
    "vio2": "#a965ef",
    "vio3": "#e3b8ff",
    "skin0": "#6e4030",
    "skin1": "#b8775a",
    "skin2": "#e8b796",
    "blue0": "#1d3a7a",
    "blue1": "#2f6fd6",
    "blue2": "#6fb0ff",
    "white": "#f4f1ff",
    "shadow": "#0b0912",
}


def rgba(c) -> tuple[int, int, int, int]:
    if c is None:
        return (0, 0, 0, 0)
    if isinstance(c, tuple):
        return c if len(c) == 4 else (*c, 255)
    if c in PAL:
        c = PAL[c]
    c = c.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255)


PAL_RGBA = {rgba(v) for v in PAL.values()}


class Canvas:
    def __init__(self, w: int, h: int):
        self.w = w
        self.h = h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.p = self.img.load()

    # --- primitives -------------------------------------------------------
    def px(self, x: int, y: int, c) -> None:
        x = int(round(x)); y = int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[x, y] = rgba(c)

    def get(self, x: int, y: int):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.p[x, y]
        return (0, 0, 0, 0)

    def opaque(self, x: int, y: int) -> bool:
        return self.get(x, y)[3] > 0

    def rect(self, x0: int, y0: int, x1: int, y1: int, c) -> None:
        """Filled rect, inclusive corners."""
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for x in range(min(x0, x1), max(x0, x1) + 1):
                self.px(x, y, c)

    def hline(self, x0: int, x1: int, y: int, c) -> None:
        self.rect(x0, y, x1, y, c)

    def vline(self, x: int, y0: int, y1: int, c) -> None:
        self.rect(x, y0, x, y1, c)

    def line(self, x0, y0, x1, y1, c) -> None:
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx = abs(x1 - x0); dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1; sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.px(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy; x0 += sx
            if e2 <= dx:
                err += dx; y0 += sy

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, c) -> None:
        """Filled ellipse centred on (cx, cy) with radii in pixels."""
        if rx <= 0 or ry <= 0:
            return
        for y in range(int(math.floor(cy - ry)), int(math.ceil(cy + ry)) + 1):
            for x in range(int(math.floor(cx - rx)), int(math.ceil(cx + rx)) + 1):
                dx = (x + 0.5 - cx - 0.5) / (rx + 0.25)
                dy = (y + 0.5 - cy - 0.5) / (ry + 0.25)
                if dx * dx + dy * dy <= 1.0:
                    self.px(x, y, c)

    def ring(self, cx: float, cy: float, r: float, c, thickness: float = 1.0) -> None:
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                d = math.hypot(x - cx, y - cy)
                if r - thickness < d <= r:
                    self.px(x, y, c)

    def poly(self, pts, c) -> None:
        """Filled polygon via scanline (even-odd)."""
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            n = len(pts)
            for i in range(n):
                x0, y0 = pts[i]; x1, y1 = pts[(i + 1) % n]
                if (y0 <= y + 0.5 < y1) or (y1 <= y + 0.5 < y0):
                    xs.append(x0 + (y + 0.5 - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(math.ceil(xs[i] - 0.5)), int(math.floor(xs[i + 1] - 0.5)) + 1):
                    self.px(x, y, c)

    def ascii(self, x0: int, y0: int, rows: list[str], key: dict) -> None:
        """Stamp an ASCII drawing; '.' and ' ' are transparent."""
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in ".  ":
                    continue
                self.px(x0 + i, y0 + j, key[ch])

    # --- pixel-art passes ---------------------------------------------------
    def outline(self, c="ink", diagonal: bool = False) -> None:
        """Add a 1px outline around every opaque region (outside the shape)."""
        src = [[self.opaque(x, y) for x in range(self.w)] for y in range(self.h)]
        col = rgba(c)
        nbrs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            nbrs += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
        for y in range(self.h):
            for x in range(self.w):
                if src[y][x]:
                    continue
                for dx, dy in nbrs:
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < self.w and 0 <= yy < self.h and src[yy][xx]:
                        self.p[x, y] = col
                        break

    def recolor(self, mapping: dict) -> None:
        m = {rgba(k): rgba(v) for k, v in mapping.items()}
        for y in range(self.h):
            for x in range(self.w):
                v = self.p[x, y]
                if v in m:
                    self.p[x, y] = m[v]

    def flip_h(self) -> "Canvas":
        out = Canvas(self.w, self.h)
        out.img = self.img.transpose(Image.FLIP_LEFT_RIGHT)
        out.p = out.img.load()
        return out

    def blit(self, other: "Canvas", ox: int, oy: int) -> None:
        for y in range(other.h):
            for x in range(other.w):
                v = other.p[x, y]
                if v[3] > 0:
                    self.px(ox + x, oy + y, v)

    def copy(self) -> "Canvas":
        out = Canvas(self.w, self.h)
        out.img = self.img.copy()
        out.p = out.img.load()
        return out


def strip(frames: list[Canvas]) -> Image.Image:
    """Lay frames out horizontally in one image."""
    w, h = frames[0].w, frames[0].h
    img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        assert f.w == w and f.h == h, "frame size mismatch"
        img.paste(f.img, (i * w, 0))
    return img


def sheet(anims: dict[str, list[Canvas]]) -> tuple[Image.Image, dict]:
    """Stack animations as rows; return image + per-anim metadata."""
    fw, fh = next(iter(anims.values()))[0].w, next(iter(anims.values()))[0].h
    cols = max(len(v) for v in anims.values())
    img = Image.new("RGBA", (fw * cols, fh * len(anims)), (0, 0, 0, 0))
    meta = {}
    for row, (name, frames) in enumerate(anims.items()):
        for i, f in enumerate(frames):
            assert f.w == fw and f.h == fh, f"{name}: frame size mismatch"
            img.paste(f.img, (i * fw, row * fh))
        meta[name] = {"row": row, "frames": len(frames)}
    return img, {"frame_w": fw, "frame_h": fh, "anims": meta}
