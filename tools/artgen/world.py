"""Dungeon tiles and props."""
from __future__ import annotations

import math
import random

from px import Canvas

T = 16


def _floor(seed: int, base="floor1", hi="floor2", lo="floor0", rune: str | None = None, crack=False) -> Canvas:
    rnd = random.Random(seed)
    c = Canvas(T, T)
    c.rect(0, 0, 15, 15, base)
    # flagstone seams: two slabs per tile, offset by seed
    split = 7 + rnd.randint(-1, 1)
    c.hline(0, 15, 15, lo); c.vline(15, 0, 15, lo)
    c.hline(0, 15, split, lo)
    c.vline(rnd.randint(4, 11), 0, split - 1, lo)
    c.vline(rnd.randint(3, 12), split + 1, 14, lo)
    c.hline(0, 14, 0, hi); c.hline(0, 14, split + 1, hi)
    for _ in range(4):
        c.px(rnd.randint(1, 14), rnd.randint(1, 14), hi if rnd.random() < 0.5 else lo)
    if crack:
        x, y = rnd.randint(3, 6), rnd.randint(2, 5)
        for _ in range(6):
            c.px(x, y, lo); x += rnd.choice((0, 1)); y += 1
    if rune:
        c.ring(7.5, 7.5, 5, rune)
        c.px(7, 3, rune); c.px(8, 12, rune); c.px(3, 8, rune); c.px(12, 7, rune)
    return c


def _wall_top() -> Canvas:
    c = Canvas(T, T)
    c.rect(0, 0, 15, 15, "night")
    c.rect(1, 1, 14, 14, "dusk")
    c.hline(1, 14, 1, "stone0")
    c.px(4, 5, "night"); c.px(10, 9, "night"); c.px(7, 12, "night")
    return c


def _wall_face(seed: int, deco: str | None = None) -> Canvas:
    rnd = random.Random(seed)
    c = Canvas(T, T)
    c.rect(0, 0, 15, 15, "stone0")
    c.rect(0, 0, 15, 2, "dusk")               # wall cap
    c.hline(0, 15, 3, "stone1")
    for row, y in enumerate((4, 8, 12)):
        off = 0 if row % 2 == 0 else 4
        c.hline(0, 15, y + 3, "night")
        for x in range(off, 16, 8):
            c.vline(x, y, y + 2, "night")
        for x in range(off + 1, 16, 8):
            c.hline(x, min(x + 6, 15), y, "stone1")
    for _ in range(3):
        c.px(rnd.randint(1, 14), rnd.randint(5, 14), "stone2")
    c.hline(0, 15, 15, "ink")
    if deco == "lamp":
        c.rect(6, 6, 9, 10, "amber0"); c.rect(7, 7, 8, 9, "teal2"); c.px(7, 7, "teal3")
    if deco == "banner":
        c.rect(5, 3, 10, 12, "red1"); c.vline(5, 3, 12, "red0"); c.poly([(5, 12), (10, 12), (7.5, 15)], "red1")
        c.px(7, 7, "amber2"); c.px(8, 7, "amber2"); c.px(7, 8, "amber2"); c.px(8, 8, "amber2")
    return c


def tileset() -> list[Canvas]:
    """Atlas order is the contract with scripts/world/tiles.gd (TILE_* constants)."""
    return [
        _floor(1), _floor(2), _floor(3), _floor(4),                     # 0-3 floor
        _floor(5, crack=True), _floor(6, rune="teal0"),                  # 4 cracked, 5 rune
        _floor(7, "floor0", "floor1", "shadow"),                         # 6 corridor
        _floor(8, "floor0", "floor1", "shadow", crack=True),             # 7 corridor cracked
        _wall_top(),                                                     # 8 wall top
        _wall_face(1), _wall_face(2), _wall_face(3, "lamp"), _wall_face(4, "banner"),  # 9-12
        _floor(9, "floor2", "floor3", "floor1"),                          # 13 hub floor
        _floor(10, "floor2", "floor3", "floor1", rune="amber0"),          # 14 hub rune
        _floor(11, "floor1", "floor2", "floor0", rune="vio0"),            # 15 boss rune
    ]


