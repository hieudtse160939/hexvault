"""Ossifex, the Clockwork Lich - HD boss (192 px frame, pivot under the hem).

Faces the camera like a JRPG boss: a huge brass gear halo behind a crowned
skull, a floating bell-shaped robe with a tattered hem, an open ribcage with
a glowing gear core, spiked brass pauldrons and two floating skeletal hands.
Enraged animations (idle2 / cast2 / phase) swap the violet for crimson.
"""
from __future__ import annotations

import math

from canvas import HDCanvas

FRAME = 192
CX, HEM = 96, 178
PIVOT = (CX, HEM)
SPEC = {"id": "ossifex", "sprite": "enemy_ossifex", "version": 1, "source": "procedural: tools/artgen/hd/enemies/ossifex.py"}
FPS = {"idle": 6, "idle2": 8, "cast": 8, "cast2": 10, "slam": 8, "phase": 8, "hurt": 10, "death": 9}
LOOP = {"idle": True, "idle2": True}


def _gear(c: HDCanvas, cx: float, cy: float, r: float, teeth: int, rot: float, ramp: str, bias: int = 0):
    m = c.ellipse(cx, cy, r, r)
    for k in range(teeth):
        a = rot + k * math.tau / teeth
        m |= c.capsule(cx + math.cos(a) * r, cy + math.sin(a) * r, cx + math.cos(a) * (r + 6), cy + math.sin(a) * (r + 6), 3.2, 2.6)
    return m


def draw(bob: float = 0.0, gear: float = 0.0, hands: float = 0.0, eyes: str = "glow_amber", enraged: bool = False,
         flash: bool = False, slam: float = 0.0, dead: int = 0) -> HDCanvas:
    c = HDCanvas(FRAME, FRAME)
    robe = "crimson" if enraged else "violet"
    y = bob + slam * 4
    hx_, hy_ = CX, 58 + y              # skull centre
    # 1. gear halo
    halo = _gear(c, CX, hy_ - 4, 37, 14, gear * 0.22, "amber")
    halo &= ~c.ellipse(CX, hy_ - 4, 29, 29)
    c.draw(halo, "amber", "metal", bias=-1 if not enraged else -2, name="halo")
    for k in range(6):  # spokes
        a = gear * 0.22 + k * math.tau / 6
        c.draw(c.capsule(CX + math.cos(a) * 18, hy_ - 4 + math.sin(a) * 18, CX + math.cos(a) * 30, hy_ - 4 + math.sin(a) * 30, 2.2, 2.2),
               "amber", "metal", bias=-2, name="spoke")
    # 2. robe: bell from the shoulders to a tattered hem
    top, w0, w1 = 82 + y, 26, 62
    pts = [(CX - w0, top), (CX + w0, top)]
    n = 9
    for i in range(n + 1):
        t = i / n
        x = CX + w1 - t * 2 * w1
        dy = (6 if i % 2 else 0) + math.sin(gear * 0.5 + i) * 2
        pts.append((x, HEM - 6 + dy + y * 0.3))
    body = c.poly(pts)
    c.draw(body, robe, "cloth", name="robe")
    c.relight(body & c.ellipse(CX, HEM, 70, 20), -1)
    for side in (-1, 1):  # gold trim down the front edges
        c.line(CX + side * 10, top + 8, CX + side * 22, HEM - 4 + y * 0.3, "amber", 3)
    # 3. open ribcage with a glowing gear core
    cage = c.ellipse(CX, top + 26, 17, 22)
    c.draw(cage, "night", "soft", bias=-1, name="cavity", selout=False)
    for k in range(4):
        ry = top + 12 + k * 9
        for side in (-1, 1):
            c.draw(c.capsule(CX + side * 2, ry, CX + side * 14, ry + 4, 1.8, 1.4), "bone", "round", name="rib")
    c.draw(c.capsule(CX, top + 6, CX, top + 46, 2.0, 2.0), "bone", "round", name="spine")
    core = _gear(c, CX, top + 28, 6, 8, -gear * 0.4, "amber")
    c.draw(core, "amber", "glow", name="core", selout=False)
    c.fixed(c.ellipse(CX, top + 28, 2.4, 2.4), eyes)
    # 4. spiked brass pauldrons
    for side in (-1, 1):
        px_, py_ = CX + side * 30, top + 4
        c.draw(c.ellipse(px_, py_, 14, 9), "amber", "metal", bias=0 if side > 0 else -1, name="pauldron")
        for k in range(3):
            sx = px_ + side * (-6 + k * 6)
            c.draw(c.poly([(sx - 3, py_ - 6), (sx + 3, py_ - 6), (sx + side * 2, py_ - 16 + k * 2)]), "steel", "metal", name="spike")
    # 5. skull with jaw, glowing sockets, crown
    skull = c.ellipse(hx_, hy_, 20, 19)
    c.draw(skull, "bone", "round", name="skull")
    jaw = c.ellipse(hx_, hy_ + 18, 13, 7) & ~c.ellipse(hx_, hy_ + 12, 13, 6)
    c.draw(jaw, "bone", "round", bias=-1, name="jaw")
    for x in range(int(hx_) - 9, int(hx_) + 10, 3):
        c.line(x, hy_ + 14, x, hy_ + 18, "bone", 1)
    for side in (-1, 1):
        sock = c.ellipse(hx_ + side * 8, hy_ + 2, 6, 5.5)
        c.fill(sock, "night", 0, name="socket")
        if dead < 2:
            c.fixed(c.ellipse(hx_ + side * 8, hy_ + 2, 2.6, 2.4), "white" if flash else eyes)
    c.fill(c.poly([(hx_ - 2, hy_ + 9), (hx_ + 2, hy_ + 9), (hx_, hy_ + 5)]), "night", 0, name="nose")
    c.line(hx_ + 6, hy_ - 16, hx_ + 11, hy_ - 7, "bone", 1)          # crack
    crown = c.rect(int(hx_ - 17), int(hy_ - 20), int(hx_ + 17), int(hy_ - 14))
    for k in range(5):
        cx2 = hx_ - 16 + k * 8
        crown |= c.poly([(cx2 - 3.5, hy_ - 19), (cx2 + 3.5, hy_ - 19), (cx2, hy_ - 29 - (k == 2) * 5)])
    c.draw(crown & ~c.ellipse(hx_, hy_ + 4, 18, 18) | (crown & c.rect(0, 0, FRAME, int(hy_ - 13))), "amber", "metal", name="crown")
    c.fixed(c.ellipse(hx_, hy_ - 17, 2.2, 2.2), "glow_red" if enraged else "glow_teal")
    # 6. floating skeletal hands with spell orbs
    for side in (-1, 1):
        hx2 = CX + side * (58 + hands * 6)
        hy2 = 118 + y - hands * 26 + slam * 30
        palm = c.ellipse(hx2, hy2, 7, 6)
        for k in range(4):
            fx = hx2 - 6 + k * 4
            palm |= c.capsule(fx, hy2 - 3, fx + side * 1.5, hy2 - 12 - (k in (1, 2)) * 2, 1.6, 1.2)
        c.draw(palm, "bone", "round", bias=0 if side > 0 else -1, name="hand")
        if hands > 0.5:
            orb = c.ellipse(hx2, hy2 - 20, 6 + hands * 2, 6 + hands * 2)
            c.draw(orb, robe, "glow", name="orb", selout=False)
            c.fixed(c.ellipse(hx2 - 1.5, hy2 - 21.5, 2.2, 2.2), "white" if flash else eyes)
    if flash:
        c.relight(c.opaque(), 1)
    c.outline("ink")
    c.despeckle()
    return c


