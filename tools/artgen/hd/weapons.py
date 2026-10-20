"""HD weapon sprites (density 4). Frame 96 x 48, grip pivot (24, 28) - the
16 px weapons' (6, 7) pivot times 4, so held positions are unchanged.
Each weapon records its muzzle point so shots leave the barrel tip."""
from __future__ import annotations

from canvas import HDCanvas

FRAME = (96, 48)
PIVOT = (24, 28)


def rift_pistol() -> HDCanvas:
    c = HDCanvas(*FRAME)
    # grip, angled back, wrapped
    grip = c.poly([(21, 27), (29, 27), (27, 41), (19, 40)])
    c.draw(grip, "hair_ink", "round", bias=1, name="grip")
    for y in (31, 35, 39):
        c.line(20, y, 27, y - 1, "hair_ink", 1)
    c.draw(c.ellipse(23, 41, 4.2, 2.0), "steel", "plate", bias=-1, name="pommel")
    # trigger guard
    guard = c.ellipse(33, 30, 4.5, 3.6) & ~c.ellipse(33, 29.4, 2.8, 2.2) & c.rect(28, 29, 38, 40)
    c.draw(guard, "slate", "plate", name="guard")
    c.draw(c.rect(32, 28, 33, 31), "steel", "flat", bias=-1, name="trigger")
    # receiver
    body = c.poly([(19, 16), (47, 16), (49, 21), (47, 29), (22, 29), (18, 23)])
    c.draw(body, "steel", "plate", name="receiver")
    c.draw(c.rect(18, 13, 22, 17), "slate", "plate", name="hammer")
    # barrel + shroud
    c.draw(c.capsule(46, 20.5, 64, 20.5, 3.4, 3.4), "steel", "metal", name="barrel")
    c.draw(c.rect(46, 15, 60, 18), "slate", "plate", name="rail")
    for x in (49, 53, 57):
        c.px(x, 16, "slate", 0)
    c.draw(c.ellipse(65, 20.5, 2.4, 4.2), "slate", "plate", name="muzzle_ring")
    c.fixed(c.ellipse(66.5, 20.5, 0.9, 1.6), "void")
    # rift cell: glowing teal core in a window
    c.draw(c.capsule(27, 22, 41, 22, 3.2, 3.2), "night", "soft", name="cell_window")
    c.draw(c.capsule(28, 22, 40, 22, 2.0, 2.0), "teal", "metal", bias=1, name="cell")
    c.fixed(c.rect(30, 21, 37, 21), "glow_teal")
    # amber screws
    for x, y in ((23, 19), (44, 26)):
        c.px(x, y, "amber", 4)
    c.outline("ink")
    c.despeckle()
    return c


def cinder_wand() -> HDCanvas:
    c = HDCanvas(*FRAME)
    # charred wood shaft with a leather grip, ember crystal caged at the tip
    c.draw(c.capsule(20, 31, 56, 21, 2.6, 2.2), "hair_brown", "round", bias=-1, name="shaft")
    c.draw(c.capsule(20, 31, 30, 28.2, 3.0, 3.0), "leather", "round", name="grip")
    for x0 in (22, 26):
        c.line(x0, 33, x0 + 1, 28, "leather", 1)
    claw = c.ellipse(60, 19, 6.0, 6.5) & ~c.ellipse(60, 19, 4.2, 4.6)
    c.draw(claw & ~c.rect(61, 10, 70, 16), "amber", "metal", bias=-1, name="cage")
    c.draw(c.ellipse(60.5, 18.5, 4.0, 4.6), "flame", "glow", name="ember")
    c.fixed(c.ellipse(59.5, 17.5, 1.4, 1.8), "glow_amber")
    for x, y in ((66, 12), (68, 16), (63, 10)):
        c.px(x, y, "flame", 4)
    c.outline("ink")
    c.despeckle()
    return c


def wisp_lantern() -> HDCanvas:
    c = HDCanvas(*FRAME)
    c.draw(c.capsule(20, 30, 44, 24, 2.0, 1.8), "night", "round", name="pole")
    c.draw(c.capsule(20, 30, 28, 28, 2.6, 2.6), "bone", "round", bias=-1, name="grip")
    c.line(44, 24, 50, 16, "steel", 2)
    body = c.ellipse(56, 25, 7.5, 9.0)
    c.draw(body, "steel", "metal", bias=-1, name="lantern")
    glass = c.ellipse(56, 26, 5.0, 6.5)
    c.draw(glass, "moss", "glow", bias=-1, name="glass")
    c.fixed(c.ellipse(56, 27, 2.0, 3.0), "glow_teal")
    for y in (20, 26, 32):
        c.line(50, y, 62, y, "steel", 1)
    c.draw(c.ellipse(56, 15.5, 4.0, 2.0), "steel", "plate", name="cap")
    c.draw(c.ellipse(56, 35, 3.6, 1.8), "steel", "plate", bias=-1, name="base")
    c.outline("ink")
    c.despeckle()
    return c


def sunforge_mace() -> HDCanvas:
    c = HDCanvas(*FRAME)
    c.draw(c.capsule(18, 31, 52, 23, 2.4, 2.4), "leather", "round", name="haft")
    for x0 in (20, 24, 28):
        c.line(x0, 33, x0 + 1, 29, "leather", 0)
    c.draw(c.ellipse(19, 31.5, 3.0, 3.0), "amber", "metal", name="pommel")
    head = c.ellipse(60, 21, 8.5, 8.5)
    for k in range(6):  # flanges
        import math
        a = k / 6 * math.tau
        head |= c.capsule(60, 21, 60 + math.cos(a) * 11, 21 + math.sin(a) * 11, 3.0, 1.6)
    c.draw(head, "amber", "metal", name="mace_head")
    c.draw(c.ellipse(60, 21, 3.4, 3.4), "bone", "glow", name="sun_core")
    c.fixed(c.ellipse(59.4, 20.4, 1.2, 1.2), "glow_amber")
    c.outline("ink")
    c.despeckle()
    return c


WEAPONS = {
    "rift_pistol": {"draw": rift_pistol, "muzzle": (68, 20), "version": 1},
    "cinder_wand": {"draw": cinder_wand, "muzzle": (64, 18), "version": 1},
    "wisp_lantern": {"draw": wisp_lantern, "muzzle": (62, 26), "version": 1},
    "sunforge_mace": {"draw": sunforge_mace, "muzzle": (68, 21), "version": 1},
}
