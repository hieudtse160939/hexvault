"""Morrow, the Necromancer. Silhouette: dark hood crowned with bone antlers,
long night robe with moss trim, a ghost wisp at the hand."""
from __future__ import annotations

import kit
from _common import orb
from kit import Look

PR = kit.proportions(k=1.25)
PIVOT = (int(PR.cx), int(PR.ground))
FPS, LOOP = kit.FPS, kit.LOOP
SPEC = {"id": "necromancer", "sprite": "hero_necromancer", "version": 1, "source": "procedural: tools/artgen/hd/heroes/necromancer.py"}


def _antlers(x) -> None:
    c, R = x.c, x.R
    for side, ox in ((-1, -5.0), (1, 3.0)):
        b = x.hp(ox, -12.0)
        m = x.hp(ox - 2.0 + side * 1.0, -19.0)
        t = x.hp(ox - 6.0 + side * 2.0, -24.0)
        br = x.hp(ox + 3.0 * side, -21.0)
        a = c.capsule(b[0], b[1], m[0], m[1], R(1.5), R(1.2)) | c.capsule(m[0], m[1], t[0], t[1], R(1.2), R(0.6))
        a |= c.capsule(m[0], m[1], br[0], br[1], R(1.1), R(0.5))
        c.draw(a, "bone", "round", bias=0 if side > 0 else -1, name="antler")


LOOK = Look(
    skin="skin_fair", hair="hair_ink", iris="moss", torso="night", trim="moss", sleeve="night", glove="bone",
    pants="night", boot="night", belt="moss", head="hood", head_ramp="night", body="robe",
    extra_head=_antlers, extra_front=lambda x: orb(x, "moss", "glow_teal"), glow="glow_teal",
)


def animations() -> dict:
    return kit.animations(LOOK, PR)
