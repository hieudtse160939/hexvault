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
    """Long floorboards. Four 16 px boards per tile, flat-shaded per board (lit top edge,
    shaded bottom edge, no bevel at the tile border) so boards continue across tiles. Each
    tile variant has butt joints in two rows only, so alternating tiles read as boards
    ~128 px long. Board tone varies by row, never by tile, to avoid a checker pattern."""
    rng = random.Random(seed)
    c = HDCanvas(T, T)
    base = 2 + bias + 1          # mid shade
    tones = [0, 1, 0, -1]        # per-row tone (same in every tile)
    joints = {0: 20, 2: 44} if seed % 2 else {1: 36, 3: 12}
    c.fill(c.rect(0, 0, T - 1, T - 1), ramp, max(base - 2, 0), name="gaps")
    for row in range(4):
        y0, y1 = row * 16, row * 16 + 14
        t = max(min(base + tones[row], 5), 0)
        c.fill(c.rect(0, y0, 63, y1), ramp, t)
        c.fill(c.rect(0, y0, 63, y0), ramp, min(t + 1, 5))        # lit top edge
        c.fill(c.rect(0, y1, 63, y1), ramp, max(t - 1, 0))        # shaded bottom edge
        s = joints.get(row, 0)
        if s:
            c.fill(c.rect(s - 1, y0, s - 1, y1), ramp, max(base - 2, 0))
            c.fill(c.rect(s, y0, s, y1), ramp, min(t + 1, 5))
            c.fill(c.rect(s + 2, y0 + 7, s + 2, y0 + 7), "steel", 3)
            c.fill(c.rect(s - 4, y0 + 7, s - 4, y0 + 7), "steel", 3)
        for _ in range(3):        # faint grain
            gx = rng.randint(1, 40)
            gy = rng.randint(y0 + 3, y1 - 3)
            c.fill(c.rect(gx, gy, gx + rng.randint(10, 22), gy), ramp, max(t - 1, 0))
    return c


def rug(seed: int = 3) -> HDCanvas:
    """Guild runner: royal-blue field with a gold border and diamond; repeated tiles read
    as one woven carpet (reference: blue rugs with gold compass motifs)."""
    c = HDCanvas(T, T)
    c.draw(c.rect(0, 0, 63, 63), "azure", "plate", bias=-1, selout=False, cast=False)
    c.fill(c.rect(0, 0, 63, 63) & ~c.rect(3, 0, 60, 63), "amber", 3)      # side borders run along the runner
    c.fill(c.rect(5, 0, 5, 63) | c.rect(58, 0, 58, 63), "amber", 2)
    dia = c.poly([(31.5, 16), (47, 31.5), (31.5, 47), (16, 31.5)])
    c.fill(dia & ~c.poly([(31.5, 20), (43, 31.5), (31.5, 43), (20, 31.5)]), "amber", 3)
    c.fill(c.poly([(31.5, 27), (36, 31.5), (31.5, 36), (27, 31.5)]), "amber", 4)
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
    elif deco == "window":
        frame = c.rect(16, 13, 47, 39)
        c.draw(frame, "hair_brown", "plate", name="frame")
        for (x0, y0, x1, y1) in ((19, 16, 30, 26), (33, 16, 44, 26), (19, 28, 30, 36), (33, 28, 44, 36)):
            c.fill(c.rect(x0, y0, x1, y1), "amber", 4)
            c.fill(c.rect(x0, y0, x0 + 3, y0 + 1), "amber", 5)
        c.draw(c.rect(14, 39, 49, 42), "hair_brown", "plate", name="sill")
        c.draw(c.ellipse(24, 38, 5, 3), "moss", "cloth", name="flowers")
        c.draw(c.ellipse(40, 38, 5, 3), "moss", "cloth", name="flowers")
        c.px(23, 37, "rose", 4)
        c.px(41, 37, "amber", 5)
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


def wall_top_wood() -> HDCanvas:
    """Top of a guild wall seen from above: dark timber cap with plank joints."""
    c = HDCanvas(T, T)
    c.fill(c.rect(0, 0, T - 1, T - 1), "hair_brown", 0)
    for y0 in (0, 32):
        c.fill(c.rect(0, y0 + 1, 63, y0 + 30), "hair_brown", 1)
        c.fill(c.rect(0, y0 + 1, 63, y0 + 1), "hair_brown", 2)
        c.fill(c.rect(0, y0 + 30, 63, y0 + 30), "hair_brown", 0)
    for x, y in ((21, 1), (47, 33)):
        c.fill(c.rect(x, y, x, y + 29), "hair_brown", 0)
    return c