def ruin(t: int) -> HDCanvas:
    """Death: robe collapses into a heap, the halo falls, bones scatter."""
    c = HDCanvas(FRAME, FRAME)
    heap = c.ellipse(CX, HEM - 8, 60 - t * 4, 14 - t)
    c.draw(heap, "violet", "cloth", bias=-1, name="heap")
    for k in range(7):
        a = k * 2.4
        bx, by = CX + math.cos(a) * (20 + k * 5), HEM - 12 + math.sin(a) * 6
        c.draw(c.capsule(bx - 5, by, bx + 5, by - 2, 2.0, 1.6), "bone", "round", name="bone")
    c.draw(c.ellipse(CX + 20, HEM - 22, 16, 15), "bone", "round", name="skull")
    for side in (-1, 1):
        c.fill(c.ellipse(CX + 20 + side * 6, HEM - 20, 4.5, 4), "night", 0)
    g = _gear(c, CX - 34, HEM - 16, 14, 10, t * 0.3, "amber")
    c.draw(g & ~c.ellipse(CX - 34, HEM - 16, 8, 8), "amber", "metal", bias=-2, name="halo_piece")
    if t < 2:
        c.fixed(c.ellipse(CX, HEM - 30, 3, 3), "glow_amber")
    c.outline("ink")
    return c


def animations() -> dict:
    return {
        "idle": [draw(bob=b, gear=g).image() for b, g in ((0, 0), (-2, 1), (-3, 2), (-1, 3))],
        "cast": [draw(0, 0, 0.6).image(), draw(-2, 1, 1.0, flash=True).image(), draw(-2, 2, 1.0).image(), draw(0, 3, 0.6).image()],
        "slam": [draw(-3, 0, 1.0).image(), draw(2, 2, 0.0, slam=1.0, flash=True).image(), draw(3, 3, 0.0, slam=0.6).image()],
        "phase": [draw(0, g, 1.0, eyes="white", enraged=bool(g % 2), flash=bool(g % 2)).image() for g in range(4)],
        "idle2": [draw(bob=b, gear=g, eyes="glow_red", enraged=True).image() for b, g in ((0, 0), (-2, 2), (-3, 4), (-1, 6))],
        "cast2": [draw(0, 0, 0.6, "glow_red", True).image(), draw(-2, 2, 1.0, "glow_red", True, True).image(),
                  draw(-2, 4, 1.0, "glow_red", True).image(), draw(0, 6, 0.6, "glow_red", True).image()],
        "hurt": [draw(1, 0, 0.0, "glow_red", flash=True).image()],
        "death": [draw(0, 0, 1.0, "white", flash=True).image(), draw(4, 2, 0.4, dead=1).image()] + [ruin(t).image() for t in range(4)],
    }
