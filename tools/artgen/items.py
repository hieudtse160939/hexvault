"""Weapons, projectiles, pickups, combat FX and UI icons."""
from __future__ import annotations

import math

from px import Canvas

# --- weapons: 24x12 cell, pointing right, grip pivot at (6, 7) ----------------
WEAPON_PIVOT = (6, 7)


def _w() -> Canvas:
    return Canvas(24, 12)


def rift_pistol():
    c = _w()
    c.rect(6, 4, 15, 6, "stone1"); c.hline(6, 15, 4, "stone2")
    c.rect(5, 7, 7, 10, "night"); c.px(14, 5, "teal2"); c.px(16, 5, "stone0")
    c.outline("ink"); return c


def scatter_cannon():
    c = _w()
    c.rect(4, 4, 19, 7, "amber0"); c.rect(10, 3, 20, 5, "stone1"); c.hline(10, 20, 3, "stone2")
    c.rect(4, 7, 6, 10, "amber1"); c.rect(11, 6, 14, 7, "stone0"); c.px(19, 4, "ink")
    c.outline("ink"); return c


def pulse_rifle():
    c = _w()
    c.rect(2, 4, 21, 6, "stone0"); c.hline(2, 21, 4, "stone1")
    c.rect(9, 7, 11, 10, "night"); c.rect(2, 5, 4, 8, "stone0")
    c.hline(12, 18, 5, "teal2"); c.rect(5, 7, 7, 9, "stone0")
    c.outline("ink"); return c


def longshot():
    c = _w()
    c.rect(1, 5, 23, 6, "stone1"); c.hline(1, 23, 5, "stone2")
    c.rect(1, 6, 8, 8, "amber0"); c.rect(9, 3, 14, 4, "night"); c.px(14, 3, "blue2")
    c.rect(7, 7, 8, 10, "night")
    c.outline("ink"); return c


def thornbow():
    c = _w()
    for y in range(0, 12):
        x = 9 + int(round(3 * math.sin(y / 11 * math.pi)))
        c.px(x, y, "moss1" if 2 < y < 9 else "moss2")
    c.vline(8, 0, 11, "stone3")
    c.rect(9, 5, 11, 6, "amber1")
    c.outline("ink"); return c


def ember_blade():
    c = _w()
    c.rect(3, 5, 6, 6, "amber0")
    c.vline(7, 3, 8, "amber2")
    c.poly([(8, 4), (21, 4), (23, 5.5), (21, 7), (8, 7)], "stone2")
    c.hline(8, 21, 4, "stone3"); c.hline(9, 20, 6, "red2")
    c.outline("ink"); return c


def hex_staff():
    c = _w()
    c.hline(2, 18, 6, "amber0"); c.hline(2, 18, 5, "amber1")
    c.ellipse(20, 5.5, 2.5, 2.5, "vio1"); c.ellipse(20, 5.5, 1.5, 1.5, "vio3")
    c.px(17, 3, "vio2"); c.px(17, 8, "vio2")
    c.outline("ink"); return c


def boom_tube():
    c = _w()
    c.rect(2, 3, 20, 7, "moss0"); c.hline(2, 20, 3, "moss1")
    c.rect(20, 2, 22, 8, "stone1"); c.rect(0, 4, 2, 6, "stone0")
    c.rect(8, 8, 10, 10, "night"); c.rect(12, 1, 14, 2, "red2")
    c.outline("ink"); return c


def prism_lance():
    c = _w()
    c.rect(3, 4, 14, 7, "stone0"); c.hline(3, 14, 4, "stone2")
    c.poly([(15, 2), (22, 5.5), (15, 9)], "teal2")
    c.poly([(15, 2), (22, 5.5), (15, 5)], "teal3")
    c.rect(5, 8, 7, 10, "night"); c.px(10, 5, "vio2")
    c.outline("ink"); return c


def frost_needler():
    c = _w()
    c.rect(4, 4, 17, 6, "blue0"); c.hline(4, 17, 4, "blue1")
    c.rect(17, 5, 21, 5, "blue2"); c.rect(9, 7, 13, 9, "blue1")
    c.rect(5, 7, 7, 10, "night"); c.px(12, 3, "white")
    c.outline("ink"); return c


