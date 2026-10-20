"""Brixa, the Artillerist. Silhouette: crimson bandana with big ear
protectors, heavy stone-grey coat, shell bandolier, mortar tube on the back."""
from __future__ import annotations

import kit
from kit import Look

PR = kit.proportions(k=1.28, hip_w=3.4)
PIVOT = (int(PR.cx), int(PR.ground))
FPS, LOOP = kit.FPS, kit.LOOP
SPEC = {"id": "artillerist", "sprite": "hero_artillerist", "version": 1, "source": "procedural: tools/artgen/hd/heroes/artillerist.py"}


def _mortar(x) -> None:
    c, R = x.c, x.R
    a, b = x.bp(-4.0, -9.0), x.bp(19.0, -13.0)
    c.draw(c.capsule(a[0], a[1], b[0], b[1], R(3.4), R(3.6)), "steel", "metal", bias=-1, name="mortar")
    c.draw(c.ellipse(b[0], b[1], R(3.6), R(2.0), rot=x.sk.angle + 0.3), "night", "flat", name="muzzle")
    for t in (0.3, 0.6):
        px_, py_ = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        c.draw(c.ellipse(px_, py_, R(3.8), R(1.4), rot=0.3), "amber", "metal", bias=-1, name="band")


def _gear(x) -> None:
    c, R = x.c, x.R
    band = c.ellipse(*x.hp(-0.5, -8.0), x.hr + R(0.6), R(2.6), rot=x.sk.angle) & c.ellipse(*x.hp(0, -2.0), x.hr + R(1.0), x.hr + R(0.6), rot=x.sk.angle)
    c.draw(band, "crimson", "cloth", name="bandana")
    k0, k1 = x.hp(-11.0, -8.0), x.hp(-16.0 - x.p.sway * 2, -4.0)
    c.draw(c.capsule(k0[0], k0[1], k1[0], k1[1], R(1.6), R(0.8)), "crimson", "cloth", bias=-1, name="bandana_tail")
    ex, ey = x.hp(-3.5, 2.0)
    c.draw(c.ellipse(ex, ey, R(3.8), R(4.4), rot=x.sk.angle), "amber", "plate", name="ear_muff")
    c.draw(c.ellipse(ex, ey, R(2.0), R(2.4), rot=x.sk.angle), "night", "flat", name="ear_pad")
    # bandolier with shells across the chest
    s0, s1 = x.bp(15.0, -6.0), x.bp(1.0, 6.0)
    c.draw(c.capsule(s0[0], s0[1], s1[0], s1[1], R(1.4), R(1.4)), "leather", "flat", name="bandolier")
    for t in (0.25, 0.5, 0.75):
        px_, py_ = s0[0] + (s1[0] - s0[0]) * t, s0[1] + (s1[1] - s0[1]) * t
        c.draw(c.ellipse(px_, py_, R(1.2), R(1.6)), "amber", "metal", name="shell")


LOOK = Look(
    skin="skin_tan", hair="hair_gold", iris="crimson", torso="stone", trim="amber", sleeve="stone", glove="leather",
    pants="slate", boot="leather", belt="leather", head="hair", hair_style="short", body="coat", width=1.1,
    extra_back=_mortar, extra_front=_gear, glow="glow_amber",
)


def animations() -> dict:
    return kit.animations(LOOK, PR)
