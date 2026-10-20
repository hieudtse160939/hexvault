"""Enemy and boss sprite sheets. All drawn facing right."""
from __future__ import annotations

import math

from px import Canvas


# --- Gloop: melee chaser slime with a crystal core (16x16) -----------------
def gloop(squash: float = 0.0, stretch_x: float = 0.0, core: str = "teal2", dead: int = 0) -> Canvas:
    c = Canvas(16, 16)
    if dead:
        # splat puddle that shrinks
        r = max(1, 7 - dead)
        c.ellipse(7.5, 13, r, max(1, 2 - dead // 3), "moss1")
        if dead < 3:
            c.px(8, 12, core)
        c.outline("ink")
        return c
    rx = 6 + stretch_x - squash * 0.3
    ry = 5 - squash
    cy = 14 - ry - 0.5
    c.ellipse(7.5, cy, rx, ry, "moss1")
    c.ellipse(8.5, cy - 1, rx - 2, ry - 2, "moss2")        # lit side
    c.px(10, int(cy - ry + 2), "moss3"); c.px(11, int(cy - ry + 2), "moss3")  # specular
    c.hline(int(7.5 - rx + 1), int(7.5 + rx - 1), 13, "moss0")  # base shade
    c.rect(7, int(cy), 8, int(cy) + 1, core)
    c.px(10, int(cy - 1), "ink"); c.px(12, int(cy - 1), "ink")  # eyes
    c.outline("ink")
    return c


def gloop_sheet():
    return {
        "idle": [gloop(0), gloop(0.5), gloop(1), gloop(0.5)],
        "move": [gloop(1, 0.5), gloop(0), gloop(-1, -0.5), gloop(0)],
        "attack": [gloop(1.5, 1.0, "amber2"), gloop(-1, 1.5, "amber3"), gloop(0, 1.0, "amber2")],
        "hurt": [gloop(1, 1, "red2")],
        "death": [gloop(dead=d) for d in (1, 2, 3, 4, 5)],
    }


# --- Sparkeye: floating ranged drone (16x16) ---------------------------------
def sparkeye(bob: int = 0, iris: str = "teal2", charge: int = 0, dead: int = 0) -> Canvas:
    c = Canvas(16, 16)
    cy = 7 + bob
    if dead:
        for i in range(6):
            a = i * math.pi / 3 + dead * 0.4
            r = 2 + dead * 1.2
            c.px(7.5 + math.cos(a) * r, cy + math.sin(a) * r, "stone2" if i % 2 else "teal2")
        if dead < 3:
            c.ellipse(7.5, cy, 3 - dead, 3 - dead, "stone1")
        return c
    # fins
    c.poly([(1, cy - 3), (4, cy - 1), (4, cy + 1), (1, cy + 3)], "stone0")
    c.poly([(14, cy - 3), (11, cy - 1), (11, cy + 1), (14, cy + 3)], "stone0")
    c.ellipse(7.5, cy, 4.5, 4.5, "stone1")
    c.ellipse(6.5, cy - 1, 3, 3, "stone2")
    c.ellipse(8.5, cy, 2.5, 2.5, "night")
    c.ellipse(8.5, cy, 1.5 + charge * 0.5, 1.5 + charge * 0.5, iris)
    c.px(9, cy - 1, "white")
    c.hline(4, 11, cy + 5, "ink") if False else None
    c.outline("ink")
    # thruster glow under
    c.px(7, cy + 6, "teal1"); c.px(8, cy + 6, "teal1")
    if bob == 0:
        c.px(7, cy + 7, "teal0")
    return c


def sparkeye_sheet():
    return {
        "idle": [sparkeye(0), sparkeye(-1), sparkeye(-1), sparkeye(0)],
        "move": [sparkeye(0), sparkeye(-1)],
        "attack": [sparkeye(0, "amber2", 1), sparkeye(0, "amber3", 2), sparkeye(0, "white", 2)],
        "hurt": [sparkeye(0, "red2")],
        "death": [sparkeye(dead=d) for d in (1, 2, 3, 4)],
    }


# --- Skitter: fast flanker crawler (16x16) -----------------------------------
def skitter(phase: int = 0, lunge: int = 0, eye: str = "amber2", dead: int = 0) -> Canvas:
    c = Canvas(16, 16)
    if dead:
        c.ellipse(7.5, 12, 4, 2, "red0")
        for i in range(dead):
            c.px(3 + i * 2, 13 - (i % 2), "red1")
        c.outline("ink")
        return c
    ox = lunge
    # legs (4 visible), alternate by phase
    for i, lx in enumerate((4, 6, 9, 11)):
        up = (i + phase) % 2
        c.line(lx + ox, 10, lx + ox - 1 + 2 * (i % 2), 13 - up, "red0")
    c.ellipse(7.5 + ox, 9, 5, 3, "red1")
    c.ellipse(7 + ox, 8, 3.5, 1.5, "red2")
    c.px(5 + ox, 7, "red3")
    # head + mandibles
    c.ellipse(12.5 + ox, 9, 2, 2, "red1")
    c.px(13 + ox, 8, eye); c.px(14 + ox, 10, "stone3"); c.px(15 + ox, 10, "stone3")
    c.outline("ink")
    return c


def skitter_sheet():
    return {
        "idle": [skitter(0), skitter(1)],
        "move": [skitter(0), skitter(1), skitter(0, 0), skitter(1, 0)],
        "attack": [skitter(0, -1, "amber3"), skitter(1, 1, "white"), skitter(0, 1, "amber3")],
        "hurt": [skitter(0, -1, "red3")],
        "death": [skitter(dead=d) for d in (1, 2, 3, 4)],
    }


# --- Golem: heavy tank (24x24) ------------------------------------------------
def golem(bob: int = 0, step: int = 0, crack: str = "amber2", raise_arm: int = 0, dead: int = 0) -> Canvas:
    c = Canvas(24, 24)
    if dead:
        n = 7 - dead
        for i in range(6):
            x = 4 + i * 3
            y = 22 - (i * 7 + dead) % 4
            c.rect(x, y - 1, x + 2, y, "stone1" if i % 2 else "stone0")
        if dead < 3:
            c.rect(7, 22 - n * 2, 16, 21, "stone1")
            c.px(12, 21 - n, crack)
        c.outline("ink")
        return c
    # legs
    c.rect(7 - step, 18, 10 - step, 22, "stone0")
    c.rect(14 + step, 18, 17 + step, 22, "stone0")
    # body
    by = 6 + bob
    c.rect(5, by + 3, 18, by + 13, "stone1")
    c.rect(5, by + 3, 6, by + 13, "stone0")
    c.rect(15, by + 4, 18, by + 11, "stone2")
    c.line(9, by + 6, 12, by + 10, crack); c.line(12, by + 10, 14, by + 8, crack)
    # head
    c.rect(9, by, 15, by + 3, "stone1"); c.rect(9, by, 15, by, "stone2")
    c.hline(12, 14, by + 2, crack)
    # arms (big fists)
    c.rect(1, by + 5, 4, by + 12, "stone0"); c.rect(1, by + 11, 4, by + 14, "stone1")
    ay = by + 5 - raise_arm * 4
    c.rect(19, ay, 22, ay + 7, "stone1"); c.rect(19, ay + 6, 22, ay + 9, "stone2")
    c.outline("ink")
    return c


def golem_sheet():
    return {
        "idle": [golem(0), golem(0), golem(1), golem(1)],
        "move": [golem(0, -1), golem(1, 0), golem(0, 1), golem(1, 0)],
        "attack": [golem(0, 0, "amber3", 1), golem(-1, 0, "white", 2), golem(1, 0, "amber2", 0)],
        "hurt": [golem(0, 0, "red2")],
        "death": [golem(dead=d) for d in (1, 2, 3, 4, 5)],
    }


# --- Acolyte: summoner caster (16x16) -----------------------------------------
def acolyte(bob: int = 0, glow: int = 0, dead: int = 0) -> Canvas:
    c = Canvas(16, 16)
    if dead:
        c.rect(4, 13, 11, 14, "vio0"); c.px(6, 13, "vio1")
        if dead < 3:
            c.ellipse(7.5, 10, 3 - dead, 3 - dead, "vio1")
        for i in range(dead):
            c.px(4 + i * 2, 11 - i, "vio2")
        c.outline("ink")
        return c
    y = 2 + bob
    # robe (triangle-ish)
    c.poly([(7.5, y + 4), (3, 14), (12, 14)], "vio1")
    c.poly([(7.5, y + 4), (3, 14), (6, 14)], "vio0")
    c.hline(4, 11, 14, "vio0")
    # hood
    c.ellipse(7.5, y + 3, 3, 3, "vio1"); c.rect(7, y + 3, 10, y + 5, "night")
    c.px(8, y + 4, "red2"); c.px(10, y + 4, "red2")
    # staff
    c.vline(12, y + 2, 14, "amber0")
    orb = ["teal1", "teal2", "teal3"][min(glow, 2)]
    c.ellipse(12, y + 1, 1 + (1 if glow > 1 else 0), 1 + (1 if glow > 1 else 0), orb)
    c.outline("ink")
    return c


def acolyte_sheet():
    return {
        "idle": [acolyte(0), acolyte(0), acolyte(1), acolyte(1)],
        "move": [acolyte(0), acolyte(1)],
        "attack": [acolyte(0, 1), acolyte(-1, 2), acolyte(-1, 2), acolyte(0, 1)],
        "hurt": [acolyte(1, 0)],
        "death": [acolyte(dead=d) for d in (1, 2, 3, 4)],
    }


# --- Boss: Ossifex, the Clockwork Lich (48x48) --------------------------------
def ossifex(bob: int = 0, eyes: str = "amber2", hands: int = 0, gear: int = 0,
            robe: tuple = ("vio0", "vio1", "vio2"), dead: int = 0) -> Canvas:
    c = Canvas(48, 48)
    r0, r1, r2 = robe
    y = 6 + bob
    if dead >= 4:
        # pile of brass and bone
        c.ellipse(24, 42, 14 - (dead - 4) * 3, 4, r0)
        c.ellipse(20, 40, 4, 3, "stone3"); c.px(19, 40, "ink"); c.px(21, 40, "ink")
        for i in range(5):
            c.ellipse(28 + i * 2 - dead, 41 - i % 2, 1.5, 1.5, "amber1")
        c.outline("ink")
        return c
    # floating robe body
    c.poly([(24, y + 12), (10, y + 38), (38, y + 38)], r1)
    c.poly([(24, y + 12), (10, y + 38), (19, y + 38)], r0)
    c.poly([(26, y + 14), (32, y + 38), (37, y + 38)], r2)
    for i in range(5):  # tattered hem
        c.px(12 + i * 6, y + 39, r0); c.px(13 + i * 6, y + 40, r0)
    # brass ribcage with spinning gear
    c.ellipse(24, y + 20, 7, 6, "amber0")
    c.ellipse(24, y + 20, 5, 4, "night")
    for k in range(6):
        a = (k * math.pi / 3) + gear * math.pi / 12
        c.px(24 + math.cos(a) * 3, y + 20 + math.sin(a) * 3, "amber2")
    c.ellipse(24, y + 20, 1.5, 1.5, eyes)
    for k in range(3):
        c.hline(18, 30, y + 15 + k * 4, "amber1") if k != 1 else None
    # skull head
    c.ellipse(24, y + 7, 7, 7, "stone3")
    c.ellipse(22, y + 5, 4, 4, "white")
    c.rect(19, y + 6, 22, y + 9, "ink"); c.rect(26, y + 6, 29, y + 9, "ink")
    c.rect(20, y + 7, 21, y + 8, eyes); c.rect(27, y + 7, 28, y + 8, eyes)
    c.rect(21, y + 12, 27, y + 14, "stone2")
    for x in range(21, 28, 2):
        c.px(x, y + 13, "ink")
    # crown of gears
    for x in (18, 24, 30):
        c.rect(x - 1, y - 2, x + 1, y, "amber1"); c.px(x, y - 3, "amber2")
    # floating hands
    hy = y + 22 - hands * 6
    for hx in (5, 43):
        c.ellipse(hx, hy, 3, 3, "stone3")
        c.px(hx, hy, "stone2")
        c.px(hx - 2, hy - 3, "stone3"); c.px(hx, hy - 4, "stone3"); c.px(hx + 2, hy - 3, "stone3")
        if hands >= 2:
            c.ring(hx, hy, 5, eyes)
    c.outline("ink")
    if dead:
        for k in range(dead * 3):
            a = k * 2.399
            rr = 6 + (k * 5) % 16
            c.px(24 + math.cos(a) * rr, y + 20 + math.sin(a) * rr, "white" if k % 2 else "amber3")
    return c


ENRAGED = ("red0", "red1", "red2")


def boss_sheet():
    return {
        "idle": [ossifex(b, gear=g) for b, g in ((0, 0), (-1, 1), (-1, 2), (0, 3))],
        "cast": [ossifex(0, "amber3", 1, 0), ossifex(-1, "white", 2, 1), ossifex(-1, "white", 2, 2), ossifex(0, "amber3", 1, 3)],
        "slam": [ossifex(-2, "amber3", 2, 0), ossifex(1, "white", -1, 2), ossifex(2, "amber2", -1, 3)],
        "phase": [ossifex(0, "white", 2, g, ENRAGED if g % 2 else ("vio0", "vio1", "vio2")) for g in range(4)],
        "idle2": [ossifex(b, "red3", 0, g, ENRAGED) for b, g in ((0, 0), (-1, 2), (-1, 4), (0, 6))],
        "cast2": [ossifex(0, "white", 1, 0, ENRAGED), ossifex(-1, "white", 2, 2, ENRAGED),
                  ossifex(-1, "white", 2, 4, ENRAGED), ossifex(0, "white", 1, 6, ENRAGED)],
        "hurt": [ossifex(0, "red2", 0, 0)],
        "death": [ossifex(0, "white", 2, 0, dead=1), ossifex(1, "white", 2, 2, dead=2),
                  ossifex(2, "white", 1, 4, dead=3), ossifex(dead=4), ossifex(dead=5), ossifex(dead=6)],
    }


SHEETS = {
    "gloop": gloop_sheet, "sparkeye": sparkeye_sheet, "skitter": skitter_sheet,
    "golem": golem_sheet, "acolyte": acolyte_sheet, "ossifex": boss_sheet,
}

FPS = {"idle": 5, "idle2": 6, "move": 8, "attack": 10, "cast": 8, "cast2": 10, "slam": 8,
       "phase": 8, "hurt": 10, "death": 10}
LOOP = {"idle": True, "idle2": True, "move": True}


def preview_sets():
    return [f() for f in SHEETS.values()]
