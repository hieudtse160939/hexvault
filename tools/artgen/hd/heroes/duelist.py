"""Kaida, the Blade Dancer - duelist. Silhouette: long black ponytail, short
crimson tunic with a gold sash, bare arms, a katana across the back."""
from __future__ import annotations

import kit
from _common import blade_on_back
from kit import Look

PR = kit.proportions(k=1.25)
PIVOT = (int(PR.cx), int(PR.ground))
FPS, LOOP = kit.FPS, kit.LOOP
SPEC = {"id": "duelist", "sprite": "hero_duelist", "version": 1, "source": "procedural: tools/artgen/hd/heroes/duelist.py"}

LOOK = Look(
    skin="skin_fair", hair="hair_ink", iris="crimson", torso="crimson", trim="amber", sleeve="skin_fair",
    glove="leather", pants="night", boot="night", belt="amber", head="hair", hair_style="ponytail", body="tunic",
    width=0.92, extra_back=lambda x: blade_on_back(x), glow="glow_red", params={"hair_band": "amber"},
)


def animations() -> dict:
    return kit.animations(LOOK, PR, kit.skill_slash())
