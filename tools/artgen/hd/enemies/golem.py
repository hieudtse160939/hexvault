"""Bastion Golem - HD tank enemy (128 px frame, feet pivot).

Warm stone (reads against the cool slate floor), brass bands, an amber rune
crack that brightens when it winds up a charge, tiny head sunk between huge
shoulders, oversized fists. Faces right.
"""
from __future__ import annotations

import math
import random

from canvas import HDCanvas

FRAME = 128
CX, GROUND = 64, 108
PIVOT = (CX, GROUND)
STONE = "stone"
BRASS = "amber"
MOSS = "moss"

SPEC = {"id": "golem", "sprite": "enemy_golem", "version": 1, "source": "procedural: tools/artgen/hd/enemies/golem.py"}
FPS = {"idle": 5, "move": 8, "attack": 8, "hurt": 10, "death": 9}
LOOP = {"idle": True, "move": True}


def _moss(c: HDCanvas, mask, seed: int) -> None:
    """A few moss clumps on the lit top of a mass."""
    rng = random.Random(seed)
    top = mask & ~c_shift(mask, 0, 3)
    ys, xs = top.nonzero()
    if len(xs) == 0:
        return
    for _ in range(3):
        i = rng.randrange(len(xs))
        c.draw(c.ellipse(xs[i] + 0.5, ys[i] + 1.0, rng.uniform(2.5, 4.0), 1.8) & mask, MOSS, "round", bias=-1,
               selout=False, cast=False, name="moss")


def c_shift(m, dx, dy):
    from canvas import shift
    return shift(m, dx, dy)


def draw(bob: float = 0.0, step: float = 0.0, raise_arm: float = 0.0, glow: int = 0, lean: float = 0.0,
         hurt: bool = False) -> HDCanvas:
    c = HDCanvas(FRAME, FRAME)
    by = bob
    # back fist + arm
    bsx, bsy = CX - 24 + lean, 58 + by
    bfx, bfy = CX - 30 + lean * 0.5, 88 + by * 0.5 - raise_arm * 6
    c.draw(c.capsule(bsx, bsy, bfx, bfy, 9, 8), STONE, "round", bias=-1, name="arm_back")
    c.draw(c.ellipse(bfx - 1, bfy + 3, 11, 10), STONE, "round", bias=-1, name="fist_back")
    # legs (back, front)
    for i, (lx, s) in enumerate(((CX - 12, -step), (CX + 10, step))):
        x = lx + s * 3
        lift = max(0.0, s) * 3
        c.draw(c.rect(int(x - 7), int(86 + by * 0.4), int(x + 7), int(GROUND - 4 - lift)), STONE, "round",
               bias=-1 if i == 0 else 0, name="leg")
        c.draw(c.ellipse(x + 2, GROUND - 4 - lift, 10, 5), STONE, "plate", bias=-1 if i == 0 else 0, name="foot")
    # torso boulder + shoulders
    tx, ty = CX + lean, 70 + by
    torso = c.ellipse(tx, ty, 30, 23) | c.ellipse(tx - 20, ty - 10, 14, 13) | c.ellipse(tx + 22, ty - 9, 15, 14)
    c.draw(torso, STONE, "round", name="torso")
    _moss(c, torso, 7)
    # chest plate seams
    c.line(tx - 6, ty - 18, tx - 10, ty + 18, STONE, 1)
    c.line(tx + 12, ty - 16, tx + 16, ty + 14, STONE, 1)
    # brass band across the belly
    band = c.ellipse(tx, ty + 9, 31, 3.2) & torso
    c.draw(band, BRASS, "metal", bias=-2, name="band")
    for rx in (-18, -4, 10, 24):
        c.px(int(tx + rx), int(ty + 9), BRASS, 5)
    # rune crack: a chevron that glows brighter on wind-up
    rune_col = ("amber", 3) if glow == 0 else ("glow_amber", 0)
    pts = [(tx - 8, ty - 9), (tx - 2, ty + 1), (tx + 2, ty - 4), (tx + 8, ty + 2), (tx + 13, ty - 7)]
    for (ax, ay), (bx2, by2) in zip(pts, pts[1:]):
        if rune_col[0] == "glow_amber":
            c.line(ax, ay, bx2, by2, "glow_amber")
            c.line(ax, ay + 1, bx2, by2 + 1, "amber", 4)
        else:
            c.line(ax, ay, bx2, by2, "amber", 3)
            c.line(ax, ay + 1, bx2, by2 + 1, "amber", 1)
    # head sunk between the shoulders
    hx, hy = tx + 6 + lean * 0.3, ty - 22
    head = c.ellipse(hx, hy, 11, 9)
    c.draw(head, STONE, "round", bias=1, name="head")
    c.draw(c.rect(int(hx - 2), int(hy - 1), int(hx + 10), int(hy + 2)) & head, "night", "flat", bias=-2, name="visor")
    eye = "glow_red" if hurt else ("glow_amber" if glow else None)
    if eye:
        c.fixed(c.rect(int(hx + 3), int(hy), int(hx + 8), int(hy + 1)), eye)
    else:
        c.fill(c.rect(int(hx + 3), int(hy), int(hx + 8), int(hy + 1)), "amber", 4)
    # front arm + fist (raised for the slam)
    fsx, fsy = tx + 24, ty - 8
    ffx, ffy = tx + 32 + raise_arm * 2, 86 + by * 0.5 - raise_arm * 42
    c.draw(c.capsule(fsx, fsy, ffx, ffy, 10, 9), STONE, "round", name="arm_front")
    c.draw(c.ellipse(ffx + 1, ffy + 3 - raise_arm * 4, 12, 11), STONE, "round", bias=1 if raise_arm else 0, name="fist")
    k0 = (ffx - 6, ffy - 2 - raise_arm * 4)
    for j in range(3):  # knuckle ridges
        c.line(k0[0] + j * 5, k0[1], k0[0] + j * 5 + 1, k0[1] + 3, STONE, 2)
    # brass cuff on the front wrist
    cx2, cy2 = (fsx + ffx) / 2 + (ffx - fsx) * 0.25, (fsy + ffy) / 2 + (ffy - fsy) * 0.25
    c.draw(c.ellipse(cx2, cy2, 9.5, 5, rot=math.atan2(ffy - fsy, ffx - fsx) + math.pi / 2), BRASS, "metal", bias=-1, name="cuff")
    if hurt:
        c.relight(c.opaque(), +1)
    c.outline("ink")
    c.despeckle()
    return c


