"""HD skill icons, 64 x 64 (16 x 16 world units, same footprint as the old icons)."""
from __future__ import annotations

import math

from canvas import HDCanvas

S = 64


def _frame(c: HDCanvas, ramp: str) -> None:
    c.draw(c.ellipse(31.5, 31.5, 29, 29), "night", "round", bias=-1, name="disc", selout=False, cast=False)
    ring = c.ellipse(31.5, 31.5, 29, 29) & ~c.ellipse(31.5, 31.5, 26, 26)
    c.fill(ring, ramp, 3, name="ring")


def whirlwind() -> HDCanvas:
    c = HDCanvas(S, S)
    _frame(c, "crimson")
    for k in range(3):
        a0 = k * math.tau / 3
        pts = [(31.5 + math.cos(a0 + t * 0.25) * (6 + t * 2.2), 31.5 + math.sin(a0 + t * 0.25) * (6 + t * 2.2)) for t in range(9)]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            c.draw(c.capsule(ax, ay, bx, by, 2.0, 2.0), "steel", "metal", selout=False, cast=False)
    c.fixed(c.ellipse(31.5, 31.5, 3, 3), "glow_red")
    c.outline("ink")
    return c


def flame_nova() -> HDCanvas:
    c = HDCanvas(S, S)
    _frame(c, "flame")
    for k in range(8):
        a = k * math.tau / 8
        x, y = 31.5 + math.cos(a) * 15, 31.5 + math.sin(a) * 15
        c.draw(c.ellipse(x, y, 4.0, 4.0), "flame", "glow", selout=False, cast=False)
    c.draw(c.ellipse(31.5, 31.5, 7, 7), "amber", "glow", selout=False, cast=False)
    c.fixed(c.ellipse(31.5, 31.5, 3, 3), "glow_amber")
    c.outline("ink")
    return c


def glacial_field() -> HDCanvas:
    c = HDCanvas(S, S)
    _frame(c, "frost")
    for k in range(6):
        a = k * math.tau / 6
        ex, ey = 31.5 + math.cos(a) * 19, 31.5 + math.sin(a) * 19
        c.draw(c.capsule(31.5, 31.5, ex, ey, 2.2, 1.4), "frost", "metal", selout=False, cast=False)
        for s in (-1, 1):
            mx, my = 31.5 + math.cos(a) * 12, 31.5 + math.sin(a) * 12
            bx, by = mx + math.cos(a + s * 0.8) * 6, my + math.sin(a + s * 0.8) * 6
            c.draw(c.capsule(mx, my, bx, by, 1.4, 1.0), "frost", "metal", selout=False, cast=False)
    c.fixed(c.ellipse(31.5, 31.5, 3, 3), "glow_frost")
    c.outline("ink")
    return c


def thunderhead() -> HDCanvas:
    c = HDCanvas(S, S)
    _frame(c, "violet")
    c.draw(c.ellipse(28, 22, 13, 8) | c.ellipse(38, 20, 10, 8) | c.ellipse(20, 24, 8, 6), "slate", "round", selout=False, cast=False)
    bolt = c.poly([(33, 26), (26, 40), (32, 40), (27, 54), (42, 34), (35, 34), (40, 26)])
    c.fixed(bolt, "glow_violet")
    c.outline("ink")
    return c


def raise_wisps() -> HDCanvas:
    c = HDCanvas(S, S)
    _frame(c, "moss")
    for k, (x, y) in enumerate(((22, 26), (40, 24), (31, 42))):
        body = c.ellipse(x, y, 6, 7) | c.poly([(x - 6, y), (x + 6, y), (x + 2, y + 13), (x - 3, y + 9)])
        c.draw(body, "moss", "glow", selout=False, cast=False)
        c.fixed(c.rect(x - 2, y - 1, x - 1, y + 1) | c.rect(x + 1, y - 1, x + 2, y + 1), "void")
    c.outline("ink")
    return c


def veil() -> HDCanvas:
    c = HDCanvas(S, S)
    _frame(c, "violet")
    eye = c.ellipse(31.5, 31.5, 18, 9)
    c.draw(eye, "violet", "round", bias=-1, selout=False, cast=False)
    c.fill(c.ellipse(31.5, 31.5, 7, 7), "night", 0)
    c.fixed(c.ellipse(29.5, 29.5, 2, 2), "glow_violet")
    c.line(14, 44, 50, 18, "bone", 4)
    c.line(15, 45, 51, 19, "bone", 4)
    c.outline("ink")
    return c


def sanctuary() -> HDCanvas:
    c = HDCanvas(S, S)
    _frame(c, "amber")
    for k in range(12):
        a = k * math.tau / 12
        c.draw(c.capsule(31.5, 31.5, 31.5 + math.cos(a) * 20, 31.5 + math.sin(a) * 20, 2.0 if k % 2 else 3.0, 0.8), "amber",
               "glow", selout=False, cast=False)
    c.draw(c.rect(28, 18, 35, 45) | c.rect(18, 28, 45, 35), "bone", "metal", selout=False, cast=False)
    c.fixed(c.ellipse(31.5, 31.5, 3, 3), "glow_amber")
    c.outline("ink")
    return c


def barrage() -> HDCanvas:
    c = HDCanvas(S, S)
    _frame(c, "amber")
    for x, y in ((22, 22), (36, 18), (30, 34)):
        c.draw(c.capsule(x, y, x + 6, y + 10, 3.2, 3.0), "steel", "metal", selout=False, cast=False)
        c.draw(c.ellipse(x + 6.5, y + 11, 3.2, 2.4), "amber", "metal", selout=False, cast=False)
    c.fixed(c.ellipse(42, 48, 5, 3), "glow_amber")
    c.draw(c.ellipse(42, 48, 9, 5) & ~c.ellipse(42, 48, 5, 3), "flame", "glow", selout=False, cast=False)
    c.outline("ink")
    return c


ICONS = {
    "skill_whirlwind": whirlwind, "skill_flame_nova": flame_nova, "skill_glacial_field": glacial_field,
    "skill_thunderhead": thunderhead, "skill_raise_wisps": raise_wisps, "skill_veil": veil,
    "skill_sanctuary": sanctuary, "skill_barrage": barrage,
}