def storm_coil():
    c = _w()
    c.rect(4, 4, 13, 7, "amber0"); c.hline(4, 13, 4, "amber1")
    for i, x in enumerate(range(14, 22, 2)):
        c.vline(x, 3, 8, "amber2" if i % 2 else "blue2")
    c.rect(5, 8, 7, 10, "night"); c.px(21, 5, "white")
    c.outline("ink"); return c


WEAPONS = {
    "rift_pistol": rift_pistol, "scatter_cannon": scatter_cannon, "pulse_rifle": pulse_rifle,
    "longshot": longshot, "thornbow": thornbow, "ember_blade": ember_blade, "hex_staff": hex_staff,
    "boom_tube": boom_tube, "prism_lance": prism_lance, "frost_needler": frost_needler,
    "storm_coil": storm_coil,
}


# --- projectiles: 8x8 frames --------------------------------------------------
def _p() -> Canvas:
    return Canvas(8, 8)


def bullet(col=("amber1", "amber3")):
    c = _p(); c.rect(2, 3, 5, 4, col[0]); c.rect(4, 3, 5, 4, col[1]); return c


def pellet():
    c = _p(); c.rect(3, 3, 4, 4, "amber3"); c.px(2, 3, "amber1"); return c


def arrow():
    c = _p(); c.hline(0, 6, 3, "amber1"); c.px(7, 3, "stone3"); c.px(6, 2, "stone3"); c.px(6, 4, "stone3")
    c.px(0, 2, "moss2"); c.px(0, 4, "moss2"); return c


def orb(cols, f):
    c = _p(); r = 2.5 + (f % 2) * 0.5
    c.ellipse(3.5, 3.5, r, r, cols[0]); c.ellipse(3.5, 3.5, r - 1, r - 1, cols[1]); c.px(3, 3, cols[2])
    return c


def rocket(f):
    c = _p(); c.rect(2, 3, 6, 4, "moss1"); c.px(7, 3, "red2"); c.px(7, 4, "red2")
    c.px(1, 3, "amber3" if f else "amber2"); c.px(0, 4 - f, "amber1"); return c


def needle():
    c = _p(); c.hline(1, 6, 3, "blue2"); c.px(7, 3, "white"); c.hline(1, 4, 4, "blue1"); return c


def spark(f):
    c = _p()
    pts = [(0, 4), (2, 2), (4, 5), (6, 2), (7, 4)] if f else [(0, 3), (2, 5), (4, 2), (6, 5), (7, 3)]
    for a, b in zip(pts, pts[1:]):
        c.line(a[0], a[1], b[0], b[1], "blue2")
    c.px(4, 3 + f, "white"); return c


PROJECTILES = {
    "bullet": [bullet()],
    "pellet": [pellet()],
    "arrow": [arrow()],
    "orb_teal": [orb(("teal1", "teal2", "teal3"), f) for f in range(2)],
    "orb_vio": [orb(("vio1", "vio2", "vio3"), f) for f in range(2)],
    "orb_red": [orb(("red1", "red2", "red3"), f) for f in range(2)],
    "orb_amber": [orb(("amber1", "amber2", "amber3"), f) for f in range(2)],
    "rocket": [rocket(f) for f in range(2)],
    "needle": [needle()],
    "spark": [spark(f) for f in range(2)],
    "enemy_bullet": [bullet(("red1", "red3"))],
}


# --- pickups: 8x8 -------------------------------------------------------------
def coin(f):
    c = _p(); w = [2.5, 1.5, 0.5, 1.5][f]
    c.ellipse(3.5, 3.5, w, 2.5, "amber2")
    if w > 1:
        c.ellipse(3.5, 3.5, w - 1, 1.5, "amber1")
    c.px(3, 2, "amber3"); c.outline("ink"); return c


