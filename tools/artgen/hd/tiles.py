"""HD dungeon tileset: 16 tiles of 64 x 64 px (one 16-unit cell at density 4).

Index order is the contract with scripts/world/tiles.gd (same as the 16 px
set in world.py::tileset). Floors are low-contrast bevelled flagstones so
actors read on top of them; every slab sits inside its tile with the grout on
the tile border, so any arrangement tiles seamlessly.
"""
from __future__ import annotations

import math
import random

import numpy as np

from canvas import HDCanvas

T = 64


def _slab_layout(variant: int) -> list[tuple[int, int, int, int]]:
    """Flagstone rectangles (x0, y0, x1, y1) inclusive, grout = 2 px gaps."""
    layouts = [
        [(1, 1, 30, 30), (33, 1, 62, 30), (1, 33, 30, 62), (33, 33, 62, 62)],
        [(1, 1, 40, 30), (43, 1, 62, 30), (1, 33, 20, 62), (23, 33, 62, 62)],
        [(1, 1, 62, 22), (1, 25, 30, 62), (33, 25, 62, 62)],
        [(1, 1, 20, 40), (23, 1, 62, 30), (23, 33, 62, 62), (1, 43, 20, 62)],
    ]
    return layouts[variant % len(layouts)]


def _floor(seed: int, ramp: str = "slate", grout: str = "night", bias: int = -2, crack: bool = False,
           rune: str | None = None) -> HDCanvas:
    rng = random.Random(seed)
    c = HDCanvas(T, T)
    c.fill(c.rect(0, 0, T - 1, T - 1), grout, 0, name="grout")
    for i, (x0, y0, x1, y1) in enumerate(_slab_layout(seed)):
        m = c.rect(x0, y0, x1, y1)
        # chip a corner off some slabs for wear
        if rng.random() < 0.5:
            cx, cy = (x0, y0) if rng.random() < 0.5 else (x1, y1)
            m &= ~c.ellipse(cx + 0.5, cy + 0.5, 2.2, 2.2)
        c.draw(m, ramp, "plate", bias=bias - (1 if rng.random() < 0.18 else 0),
               name=f"slab{i}", selout=False, cast=False)
        # sparse 2 px pits (clusters, never single pixels)
        for _ in range(rng.randint(1, 3)):
            px_, py_ = rng.randint(x0 + 3, max(x0 + 3, x1 - 4)), rng.randint(y0 + 3, max(y0 + 3, y1 - 4))
            c.relight(c.rect(px_, py_, px_ + 1, py_), -1)
    if crack:
        x, y = rng.randint(14, 26), rng.randint(10, 20)
        pts = [(x, y)]
        for _ in range(7):
            x += rng.choice((-2, -1, 1, 2, 3))
            y += rng.randint(3, 6)
            pts.append((min(max(x, 2), 61), min(y, 61)))
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            c.line(ax, ay, bx, by, grout, 0)
            c.line(ax + 1, ay, bx + 1, by, ramp, 0)
    if rune:
        cx = cy = 31.5
        ring = c.ellipse(cx, cy, 21, 21) & ~c.ellipse(cx, cy, 18, 18)
        c.fill(ring, rune, 1, name="rune_ring")
        inner = c.ellipse(cx, cy, 13, 13) & ~c.ellipse(cx, cy, 11, 11)
        c.fill(inner, rune, 1, name="rune_inner")
        for k in range(6):  # glyph ticks + lit nodes
            a = k / 6 * math.tau + 0.3
            x0, y0 = cx + math.cos(a) * 12, cy + math.sin(a) * 12
            x1, y1 = cx + math.cos(a) * 19, cy + math.sin(a) * 19
            c.line(x0, y0, x1, y1, rune, 2)
            c.fill(c.rect(int(x1) - 1, int(y1) - 1, int(x1), int(y1)), rune, 4)
        c.fill(c.ellipse(cx, cy, 3, 3), rune, 3)
    return c


