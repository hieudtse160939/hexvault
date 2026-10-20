"""Sparkeye - HD flying ranged enemy (96 px frame, pivot under the body).

A floating arcane eye in a cracked stone socket with leathery violet wings;
the crimson iris flares before it fires."""
from __future__ import annotations

import math

from canvas import HDCanvas

FRAME = 96
CX, GROUND = 48, 70
PIVOT = (CX, GROUND)
SPEC = {"id": "sparkeye", "sprite": "enemy_sparkeye", "version": 1, "source": "procedural: tools/artgen/hd/enemies/sparkeye.py"}
FPS = {"idle": 8, "move": 12, "attack": 10, "hurt": 10, "death": 10}
LOOP = {"idle": True, "move": True}


def draw(flap: float = 0.0, bob: float = 0.0, charge: float = 0.0, look: float = 1.0, hurt: bool = False,
         dead: int = 0) -> HDCanvas:
    c = HDCanvas(FRAME, FRAME)
    cx, cy = CX, 44 + bob + dead * 5
    # wings: three-finger bat wings, angle by flap (-1 down .. 1 up)
    for side in (-1, 1):
        far = side < 0
        base = (cx + side * 9, cy - 3)
        pts = [base]
        for k, (ang, ln) in enumerate(((-60, 22), (-25, 26), (10, 20))):
            a = math.radians(ang - flap * 35 - (dead * 20))
            pts.append((base[0] + side * math.cos(a) * ln, base[1] + math.sin(a) * ln))
            if k < 2:
                a2 = math.radians(ang + 15 - flap * 35)
                pts.append((base[0] + side * math.cos(a2) * ln * 0.62, base[1] + math.sin(a2) * ln * 0.62 + 3))
        pts.append((cx + side * 6, cy + 6))
        m = c.poly(pts)
        c.draw(m, "violet", "cloth", bias=-2 if far else -1, name="wing")
        for p in pts[1:-1:2]:
            c.line(base[0], base[1], p[0], p[1], "violet", 0)
    # socket ring of cracked stone
    c.draw(c.ellipse(cx, cy, 15, 14), "stone", "round", bias=-1, name="socket")
    for a in (0.6, 2.2, 3.9, 5.2):
        c.line(cx + math.cos(a) * 11, cy + math.sin(a) * 10, cx + math.cos(a) * 15, cy + math.sin(a) * 14, "stone", 0)
    # eyeball, iris, pupil, glints
    c.draw(c.ellipse(cx + 1, cy, 11, 10.5), "bone", "round", bias=1, name="eyeball")
    if dead >= 2:
        c.line(cx - 5, cy - 4, cx + 7, cy + 4, "night", 0)
        c.line(cx - 5, cy + 4, cx + 7, cy - 4, "night", 0)
    else:
        ix = cx + 3 * look
        r = 6.0 + charge * 1.5
        c.draw(c.ellipse(ix, cy, r, r), "crimson", "glow" if charge > 0 else "round", bias=1 if charge > 0 else 0, name="iris")
        c.fill(c.ellipse(ix + 0.5, cy, 2.2 - charge * 0.8, 3.6), "night", 0, name="pupil")
        c.px(int(ix - 3), int(cy - 4), "white")
        c.px(int(ix - 2), int(cy - 4), "white")
        c.px(int(ix - 3), int(cy - 3), "white")
        if charge > 0:
            for k in range(6):
                a = k / 6 * math.tau + charge * 3
                c.px(int(ix + math.cos(a) * (r + 4)), int(cy + math.sin(a) * (r + 4)), "glow_red")
    if hurt:
        c.relight(c.opaque(), 1)
    c.outline("ink")
    c.despeckle()
    return c


def animations() -> dict:
    return {
        "idle": [draw(flap=f, bob=b).image() for f, b in ((1, 0), (0.3, 1), (-0.6, 2), (0.3, 1))],
        "move": [draw(flap=f, bob=b).image() for f, b in ((1, 0), (-0.8, 2))],
        "attack": [draw(flap=0.5, charge=0.4).image(), draw(flap=-0.2, charge=1.0).image(), draw(flap=0.6, bob=-2, charge=0.2, look=1.5).image()],
        "hurt": [draw(flap=-1, bob=2, hurt=True, look=-1).image()],
        "death": [draw(flap=-1, dead=1).image(), draw(flap=-1, dead=2).image(), draw(flap=-1, dead=3).image(), draw(flap=-1, dead=4).image()],
    }