def tiles() -> list[HDCanvas]:
    """Atlas indices 16-24."""
    return [
        wood_floor(1), wood_floor(2), rug(), stage_floor(),
        wall_wood(1), wall_wood(2, "banner"), wall_wood(3, "lantern"), wall_wood(4, "map"),
        wall_top_wood(), wall_wood(5, "window"), grass(), hedge(),
    ]


def hedge() -> HDCanvas:
    """Dense hedge that bounds the courtyard (atlas 27, solid)."""
    rng = random.Random(21)
    c = HDCanvas(T, T)
    c.fill(c.rect(0, 0, T - 1, T - 1), "moss", 0)
    for _ in range(12):
        x, y = rng.uniform(6, 58), rng.uniform(6, 58)
        c.draw(c.ellipse(x, y, rng.uniform(9, 14), rng.uniform(8, 12)), "moss", "cloth", bias=rng.choice((-2, -1)), selout=False, cast=False)
    return c


def grass() -> HDCanvas:
    """Courtyard grass outside the entrance (atlas 26)."""
    rng = random.Random(12)
    c = HDCanvas(T, T)
    c.fill(c.rect(0, 0, T - 1, T - 1), "moss", 1)
    for _ in range(40):
        x, y = rng.randint(1, 61), rng.randint(1, 61)
        c.fill(c.rect(x, y, x + 1, y), "moss", rng.choice((0, 2)))
    return c


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


