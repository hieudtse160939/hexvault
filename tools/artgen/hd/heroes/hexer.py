"""Nyx, the Hexer - HD hex caster. Silhouette: tall bent hood, floor-length
violet robe, glowing teal eyes in a shadowed face, a hex flame orbiting the hand."""
from __future__ import annotations

import math

import kit
from kit import Look

PR = kit.proportions(k=1.25, torso=17.5, upper_arm=8.0, forearm=8.0)
PIVOT = (int(PR.cx), int(PR.ground))
FPS, LOOP = kit.FPS, kit.LOOP
SPEC = {"id": "hexer", "sprite": "hero_hexer", "version": 1, "source": "procedural: tools/artgen/hd/heroes/hexer.py"}


def _wisp(x) -> None:
    """A small hex flame circling the near hand; brighter while casting."""
    c, R, p = x.c, x.R, x.p
    hx, hy = x.sk.hand_near
    ph = p.sway * 1.6 + p.glow * 3.0
    ox, oy = hx + math.cos(ph) * R(5.5), hy - R(6.0) + math.sin(ph) * R(2.0)
    flame = c.ellipse(ox, oy, R(2.2), R(3.0)) | c.poly([(ox - R(1.6), oy - R(1.0)), (ox + R(1.6), oy - R(1.0)), (ox + R(0.4), oy - R(5.5))])
    c.draw(flame, "violet", "glow", name="hex_flame")
    c.fixed(c.ellipse(ox, oy + R(0.4), R(0.9), R(1.3)), "glow_teal")


def _sigil(x) -> None:
    """Rune stitched on the robe front."""
    c = x.c
    cx, cy = x.bp(-6.0, 4.0)
    ring = c.ellipse(cx, cy, x.R(2.6), x.R(2.6)) & ~c.ellipse(cx, cy, x.R(1.5), x.R(1.5))
    c.fill(ring, "amber", 3, name="sigil")


LOOK = Look(
    skin="night", hair="hair_silver", eyes="glow_teal", eye_glow=True, torso="violet", trim="amber",
    sleeve="violet", glove="night", pants="night", boot="night", belt="night", head="hood", head_ramp="violet",
    body="robe", width=0.95, collar="night", glow="glow_violet",
    extra_front=lambda x: (_sigil(x), _wisp(x)), params={"tall_hood": True, "face_bias": -2},
)


def animations() -> dict:
    return kit.animations(LOOK, PR)