# --- props -------------------------------------------------------------------
def crate(broken: int = 0) -> Canvas:
    c = Canvas(T, T)
    if broken:
        for (x, y, w) in ((2, 12, 4), (8, 13, 5), (5, 10, 3)):
            c.rect(x, y, x + w, y + 1, "amber0" if broken % 2 else "amber1")
        c.outline("ink")
        return c
    c.rect(2, 3, 13, 14, "amber1")
    c.rect(2, 3, 13, 4, "amber2")
    c.rect(2, 3, 3, 14, "amber0"); c.rect(12, 3, 13, 14, "amber0")
    c.line(4, 6, 11, 13, "amber0"); c.line(4, 13, 11, 6, "amber0")
    c.hline(2, 13, 14, "amber0")
    c.outline("ink")
    return c


def barrel(glow: int = 0) -> Canvas:
    c = Canvas(T, T)
    c.ellipse(7.5, 9, 5, 5.5, "red1")
    c.rect(3, 6, 12, 13, "red1")
    c.vline(3, 6, 13, "red0"); c.vline(11, 6, 13, "red2")
    c.hline(3, 12, 7, "stone1"); c.hline(3, 12, 12, "stone1")
    c.ellipse(7.5, 5, 4.5, 1.5, "red2")
    c.rect(6, 9, 9, 10, "amber3" if glow else "amber2")
    c.outline("ink")
    return c


def pillar() -> Canvas:
    c = Canvas(16, 32)
    c.rect(3, 4, 12, 27, "stone1")
    c.rect(3, 4, 4, 27, "stone0"); c.rect(10, 4, 12, 27, "stone2")
    c.rect(1, 1, 14, 4, "stone2"); c.hline(1, 14, 1, "stone3")
    c.rect(1, 27, 14, 30, "stone0")
    for y in (9, 15, 21):
        c.hline(5, 9, y, "stone0")
    c.rect(6, 12, 9, 14, "teal1"); c.px(7, 12, "teal3")
    c.outline("ink")
    return c


def lamp(f: int) -> Canvas:
    c = Canvas(T, T)
    c.rect(6, 9, 9, 14, "stone0"); c.hline(5, 10, 14, "stone1")
    r = 2 + (f % 2) * 0.5
    c.ellipse(7.5, 6, r + 1, r + 2, "teal1")
    c.ellipse(7.5, 6, r, r + 1, "teal2")
    c.px(7, 5 - f % 2, "teal3"); c.px(8, 6, "white")
    c.outline("ink")
    return c


def chest(open_: int = 0) -> Canvas:
    c = Canvas(T, T)
    c.rect(2, 8, 13, 14, "amber0")
    c.rect(3, 9, 12, 13, "amber1")
    c.hline(2, 13, 11, "amber2")
    if open_ == 0:
        c.rect(2, 4, 13, 8, "amber1"); c.hline(2, 13, 4, "amber2")
        c.rect(7, 7, 8, 9, "teal2")
    else:
        lift = min(open_, 2) * 2
        c.rect(2, 4 - lift, 13, 6 - lift, "amber0"); c.hline(2, 13, 4 - lift, "amber1")
        c.rect(3, 8, 12, 8, "night")
        if open_ >= 2:
            c.px(6, 7, "teal3"); c.px(9, 6, "amber3"); c.px(8, 7, "white")
    c.outline("ink")
    return c


def portal(f: int) -> Canvas:
    c = Canvas(32, 32)
    c.ellipse(15.5, 17, 11, 13, "vio0")
    c.ellipse(15.5, 17, 9, 11, "vio1")
    for k in range(10):
        a = k * math.pi / 5 + f * 0.35
        r = 3 + (k % 3) * 2.5
        c.px(15.5 + math.cos(a) * r, 17 + math.sin(a) * r * 1.2, "vio3" if k % 2 else "teal2")
    c.ellipse(15.5, 17, 3, 4, "vio2")
    c.px(15, 16, "white")
    c.rect(4, 28, 27, 30, "stone1"); c.hline(4, 27, 28, "stone2")
    c.outline("ink")
    return c


