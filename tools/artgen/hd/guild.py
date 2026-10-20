"""Adventurers' Guild art at density 4: interior tiles, furniture props,
the training dummy and equipment icons.

Tiles (64 x 64, one 16-unit cell) extend the dungeon atlas at indices 16-23
(see scripts/world/tiles.gd). Warm wood and plaster read as a lived-in guild
hall against the cold stone dungeon. Same light (top-left), same palette,
same ink outline rules as every other HD asset.
"""
from __future__ import annotations

import math
import random

from canvas import HDCanvas

T = 64


# --- tiles ---------------------------------------------------------------------------
def wood_floor(seed: int, ramp: str = "leather", bias: int = -1) -> HDCanvas:
    """Four courses of planks with staggered seams and soft grain."""
    rng = random.Random(seed)
    c = HDCanvas(T, T)
    c.fill(c.rect(0, 0, T - 1, T - 1), ramp, 0, name="gaps")
    for row in range(4):
        y0, y1 = row * 16, row * 16 + 14
        seam = (rng.randint(14, 46) + row * 23) % 64
        pieces = [(0, seam - 1), (seam + 1, 63)] if 4 < seam < 60 else [(0, 63)]
        for (x0, x1) in pieces:
            if x1 - x0 < 3:
                continue
            c.draw(c.rect(x0, y0, x1, y1), ramp, "plate", bias=bias + (1 if rng.random() < 0.25 else 0),
                   selout=False, cast=False)
            for _ in range(2):  # grain: short darker streaks, 2 px tall clusters
                gx = rng.randint(x0 + 2, max(x0 + 2, x1 - 10))
                gy = rng.randint(y0 + 3, y1 - 4)
                c.relight(c.rect(gx, gy, min(gx + rng.randint(5, 9), x1 - 1), gy + 1), -1)
        # nail heads at plank ends
        for nx in (2, seam + 3):
            if nx < 62:
                c.fill(c.rect(nx, y0 + 6, nx + 1, y0 + 7), "steel", 1)
    return c


def rug(seed: int = 3) -> HDCanvas:
    """Guild runner: crimson field, amber diamond, border on every side so
    repeated tiles read as a woven carpet."""
    c = HDCanvas(T, T)
    c.draw(c.rect(0, 0, 63, 63), "crimson", "plate", bias=-1, selout=False, cast=False)
    border = c.rect(0, 0, 63, 63) & ~c.rect(4, 4, 59, 59)
    c.fill(border, "amber", 2)
    c.fill(c.rect(6, 6, 57, 57) & ~c.rect(7, 7, 56, 56), "amber", 1)
    dia = c.poly([(31.5, 14), (49, 31.5), (31.5, 49), (14, 31.5)])
    c.fill(dia & ~c.poly([(31.5, 19), (44, 31.5), (31.5, 44), (19, 31.5)]), "amber", 3)
    c.fill(c.poly([(31.5, 25), (38, 31.5), (31.5, 38), (25, 31.5)]), "azure", 3)
    return c


def stage_floor() -> HDCanvas:
    """Darker stained boards (entrance mat / training ring)."""
    return wood_floor(41, "hair_brown", bias=-1)


