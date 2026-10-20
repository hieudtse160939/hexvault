"""Vex, the Rift Ranger - reference hero (anime RPG style).

Silhouette: pointed teal hood with goggles pushed up on the brow, crimson
scarf trailing back, long split coat, chunky boots. Accent: amber.
"""
from __future__ import annotations

import math

import kit
from kit import Look

PR = kit.proportions(k=1.3)
PIVOT = (int(PR.cx), int(PR.ground))
FPS, LOOP = kit.FPS, kit.LOOP
SPEC = {"id": "ranger", "sprite": "hero_ranger", "version": 3, "source": "procedural: tools/artgen/hd/heroes/ranger.py"}


def _scarf_tail(x) -> None:
    """Two ribbons: hang down when still, stream back when moving."""
    c, R, p = x.c, x.R, x.p
    n = x.sk.neck
    wind = float(p.extras.get("wind", 0.0))
    for k, (ln, w) in enumerate(((16.0, 3.0), (12.0, 2.5))):
        pts = []
        segs = 9
        ang = math.radians(100 - 85 * wind + k * 14)
        for i in range(segs + 1):
            t = i / segs
            dirx, diry = -math.cos(ang), math.sin(ang)
            fl = math.sin(t * 3.4 + p.sway * 1.8 + k * 1.3) * (0.4 + 2.0 * t) * (0.4 + wind)
            pts.append((n[0] + R(-2.5 + dirx * t * ln - diry * fl * 0.5), n[1] + R(-1.5 + diry * t * ln + fl * (0.3 + 0.7 * wind))))
        top = [(px, py - R(w * (1 - 0.5 * i / segs))) for i, (px, py) in enumerate(pts)]
        bot = [(px + R(0.8), py + R(w * (1 - 0.5 * i / segs) * 0.5)) for i, (px, py) in enumerate(pts)]
        c.draw(c.poly(top + bot[::-1]), "crimson", "cloth", bias=-1 if k else 0, name="scarf_tail")


def _scarf_wrap(x) -> None:
    c, R, sk = x.c, x.R, x.sk
    wrap = c.ellipse(*x.hp(-1.0, 13.2), R(9.0), R(3.0), rot=sk.angle)
    c.draw(wrap, "crimson", "cloth", name="scarf_wrap")
    knot = [x.hp(4.0, 13.4), x.hp(7.0, 13.8), x.hp(5.5 - x.p.sway, 19.0), x.hp(3.5 - x.p.sway, 18.0)]
    c.draw(c.poly(knot), "crimson", "cloth", bias=-1, name="scarf_knot")


def _goggles(x) -> None:
    c, R, sk = x.c, x.R, x.sk
    s0, s1 = x.hp(-6.0, -8.0), x.hp(9.0, -7.0)
    c.draw(c.capsule(s0[0], s0[1], s1[0], s1[1], R(1.1), R(1.1)), "slate", "flat", name="strap")
    for dx in (2.5, 8.6):
        gx, gy = x.hp(dx, -7.6)
        c.draw(c.ellipse(gx, gy, R(2.8), R(2.4), rot=sk.angle), "slate", "plate", name="goggle_frame")
        c.draw(c.ellipse(gx + R(0.3), gy, R(1.8), R(1.4), rot=sk.angle), "amber", "metal", bias=1, name="lens", selout=False)
    gx, gy = x.hp(8.0, -8.2)
    c.px(int(gx), int(gy), "glow_amber")


def _holster(x) -> None:
    c, R = x.c, x.R
    hx, hy = x.bp(-2.8, -4.6)
    c.draw(c.ellipse(hx, hy, R(2.5), R(3.3)), "leather", "round", bias=-1, name="pouch")


LOOK = Look(
    skin="skin_fair", hair="hair_brown", iris="amber", torso="teal", trim="amber", sleeve="teal", glove="hair_ink",
    pants="slate", boot="leather", belt="leather", head="hood", head_ramp="teal", body="coat", width=1.0,
    extra_back=_scarf_tail, extra_head=lambda x: (_scarf_wrap(x), _goggles(x)), extra_front=_holster,
)


def animations() -> dict:
    return kit.animations(LOOK, PR)