def pedestal() -> Canvas:
    c = Canvas(T, T)
    c.rect(3, 9, 12, 14, "stone1"); c.rect(3, 9, 12, 9, "stone3"); c.rect(3, 10, 3, 14, "stone0")
    c.rect(5, 14, 10, 15, "stone0")
    c.outline("ink")
    return c


def fountain(f: int) -> Canvas:
    c = Canvas(T, T)
    c.ellipse(7.5, 11, 7, 4, "stone1")
    c.ellipse(7.5, 10.5, 5.5, 2.5, "red1")
    c.ellipse(7.5, 10, 4, 1.5, "red2")
    c.vline(7, 3, 9, "stone2"); c.vline(8, 3, 9, "stone1")
    for k in range(3):
        y = 2 + (f + k) % 4 * 2
        c.px(5 + k * 2, y, "red3")
    c.outline("ink")
    return c


def statue() -> Canvas:
    c = Canvas(16, 32)
    c.rect(2, 26, 13, 30, "stone0"); c.hline(2, 13, 26, "stone2")
    c.poly([(8, 8), (3, 26), (13, 26)], "stone1")
    c.poly([(8, 8), (3, 26), (6, 26)], "stone0")
    c.ellipse(7.5, 6, 3.5, 3.5, "stone2"); c.px(9, 6, "amber2")
    c.vline(12, 4, 22, "stone2"); c.ellipse(12, 3, 1.5, 1.5, "amber2")
    c.outline("ink")
    return c


def spawn_rune(f: int) -> Canvas:
    c = Canvas(T, T)
    r = 3 + f * 1.3
    c.ring(7.5, 7.5, r, "red2" if f % 2 else "red1")
    c.ring(7.5, 7.5, max(1, r - 3), "red3")
    return c


def barrier(f: int) -> Canvas:
    """Locked-door energy field (one tile)."""
    c = Canvas(T, T)
    for x in range(T):
        y0 = int(7 + 3 * math.sin((x + f * 4) * 0.8))
        c.vline(x, 0, 15, "vio0")
        c.px(x, y0, "vio3"); c.px(x, (y0 + 8) % 16, "vio2")
    c.hline(0, 15, 0, "vio2"); c.hline(0, 15, 15, "vio2")
    return c


def shadow(w: int) -> Canvas:
    c = Canvas(w, 6)
    c.ellipse(w / 2 - 0.5, 2.5, w / 2 - 1, 2, "shadow")
    return c


def props() -> dict:
    """name -> (anims dict, fps)"""
    return {
        "crate": ({"idle": [crate()], "break": [crate(1), crate(2)]}, 8),
        "barrel": ({"idle": [barrel(0), barrel(1)]}, 3),
        "pillar": ({"idle": [pillar()]}, 1),
        "lamp": ({"idle": [lamp(i) for i in range(4)]}, 6),
        "chest": ({"closed": [chest(0)], "open": [chest(1), chest(2), chest(3)]}, 8),
        "portal": ({"idle": [portal(i) for i in range(6)]}, 10),
        "pedestal": ({"idle": [pedestal()]}, 1),
        "fountain": ({"idle": [fountain(i) for i in range(4)]}, 6),
        "statue": ({"idle": [statue()]}, 1),
        "spawn_rune": ({"idle": [spawn_rune(i) for i in range(4)]}, 8),
        "barrier": ({"idle": [barrier(i) for i in range(4)]}, 10),
        "shadow_s": ({"idle": [shadow(12)]}, 1),
        "shadow_m": ({"idle": [shadow(20)]}, 1),
        "shadow_l": ({"idle": [shadow(36)]}, 1),
    }


def preview_sets():
    return [{"tiles": tileset()}] + [a for a, _ in props().values() if next(iter(a.values()))[0].w == 16 and next(iter(a.values()))[0].h == 16]
