"""Sable, the Assassin. Silhouette: slim, black hair, a long cloth mask over
the lower face trailing back, twin daggers crossed on the back."""
from __future__ import annotations

import math

import kit
from kit import Look

PR = kit.proportions(k=1.22)
PIVOT = (int(PR.cx), int(PR.ground))
FPS, LOOP = kit.FPS, kit.LOOP
SPEC = {"id": "assassin", "sprite": "hero_assassin", "version": 1, "source": "procedural: tools/artgen/hd/heroes/assassin.py"}


def _daggers(x) -> None:
    c, R = x.c, x.R
    for a_deg in (-35.0, -145.0):
        a = math.radians(a_deg)
        base = x.bp(9.0, -7.0)
        tip = (base[0] + math.cos(a) * R(13.0), base[1] + math.sin(a) * R(13.0))
        c.draw(c.capsule(base[0], base[1], tip[0], tip[1], R(1.3), R(0.6)), "steel", "metal", name="dagger")


def _mask(x) -> None:
    c, R, p = x.c, x.R, x.p
    wind = float(p.extras.get("wind", 0.0))
    m = c.ellipse(*x.hp(7.5, 8.2), R(7.6), R(3.6), rot=x.sk.angle) & c.ellipse(*x.hp(0.0, 0.0), x.hr + R(0.6), x.hr, rot=x.sk.angle)
    c.draw(m, "violet", "cloth", bias=-1, name="face_mask")
    t0 = x.hp(-10.0, 7.0)
    t1 = x.hp(-22.0 - wind * 4.0, 10.0 - wind * 6.0 + p.sway * 2.0)
    c.draw(c.capsule(t0[0], t0[1], t1[0], t1[1], R(2.4), R(1.0)), "violet", "cloth", bias=-1, name="mask_tail")


LOOK = Look(
    skin="skin_fair", hair="hair_silver", iris="violet", torso="slate", trim="violet", sleeve="night", glove="night",
    pants="night", boot="night", belt="night", head="hair", hair_style="short", body="tunic", width=0.9,
    extra_back=_daggers, extra_head=_mask, glow="glow_violet",
)


def animations() -> dict:
    return kit.animations(LOOK, PR, kit.skill_slash())
