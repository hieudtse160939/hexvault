"""Skitter - HD flanker (96 px frame). A clockwork beetle: brass carapace,
six thin legs, a glowing amber eye cluster; lunges low and fast."""
from __future__ import annotations

import math

from canvas import HDCanvas

FRAME = 96
CX, GROUND = 48, 72
PIVOT = (CX, GROUND)
SPEC = {"id": "skitter", "sprite": "enemy_skitter", "version": 1, "source": "procedural: tools/artgen/hd/enemies/skitter.py"}
FPS = {"idle": 6, "move": 14, "attack": 12, "hurt": 10, "death": 10}
LOOP = {"idle": True, "move": True}


def draw(phase: float = 0.0, lunge: float = 0.0, crouch: float = 0.0, hurt: bool = False, dead: int = 0) -> HDCanvas:
    c = HDCanvas(FRAME, FRAME)
    cx = CX + lunge * 6
    cy = GROUND - 17 + crouch * 4 + dead * 3
    # legs: three pairs, far side first (darker); alternate tripod gait
    for side, bias in ((-1, -1), (1, 0)):
        for i, ox in enumerate((-12, -2, 9)):
            ph = phase * math.tau + (i % 2) * math.pi + (0 if side > 0 else math.pi)
            lift = max(0.0, math.sin(ph)) * 4 * (1 - dead / 4)
            sx = cx + ox + math.cos(ph) * 3
            hip = (cx + ox * 0.6, cy - 2)
            knee = (sx + (ox * 0.45), cy - 11 - lift - side * 1.5)
            foot = (sx + ox * 0.35 + lunge * 2, GROUND - 1 - lift if not dead else cy + 4)
            m = c.capsule(hip[0], hip[1], knee[0], knee[1], 2.0, 1.6) | c.capsule(knee[0], knee[1], foot[0], foot[1], 1.6, 0.9)
            c.draw(m, "steel", "metal", bias=bias, name="leg")
    # body segments
    abdomen = c.ellipse(cx - 9, cy - 1, 13, 9.5)
    c.draw(abdomen, "amber", "metal", bias=-1, name="abdomen")
    for k in range(3):
        c.line(cx - 19 + k * 6, cy - 8 + k, cx - 15 + k * 6, cy + 7, "amber", 1)
    thorax = c.ellipse(cx + 6, cy - 2, 9, 7.5)
    c.draw(thorax, "amber", "metal", name="thorax")
    head = c.ellipse(cx + 15, cy - 1, 6.5, 5.5)
    c.draw(head, "slate", "metal", name="head")
    # mandibles
    for dy in (-2, 2):
        c.line(cx + 20, cy - 1 + dy, cx + 24 + lunge * 2, cy + dy * 1.6, "bone", 3)
    # eye cluster
    eye = "glow_red" if (hurt or lunge > 0.5) else "glow_amber"
    if dead < 2:
        for ex, ey in ((cx + 15, cy - 4), (cx + 18, cy - 3)):
            c.fixed(c.rect(int(ex), int(ey), int(ex) + 1, int(ey) + 1), eye)
    c.px(int(cx - 10), int(cy - 7), "amber", 5)
    if hurt:
        c.relight(c.opaque(), 1)
    c.outline("ink")
    c.despeckle()
    return c


def animations() -> dict:
    return {
        "idle": [draw(phase=0.0).image(), draw(phase=0.0, crouch=0.5).image()],
        "move": [draw(phase=t / 4).image() for t in range(4)],
        "attack": [draw(crouch=1.0).image(), draw(lunge=1.0, phase=0.25).image(), draw(lunge=0.6, phase=0.5).image()],
        "hurt": [draw(hurt=True, crouch=0.5).image()],
        "death": [draw(dead=d, phase=0.1 * d).image() for d in (1, 2, 3, 4)],
    }
