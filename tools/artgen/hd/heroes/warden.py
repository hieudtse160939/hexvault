"""Bramble, the Warden - HD guardian. Silhouette: broad plate armour, great
helm with a moss plume, tower shield on the back, moss-green cape."""
from __future__ import annotations

import kit
from kit import Look

PR = kit.proportions(k=1.35, hip_w=3.6, shoulder_w=4.2, thigh=9.5, shin=9.0, pelvis_y=58.0)
PIVOT = (int(PR.cx), int(PR.ground))
FPS, LOOP = kit.FPS, kit.LOOP
SPEC = {"id": "warden", "sprite": "hero_warden", "version": 1, "source": "procedural: tools/artgen/hd/heroes/warden.py"}


def _shield(x) -> None:
    c, R = x.c, x.R
    top, bot = x.bp(17.0, -9.0), x.bp(-6.0, -9.5)
    m = c.capsule(top[0], top[1], bot[0], bot[1], R(7.5), R(6.0))
    c.draw(m, "steel", "plate", bias=-1, name="tower_shield")
    face = c.capsule(top[0], top[1], bot[0], bot[1], R(6.0), R(4.6))
    c.draw(face, "moss", "plate", bias=-2, name="shield_face", selout=False, cast=False)
    mx, my = x.bp(6.0, -9.3)
    c.draw(c.ellipse(mx, my, R(2.6), R(3.2)), "amber", "metal", bias=-1, name="shield_boss")


def _plume(x) -> None:
    c, R, sw = x.c, x.R, x.p.sway
    wind = float(x.p.extras.get("wind", 0.0))
    base = x.hp(-1.0, -10.5)
    tip = x.hp(-11.0 - wind * 4.0 - sw * 1.5, -9.0 - wind * 2.0 + sw)
    mid = x.hp(-6.0 - wind * 2.0, -14.0)
    m = c.capsule(base[0], base[1], mid[0], mid[1], R(2.8), R(2.6)) | c.capsule(mid[0], mid[1], tip[0], tip[1], R(2.6), R(0.8))
    c.draw(m, "moss", "cloth", name="plume")
    # brass brow band around the helm
    band = c.ellipse(*x.hp(-0.3, -3.6), R(11.2), R(2.0), rot=x.sk.angle) & c.ellipse(*x.hp(-0.3, 0.0), R(11.0), R(10.4), rot=x.sk.angle)
    c.draw(band, "amber", "metal", bias=-1, name="helm_band", selout=False)
    for dx in (-6.0, 0.0, 6.0):
        rx, ry = x.hp(dx, -3.6)
        c.px(int(rx), int(ry), "amber", 5)


LOOK = Look(
    skin="skin_tan", eyes="glow_teal", torso="steel", torso_form="plate", trim="amber", sleeve="slate",
    glove="steel", pants="slate", boot="slate", belt="leather", head="helm", head_ramp="steel",
    body="armor", width=1.3, cape="moss", pauldrons="steel", gauntlet="steel", tabard="moss",
    extra_back=_shield, extra_head=_plume, glow="glow_teal",
)


def animations() -> dict:
    return kit.animations(LOOK, PR)
