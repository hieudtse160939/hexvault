"""Ignis, the Pyromancer. Silhouette: tall crimson witch hat, spiky red hair,
flame-orange coat with a cape, a fire orb dancing over the hand."""
from __future__ import annotations

import kit
from _common import orb
from kit import Look

PR = kit.proportions(k=1.25)
PIVOT = (int(PR.cx), int(PR.ground))
FPS, LOOP = kit.FPS, kit.LOOP
SPEC = {"id": "pyromancer", "sprite": "hero_pyromancer", "version": 1, "source": "procedural: tools/artgen/hd/heroes/pyromancer.py"}

LOOK = Look(
    skin="skin_fair", hair="hair_red", iris="amber", torso="flame", trim="amber", sleeve="flame", glove="leather",
    pants="night", boot="leather", belt="leather", head="hair", hair_style="spiky", head_ramp="crimson", body="coat",
    cape="crimson", extra_front=lambda x: orb(x, "flame", "glow_amber"), glow="glow_amber", params={"hat": True},
)


def animations() -> dict:
    return kit.animations(LOOK, PR)
