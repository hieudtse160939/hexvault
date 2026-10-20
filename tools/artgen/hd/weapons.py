"""HD weapon sprites (density 4). Frame 96 x 48, grip pivot (24, 28) - the
16 px weapons' (6, 7) pivot times 4, so held positions are unchanged.
Each weapon records its muzzle point so shots leave the barrel tip."""
from __future__ import annotations

import math

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


def _grip(c: HDCanvas, ramp: str = "leather", x0: float = 20, y0: float = 40, x1: float = 26, y1: float = 28) -> None:
    c.draw(c.capsule(x0, y0, x1, y1, 3.0, 3.0), ramp, "round", name="grip")
    for k in range(3):
        yy = y0 - 3 - k * 3.5
        c.line(x0 - 2 + k * 1.5, yy, x0 + 3 + k * 1.5, yy - 1, ramp, 1)


def scatter_cannon() -> HDCanvas:
    c = HDCanvas(*FRAME)
    c.draw(c.poly([(6, 24), (22, 22), (26, 31), (8, 36)]), "hair_brown", "plate", name="stock")
    _grip(c, "hair_brown", 22, 39, 27, 29)
    c.draw(c.poly([(20, 17), (46, 16), (48, 30), (22, 31)]), "amber", "plate", bias=-1, name="receiver")
    for y in (18.5, 25.5):
        c.draw(c.capsule(44, y, 68, y, 3.3, 3.3), "steel", "metal", name="barrel")
    c.draw(c.ellipse(70, 22, 4, 9), "amber", "metal", name="muzzle_flare")
    c.fixed(c.ellipse(71.5, 18.5, 1.2, 1.6) | c.ellipse(71.5, 25.5, 1.2, 1.6), "void")
    c.draw(c.rect(30, 30, 36, 34), "steel", "plate", bias=-1, name="trigger_guard")
    for x in (26, 34, 42):
        c.px(x, 19, "amber", 5)
    c.outline("ink")
    c.despeckle()
    return c


def ember_blade() -> HDCanvas:
    c = HDCanvas(*FRAME)
    _grip(c, "leather", 16, 32, 25, 28)
    c.draw(c.ellipse(16, 32.5, 2.6, 2.6), "amber", "metal", name="pommel")
    c.draw(c.poly([(26, 20), (31, 21), (31, 36), (26, 37)]), "amber", "metal", name="guard")
    blade = c.poly([(31, 25), (78, 22), (88, 26), (78, 31), (31, 32)])
    c.draw(blade, "steel", "metal", bias=1, name="blade")
    edge = c.poly([(34, 30), (78, 29), (86, 26.5), (78, 31.5), (34, 32.5)])
    c.draw(edge, "flame", "glow", name="ember_edge", selout=False)
    c.line(33, 26.5, 76, 24.5, "steel", 5)
    for x, y in ((48, 33), (62, 32), (74, 33)):
        c.px(x, y + 1, "flame", 4)
    c.outline("ink")
    c.despeckle()
    return c


def thornbow(draw: float = 1.0, arrow: bool = True) -> HDCanvas:
    """draw: 0 = string at rest, 1 = fully drawn (the in-hand pose); arrow=False after release."""
    c = HDCanvas(*FRAME)
    bend = 10 + 3 * draw                     # limbs flex as the string is pulled
    pts = [(38 + bend * math.sin(t / 10 * math.pi) - 2 * draw, 6 + 2 * draw + t * (3.6 - 0.4 * draw)) for t in range(11)]
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        c.draw(c.capsule(ax, ay, bx, by, 2.6, 2.6), "hair_brown", "round", name="limb")
    for t in (2, 4, 6, 8):
        x, y = pts[t]
        c.draw(c.poly([(x + 1, y), (x + 5, y - 3), (x + 2, y + 2)]), "moss", "round", name="thorn")
    nock = pts[0][0] - 16 * draw             # string pulled back to the nock
    c.line(pts[0][0], pts[0][1], nock, 28, "bone", 4)
    c.line(nock, 28, pts[-1][0], pts[-1][1], "bone", 4)
    if arrow:
        tip = nock + 51
        c.draw(c.capsule(nock, 28, tip - 7, 28, 1.1, 1.1), "hair_brown", "round", bias=1, name="arrow")
        c.draw(c.poly([(tip - 7, 25), (tip, 28), (tip - 7, 31)]), "steel", "metal", name="arrowhead")
        c.draw(c.poly([(nock, 28), (nock - 5, 24), (nock - 3, 28), (nock - 5, 32)]), "moss", "cloth", name="fletching")
    _grip(c, "leather", 44, 33, 47, 24)
    c.outline("ink")
    c.despeckle()
    return c


def thornbow_anims() -> dict:
    """idle = drawn and aimed (unchanged look); draw = nock -> full draw; release = string snaps, arrow gone."""
    return {"idle": [thornbow().image()],
            "draw": [thornbow(0.0).image(), thornbow(0.45).image(), thornbow(1.0).image()],
            "release": [thornbow(0.0, False).image(), thornbow(0.15, False).image()]}


