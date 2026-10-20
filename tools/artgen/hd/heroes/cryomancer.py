"""Rime, the Cryomancer. Silhouette: long silver hair under an ice crown,
pale blue robe with a white fur collar, a frost orb in hand."""
from __future__ import annotations

import kit
from _common import orb
from kit import Look

PR = kit.proportions(k=1.25)
PIVOT = (int(PR.cx), int(PR.ground))
FPS, LOOP = kit.FPS, kit.LOOP
SPEC = {"id": "cryomancer", "sprite": "hero_cryomancer", "version": 1, "source": "procedural: tools/artgen/hd/heroes/cryomancer.py"}


def _crown(x) -> None:
    c, R = x.c, x.R
    for dx, h in ((-6.0, 5.0), (-1.5, 7.5), (3.0, 6.0), (7.0, 4.0)):
        b0, b1 = x.hp(dx - 1.6, -11.0), x.hp(dx + 1.6, -11.0)
        tip = x.hp(dx, -11.0 - h)
        c.draw(c.poly([b0, b1, tip]), "frost", "metal", bias=1, name="ice_spike")
    band = c.ellipse(*x.hp(0.0, -10.6), R(10.0), R(1.6), rot=x.sk.angle)
    c.draw(band, "frost", "metal", name="crown_band")
    gx, gy = x.hp(0.5, -10.8)
    c.fixed(c.ellipse(gx, gy, R(1.0), R(1.0)), "glow_frost")


LOOK = Look(
    skin="skin_fair", hair="hair_silver", iris="frost", torso="frost", trim="azure", sleeve="frost", glove="bone",
    pants="slate", boot="slate", belt="azure", head="hair", hair_style="long", body="robe", collar="bone",
    extra_head=_crown, extra_front=lambda x: orb(x, "frost", "glow_frost"), glow="glow_frost",
)


def animations() -> dict:
    return kit.animations(LOOK, PR)