def wall_wood(seed: int, deco: str | None = None) -> HDCanvas:
    """South-facing guild wall: beam, plaster panel between timber posts, wainscot."""
    rng = random.Random(seed)
    c = HDCanvas(T, T)
    c.draw(c.rect(0, 0, 63, 63), "cloth", "plate", bias=-1, selout=False, cast=False)
    c.draw(c.rect(0, 0, 63, 8), "hair_brown", "plate", bias=0, selout=False, cast=False, name="beam")
    c.fill(c.rect(0, 9, 63, 10), "hair_brown", 0)
    for x0 in (0, 58):
        c.draw(c.rect(x0, 9, x0 + 5, 63), "hair_brown", "plate", bias=-1, selout=False, cast=False, name="post")
    # wainscot planks
    c.fill(c.rect(0, 40, 63, 41), "hair_brown", 0)
    for x0 in range(0, 64, 11):
        c.draw(c.rect(x0, 42, min(x0 + 9, 63), 61), "leather", "plate", bias=-1 + (rng.random() < 0.2), selout=False, cast=False)
    c.relight(c.rect(0, 59, 63, 63), -1)
    if deco == "banner":
        c.draw(c.rect(16, 11, 47, 14), "hair_brown", "round", name="rod")
        cloth = c.poly([(18, 14), (45, 14), (45, 50), (31.5, 57), (18, 50)])
        c.draw(cloth, "azure", "cloth", name="banner")
        c.fill(c.poly([(18, 14), (45, 14), (45, 17), (18, 17)]), "amber", 3)
        # guild emblem: shield with crossed sword
        shield = c.poly([(24, 23), (39, 23), (39, 35), (31.5, 43), (24, 35)])
        c.draw(shield, "amber", "metal", name="shield")
        c.draw(c.capsule(31.5, 19, 31.5, 46, 1.4, 1.2), "steel", "metal", name="blade")
        c.draw(c.rect(27, 26, 36, 27), "leather", "plate", name="guard")
    elif deco == "lantern":
        c.draw(c.rect(29, 12, 34, 16), "steel", "plate", name="hook")
        c.draw(c.capsule(31.5, 18, 31.5, 33, 6.5, 6.5), "hair_brown", "metal", name="cage")
        c.fixed(c.ellipse(31.5, 26, 4.2, 5.5), "glow_amber")
        c.fill(c.ellipse(31.5, 27, 2, 3), "flame", 5)
        for k, (x, y) in enumerate(((22, 22), (41, 24), (24, 33), (40, 34))):
            c.px(x, y, "amber", 5)
    elif deco == "map":
        paper = c.rect(12, 14, 51, 37)
        c.draw(paper, "bone", "plate", name="map")
        for (ax, ay, bx, by) in ((16, 30, 24, 22), (24, 22, 33, 27), (33, 27, 45, 18)):
            c.line(ax, ay, bx, by, "leather", 1)
        c.fill(c.ellipse(45, 18, 1.6, 1.6), "crimson", 2)
        c.fill(c.rect(16, 33, 22, 34), "moss", 2)
        c.fill(c.rect(38, 31, 47, 32), "azure", 2)
        for x, y in ((12, 14), (51, 14)):
            c.fill(c.rect(x, y, x + 1, y + 1), "steel", 3)
    return c


def tiles() -> list[HDCanvas]:
    """Atlas indices 16-23."""
    return [
        wood_floor(1), wood_floor(2), rug(), stage_floor(),
        wall_wood(1), wall_wood(2, "banner"), wall_wood(3, "lantern"), wall_wood(4, "map"),
    ]


# --- props ------------------------------------------------------------------------------
def counter() -> HDCanvas:
    """Reception counter, 40 x 14 world units, ledger + bell on top."""
    w, h = 160, 64
    c = HDCanvas(w, h)
    c.draw(c.rect(2, 26, w - 3, h - 4), "hair_brown", "plate", bias=-1, name="front")
    for x0 in range(8, w - 12, 30):
        c.draw(c.rect(x0, 32, x0 + 22, h - 10), "leather", "plate", bias=-1, name="panel")
    c.draw(c.rect(0, 12, w - 1, 27), "leather", "plate", bias=1, name="top")
    c.fill(c.rect(0, 27, w - 1, 28), "hair_brown", 0)
    # ledger book
    c.draw(c.poly([(30, 9), (60, 7), (62, 19), (32, 21)]), "bone", "plate", name="ledger")
    c.line(46, 8, 47, 20, "leather", 1)
    c.draw(c.rect(28, 18, 60, 21), "crimson", "plate", name="cover")
    # brass bell
    c.draw(c.ellipse(110, 12, 6, 5.5), "amber", "metal", name="bell")
    c.draw(c.rect(103, 16, 117, 18), "hair_brown", "plate", name="bell_base")
    c.fill(c.rect(109, 5, 110, 6), "amber", 4)
    # inkwell + quill
    c.draw(c.ellipse(80, 15, 3.5, 3.0), "night", "round", name="ink")
    c.draw(c.capsule(80, 13, 88, 1, 1.0, 0.6), "bone", "soft", name="quill")
    c.outline("ink")
    return c


