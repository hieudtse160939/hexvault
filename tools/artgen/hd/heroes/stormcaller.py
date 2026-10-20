"""Volt, the Stormcaller. Silhouette: wild spiky gold hair with a crackle of
sparks, azure long coat, violet cape, a lightning rod slung on the back."""
from __future__ import annotations

import kit
from kit import Look

PR = kit.proportions(k=1.28)
PIVOT = (int(PR.cx), int(PR.ground))
FPS, LOOP = kit.FPS, kit.LOOP
SPEC = {"id": "stormcaller", "sprite": "hero_stormcaller", "version": 1, "source": "procedural: tools/artgen/hd/heroes/stormcaller.py"}


def _rod(x) -> None:
    c, R = x.c, x.R
    a, b = x.bp(-6.0, -9.0), x.bp(20.0, -4.0)
    c.draw(c.capsule(a[0], a[1], b[0], b[1], R(1.3), R(1.1)), "steel", "metal", bias=-1, name="rod")
    for t in (0.55, 0.75):
        px_, py_ = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        c.draw(c.ellipse(px_, py_, R(2.2), R(1.4)), "amber", "metal", bias=-1, name="coil")
    c.fixed(c.ellipse(b[0], b[1], R(1.5), R(1.5)), "glow_violet")


def _sparks(x) -> None:
    c = x.c
    ph = int((x.p.sway + 1.0) * 3) % 3
    for i, (dx, dy) in enumerate(((-9.0, -16.0), (3.0, -19.0), (-15.0, -9.0), (9.0, -14.0))):
        if (i + ph) % 3 == 0:
            continue
        p0 = x.hp(dx, dy)
        c.line(p0[0], p0[1], p0[0] + 2, p0[1] + 2, "glow_violet")


LOOK = Look(
    skin="skin_tan", hair="hair_gold", iris="azure", torso="azure", trim="amber", sleeve="azure", glove="night",
    pants="night", boot="night", belt="night", head="hair", hair_style="spiky", body="coat", cape="violet",
    extra_back=_rod, extra_head=_sparks, glow="glow_violet",
)


def animations() -> dict:
    return kit.animations(LOOK, PR)
