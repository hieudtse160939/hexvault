"""Small prop painters shared by several hero designs."""
from __future__ import annotations

import math


def blade_on_back(x, ramp: str = "steel", sheath: str = "night", length: float = 26.0, angle_deg: float = -50.0) -> None:
    c, R = x.c, x.R
    a = math.radians(angle_deg)
    base = x.bp(4.0, -7.5)
    tip = (base[0] + math.cos(a) * R(length) * -1, base[1] + math.sin(a) * R(length))
    c.draw(c.capsule(base[0], base[1], tip[0], tip[1], R(1.9), R(1.5)), sheath, "round", bias=-1, name="sheath")
    hilt = (base[0] + math.cos(a) * R(5.0), base[1] - math.sin(a) * R(5.0))
    c.draw(c.capsule(base[0], base[1], hilt[0], hilt[1], R(1.3), R(1.3)), "leather", "round", name="hilt")
    c.draw(c.ellipse(base[0], base[1], R(2.6), R(1.2), rot=a), "amber", "metal", name="guard")


def orb(x, ramp: str, glow: str, dx: float = 6.0, dy: float = -7.0, r: float = 2.6) -> None:
    c, R, p = x.c, x.R, x.p
    hx, hy = x.sk.hand_near
    ph = p.sway * 1.4 + p.glow * 3.0
    ox, oy = hx + R(dx) + math.cos(ph) * R(1.2), hy + R(dy) + math.sin(ph) * R(1.0)
    c.draw(c.ellipse(ox, oy, R(r), R(r)), ramp, "glow", name="orb")
    c.fixed(c.ellipse(ox - R(0.5), oy - R(0.5), R(r * 0.35), R(r * 0.35)), glow)


def round_shield(x, rim: str, face: str, emblem: str) -> None:
    c, R = x.c, x.R
    cx, cy = x.bp(7.0, -9.5)
    c.draw(c.ellipse(cx, cy, R(8.0), R(9.0)), rim, "metal", bias=-1, name="shield_rim")
    c.draw(c.ellipse(cx, cy, R(6.4), R(7.4)), face, "plate", bias=-1, name="shield_face", selout=False)
    c.draw(c.ellipse(cx, cy, R(2.4), R(2.6)), emblem, "metal", name="shield_boss")
