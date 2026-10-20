"""Halvard, the Paladin. Silhouette: white-and-gold plate, winged open helm,
azure tabard with a sun, round gold shield on the back."""
from __future__ import annotations

import kit
from _common import round_shield
from kit import Look

PR = kit.proportions(k=1.32, hip_w=3.5, shoulder_w=4.0)
PIVOT = (int(PR.cx), int(PR.ground))
FPS, LOOP = kit.FPS, kit.LOOP
SPEC = {"id": "paladin", "sprite": "hero_paladin", "version": 1, "source": "procedural: tools/artgen/hd/heroes/paladin.py"}


def _wings(x) -> None:
    c, R = x.c, x.R
    for i, (dx, dy) in enumerate(((-14.0, -8.0), (-17.0, -14.0), (-17.5, -20.0))):
        b = x.hp(-8.0, -6.0 - i * 1.5)
        t = x.hp(dx - 2.0, dy - 2.0)
        c.draw(c.capsule(b[0], b[1], t[0], t[1], R(2.8 - i * 0.4), R(1.0)), "bone", "round", bias=1 - i, name="wing")
    sx, sy = x.bp(6.0, 3.6)
    c.fixed(c.ellipse(sx, sy, R(1.4), R(1.4)), "glow_amber")


LOOK = Look(
    skin="skin_fair", hair="hair_gold", iris="azure", torso="bone", torso_form="plate", trim="amber", sleeve="bone",
    glove="amber", pants="slate", boot="steel", belt="leather", head="helm", head_ramp="amber", body="armor", width=1.2,
    tabard="azure", pauldrons="amber", gauntlet="steel",
    extra_back=lambda x: round_shield(x, "amber", "azure", "amber"), extra_head=_wings, glow="glow_amber",
)


def animations() -> dict:
    return kit.animations(LOOK, PR, kit.skill_slash())