def table() -> HDCanvas:
    """Tavern table with mugs and a candle, 24 x 16 world units."""
    w, h = 96, 64
    c = HDCanvas(w, h)
    for x in (12, 80):
        c.draw(c.rect(x, 32, x + 4, 58), "hair_brown", "plate", bias=-1, name="leg")
    c.draw(c.rect(2, 16, w - 3, 33), "leather", "plate", bias=1, name="top")
    c.draw(c.rect(2, 34, w - 3, 38), "hair_brown", "plate", bias=-1, name="apron")
    for k, x in enumerate((24, 66)):
        c.draw(c.capsule(x, 12, x, 22, 4.5, 4.5), "bone" if k == 0 else "steel", "round", name="mug")
        c.fill(c.ellipse(x, 12, 3, 1.2), "amber", 4)
        c.draw(c.capsule(x + 5, 15, x + 6, 20, 1.3, 1.3), "bone" if k == 0 else "steel", "round", name="handle")
    c.draw(c.rect(45, 11, 49, 24), "bone", "round", name="candle")
    c.fixed(c.ellipse(47, 7, 1.8, 3), "glow_amber")
    c.outline("ink")
    return c


def shelf() -> HDCanvas:
    """Bookshelf, 16 x 24 world units."""
    w, h = 64, 96
    c = HDCanvas(w, h)
    rng = random.Random(7)
    c.draw(c.rect(2, 2, w - 3, h - 3), "hair_brown", "plate", bias=-1, name="frame")
    c.draw(c.rect(6, 6, w - 7, h - 8), "hair_brown", "plate", bias=-3, name="back", selout=False)
    cols = ["crimson", "azure", "moss", "violet", "amber", "teal", "leather"]
    for sy in (8, 34, 60):
        x = 7
        while x < w - 10:
            bw = rng.randint(3, 6)
            bh = rng.randint(14, 21)
            top = sy + 22 - bh
            if rng.random() < 0.12:  # leaning book
                c.draw(c.poly([(x, sy + 22), (x + bw, sy + 22), (x + bw + 4, top + 2), (x + 4, top)]), rng.choice(cols), "plate")
                x += bw + 5
                continue
            c.draw(c.rect(x, top, x + bw - 1, sy + 22), rng.choice(cols), "plate", bias=rng.choice((-1, 0, 0, 1)))
            c.fill(c.rect(x, top + 3, x + bw - 1, top + 3), "amber", 3)
            x += bw
        c.draw(c.rect(4, sy + 23, w - 5, sy + 26), "leather", "plate", name="board")
    c.outline("ink")
    return c


def weapon_rack() -> HDCanvas:
    """Rack with a sword, a spear and an axe, 16 x 20 world units."""
    w, h = 64, 80
    c = HDCanvas(w, h)
    for x in (6, 54):
        c.draw(c.rect(x, 10, x + 4, h - 4), "hair_brown", "plate", name="post")
    c.draw(c.rect(4, 18, w - 5, 22), "leather", "plate", name="bar")
    c.draw(c.rect(4, 58, w - 5, 62), "leather", "plate", name="bar2")
    c.draw(c.capsule(20, 6, 20, 56, 2.2, 1.8), "steel", "metal", name="sword")
    c.draw(c.rect(14, 46, 26, 48), "amber", "metal", name="guard")
    c.draw(c.capsule(20, 49, 20, 58, 1.6, 1.6), "leather", "round", name="grip")
    c.draw(c.capsule(32, 4, 32, 70, 1.4, 1.4), "hair_brown", "round", name="shaft")
    c.draw(c.poly([(32, 0), (36, 9), (32, 13), (28, 9)]), "steel", "metal", name="spearhead")
    c.draw(c.capsule(44, 14, 44, 70, 1.5, 1.5), "hair_brown", "round", name="haft")
    c.draw(c.poly([(45, 14), (55, 10), (57, 22), (45, 26)]), "steel", "metal", name="axe")
    c.outline("ink")
    return c