def rubble(t: int) -> HDCanvas:
    """Death: the golem sinks and splits into boulders that settle."""
    rng = random.Random(42)
    c = HDCanvas(FRAME, FRAME)
    chunks = [(-24, 0, 12), (-6, -4, 14), (14, 0, 12), (30, 4, 9), (-36, 6, 8), (4, 8, 10), (22, 10, 7)]
    sink = min(t, 4) * 5
    spread = min(t, 4) * 2.5
    for i, (dx, dy, r) in enumerate(chunks):
        ox = dx * (1 + spread / 30)
        oy = 82 + dy + sink * (0.6 + 0.1 * i) - (8 if t <= 1 else 0)
        oy = min(oy, GROUND - r * 0.6)
        m = c.ellipse(CX + ox, oy, r * (1 - 0.04 * t), r * 0.75)
        c.draw(m, STONE, "round", bias=-1 if i % 2 else 0, name="chunk")
    if t < 3:  # dying rune glow
        c.line(CX - 6, 80 + sink, CX + 6, 84 + sink, "glow_amber" if t == 0 else "amber", 3)
    _ = rng
    c.outline("ink")
    c.despeckle()
    return c


def animations() -> dict:
    return {
        "idle": [draw(bob=b).image() for b in (0, 0, 1, 1)],
        "move": [draw(bob=b, step=s, lean=l).image()
                 for b, s, l in ((0, -1, 1), (1, -0.5, 2), (0, 0, 1), (0, 1, 1), (1, 0.5, 2), (0, 0, 1))],
        "attack": [draw(bob=1, raise_arm=0.5, glow=1, lean=-2).image(), draw(bob=-1, raise_arm=1.0, glow=1, lean=-3).image(),
                   draw(bob=2, raise_arm=-0.2, glow=1, lean=4).image(), draw(bob=1, raise_arm=0.0, glow=0, lean=2).image()],
        "hurt": [draw(lean=-3, hurt=True).image(), draw(lean=-1).image()],
        "death": [draw(bob=2, hurt=True).image()] + [rubble(t).image() for t in range(5)],
    }