def shard(f):
    c = _p(); cols = ("teal1", "teal2", "teal3", "teal2")
    c.poly([(3.5, 0), (6, 3.5), (3.5, 7), (1, 3.5)], cols[f])
    c.poly([(3.5, 0), (6, 3.5), (3.5, 3.5)], "teal3" if f != 2 else "white")
    return c


def heart():
    c = _p()
    c.ascii(0, 1, [".rr.rr.", "rRRrrrr", "rRrrrrr", ".rrrrr.", "..rrr..", "...r..."],
            {"r": "red2", "R": "red3"}); c.outline("ink"); return c


def armor_pip():
    c = _p()
    c.ascii(1, 0, ["bbbbb", "bBBbb", "bBbbb", "bbbbb", ".bbb.", "..b.."], {"b": "blue1", "B": "blue2"})
    c.outline("ink"); return c


PICKUPS = {
    "coin": [coin(f) for f in range(4)],
    "shard": [shard(f) for f in range(4)],
    "heart": [heart()],
    "armor": [armor_pip()],
}


# --- FX -----------------------------------------------------------------------
def impact(f, cols=("white", "amber3", "amber2", "amber1")):
    c = _p(); r = 1 + f
    for k in range(8):
        a = k * math.pi / 4
        c.px(3.5 + math.cos(a) * r, 3.5 + math.sin(a) * r, cols[f])
    if f < 2:
        c.ellipse(3.5, 3.5, 1.5 - f * 0.5, 1.5 - f * 0.5, cols[0])
    return c


def muzzle(f):
    c = _p()
    c.poly([(0, 2), (7, 3.5), (0, 5)], "amber2" if f == 0 else "amber1")
    c.rect(0, 3, 3, 4, "white" if f == 0 else "amber3")
    return c


def explosion(f):
    c = Canvas(32, 32)
    r = [4, 8, 11, 13, 14, 15][f]
    cols = [("white", "amber3"), ("amber3", "amber2"), ("amber2", "red2"), ("red2", "red1"), ("red1", "stone0"), ("stone0", "night")][f]
    c.ellipse(15.5, 15.5, r, r, cols[1])
    if f < 5:
        c.ellipse(15.5, 15.5, r * 0.6, r * 0.6, cols[0])
    if f >= 3:  # hollow out
        c.ellipse(15.5, 15.5, r - 4 - (f - 3) * 3, r - 4 - (f - 3) * 3, None)
    return c


def puff(f):
    c = Canvas(16, 16); r = 2 + f * 1.3
    for k in range(6):
        a = k * math.pi / 3 + f * 0.2
        c.ellipse(7.5 + math.cos(a) * r, 7.5 + math.sin(a) * r, max(0.6, 2.2 - f * 0.35), max(0.6, 2.2 - f * 0.35),
                  "stone3" if f < 3 else "stone1")
    return c


def slash(f):
    c = Canvas(24, 24)
    a0 = -1.2 + f * 0.6
    for k in range(14):
        a = a0 + k * 0.12
        for r in (8, 9, 10):
            col = "white" if r == 10 else ("stone3" if r == 9 else "teal2")
            if k > 10 and r == 8:
                continue
            c.px(11.5 + math.cos(a) * r, 11.5 + math.sin(a) * r, col)
    return c


def sparkle(f, col="moss3"):
    c = _p()
    s = [1, 2, 3, 1][f]
    c.hline(3 - s, 3 + s, 3, col); c.vline(3, 3 - s, 3 + s, col); c.px(3, 3, "white")
    return c


FX = {
    "impact": ([impact(f) for f in range(4)], 18),
    "impact_red": ([impact(f, ("white", "red3", "red2", "red1")) for f in range(4)], 18),
    "impact_teal": ([impact(f, ("white", "teal3", "teal2", "teal1")) for f in range(4)], 18),
    "muzzle": ([muzzle(f) for f in range(2)], 20),
    "explosion": ([explosion(f) for f in range(6)], 14),
    "puff": ([puff(f) for f in range(6)], 14),
    "slash": ([slash(f) for f in range(3)], 20),
    "sparkle": ([sparkle(f) for f in range(4)], 10),
    "sparkle_teal": ([sparkle(f, "teal3") for f in range(4)], 10),
}