def _wall_top(seed: int = 21) -> HDCanvas:
    """Top surface of a wall seen from above: dark capstones."""
    rng = random.Random(seed)
    c = HDCanvas(T, T)
    c.fill(c.rect(0, 0, T - 1, T - 1), "night", 0)
    for (x0, y0, x1, y1) in ((1, 1, 30, 30), (33, 1, 62, 30), (1, 33, 30, 62), (33, 33, 62, 62)):
        c.draw(c.rect(x0, y0, x1, y1), "night", "plate", bias=rng.choice((-2, -1)), selout=False, cast=False)
    return c


def _wall_face(seed: int, deco: str | None = None) -> HDCanvas:
    """South-facing wall: lit capstone lip on top, then brick courses."""
    rng = random.Random(seed)
    c = HDCanvas(T, T)
    c.fill(c.rect(0, 0, T - 1, T - 1), "night", 1)
    # capstone lip catching the light
    c.draw(c.rect(0, 0, 63, 9), "steel", "plate", bias=-1, selout=False, cast=False)
    c.fill(c.rect(0, 10, 63, 11), "night", 0)
    # brick courses (staggered), 12 px tall
    y = 12
    row = 0
    while y < 62:
        h = min(12, 63 - y)
        off = (row % 2) * 12 + rng.randint(-2, 2)
        x = -24 + off
        while x < 64:
            w = rng.choice((22, 24, 26))
            m = c.rect(max(x + 1, 0), y + 1, min(x + w - 1, 63), y + h - 1)
            c.draw(m, "slate", "plate", bias=-1 + (1 if rng.random() < 0.2 else 0), selout=False, cast=False)
            x += w
        y += h
        row += 1
    # floor contact shadow
    c.relight(c.rect(0, 58, 63, 63), -1)
    if deco == "lamp":
        c.draw(c.rect(26, 22, 37, 52), "slate", "plate", bias=-2, name="niche")
        c.draw(c.ellipse(31.5, 33, 5.5, 8), "teal", "metal", bias=1, name="crystal")
        c.fixed(c.rect(30, 28, 31, 35), "glow_teal")
        c.draw(c.rect(25, 44, 38, 48), "steel", "plate", name="sconce")
        for k in range(3):
            c.px(24 + k * 7, 20 - k % 2, "glow_teal")
    elif deco == "banner":
        c.draw(c.rect(20, 12, 43, 15), "leather", "round", name="rod")
        banner = c.poly([(22, 15), (41, 15), (41, 52), (31.5, 58), (22, 52)])
        c.draw(banner, "crimson", "cloth", name="banner")
        c.fill(c.ellipse(31.5, 32, 5, 5) & ~c.ellipse(31.5, 32, 3, 3), "amber", 4, name="emblem")
        c.fill(c.rect(31, 30, 32, 34), "amber", 3)
    return c


def tileset() -> list[HDCanvas]:
    return [
        _floor(1), _floor(2), _floor(3), _floor(4),                       # 0-3 floor
        _floor(5, crack=True), _floor(6, rune="teal"),                     # 4 cracked, 5 rune
        _floor(7, "night", "night", bias=-1),                              # 6 corridor
        _floor(8, "night", "night", bias=-1, crack=True),                  # 7 corridor cracked
        _wall_top(),                                                       # 8 wall top
        _wall_face(1), _wall_face(2), _wall_face(3, "lamp"), _wall_face(4, "banner"),  # 9-12
        _floor(9, "stone", "night", bias=-2),                              # 13 hub floor
        _floor(10, "stone", "night", bias=-2, rune="amber"),               # 14 hub rune
        _floor(11, "night", "night", bias=-1, rune="violet"),              # 15 boss rune
    ]


def atlas(cols: int = 8):
    from PIL import Image
    tiles = tileset()
    img = Image.new("RGBA", (T * cols, T * ((len(tiles) + cols - 1) // cols)), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        img.paste(t.image(), ((i % cols) * T, (i // cols) * T))
    return img


if __name__ == "__main__":
    atlas().save("/tmp/hd_tiles.png")
    _ = np