def mission_board() -> HDCanvas:
    """Notice board on two legs with pinned mission posters, 20 x 22 world units."""
    w, h = 80, 88
    c = HDCanvas(w, h)
    rng = random.Random(11)
    for x in (10, 66):
        c.draw(c.rect(x, 40, x + 4, h - 3), "hair_brown", "plate", bias=-1, name="leg")
    c.draw(c.rect(2, 4, w - 3, 62), "hair_brown", "plate", name="frame")
    c.draw(c.rect(6, 8, w - 7, 58), "leather", "plate", bias=-1, name="cork", selout=False)
    c.draw(c.poly([(0, 6), (w / 2, -1), (w - 1, 6), (w - 1, 9), (0, 9)]), "crimson", "plate", name="roof")
    for (x0, y0, x1, y1) in ((9, 12, 31, 33), (35, 11, 54, 29), (57, 14, 72, 35), (12, 37, 30, 55), (36, 33, 58, 55), (61, 40, 71, 55)):
        c.draw(c.rect(x0, y0, x1, y1), "bone", "plate", bias=rng.choice((-1, 0)), name="poster")
        for ly in range(y0 + 5, y1 - 2, 4):
            c.fill(c.rect(x0 + 3, ly, x1 - 3 - rng.randint(0, 5), ly), "leather", 1)
        c.fill(c.rect((x0 + x1) // 2 - 1, y0 - 1, (x0 + x1) // 2, y0), "crimson", 3)
    c.fill(c.ellipse(46, 50, 3, 3), "crimson", 2)  # wax seal on the urgent quest
    c.outline("ink")
    return c


def plant() -> HDCanvas:
    """Potted fern, 10 x 14 world units."""
    w, h = 40, 56
    c = HDCanvas(w, h)
    c.draw(c.poly([(10, 36), (30, 36), (27, 53), (13, 53)]), "flame", "round", bias=-2, name="pot")
    c.draw(c.rect(8, 33, 32, 37), "flame", "plate", bias=-1, name="rim")
    for k in range(7):
        a = -math.pi / 2 + (k - 3) * 0.42
        ex, ey = 20 + math.cos(a) * 17, 33 + math.sin(a) * 23
        c.draw(c.capsule(20, 33, ex, ey, 3.0, 1.4), "moss", "cloth", bias=(k % 2) - 1, name="frond")
    c.outline("ink")
    return c


def dummy(lean: float = 0.0, squash: int = 0) -> HDCanvas:
    """Straw training dummy on a post; lean/squash animate the hit wobble."""
    w, h = 56, 88
    c = HDCanvas(w, h)
    cx = 28
    top = 10 + squash
    off = lambda y: lean * (78 - y) / 60.0  # noqa: E731 - lean grows toward the head
    c.draw(c.rect(cx - 3, 50, cx + 3, 80), "hair_brown", "plate", name="post")
    c.draw(c.ellipse(cx, 82, 14, 4), "leather", "plate", bias=-1, name="base")
    c.draw(c.capsule(cx - 17 + off(36), 36, cx + 17 + off(36), 36, 3.0, 3.0), "hair_brown", "round", name="arms")
    c.draw(c.capsule(cx + off(52), 30 + squash // 2, cx + off(52), 56, 11, 9), "amber", "cloth", bias=-1, name="body")
    for y in (36, 46):
        c.fill(c.rect(int(cx - 10 + off(y)), y, int(cx + 10 + off(y)), y + 1), "leather", 1)
    c.draw(c.ellipse(cx + off(top + 9), top + 9, 9, 9), "cloth", "round", name="head")
    c.fill(c.ellipse(cx + off(top + 9), top + 10, 4.5, 4.5) & ~c.ellipse(cx + off(top + 9), top + 10, 3, 3), "crimson", 2)
    c.fill(c.ellipse(cx + off(top + 9), top + 10, 1.4, 1.4), "crimson", 3)
    for k in range(3):  # straw tufts
        c.line(cx - 6 + k * 6 + off(top), top + 1, cx - 8 + k * 7 + off(top), top - 4, "amber", 4)
    c.outline("ink")
    return c


def dummy_anims() -> dict:
    return {"idle": [dummy().image()],
            "hit": [dummy(6.0, 2).image(), dummy(-4.0, 1).image(), dummy(2.0, 0).image()]}


PROPS = {
    # key: (builder, pivot (feet / base centre in px))
    "counter": (counter, (80, 58)),
    "table": (table, (48, 56)),
    "shelf": (shelf, (32, 92)),
    "rack": (weapon_rack, (32, 76)),
    "board": (mission_board, (40, 85)),
    "plant": (plant, (20, 52)),
}
DUMMY_PIVOT = (28, 84)


# --- equipment icons --------------------------------------------------------------------
def _icon_bg(c: HDCanvas) -> None:
    c.draw(c.ellipse(31.5, 31.5, 28, 28), "night", "round", bias=-1, selout=False, cast=False)


def icon_helmet() -> HDCanvas:
    c = HDCanvas(64, 64)
    _icon_bg(c)
    c.draw(c.poly([(14, 40), (16, 22), (31.5, 12), (47, 22), (49, 40), (42, 50), (21, 50)]), "steel", "metal", name="helm")
    c.fill(c.rect(22, 30, 41, 33), "night", 0)
    c.draw(c.capsule(31.5, 12, 31.5, 44, 2.0, 2.0), "amber", "metal", name="crest")
    c.outline("ink")
    return c


def icon_armor() -> HDCanvas:
    c = HDCanvas(64, 64)
    _icon_bg(c)
    c.draw(c.poly([(12, 20), (24, 13), (39, 13), (51, 20), (46, 30), (44, 52), (19, 52), (17, 30)]), "steel", "metal", name="plate")
    c.draw(c.poly([(24, 13), (31.5, 22), (39, 13)]), "night", "plate", bias=1, name="neck")
    c.fill(c.rect(19, 38, 44, 40), "leather", 2)
    c.fill(c.rect(29, 37, 34, 41), "amber", 4)
    c.outline("ink")
    return c


def icon_gloves() -> HDCanvas:
    c = HDCanvas(64, 64)
    _icon_bg(c)
    c.draw(c.poly([(18, 52), (18, 30), (22, 18), (28, 18), (29, 28), (31, 16), (37, 16), (37, 28), (40, 19), (45, 21), (44, 34), (49, 30), (52, 34), (44, 46), (42, 52)]),
           "leather", "round", name="glove")
    c.draw(c.rect(17, 46, 43, 53), "steel", "metal", name="cuff")
    c.outline("ink")
    return c


def icon_boots() -> HDCanvas:
    c = HDCanvas(64, 64)
    _icon_bg(c)
    c.draw(c.poly([(20, 12), (34, 12), (34, 38), (50, 44), (50, 52), (16, 52), (18, 38)]), "leather", "round", name="boot")
    c.draw(c.rect(19, 12, 35, 17), "hair_brown", "plate", name="top")
    c.draw(c.rect(15, 50, 51, 54), "night", "plate", bias=1, name="sole")
    c.fill(c.rect(22, 26, 32, 27), "amber", 3)
    c.outline("ink")
    return c


def icon_accessory() -> HDCanvas:
    c = HDCanvas(64, 64)
    _icon_bg(c)
    band = c.ellipse(31.5, 38, 16, 12) & ~c.ellipse(31.5, 38, 11, 7.5)
    c.draw(band, "amber", "metal", name="band")
    c.draw(c.poly([(31.5, 12), (40, 21), (31.5, 30), (23, 21)]), "crimson", "metal", name="gem")
    c.fixed(c.rect(28, 17, 29, 19), "white")
    c.outline("ink")
    return c


def icon_book() -> HDCanvas:
    c = HDCanvas(64, 64)
    _icon_bg(c)
    c.draw(c.poly([(14, 16), (44, 12), (50, 48), (20, 52)]), "violet", "plate", name="cover")
    c.draw(c.poly([(20, 52), (50, 48), (50, 51), (21, 55)]), "bone", "plate", name="pages")
    c.draw(c.poly([(14, 16), (20, 52), (17, 53), (11, 18)]), "violet", "plate", bias=-2, name="spine")
    c.fill(c.ellipse(32, 32, 6, 6) & ~c.ellipse(32, 32, 4, 4), "amber", 4)
    c.fixed(c.ellipse(32, 32, 2, 2), "glow_teal")
    c.outline("ink")
    return c


ICONS = {
    "item_helmet": icon_helmet, "item_armor": icon_armor, "item_gloves": icon_gloves,
    "item_boots": icon_boots, "item_accessory": icon_accessory, "item_book": icon_book,
}
