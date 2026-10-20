"""Hex Acolyte - HD summoner, built on the hero kit so it shares anatomy and
light: a cultist in a deep violet hood with glowing red eyes, a skull-topped
staff and bone charms. Smaller than the heroes (k = 1.1)."""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "heroes"))
import kit  # noqa: E402
from kit import Look  # noqa: E402

PR = kit.proportions(k=1.1)
PIVOT = (int(PR.cx), int(PR.ground))
SPEC = {"id": "acolyte", "sprite": "enemy_acolyte", "version": 1, "source": "procedural: tools/artgen/hd/enemies/acolyte.py"}
FPS = {"idle": 6, "move": 10, "attack": 10, "hurt": 10, "death": 9}
LOOP = {"idle": True, "move": True}


def _staff(x) -> None:
    c, R = x.c, x.R
    hx, hy = x.sk.hand_far
    hx -= R(3.0)
    top = (hx - R(4.0), hy - R(36.0))
    c.draw(c.capsule(hx + R(0.5), hy + R(8.0), top[0], top[1], R(1.1), R(1.1)), "hair_brown", "round", name="staff")
    c.draw(c.ellipse(top[0], top[1] - R(2.0), R(3.2), R(3.0)), "bone", "round", name="skull")
    c.fill(c.rect(int(top[0]), int(top[1] - R(2.4)), int(top[0] + 1), int(top[1] - R(1.6))), "night", 0)
    gx, gy = top[0] + R(0.5), top[1] - R(2.0)
    c.fixed(c.ellipse(gx + R(1.5), gy, R(0.7), R(0.7)), "glow_violet" if x.p.glow == 0 else "glow_red")


LOOK = Look(
    skin="night", hair="hair_ink", eyes="glow_red", eye_glow=True, torso="violet", trim="bone", sleeve="violet",
    glove="bone", pants="night", boot="night", belt="bone", head="hood", head_ramp="night", hair_style="none",
    body="robe", collar="bone", extra_back=_staff, glow="glow_violet", params={"brows": False},
)


def animations() -> dict:
    ps = kit.poses()
    pick = lambda name, idx: [kit._fit(LOOK, PR, ps[name][i]) if name == "death" else kit.draw(LOOK, PR, ps[name][i]).image() for i in idx]
    return {
        "idle": pick("idle", (0, 2, 3, 5)),
        "move": pick("run", (1, 5)),
        "attack": pick("skill", (0, 2, 3, 4)),
        "hurt": pick("hurt", (0,)),
        "death": pick("death", (0, 2, 4, 7)),
    }
