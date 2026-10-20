"""Cog, the Tinker - HD engineer. Silhouette: short and stocky, cap with
welding goggles, big brass backpack with an antenna and a gear, tool belt."""
from __future__ import annotations

import math

import kit
from kit import Look

PR = kit.proportions(k=1.18, head_r=11.5, torso=16.0, hip_w=3.4, pelvis_y=58.5)
PIVOT = (int(PR.cx), int(PR.ground))
FPS, LOOP = kit.FPS, kit.LOOP
SPEC = {"id": "tinker", "sprite": "hero_tinker", "version": 1, "source": "procedural: tools/artgen/hd/heroes/tinker.py"}


def _pack(x) -> None:
    c, R, sw = x.c, x.R, x.p.sway
    a, b = x.bp(15.0, -9.0), x.bp(1.0, -10.5)
    box = c.capsule(a[0], a[1], b[0], b[1], R(6.5), R(6.0))
    c.draw(box, "amber", "plate", bias=-1, name="backpack")
    st0, st1 = x.bp(13.0, -15.5), x.bp(3.0, -16.0)
    c.draw(c.capsule(st0[0], st0[1], st1[0], st1[1], R(1.6), R(1.6)), "steel", "metal", bias=-1, name="pack_pipe")
    gx, gy = x.bp(7.0, -14.5)
    gear = c.ellipse(gx, gy, R(4.0), R(4.0))
    for k in range(8):
        a2 = k / 8 * math.tau + sw * 0.4
        gear |= c.ellipse(gx + math.cos(a2) * R(4.2), gy + math.sin(a2) * R(4.2), R(1.1), R(1.1))
    c.draw(gear & ~c.ellipse(gx, gy, R(1.4), R(1.4)), "steel", "metal", name="gear")
    t0 = x.bp(17.0, -12.0)
    t1 = (t0[0] - R(3.0 + sw), t0[1] - R(12.0))
    c.line(t0[0], t0[1], t1[0], t1[1], "steel", 2)
    c.fixed(c.ellipse(t1[0], t1[1], R(1.3), R(1.3)), "glow_teal")


def _cap(x) -> None:
    c, R = x.c, x.R
    dome = c.ellipse(*x.hp(-0.5, -5.0), R(11.4), R(6.8), rot=x.sk.angle) & ~c.ellipse(*x.hp(-0.5, 4.5), R(13.0), R(8.0), rot=x.sk.angle)
    c.draw(dome, "amber", "cloth", bias=-1, name="cap")
    v0, v1 = x.hp(4.0, -4.6), x.hp(15.0, -3.6)
    c.draw(c.capsule(v0[0], v0[1], v1[0], v1[1], R(1.6), R(1.3)), "amber", "plate", bias=-2, name="cap_visor")
    # goggles pushed up on the cap
    for dx in (1.0, 6.5):
        gx, gy = x.hp(dx, -7.0)
        c.draw(c.ellipse(gx, gy, R(2.6), R(2.4)), "steel", "metal", name="goggle")
        c.draw(c.ellipse(gx + R(0.3), gy, R(1.5), R(1.3)), "frost", "metal", bias=1, name="goggle_glass", selout=False)


def _tools(x) -> None:
    c, R = x.c, x.R
    wx, wy = x.bp(-1.5, 5.5)
    c.draw(c.capsule(wx, wy, wx + R(1.0), wy + R(7.0), R(1.1), R(1.0)), "steel", "metal", name="wrench")
    c.draw(c.ellipse(wx + R(1.2), wy + R(7.6), R(1.8), R(1.4)), "steel", "metal", name="wrench_head")


LOOK = Look(
    skin="skin_tan", hair="hair_red", eyes="hair_ink", torso="leather", trim="amber", sleeve="cloth",
    glove="leather", pants="stone", boot="leather", belt="leather", head="hair", hair_style="short",
    body="tunic", width=1.15, extra_back=_pack, extra_head=_cap, extra_front=_tools, glow="glow_teal",
)


def animations() -> dict:
    return kit.animations(LOOK, PR)