# --- UI icons 16x16 -------------------------------------------------------------
def _i() -> Canvas:
    return Canvas(16, 16)


def icon_heart():
    c = _i()
    c.ascii(1, 2, [".rrr...rrr.", "rRRrr.rrrrr", "rRrrrrrrrrr", "rrrrrrrrrrr", ".rrrrrrrrr.",
                   "..rrrrrrr..", "...rrrrr...", "....rrr....", ".....r....."], {"r": "red2", "R": "red3"})
    c.outline("ink"); return c


def icon_shield():
    c = _i()
    c.ascii(2, 1, ["bbbbbbbbbbb", "bBBBbbbbbbb", "bBbbbbbbbbb", "bBbbbbbbbbb", "bbbbbbbbbbb", ".bbbbbbbbb.",
                   ".bbbbbbbbb.", "..bbbbbbb..", "...bbbbb...", "....bbb....", ".....b....."],
            {"b": "blue1", "B": "blue2"})
    c.outline("ink"); return c


def icon_coin():
    c = _i(); c.ellipse(7.5, 7.5, 5, 5, "amber2"); c.ellipse(7.5, 7.5, 3, 3, "amber1")
    c.vline(7, 5, 10, "amber3"); c.outline("ink"); return c


def icon_shard():
    c = _i(); c.poly([(7.5, 1), (13, 7.5), (7.5, 14), (2, 7.5)], "teal2")
    c.poly([(7.5, 1), (13, 7.5), (7.5, 7.5)], "teal3"); c.poly([(2, 7.5), (7.5, 14), (7.5, 7.5)], "teal1")
    c.outline("ink"); return c


def icon_skill(kind: str):
    c = _i()
    if kind == "overclock":
        c.ring(7.5, 7.5, 6, "amber2", 2); c.line(7, 3, 7, 8, "amber3"); c.line(7, 8, 10, 10, "amber3")
    elif kind == "bulwark":
        c.ellipse(7.5, 8, 6, 6, "blue1"); c.ellipse(7.5, 8, 4, 4, "blue2"); c.ellipse(7.5, 8, 2, 2, "white")
    elif kind == "phase":
        c.poly([(2, 12), (8, 2), (7, 7), (13, 4), (6, 14), (8, 9)], "vio2"); c.px(8, 3, "vio3")
    elif kind == "turret":
        c.rect(4, 8, 11, 13, "stone1"); c.rect(6, 5, 12, 8, "stone2"); c.hline(12, 14, 6, "teal2")
    c.outline("ink"); return c


def icon_btn(kind: str):
    c = Canvas(24, 24)
    c.ellipse(11.5, 11.5, 11, 11, "night"); c.ring(11.5, 11.5, 11.5, "stone2")
    if kind == "attack":
        c.ring(11.5, 11.5, 6, "red2", 2); c.vline(11, 3, 20, "red2"); c.hline(3, 20, 11, "red2")
    elif kind == "skill":
        c.poly([(11.5, 4), (14, 10), (20, 11.5), (14, 13), (11.5, 19), (9, 13), (3, 11.5), (9, 10)], "teal2")
    elif kind == "dash":
        for o in (0, 5):
            c.line(6 + o, 6, 11 + o, 11, "amber2"); c.line(11 + o, 11, 6 + o, 16, "amber2")
    elif kind == "swap":
        c.line(6, 9, 17, 9, "stone3"); c.line(14, 6, 17, 9, "stone3")
        c.line(6, 14, 17, 14, "stone3"); c.line(6, 14, 9, 17, "stone3")
    elif kind == "interact":
        c.ascii(9, 5, ["..h..", ".hhh.", "hhhhh", "..h..", "..h..", "..h..", ".....", "hhhhh"], {"h": "moss3"})
    elif kind == "pause":
        c.rect(8, 7, 10, 16, "stone3"); c.rect(13, 7, 15, 16, "stone3")
    return c