def pulse_rifle() -> HDCanvas:
    c = HDCanvas(*FRAME)
    c.draw(c.poly([(4, 22), (20, 21), (21, 30), (6, 33)]), "slate", "plate", name="stock")
    _grip(c, "night", 22, 39, 26, 29)
    c.draw(c.poly([(18, 17), (62, 17), (64, 28), (20, 29)]), "slate", "plate", name="body")
    c.draw(c.rect(34, 28, 40, 40), "steel", "plate", bias=-1, name="magazine")
    c.draw(c.capsule(62, 21, 84, 21, 2.6, 2.4), "steel", "metal", name="barrel")
    c.draw(c.rect(30, 11, 46, 15), "night", "plate", name="scope")
    c.draw(c.ellipse(46.5, 13, 1.6, 2.2), "teal", "glow", selout=False, name="scope_lens")
    for x in range(24, 58, 6):
        c.draw(c.rect(x, 20, x + 3, 24), "teal", "glow", selout=False, name="coil")
    c.outline("ink")
    c.despeckle()
    return c


def frost_needler() -> HDCanvas:
    c = HDCanvas(*FRAME)
    _grip(c, "slate", 22, 39, 26, 29)
    c.draw(c.poly([(18, 19), (50, 18), (52, 29), (20, 30)]), "steel", "plate", name="body")
    tank = c.ellipse(34, 14, 9, 5.5)
    c.draw(tank, "frost", "glow", name="cryo_tank")
    c.fixed(c.ellipse(31, 12.5, 2, 1.2), "glow_frost")
    c.draw(c.capsule(50, 23, 74, 23, 1.6, 1.0), "frost", "metal", bias=1, name="needle_barrel")
    for x in (56, 62, 68):
        c.draw(c.poly([(x, 21), (x + 3, 18), (x + 2, 22)]), "frost", "metal", bias=1, name="ice_spur")
    c.outline("ink")
    c.despeckle()
    return c


def hex_staff() -> HDCanvas:
    c = HDCanvas(*FRAME)
    c.draw(c.capsule(10, 32, 70, 22, 2.0, 2.0), "night", "round", name="staff")
    _grip(c, "violet", 20, 31, 28, 29)
    c.draw(c.ellipse(78, 20, 7.5, 7.5) & ~c.ellipse(78, 20, 5.8, 5.8), "amber", "metal", name="halo_ring")
    gem = c.poly([(78, 11), (84, 20), (78, 29), (72, 20)])
    c.draw(gem, "violet", "glow", name="hex_gem")
    c.fixed(c.ellipse(76.5, 17.5, 1.4, 2), "glow_violet")
    for x, y in ((66, 12), (89, 26), (84, 10)):
        c.px(x, y, "violet", 5)
    c.outline("ink")
    c.despeckle()
    return c


def longshot() -> HDCanvas:
    c = HDCanvas(*FRAME)
    c.draw(c.poly([(2, 23), (20, 22), (22, 31), (4, 34)]), "hair_brown", "plate", name="stock")
    _grip(c, "hair_brown", 22, 38, 26, 29)
    c.draw(c.poly([(18, 19), (46, 19), (46, 29), (20, 29)]), "slate", "plate", name="receiver")
    c.draw(c.capsule(44, 23, 92, 23, 2.0, 1.8), "steel", "metal", name="long_barrel")
    c.draw(c.rect(88, 20, 92, 26), "slate", "plate", name="brake")
    c.draw(c.capsule(24, 13, 44, 13, 3.0, 3.0), "night", "plate", name="scope")
    c.draw(c.ellipse(45, 13, 1.5, 2.6), "azure", "glow", selout=False, name="lens")
    c.line(60, 26, 54, 38, "steel", 1)
    c.line(62, 26, 68, 38, "steel", 1)
    c.outline("ink")
    c.despeckle()
    return c


def boom_tube() -> HDCanvas:
    c = HDCanvas(*FRAME)
    tube = c.capsule(10, 20, 74, 20, 8.0, 8.0)
    c.draw(tube, "moss", "metal", bias=-1, name="tube")
    for x in (22, 30):
        c.draw(c.rect(x, 12, x + 3, 28) & tube, "amber", "flat", name="hazard")
    c.draw(c.ellipse(76, 20, 3.0, 8.5), "slate", "plate", name="rim")
    c.draw(c.poly([(76, 15), (86, 20), (76, 25)]), "crimson", "round", name="warhead")
    _grip(c, "night", 26, 40, 30, 28)
    c.draw(c.rect(40, 9, 50, 12), "steel", "plate", name="sight")
    c.outline("ink")
    c.despeckle()
    return c


