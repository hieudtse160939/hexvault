"""Gloop - HD chaser slime (96 px frame, pivot on the ground contact).

Glossy moss-green jelly with big anime eyes, a glowing rune cube floating
inside, a wet shine. Squashes and stretches; splats on death."""
from __future__ import annotations

import math

from canvas import HDCanvas

FRAME = 96
CX, GROUND = 48, 78
PIVOT = (CX, GROUND)
SPEC = {"id": "gloop", "sprite": "enemy_gloop", "version": 1, "source": "procedural: tools/artgen/hd/enemies/gloop.py"}
FPS = {"idle": 6, "move": 10, "attack": 12, "hurt": 10, "death": 12}
LOOP = {"idle": True, "move": True}
JELLY = "moss"


def draw(squash: float = 0.0, lift: float = 0.0, lean: float = 0.0, eyes: str = "open", core: bool = True,
         angry: bool = False) -> HDCanvas:
    """squash > 0 flattens, < 0 stretches; lift raises off the ground (hops)."""
    c = HDCanvas(FRAME, FRAME)
    rx = 22.0 * (1.0 + squash * 0.35)
    ry = 17.5 * (1.0 - squash * 0.35)
    cy = GROUND - ry - lift
    cx = CX + lean
    # body: dome with a flat-ish bottom and a drip at the back
    body = c.ellipse(cx, cy, rx, ry) & c.rect(0, 0, FRAME - 1, int(GROUND - lift))
    body |= c.ellipse(cx - rx * 0.6, cy + ry * 0.55, rx * 0.35, ry * 0.45)
    c.draw(body, JELLY, "round", name="jelly")
    # inner darker jelly + rune cube
    inner = c.ellipse(cx + 2, cy + 3, rx * 0.55, ry * 0.5) & body
    c.relight(inner, -1)
    if core:
        k = 3.5
        ox, oy = cx - rx * 0.35, cy + ry * 0.35
        cube = c.poly([(ox, oy - k), (ox + k, oy), (ox, oy + k), (ox - k, oy)])
        c.draw(cube & body, "teal", "glow", name="core", selout=False)
        c.fixed(c.ellipse(ox, oy, 1.2, 1.2), "glow_teal")
    # wet shine: a crescent + two dots top-left
    shine = c.ellipse(cx - rx * 0.4, cy - ry * 0.45, rx * 0.32, ry * 0.18) & body
    c.fill(shine, JELLY, 5, name="shine")
    c.px(int(cx - rx * 0.05), int(cy - ry * 0.62), "white")
    # face: two big eyes on the front side
    ex0, ex1 = cx + rx * 0.18, cx + rx * 0.55
    ey = cy - ry * 0.22
    for i, ex in enumerate((ex0, ex1)):
        w, h = (3.6, 6.0) if i == 1 else (3.0, 5.4)
        x0, x1 = int(round(ex - w / 2)), int(round(ex + w / 2))
        y0, y1 = int(round(ey - h / 2)), int(round(ey + h / 2))
        if eyes == "closed":
            c.line(x0, ey, x1, ey, "hair_ink", 0)
        elif eyes == "x":
            c.line(x0, y0 + 1, x1, y1 - 1, "hair_ink", 0)
            c.line(x0, y1 - 1, x1, y0 + 1, "hair_ink", 0)
        else:
            c.fill(c.rect(x0, y0, x1, y1), "night", 0, name="eye")
            c.px(x0, y0, "white")
            c.px(x0 + 1, y0, "white")
            c.px(x1, y1 - 1, "teal", 4)
            if angry:
                c.line(x0 - 1, y0 - 2 + (i == 0), x1 + 1, y0 - 1 - (i == 0) * 1, "night", 0)
    if not angry and eyes == "open":
        mx = (ex0 + ex1) / 2
        c.px(int(mx), int(ey + 5), "night", 0)
        c.px(int(mx) + 1, int(ey + 5), "night", 0)
        c.px(int(ex1) + 3, int(ey + 3), "rose", 4)
    c.outline("ink")
    c.despeckle()
    return c


def splat(t: int) -> HDCanvas:
    c = HDCanvas(FRAME, FRAME)
    spread = 1.0 + t * 0.25
    puddle = c.ellipse(CX, GROUND - 3, 22 * spread, 5 - t * 0.5)
    for i in range(5):
        a = i / 5 * math.tau + 0.4
        puddle |= c.ellipse(CX + math.cos(a) * 18 * spread, GROUND - 3 + math.sin(a) * 3, 3.0, 2.0)
    c.draw(puddle, JELLY, "round", bias=-1 - (t >= 3), name="puddle")
    if t < 3:
        c.draw(c.ellipse(CX, GROUND - 6 - t, 3.5 - t, 3.5 - t), "teal", "glow", name="core")
    c.outline("ink")
    return c


def animations() -> dict:
    return {
        "idle": [draw(squash=s).image() for s in (0.0, 0.08, 0.14, 0.08)],
        "move": [draw(squash=0.25, lean=1).image(), draw(squash=-0.2, lift=4, lean=2).image(),
                 draw(squash=-0.1, lift=7, lean=2).image(), draw(squash=0.3, lean=1).image()],
        "attack": [draw(squash=0.4, angry=True).image(), draw(squash=-0.35, lift=6, lean=5, angry=True).image(),
                   draw(squash=0.2, lean=3, angry=True).image()],
        "hurt": [draw(squash=0.2, lean=-3, eyes="closed").image()],
        "death": [draw(squash=0.45, eyes="x").image()] + [splat(t).image() for t in range(4)],
    }