def joystick_base():
    c = Canvas(48, 48)
    c.ellipse(23.5, 23.5, 23, 23, "night"); c.ring(23.5, 23.5, 23.5, "stone1")
    c.ring(23.5, 23.5, 16, "dusk")
    for a in range(4):
        ang = a * math.pi / 2
        c.px(23.5 + math.cos(ang) * 20, 23.5 + math.sin(ang) * 20, "stone2")
    return c


def joystick_knob():
    c = Canvas(24, 24)
    c.ellipse(11.5, 11.5, 11, 11, "stone1"); c.ellipse(10.5, 10.5, 8, 8, "stone2"); c.ellipse(9, 9, 3, 3, "stone3")
    c.outline("ink"); return c


BOONS = {
    "power": ("red2", "red3"), "haste": ("amber2", "amber3"), "vigor": ("moss2", "moss3"),
    "pierce": ("stone2", "white"), "crit": ("vio2", "vio3"), "reload": ("teal2", "teal3"),
    "plating": ("blue1", "blue2"), "magnet": ("amber1", "amber3"), "leech": ("red1", "red3"),
    "volley": ("teal1", "white"),
}


def icon_boon(cols):
    c = _i()
    c.poly([(7.5, 1), (14, 7.5), (7.5, 14), (1, 7.5)], cols[0])
    c.poly([(7.5, 3), (12, 7.5), (7.5, 12), (3, 7.5)], cols[1])
    c.ellipse(7.5, 7.5, 1.5, 1.5, "white")
    c.outline("ink"); return c


def icon_lock():
    c = _i(); c.ring(7.5, 6, 4, "stone2", 2); c.rect(3, 7, 12, 14, "amber1"); c.rect(7, 9, 8, 11, "ink")
    c.outline("ink"); return c


def icon_trophy():
    c = _i(); c.rect(4, 2, 11, 7, "amber2"); c.rect(5, 8, 10, 8, "amber1"); c.vline(7, 9, 11, "amber1")
    c.vline(8, 9, 11, "amber1"); c.rect(4, 12, 11, 13, "amber0"); c.px(1, 3, "amber2"); c.px(14, 3, "amber2")
    c.vline(2, 3, 5, "amber2"); c.vline(13, 3, 5, "amber2"); c.px(5, 3, "amber3")
    c.outline("ink"); return c


def icon_scroll():
    c = _i(); c.rect(3, 3, 12, 12, "skin2"); c.vline(3, 2, 13, "skin1"); c.vline(12, 2, 13, "skin1")
    for y in (5, 7, 9):
        c.hline(5, 10, y, "skin0")
    c.outline("ink"); return c


def ui_icons() -> dict[str, Canvas]:
    out = {
        "heart": icon_heart(), "shield": icon_shield(), "coin": icon_coin(), "shard": icon_shard(),
        "skill_overclock": icon_skill("overclock"), "skill_bulwark": icon_skill("bulwark"),
        "skill_phase": icon_skill("phase"), "skill_turret": icon_skill("turret"),
        "lock": icon_lock(), "trophy": icon_trophy(), "scroll": icon_scroll(),
    }
    for k, cols in BOONS.items():
        out["boon_" + k] = icon_boon(cols)
    return out


def touch_icons() -> dict[str, Canvas]:
    out = {"btn_" + k: icon_btn(k) for k in ("attack", "skill", "dash", "swap", "interact", "pause")}
    out["joy_base"] = joystick_base(); out["joy_knob"] = joystick_knob()
    return out


def turret_sheet():
    def t(f):
        c = _i(); c.rect(4, 10, 11, 14, "stone0"); c.hline(4, 11, 10, "stone1")
        c.rect(5, 5, 10, 9, "stone1"); c.hline(5, 10, 5, "stone2")
        c.rect(10, 6, 14, 7, "stone2"); c.px(7, 7, "teal3" if f else "teal1")
        c.outline("ink"); return c
    return {"idle": [t(0), t(1)]}


def preview_sets():
    w = {k: [f()] for k, f in WEAPONS.items()}
    return [{"weapons": [f() for f in WEAPONS.values()]}, {k: v for k, v in PROJECTILES.items()},
            {k: v for k, v in PICKUPS.items()}, {"icons": list(ui_icons().values())}]