def fireplace(frame: int = 0) -> HDCanvas:
    """Stone hearth with a living fire, 28 x 26 world units (stands against the north wall)."""
    w, h = 112, 104
    c = HDCanvas(w, h)
    rng = random.Random(5)
    c.draw(c.rect(4, 10, w - 5, h - 4), "stone", "plate", bias=-1, name="chimney")
    for y in range(14, h - 8, 10):  # stone courses
        off = (y // 10) % 2 * 9
        for x in range(4 - off, w - 4, 18):
            c.draw(c.rect(max(x + 1, 5), y, min(x + 16, w - 6), y + 8), "stone", "plate", bias=rng.choice((-1, 0)), selout=False, cast=False)
    c.draw(c.rect(0, 40, w - 1, 47), "hair_brown", "plate", name="mantel")
    mouth = c.poly([(22, h - 4), (22, 62), (34, 52), (78, 52), (90, 62), (90, h - 4)])
    c.fill(mouth, "night", 0, name="mouth")
    rng2 = random.Random(frame * 7 + 1)
    for k in range(5):  # flames flicker per frame
        fx = 34 + k * 11 + rng2.randint(-2, 2)
        top = 66 + rng2.randint(-6, 4) + (6 if k in (0, 4) else 0)
        c.draw(c.poly([(fx - 6, h - 10), (fx, top), (fx + 6, h - 10)]), "flame", "glow", selout=False, cast=False)
    c.draw(c.ellipse(56, h - 12, 20, 5), "flame", "glow", bias=1, selout=False, cast=False)
    c.fixed(c.ellipse(56, h - 16, 8, 4), "glow_amber")
    c.draw(c.rect(26, h - 9, 86, h - 6), "hair_brown", "round", name="logs")
    for x, y in ((20, 34), (90, 36)):  # candles on the mantel
        c.draw(c.rect(x, y, x + 3, y + 6), "bone", "round")
        c.fixed(c.ellipse(x + 1.5, y - 2, 1.2, 2), "glow_amber")
    c.draw(c.ellipse(56, 26, 10, 8), "bone", "round", name="trophy_skull")
    c.fill(c.ellipse(52, 25, 2, 2) | c.ellipse(60, 25, 2, 2), "night", 0)
    c.outline("ink")
    return c


def bench() -> HDCanvas:
    """Long wooden bench, 24 x 7 world units."""
    w, h = 96, 32
    c = HDCanvas(w, h)
    for x in (10, 82):
        c.draw(c.rect(x, 14, x + 4, 28), "hair_brown", "plate", bias=-1, name="leg")
    c.draw(c.rect(2, 8, w - 3, 16), "leather", "plate", name="seat")
    c.outline("ink")
    return c


def bar_counter() -> HDCanvas:
    """Tavern bar with taps, bottles and kegs, 44 x 16 world units."""
    w, h = 176, 72
    c = HDCanvas(w, h)
    rng = random.Random(9)
    for x in range(8, w - 20, 26):  # bottles on the back shelf
        col = rng.choice(["moss", "azure", "crimson", "amber"])
        c.draw(c.capsule(x, 4, x, 16, 2.6, 3.4), col, "metal", name="bottle")
    c.draw(c.rect(0, 16, w - 1, 20), "hair_brown", "plate", name="shelf")
    c.draw(c.rect(2, 36, w - 3, h - 4), "hair_brown", "plate", bias=-1, name="front")
    for x0 in range(8, w - 12, 28):
        c.draw(c.rect(x0, 42, x0 + 20, h - 10), "leather", "plate", bias=-1, name="panel")
    c.draw(c.rect(0, 24, w - 1, 37), "leather", "plate", bias=1, name="top")
    for x in (40, 52):  # brass taps
        c.draw(c.rect(x, 18, x + 3, 28), "amber", "metal", name="tap")
    for x in (100, 122):
        c.draw(c.capsule(x, 22, x, 32, 4.5, 4.5), "bone", "round", name="mug")
        c.fill(c.ellipse(x, 22, 3.2, 1.2), "amber", 4)
    c.outline("ink")
    return c


def banner_stand() -> HDCanvas:
    """Free-standing guild banner, 12 x 26 world units."""
    w, h = 48, 104
    c = HDCanvas(w, h)
    c.draw(c.rect(22, 6, 25, h - 6), "hair_brown", "round", name="pole")
    c.draw(c.ellipse(23.5, h - 6, 12, 4), "stone", "plate", name="foot")
    c.draw(c.rect(8, 12, 39, 15), "amber", "metal", name="bar")
    cloth = c.poly([(10, 15), (37, 15), (37, 62), (23.5, 70), (10, 62)])
    c.draw(cloth, "crimson", "cloth", name="banner")
    shield = c.poly([(16, 26), (31, 26), (31, 40), (23.5, 48), (16, 40)])
    c.draw(shield, "amber", "metal", name="emblem")
    c.draw(c.capsule(23.5, 22, 23.5, 52, 1.3, 1.1), "steel", "metal", name="sword")
    c.fixed(c.ellipse(23.5, 5, 2.5, 2.5), "glow_amber")
    c.outline("ink")
    return c


def compass_rug() -> HDCanvas:
    """Great Hall centre rug: blue field, double gold border, eight-point compass (decal)."""
    w, h = 288, 208
    c = HDCanvas(w, h)
    cx, cy = w / 2 - 0.5, h / 2 - 0.5
    c.draw(c.rect(0, 0, w - 1, h - 1), "azure", "plate", bias=-1, selout=False, cast=False)
    c.fill(c.rect(0, 0, w - 1, h - 1) & ~c.rect(6, 6, w - 7, h - 7), "amber", 3)
    c.fill(c.rect(12, 12, w - 13, h - 13) & ~c.rect(14, 14, w - 15, h - 15), "amber", 2)
    for x, y in ((22, 22), (w - 23, 22), (22, h - 23), (w - 23, h - 23)):   # corner ornaments
        c.fill(c.poly([(x, y - 6), (x + 6, y), (x, y + 6), (x - 6, y)]), "amber", 3)
    c.fill(c.ellipse(cx, cy, 70, 70) & ~c.ellipse(cx, cy, 66, 66), "amber", 2)
    big = c.poly([(cx, cy - 62), (cx + 12, cy - 12), (cx + 62, cy), (cx + 12, cy + 12), (cx, cy + 62), (cx - 12, cy + 12), (cx - 62, cy), (cx - 12, cy - 12)])
    small = c.poly([(cx + 34, cy - 34), (cx + 8, cy), (cx + 34, cy + 34), (cx, cy + 8), (cx - 34, cy + 34), (cx - 8, cy), (cx - 34, cy - 34), (cx, cy - 8)])
    c.fill(small, "amber", 2)
    c.fill(big, "amber", 4)
    c.fill(c.poly([(cx, cy - 62), (cx + 12, cy - 12), (cx, cy)]) | c.poly([(cx + 62, cy), (cx + 12, cy + 12), (cx, cy)]) |
           c.poly([(cx, cy + 62), (cx - 12, cy + 12), (cx, cy)]) | c.poly([(cx - 62, cy), (cx - 12, cy - 12), (cx, cy)]), "amber", 3)
    return c


def lounge_rug() -> HDCanvas:
    """Round red rug for the lounge corner (decal)."""
    w, h = 176, 128
    c = HDCanvas(w, h)
    cx, cy = w / 2 - 0.5, h / 2 - 0.5
    c.draw(c.ellipse(cx, cy, 86, 62), "crimson", "plate", bias=-1, selout=False, cast=False)
    c.fill(c.ellipse(cx, cy, 86, 62) & ~c.ellipse(cx, cy, 81, 57), "amber", 2)
    c.fill(c.ellipse(cx, cy, 60, 42) & ~c.ellipse(cx, cy, 57, 39), "amber", 3)
    return c


def chandelier() -> HDCanvas:
    """Iron ring chandelier with candles, seen from above at an angle (hangs over the hall)."""
    w, h = 112, 72
    c = HDCanvas(w, h)
    cx = w / 2 - 0.5
    ring = c.ellipse(cx, 44, 46, 18) & ~c.ellipse(cx, 44, 42, 15)
    c.draw(ring, "night", "metal", bias=1, name="ring")
    for k in range(4):
        a = k / 4 * math.tau + 0.4
        c.line(cx, 6, cx + math.cos(a) * 44, 44 + math.sin(a) * 17, "night", 3)
    for k in range(8):
        a = k / 8 * math.tau
        x, y = cx + math.cos(a) * 44, 44 + math.sin(a) * 16.5
        c.draw(c.rect(int(x) - 1, int(y) - 7, int(x) + 1, int(y)), "bone", "round", name="candle")
        c.fixed(c.ellipse(x, y - 10, 1.6, 2.6), "glow_amber")
    c.fill(c.ellipse(cx, 5, 3, 3), "night", 2)
    c.outline("ink")
    return c


def archery_target() -> HDCanvas:
    """Straw target on an easel, 10 x 14 world units."""
    w, h = 40, 56
    c = HDCanvas(w, h)
    c.draw(c.capsule(10, 52, 20, 18, 1.6, 1.6), "hair_brown", "round", name="leg")
    c.draw(c.capsule(30, 52, 20, 18, 1.6, 1.6), "hair_brown", "round", name="leg")
    c.draw(c.ellipse(20, 24, 15, 16), "amber", "round", name="straw")
    for r, (ramp, i) in zip((12, 9, 6, 3), (("bone", 4), ("crimson", 3), ("bone", 4), ("crimson", 3))):
        c.fill(c.ellipse(20, 24, r, r + 1), ramp, i)
    c.draw(c.capsule(24, 20, 33, 13, 0.9, 0.9), "hair_brown", "round", name="arrow")
    c.outline("ink")
    return c


def armchair() -> HDCanvas:
    """Red velvet armchair, 10 x 10 world units."""
    w, h = 40, 40
    c = HDCanvas(w, h)
    c.draw(c.rect(4, 4, 35, 20), "crimson", "cloth", name="back")
    c.draw(c.rect(6, 18, 33, 32), "crimson", "cloth", bias=1, name="seat")
    for x in (2, 31):
        c.draw(c.rect(x, 12, x + 6, 32), "crimson", "cloth", bias=-1, name="arm")
    for x in (6, 31):
        c.draw(c.rect(x, 33, x + 2, 37), "hair_brown", "plate", name="foot")
    c.outline("ink")
    return c


def round_table() -> HDCanvas:
    """Small round table with a candle and cups, 12 x 10 world units."""
    w, h = 48, 40
    c = HDCanvas(w, h)
    c.draw(c.rect(22, 20, 25, 36), "hair_brown", "plate", bias=-1, name="leg")
    c.draw(c.ellipse(23.5, 17, 21, 11), "leather", "plate", bias=1, name="top")
    c.draw(c.rect(22, 6, 25, 15), "bone", "round", name="candle")
    c.fixed(c.ellipse(23.5, 3, 1.6, 2.6), "glow_amber")
    c.draw(c.capsule(12, 14, 12, 18, 2.6, 2.6), "bone", "round", name="cup")
    c.draw(c.capsule(35, 15, 35, 19, 2.6, 2.6), "steel", "round", name="cup")
    c.outline("ink")
    return c


def rail(horizontal: bool) -> HDCanvas:
    """Low wooden balustrade segment, one cell long (divides the open hall into areas)."""
    if horizontal:
        c = HDCanvas(64, 40)
        c.draw(c.rect(0, 8, 63, 13), "hair_brown", "plate", name="handrail")
        for x in range(3, 64, 10):
            c.draw(c.rect(x, 13, x + 3, 33), "leather", "round", name="baluster")
        c.draw(c.rect(0, 32, 63, 36), "hair_brown", "plate", bias=-1, name="base")
        for x in (0, 60):
            c.draw(c.rect(x, 4, x + 3, 36), "hair_brown", "plate", bias=1, name="post")
    else:
        c = HDCanvas(24, 72)
        c.draw(c.rect(8, 2, 15, 69), "hair_brown", "plate", name="handrail")
        for y in range(6, 66, 12):
            c.draw(c.rect(6, y, 17, y + 3), "leather", "round", name="baluster")
    c.outline("ink")
    return c


def shop_stall() -> HDCanvas:
    """Shop counter under a blue-and-white striped awning with potion shelves, 40 x 30 units."""
    w, h = 160, 120
    c = HDCanvas(w, h)
    rng = random.Random(4)
    c.draw(c.rect(6, 22, w - 7, 70), "hair_brown", "plate", bias=-2, name="back")
    for y in (34, 52):
        c.draw(c.rect(8, y, w - 9, y + 3), "leather", "plate", name="shelf")
        for x in range(12, w - 14, 9):
            c.draw(c.capsule(x, y - 9, x, y - 2, 2.4, 3.0), rng.choice(["crimson", "azure", "moss", "amber", "violet"]), "metal", name="potion")
    for k in range(10):  # awning stripes
        x0 = k * 16
        c.draw(c.poly([(x0, 2), (x0 + 16, 2), (x0 + 16, 20), (x0 + 8, 25), (x0, 20)]), "azure" if k % 2 == 0 else "bone",
               "cloth", bias=0 if k % 2 == 0 else 1, name="awning")
    c.draw(c.rect(0, 0, w - 1, 4), "hair_brown", "plate", name="rail")
    c.draw(c.rect(2, 74, w - 3, h - 4), "hair_brown", "plate", bias=-1, name="front")
    c.draw(c.rect(0, 70, w - 1, 80), "leather", "plate", bias=1, name="top")
    c.draw(c.rect(60, 62, 76, 72), "bone", "plate", name="ledger")
    c.draw(c.ellipse(110, 68, 5, 4), "amber", "metal", name="scale")
    c.outline("ink")
    return c


def forge() -> HDCanvas:
    """Brick forge with glowing coals and an anvil, 24 x 22 units."""
    w, h = 96, 88
    c = HDCanvas(w, h)
    c.draw(c.rect(10, 4, 50, 70), "crimson", "plate", bias=-2, name="chimney")
    for y in range(8, 66, 8):
        off = (y // 8) % 2 * 6
        for x in range(10 - off, 50, 12):
            c.draw(c.rect(max(x + 1, 11), y, min(x + 10, 49), y + 6), "flame", "plate", bias=-2, selout=False, cast=False)
    c.fill(c.poly([(18, 70), (18, 46), (30, 38), (42, 46), (42, 70)]), "night", 0)
    c.draw(c.ellipse(30, 62, 10, 5), "flame", "glow", selout=False, cast=False)
    c.fixed(c.ellipse(30, 61, 5, 3), "glow_amber")
    c.draw(c.poly([(56, 60), (86, 60), (82, 66), (76, 66), (76, 78), (66, 78), (66, 66), (60, 66)]), "steel", "metal", name="anvil")
    c.draw(c.rect(64, 78, 78, 84), "hair_brown", "plate", name="stump")
    c.outline("ink")
    return c


def bush(seed: int = 1) -> HDCanvas:
    """Round garden shrub (outside the entrance), 14 x 12 units."""
    w, h = 56, 48
    c = HDCanvas(w, h)
    rng = random.Random(seed)
    for _ in range(7):
        x, y = rng.uniform(14, 42), rng.uniform(16, 32)
        c.draw(c.ellipse(x, y, rng.uniform(9, 13), rng.uniform(8, 11)), "moss", "cloth", bias=rng.choice((-1, 0)), selout=False)
    c.outline("ink")
    return c


def steps() -> HDCanvas:
    """Stone entrance steps (floor decal), 32 x 12 units."""
    w, h = 128, 48
    c = HDCanvas(w, h)
    for k in range(3):
        c.draw(c.rect(8 + k * 6, k * 14, w - 9 - k * 6, k * 14 + 13), "stone", "plate", bias=-k, selout=False, cast=False)
    c.outline("ink")
    return c


def small_rug() -> HDCanvas:
    """Small blue mat with a gold border (decal)."""
    w, h = 112, 48
    c = HDCanvas(w, h)
    c.draw(c.rect(0, 0, w - 1, h - 1), "azure", "plate", bias=-1, selout=False, cast=False)
    c.fill(c.rect(0, 0, w - 1, h - 1) & ~c.rect(4, 4, w - 5, h - 5), "amber", 3)
    c.fill(c.rect(8, 8, w - 9, h - 9) & ~c.rect(9, 9, w - 10, h - 10), "amber", 2)
    return c


def table_rug() -> HDCanvas:
    """Blue rug under the long tables (decal)."""
    w, h = 176, 224
    c = HDCanvas(w, h)
    c.draw(c.rect(0, 0, w - 1, h - 1), "azure", "plate", bias=-1, selout=False, cast=False)
    c.fill(c.rect(0, 0, w - 1, h - 1) & ~c.rect(5, 5, w - 6, h - 6), "amber", 3)
    c.fill(c.rect(10, 10, w - 11, h - 11) & ~c.rect(11, 11, w - 12, h - 12), "amber", 2)
    return c


def long_table() -> HDCanvas:
    """Long feast table with chairs, books and candles, 22 x 28 units (vertical)."""
    w, h = 88, 112
    c = HDCanvas(w, h)
    for y in (22, 46, 70):
        for x in (4, 72):
            c.draw(c.rect(x, y, x + 11, y + 14), "crimson", "cloth", bias=-1, name="chair")
    c.draw(c.rect(18, 8, 69, 98), "hair_brown", "plate", name="top")
    c.draw(c.rect(18, 96, 69, 104), "hair_brown", "plate", bias=-2, name="apron")
    for x, y in ((30, 20), (54, 60)):
        c.draw(c.rect(x, y, x + 3, y + 8), "bone", "round", name="candle")
        c.fixed(c.ellipse(x + 1.5, y - 3, 1.5, 2.5), "glow_amber")
    c.draw(c.poly([(40, 36), (58, 34), (60, 46), (42, 48)]), "bone", "plate", name="book")
    c.draw(c.ellipse(36, 78, 5, 5), "moss", "cloth", name="plant")
    c.draw(c.capsule(56, 84, 56, 90, 3, 3), "steel", "round", name="mug")
    c.outline("ink")
    return c


def round_rug() -> HDCanvas:
    """Large oval rug for the gathering hall floor (a decal: no collision), 64 x 40 world units."""
    w, h = 256, 160
    c = HDCanvas(w, h)
    cx, cy = w / 2 - 0.5, h / 2 - 0.5
    c.draw(c.ellipse(cx, cy, 124, 76), "crimson", "plate", bias=-1, selout=False, cast=False)
    c.fill(c.ellipse(cx, cy, 124, 76) & ~c.ellipse(cx, cy, 118, 70), "amber", 2)
    c.fill(c.ellipse(cx, cy, 108, 62) & ~c.ellipse(cx, cy, 105, 59), "amber", 3)
    c.fill(c.ellipse(cx, cy, 60, 36) & ~c.ellipse(cx, cy, 56, 32), "amber", 3)
    star = c.poly([(cx, cy - 30), (cx + 10, cy - 8), (cx + 48, cy), (cx + 10, cy + 8), (cx, cy + 30), (cx - 10, cy + 8), (cx - 48, cy), (cx - 10, cy - 8)])
    c.fill(star, "amber", 4)
    c.fill(c.ellipse(cx, cy, 8, 6), "azure", 4)
    return c


PROPS = {
    # key: (builder, pivot (feet / base centre in px))
    "counter": (counter, (80, 58)),
    "table": (table, (48, 56)),
    "shelf": (shelf, (32, 92)),
    "rack": (weapon_rack, (32, 76)),
    "board": (mission_board, (40, 85)),
    "plant": (plant, (20, 52)),
    "bench": (bench, (48, 28)),
    "bar": (bar_counter, (88, 68)),
    "banner": (banner_stand, (24, 100)),
    "target": (archery_target, (20, 52)),
    "armchair": (armchair, (20, 36)),
    "round_table": (round_table, (24, 36)),
    "rail_h": (lambda: rail(True), (32, 36)),
    "rail_v": (lambda: rail(False), (12, 69)),
    "stall": (shop_stall, (80, 116)),
    "forge": (forge, (48, 84)),
    "bush": (bush, (28, 44)),
    "long_table": (long_table, (44, 104)),
}
# floor decals (no collision) and overhead pieces: key -> builder
DECALS = {"rug": compass_rug, "rug_red": lounge_rug, "rug_small": small_rug, "rug_table": table_rug, "steps": steps}
OVERHEAD = {"chandelier": chandelier}
FIREPLACE_PIVOT = (56, 100)
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