def storm_coil() -> HDCanvas:
    c = HDCanvas(*FRAME)
    _grip(c, "night", 22, 39, 26, 29)
    c.draw(c.poly([(18, 18), (44, 17), (46, 30), (20, 31)]), "steel", "plate", name="body")
    for x in range(44, 66, 5):
        c.draw(c.ellipse(x, 24, 2.6, 6.5), "amber", "metal", name="copper_coil")
    c.draw(c.capsule(44, 24, 66, 24, 1.6, 1.6), "steel", "metal", bias=-1, name="core")
    for dy in (-6, 6):
        c.draw(c.capsule(66, 24, 76, 24 + dy, 1.4, 1.0), "steel", "metal", name="prong")
    for (x, y) in ((79, 17), (81, 24), (79, 31)):
        c.fixed(c.ellipse(x, y, 1.2, 1.2), "glow_violet")
    c.line(76, 18, 80, 24, "violet", 4)
    c.line(80, 24, 76, 30, "violet", 4)
    c.outline("ink")
    c.despeckle()
    return c


def prism_lance() -> HDCanvas:
    c = HDCanvas(*FRAME)
    _grip(c, "bone", 18, 33, 27, 28)
    c.draw(c.poly([(26, 21), (34, 22), (34, 34), (26, 35)]), "amber", "metal", name="guard")
    shaft = c.poly([(34, 25), (70, 24), (70, 31), (34, 31)])
    c.draw(shaft, "bone", "metal", bias=1, name="shaft")
    prism = c.poly([(70, 20), (90, 27.5), (70, 35)])
    c.draw(prism, "frost", "glow", name="prism")
    c.fixed(c.poly([(72, 25), (84, 27.5), (72, 30)]), "white")
    for i, ramp in enumerate(("crimson", "amber", "moss", "azure", "violet")):
        c.line(36 + i * 6, 26, 38 + i * 6, 29, ramp, 4)
    c.outline("ink")
    c.despeckle()
    return c



def shadow_fang() -> HDCanvas:
    """Short black dagger with a violet edge."""
    c = HDCanvas(*FRAME)
    _grip(c, "hair_ink", 18, 32, 25, 28)
    c.draw(c.ellipse(17.5, 32.5, 2.4, 2.4), "violet", "metal", name="pommel")
    c.draw(c.poly([(25, 22), (29, 23), (29, 35), (25, 36)]), "night", "metal", bias=1, name="guard")
    blade = c.poly([(29, 25), (50, 24), (60, 28), (50, 31), (29, 31)])
    c.draw(blade, "night", "metal", bias=2, name="blade")
    c.draw(c.poly([(31, 29.5), (50, 29.5), (58, 28), (50, 31), (31, 31)]), "violet", "glow", name="edge", selout=False)
    c.line(31, 26, 49, 25.5, "hair_silver", 4)
    c.outline("ink")
    c.despeckle()
    return c


def wardpike() -> HDCanvas:
    """Long ash-wood spear with a leaf blade and a guild pennant."""
    c = HDCanvas(*FRAME)
    c.draw(c.capsule(6, 29, 72, 27, 1.8, 1.8), "hair_brown", "round", name="shaft")
    for x in (20, 26):
        c.draw(c.rect(x, 26, x + 2, 31), "leather", "plate", name="wrap")
    c.draw(c.poly([(70, 27.5), (78, 22), (92, 27), (78, 32)]), "steel", "metal", bias=1, name="head")
    c.line(74, 27, 90, 27, "steel", 5)
    c.draw(c.rect(68, 23, 71, 32), "amber", "metal", name="collar")
    c.draw(c.poly([(56, 28), (66, 28), (64, 36), (58, 34)]), "azure", "cloth", name="pennant")
    c.outline("ink")
    c.despeckle()
    return c


WEAPONS = {
    "rift_pistol": {"draw": rift_pistol, "muzzle": (68, 20), "version": 1},
    "cinder_wand": {"draw": cinder_wand, "muzzle": (64, 18), "version": 1},
    "wisp_lantern": {"draw": wisp_lantern, "muzzle": (62, 26), "version": 1},
    "sunforge_mace": {"draw": sunforge_mace, "muzzle": (68, 21), "version": 1},
    "scatter_cannon": {"draw": scatter_cannon, "muzzle": (72, 22), "version": 1},
    "ember_blade": {"draw": ember_blade, "muzzle": (86, 26), "version": 1},
    "thornbow": {"draw": thornbow, "anims": thornbow_anims, "muzzle": (76, 28), "version": 2},
    "pulse_rifle": {"draw": pulse_rifle, "muzzle": (86, 21), "version": 1},
    "frost_needler": {"draw": frost_needler, "muzzle": (75, 23), "version": 1},
    "hex_staff": {"draw": hex_staff, "muzzle": (82, 20), "version": 1},
    "longshot": {"draw": longshot, "muzzle": (93, 23), "version": 1},
    "boom_tube": {"draw": boom_tube, "muzzle": (86, 20), "version": 1},
    "storm_coil": {"draw": storm_coil, "muzzle": (81, 24), "version": 1},
    "prism_lance": {"draw": prism_lance, "muzzle": (90, 27), "version": 1},
    "shadow_fang": {"draw": shadow_fang, "muzzle": (60, 28), "version": 1},
    "wardpike": {"draw": wardpike, "muzzle": (92, 27), "version": 1},
}
