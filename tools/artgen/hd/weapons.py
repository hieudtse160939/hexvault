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


WEAPONS = {
    "rift_pistol": {"draw": rift_pistol, "muzzle": (68, 20), "version": 1},
}
