"""Shared HD hero painter: a Look (parts + ramps) drawn on the rig.

Every hero shares the rig anatomy, light, outline and animation timing of the
reference hero (ranger.py), but gets its own silhouette from the Look:
head gear, hair, body garment, cape, shoulder pieces, back gear and two hooks
(extra_back / extra_front) for unique props. Coordinates in hooks are base
units (scaled by K through R()/at()/bp()/hp()).

Usage in a hero module:
    LOOK = Look(...); PR = proportions(k=1.3)
    def animations(): return kit.animations(LOOK, PR)
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Callable

from canvas import HDCanvas
from canvas import shift as shift_mask
from rig import Pose, Proportions, body_point as bp, head_point as hp, idle_cycle, run_cycle, solve

FRAME = 128


def proportions(k: float = 1.3, **kw) -> Proportions:
    # anime RPG chibi: ~2.5 heads tall, big head, short limbs
    base = dict(k=k, frame=FRAME, cx=64, ground=112, pelvis_y=60.0, torso=14.5, head_r=13.5, head_off=(2.0, -11.5),
                thigh=8.6, shin=8.2, upper_arm=7.2, forearm=6.6, hip_w=3.0, shoulder_w=3.2)
    base.update(kw)
    return Proportions(**base)


@dataclass
class Look:
    skin: str = "skin_fair"
    hair: str = "hair_brown"
    eyes: str = "glow_teal"           # FIXED glow colour used when eye_glow
    iris: str = "azure"               # iris ramp (anime eyes)
    eye_glow: bool = False
    # garments
    torso: str = "teal"               # main body colour
    torso_form: str = "cloth"         # cloth | plate (armour) | metal
    trim: str = "amber"               # accent ramp (belts, piping, emblems)
    sleeve: str | None = None         # defaults to torso
    glove: str = "leather"
    pants: str = "slate"
    boot: str = "leather"
    belt: str = "leather"
    # silhouette options
    head: str = "hair"                # hair | hood | helm | hat | cowl | crown | mask
    hair_style: str = "short"         # short | spiky | long | ponytail | none
    body: str = "tunic"               # tunic | coat | robe | armor
    width: float = 1.0                # torso width multiplier
    cape: str | None = None           # ramp of a back cape
    pauldrons: str | None = None      # ramp of shoulder plates
    collar: str | None = None         # ramp of a fur / cloth collar
    tabard: str | None = None         # ramp of a front tabard over the torso
    gauntlet: str | None = None       # ramp of armoured forearms
    head_ramp: str | None = None      # hood / helm / hat ramp (defaults to torso)
    extra_back: Callable | None = None
    extra_front: Callable | None = None
    extra_head: Callable | None = None
    glow: str = "glow_amber"          # skill spark colour
    params: dict = field(default_factory=dict)


class Ctx:
    """What hooks receive: canvas, skeleton, pose, look and scale helpers."""

    def __init__(self, c: HDCanvas, sk, p: Pose, look: Look, k: float, head_r: float = 13.5):
        self.c, self.sk, self.p, self.look, self.k = c, sk, p, look, k
        self.hr = head_r * k

    def R(self, v: float) -> float:
        return v * self.k

    def at(self, pt, dx: float, dy: float):
        return (pt[0] + dx * self.k, pt[1] + dy * self.k)

    def bp(self, u: float, s: float):
        return bp(self.sk, u, s)

    def hp(self, dx: float, dy: float):
        return hp(self.sk, dx, dy)


def _along(a, b, t: float):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


# --- limbs -------------------------------------------------------------------------
def arm(x: Ctx, sh, el, hd, bias: int, front: bool) -> None:
    c, L, R = x.c, x.look, x.R
    sleeve = L.sleeve or L.torso
    w = 1.0 + (0.15 if L.body == "armor" else 0.0)
    a = c.capsule(sh[0], sh[1], el[0], el[1], R(3.3 * w), R(3.0 * w)) | c.capsule(el[0], el[1], hd[0], hd[1], R(3.0 * w), R(2.8 * w))
    c.draw(a, sleeve, L.torso_form if L.body == "armor" else "cloth", bias=bias + (1 if front else 0), name="sleeve")
    if L.gauntlet:
        g0 = _along(el, hd, 0.25)
        c.draw(c.capsule(g0[0], g0[1], hd[0], hd[1], R(3.4), R(3.1)), L.gauntlet, "metal", bias=bias, name="gauntlet")
    else:
        cf = _along(el, hd, 0.7)
        c.draw(c.capsule(cf[0], cf[1], hd[0], hd[1], R(3.1), R(2.9)) & a, L.trim, "flat", bias=bias - 1, name="cuff")
    g = x.at(hd, 0.4, 1.2)
    c.draw(c.ellipse(g[0], g[1], R(2.9), R(2.7)), L.glove, "round", bias=bias + 1, name="hand")


def leg(x: Ctx, hip, knee, foot, bias: int) -> None:
    c, L, R = x.c, x.look, x.R
    c.draw(c.capsule(hip[0], hip[1], knee[0], knee[1], R(3.4), R(3.0)), L.pants, "cloth", bias=bias, name="thigh")
    c.draw(c.capsule(knee[0], knee[1], foot[0], foot[1], R(3.0), R(2.6)), L.pants, "cloth", bias=bias, name="shin")
    s = _along(knee, foot, 0.45)
    c.draw(c.capsule(s[0], s[1], foot[0], foot[1], R(3.2), R(3.0)), L.boot, "round", bias=bias, name="boot_shaft")
    b = x.at(foot, 1.6, 1.0)
    c.draw(c.ellipse(b[0], b[1], R(4.3), R(2.5)), L.boot, "round", bias=bias, name="boot")
    so = x.at(foot, -2.4, 3.2)
    c.line(so[0], so[1], so[0] + R(7.6), so[1], "hair_ink", 1 if bias > -1 else 0)


# --- body ----------------------------------------------------------------------------
def torso(x: Ctx) -> None:
    c, L, sk, w = x.c, x.look, x.sk, x.look.width
    flare = 2.0 + max(x.p.sway, 0) * 1.5
    shape = [bp(sk, 16.0, -6.5 * w), bp(sk, 16.5, 5.5 * w), bp(sk, 2.0, 6.5 * w), bp(sk, -1.0, 6.0 * w),
             bp(sk, -1.0, -6.5 * w), bp(sk, 3.0, -7.5 * w)]
    body_mask = c.poly(shape)
    if L.body == "robe":
        # robe falls to the ankles and flares; legs only peek out at the hem
        skirt = [bp(sk, 2.0, -7.0 * w), bp(sk, 2.0, 6.5 * w), bp(sk, -15.0, 9.0 * w + flare * 0.3),
                 bp(sk, -16.5, 0.0), bp(sk, -15.5, -9.5 * w - flare * 0.6)]
        c.draw(c.poly(skirt), L.torso, "cloth", name="robe")
        h0, h1 = bp(sk, -15.0, 8.5 * w), bp(sk, -15.5, -9.0 * w)
        c.draw(c.capsule(h0[0], h0[1], h1[0], h1[1], x.R(1.2), x.R(1.2)), L.trim, "flat", name="hem")
    elif L.body in ("coat", "armor"):
        ln = 10.5 if L.body == "coat" else 7.0
        skirt = [bp(sk, 0.0, -6.5 * w), bp(sk, 0.0, 6.2 * w), bp(sk, -ln + 0.5, 7.5 * w + flare * 0.3), bp(sk, -ln, 2.5),
                 bp(sk, -ln + 0.5, -7.5 * w - flare * 0.4)]
        c.draw(c.poly(skirt), L.torso, L.torso_form if L.body == "armor" else "cloth", name="skirt")
        if L.body == "armor":  # tassets split
            s0, s1 = bp(sk, -1.0, 1.0), bp(sk, -ln + 0.5, 1.5)
            c.line(s0[0], s0[1], s1[0], s1[1], L.torso, 1)
    c.draw(body_mask, L.torso, L.torso_form, name="torso")
    if L.body == "armor":
        # breastplate ridge + rivets
        r0, r1 = bp(sk, 15.0, 3.0 * w), bp(sk, 3.0, 4.0 * w)
        c.line(r0[0], r0[1], r1[0], r1[1], L.torso, 4)
        for u in (12.0, 8.0):
            rx, ry = bp(sk, u, 5.0 * w)
            c.px(int(rx), int(ry), L.trim, 4)
    if L.tabard:
        tab = [bp(sk, 14.5, 0.5 * w), bp(sk, 14.5, 6.0 * w), bp(sk, -9.0, 6.6 * w), bp(sk, -11.5, 2.8 * w), bp(sk, -9.0, -0.8 * w)]
        tm = c.poly(tab)
        c.draw(tm, L.tabard, "cloth", name="tabard", light_mask=body_mask | tm)
        e0, e1 = bp(sk, 14.5, 0.5 * w), bp(sk, -9.0, -0.8 * w)
        c.line(e0[0], e0[1], e1[0], e1[1], L.trim, 3)
    belt = [bp(sk, 2.6, -6.8 * w), bp(sk, 2.6, 6.6 * w), bp(sk, -1.0, 6.8 * w), bp(sk, -1.0, -7.0 * w)]
    c.draw(c.poly(belt), L.belt, "plate", name="belt")
    bx, by = bp(sk, 0.8, 4.2 * w)
    c.draw(c.ellipse(bx, by, x.R(1.6), x.R(1.5)), L.trim, "metal", name="buckle")
    if L.collar:
        col = c.ellipse(*hp(sk, -0.5, 9.2), x.R(8.6 * w), x.R(3.6), rot=sk.angle)
        c.draw(col, L.collar, "round", name="collar")
        for i in range(5):  # fur tufts
            fx_, fy_ = hp(sk, -6.5 + i * 3.0, 11.8)
            c.px(int(fx_), int(fy_), L.collar, 2)


def pauldrons(x: Ctx, near: bool) -> None:
    L = x.look
    if not L.pauldrons:
        return
    sh = x.sk.sh_near if near else x.sk.sh_far
    p = x.at(sh, -0.5 if near else 1.0, -0.8)
    x.c.draw(x.c.ellipse(p[0], p[1], x.R(6.2), x.R(4.6)), L.pauldrons, "metal", bias=0 if near else -1, name="pauldron")
    x.c.draw(x.c.ellipse(p[0], p[1] + x.R(3.2), x.R(6.0), x.R(1.5)), L.trim, "metal", bias=-1 if near else -2,
             name="pauldron_rim")


def cape(x: Ctx) -> None:
    L, sk = x.look, x.sk
    if not L.cape:
        return
    wind = float(x.p.extras.get("wind", 0.0))
    sw = x.p.sway
    tail = -8.0 - wind * 6.0
    pts = [bp(sk, 16.0, -4.0), bp(sk, 16.0, 2.0), bp(sk, 2.0, -6.0 + wind * 2.0),
           bp(sk, -17.0 + wind * 4.0, tail + sw * 1.5), bp(sk, -19.0 + wind * 5.0, tail - 4.0 - wind * 3.0 + sw),
           bp(sk, 4.0, -10.0 - wind * 2.0)]
    x.c.draw(x.c.poly(pts), L.cape, "cloth", bias=-1, name="cape")


# --- head ----------------------------------------------------------------------------
def eye(c: HDCanvas, cx: float, cy: float, w: float, h: float, iris: str, glow: str | None, blink: bool,
        near: bool, k: float) -> None:
    """One anime eye: lash line, two-tone iris, pupil, catch-lights."""
    x0, x1 = int(round(cx - w / 2)), int(round(cx + w / 2))
    y0, y1 = int(round(cy - h / 2)), int(round(cy + h / 2))
    if blink:
        c.line(x0 - 1, cy + 1, x1, cy + 1, "hair_ink", 0)
        return
    if glow:
        c.fixed(c.rect(x0, y0 + 1, x1, y1), glow)
        c.line(x0 - 1, y0, x1 + (1 if near else 0), y0, "hair_ink", 0)
        return
    white = c.rect(x0, y0 + 1, x1, y1)
    c.fill(white, "bone", 5, name="eye_white")
    irx0 = x0 + (1 if near else 0)
    iris_m = c.rect(irx0, y0 + 1, x1, y1)
    c.fill(iris_m, iris, 2, name="iris")
    c.fill(c.rect(irx0, y0 + 1, x1, y0 + 1 + max(1, (y1 - y0) // 3)), iris, 1, name="iris_top")
    c.fill(c.rect(irx0, y1, x1, y1), iris, 4, name="iris_low")
    pc = (irx0 + x1) // 2
    c.fill(c.rect(pc, y0 + 2, pc + (1 if w > 3 * k else 0), y1 - 1), iris, 0, name="pupil")
    c.px(irx0, y0 + 1, "white")
    if w > 3 * k:
        c.px(irx0 + 1, y0 + 1, "white")
    c.px(x1, y1 - 1, iris, 5)
    # upper lash line, thicker and swept at the outer corner
    c.line(x0 - 1, y0, x1 + (1 if near else 0), y0, "hair_ink", 0)
    if near:
        c.px(x1 + 1, y0 + 1, "hair_ink", 0)
        c.line(x0, y0 - 1, x1, y0 - 1, "hair_ink", 1)
    else:
        c.px(x0 - 1, y0 + 1, "hair_ink", 0)


def _face_features(x: Ctx, face_mask) -> None:
    """Anime 3/4 face: two eyes, brows, nose tip, mouth, blush."""
    c, L, p, R, k = x.c, x.look, x.p, x.R, x.k
    hurt = bool(p.extras.get("hurt", False)) or p.blink and p.lean < -1
    glow = L.eyes if L.eye_glow else None
    near = x.hp(7.0, 2.4)
    far = x.hp(0.6, 2.2)
    eye(c, near[0], near[1], R(3.4), R(4.8), L.iris, glow, p.blink, True, k)
    eye(c, far[0], far[1], R(2.4), R(4.4), L.iris, glow, p.blink, False, k)
    if L.params.get("brows", True):
        for (ex, ey), w in ((near, 3.2), (far, 2.2)):
            yb = ey - R(4.4) - (R(0.6) if hurt else 0)
            c.line(ex - R(w / 2), yb + (1 if hurt else 0), ex + R(w / 2), yb, L.hair, 0)
    nx, ny = x.hp(4.4, 5.6)
    c.px(int(nx), int(ny), L.skin, 2)
    mx, my = x.hp(4.4, 8.0)
    if hurt:
        c.fill(c.rect(int(mx) - 1, int(my) - 1, int(mx) + 1, int(my)), "crimson", 0, name="mouth_open")
    else:
        c.line(mx - R(0.8), my, mx + R(0.8), my, "crimson", 1)
    for bx, by in (x.hp(8.6, 6.4), x.hp(-0.6, 6.0)):
        c.line(bx - R(0.6), by, bx + R(0.6), by, "rose", 4)


def _hair_top(x: Ctx, clip=None) -> None:
    """Volume, bangs over the forehead, a side lock and the shine ring."""
    c, L, p, R, sk = x.c, x.look, x.p, x.R, x.sk
    sw = p.sway
    h = sk.head
    hr = x.hr
    crown = c.ellipse(*x.hp(-1.4, -2.6), hr + R(1.0), hr - R(1.2), rot=sk.angle)
    crown &= ~c.ellipse(*x.hp(4.4, 6.4), R(9.6), R(8.6), rot=sk.angle)
    if L.hair_style == "spiky":
        for i, (bx, by, tx, ty) in enumerate(((-9, -4, -17, -9), (-5, -9, -10, -19), (0, -11, 1, -21), (5, -9, 10, -17), (-11, 2, -18, 1))):
            a0, a1 = x.hp(bx, by), x.hp(tx - sw * (i % 2), ty)
            crown |= c.capsule(a0[0], a0[1], a1[0], a1[1], R(3.4), R(0.6))
    # bangs: pointed locks falling to just above the eyes
    locks = [(-3.5, -1.0), (0.5, 0.6), (4.0, -0.4), (7.5, 0.9), (10.6, -0.2)]
    for i, (lx, ly) in enumerate(locks):
        top_l, top_r = x.hp(lx - 3.0, -8.0), x.hp(lx + 2.6, -8.0)
        tip = x.hp(lx + 0.6 + sw * 0.3 * (i % 2), ly)
        crown |= c.poly([top_l, top_r, tip])
    # side lock in front of the ear, framing the face
    s0, s1 = x.hp(11.2, -4.0), x.hp(12.2 + sw * 0.6, 8.5)
    crown |= c.capsule(s0[0], s0[1], s1[0], s1[1], R(2.2), R(0.8))
    if clip is not None:
        crown &= clip
    c.draw(crown, L.hair, "round", name="hair")
    # shine ring: a broken arc of the brightest shade
    for t in range(-6, 5):
        if t in (-2, 2):
            continue
        a = t / 6.0
        px_, py_ = x.hp(-1.0 + a * 8.5, -7.6 + (a * a) * 2.2)
        if crown[int(py_), int(px_)]:
            c.px(int(px_), int(py_), L.hair, 5)
    if L.params.get("hair_band"):
        band = c.ellipse(*x.hp(-0.5, -6.0), hr + R(0.6), R(1.5), rot=sk.angle) & crown
        c.draw(band, L.params["hair_band"], "metal", name="hair_band")


def head(x: Ctx) -> None:
    c, L, sk, p, R = x.c, x.look, x.sk, x.p, x.R
    h = sk.head
    hr = x.hr
    sw = p.sway
    gear = L.head_ramp or L.torso
    skull = c.ellipse(h[0], h[1], hr, hr - R(0.4), rot=sk.angle)
    face_mask = c.ellipse(*x.hp(3.6, 3.0), R(10.2), R(9.8), rot=sk.angle) & skull
    # long hair / ponytail behind the head
    if L.hair_style in ("long", "ponytail"):
        if L.hair_style == "long":
            back = [x.hp(-6.0, -6.0), x.hp(-14.0 - sw, 4.0), x.hp(-12.0 - sw * 1.5, 20.0), x.hp(-2.0, 18.0), x.hp(4.0, 6.0)]
            c.draw(c.poly(back), L.hair, "cloth", bias=-1, name="hair_back")
        else:
            wind = float(p.extras.get("wind", 0.0))
            tie = x.hp(-10.5, -6.0)
            end = x.hp(-21.0 - wind * 4.0, 4.0 - wind * 5.0 + sw * 2.0)
            mid = x.hp(-17.0 - wind * 2.0, -4.0 + sw)
            c.draw(c.capsule(tie[0], tie[1], mid[0], mid[1], R(3.4), R(2.8)) | c.capsule(mid[0], mid[1], end[0], end[1], R(2.8), R(1.0)),
                   L.hair, "cloth", name="ponytail")
            c.draw(c.ellipse(tie[0], tie[1], R(2.0), R(2.0)), L.trim, "round", name="hair_tie")
    if L.head in ("hood", "cowl", "helm"):
        shell = c.ellipse(h[0] - R(0.6), h[1] - R(0.4), hr + R(1.6), hr + R(1.0), rot=sk.angle)
        if L.head == "hood":
            tip = [x.hp(-8.0, -9.0), x.hp(-23.0 - sw * 1.5, -2.0 + sw), x.hp(-8.0, 5.0)]
            if L.params.get("tall_hood"):
                tip = [x.hp(-7.0, -7.0), x.hp(-9.0 - sw, -21.0), x.hp(-17.0 - sw * 1.5, -24.0), x.hp(-14.0 - sw, -17.0), x.hp(2.0, -11.0)]
            shell |= c.poly(tip)
        form = "metal" if L.head == "helm" else "cloth"
        c.draw(shell, gear, form, name=L.head)
        opening = c.ellipse(*x.hp(5.0, 3.4), R(9.0), R(9.4), rot=sk.angle) & shell
        c.draw(opening, L.skin, "skin", bias=int(L.params.get("face_bias", 0)), name="face", selout=True)
        rim = c.ellipse(*x.hp(5.0, 3.4), R(10.4), R(10.8), rot=sk.angle) & shell & ~opening
        c.relight(rim, +1)
        if L.hair_style != "none":
            _hair_top(x, clip=opening & ~c.ellipse(*x.hp(5.0, 6.8), R(9.0), R(7.4), rot=sk.angle))
        _face_features(x, opening)
        if L.head == "helm":
            cheek = c.ellipse(*x.hp(-3.5, 6.0), R(3.6), R(5.6), rot=sk.angle) & shell
            c.draw(cheek | (c.ellipse(*x.hp(-3.5, 6.0), R(3.6), R(5.6), rot=sk.angle) & skull), gear, "metal", bias=-1, name="cheek_guard")
    else:
        c.draw(skull, L.skin, "skin", name="head")
        ex_, ey_ = x.hp(-4.5, 3.0)
        c.draw(c.ellipse(ex_, ey_, R(1.8), R(2.4), rot=sk.angle), L.skin, "skin", bias=-1, name="ear")
        _face_features(x, face_mask)
        if L.hair_style != "none":
            _hair_top(x)
    if L.head == "hat":
        pass
    if L.head == "hat" or L.params.get("hat"):
        brim = c.ellipse(*x.hp(0.0, -8.5), R(17.0), R(3.2), rot=sk.angle)
        cone = c.poly([x.hp(-8.5, -9.0), x.hp(8.5, -9.0), x.hp(-2.0 - sw * 2, -29.0), x.hp(-7.0 - sw * 3, -25.0)])
        c.draw(cone, gear, "cloth", name="hat_cone")
        c.draw(brim, gear, "plate", bias=-1, name="hat_brim")
        band = c.ellipse(*x.hp(0.0, -10.5), R(8.4), R(1.7), rot=sk.angle) & cone
        c.draw(band, L.trim, "flat", name="hat_band")
    if L.extra_head:
        L.extra_head(x)


# --- frame ---------------------------------------------------------------------------
def draw(look: Look, pr: Proportions, p: Pose) -> HDCanvas:
    c = HDCanvas(pr.frame, pr.frame)
    sk = solve(p, pr)
    x = Ctx(c, sk, p, look, pr.k, pr.head_r)
    cape(x)
    if look.extra_back:
        look.extra_back(x)
    arm(x, sk.sh_far, sk.elbow_far, sk.hand_far, -1, False)
    pauldrons(x, False)
    leg(x, sk.hip_far, sk.knee_far, sk.foot_far, -1)
    leg(x, sk.hip_near, sk.knee_near, sk.foot_near, 0)
    torso(x)
    head(x)
    arm(x, sk.sh_near, sk.elbow_near, sk.hand_near, 0, True)
    pauldrons(x, True)
    if look.extra_front:
        look.extra_front(x)
    if p.glow > 0:
        hx, hy = sk.hand_near
        r = x.R(3.5 + p.glow * 3.0)
        ring = c.ellipse(hx, hy, r, r) & ~c.ellipse(hx, hy, r - 1.5, r - 1.5) & ~c.opaque()
        c.fixed(ring, look.glow)
        for k in range(8):
            a = k / 8 * math.tau + p.glow * 2
            c.px(int(hx + math.cos(a) * (r + x.R(2.5))), int(hy + math.sin(a) * (r + x.R(2.5))), look.glow)
    c.outline("ink")
    c.despeckle()
    return c


# --- standard animation set ------------------------------------------------------------
FPS = {"idle": 6, "run": 12, "dash": 16, "skill": 12, "hurt": 12, "death": 9}
LOOP = {"idle": True, "run": True, "dash": True, "skill": False, "hurt": False, "death": False}


def skill_cast() -> list[Pose]:
    """Default skill: anticipation, raise the near hand overhead, hold, recover."""
    return [
        Pose(y=2, squash=1, lean=-1, near_hand=(-2, -4), sway=0.2),
        Pose(y=1, lean=1, near_hand=(5, -18), far_hand=(-4, -2), glow=0.3, sway=0.5, extras={"wind": 0.4}),
        Pose(y=-1, lean=2, near_hand=(6, -25), far_hand=(-5, -3), glow=0.7, sway=0.9, extras={"wind": 0.7}),
        Pose(y=-1, lean=2, near_hand=(6, -25), far_hand=(-5, -3), glow=1.0, sway=0.4, extras={"wind": 0.7}),
        Pose(y=0, lean=1, near_hand=(6, -14), glow=0.5, sway=-0.2, extras={"wind": 0.3}),
        Pose(y=0, near_hand=(5, -1), sway=-0.4),
    ]


def skill_slash() -> list[Pose]:
    """Melee skill: wind up behind, sweep through, follow-through."""
    return [
        Pose(y=2, squash=1, lean=-3, near_hand=(-9, -10), far_hand=(-5, -4), sway=-0.4),
        Pose(y=1, lean=-2, near_hand=(-6, -16), far_hand=(-6, -6), glow=0.4, sway=-0.2, extras={"wind": 0.3}),
        Pose(y=0, lean=5, near_hand=(12, -6), far_hand=(-6, -2), glow=1.0, near_foot=(6, 0), far_foot=(-6, 0), sway=0.9, extras={"wind": 1.0}),
        Pose(y=1, lean=6, near_hand=(12, 2), far_hand=(-7, -1), glow=0.6, near_foot=(6, 0), far_foot=(-6, 0), sway=0.6, extras={"wind": 0.8}),
        Pose(y=1, lean=3, near_hand=(8, 2), sway=0.2, extras={"wind": 0.3}),
        Pose(y=0, near_hand=(5, -1), sway=-0.2),
    ]


def poses(skill: list[Pose] | None = None) -> dict[str, list[Pose]]:
    dash = [Pose(y=-1, lean=6, near_foot=(7, -3), far_foot=(-9, -2), near_hand=(-7, -3), far_hand=(-6, -4),
                 head=(1, 1), sway=s, extras={"wind": 1.0}) for s in (-1.0, -0.4, 0.3, 0.9)]
    hurt = [
        Pose(x=-2, lean=-4, head=(-2, -1), near_hand=(-6, -6), far_hand=(-7, -5), near_foot=(3, 0), far_foot=(-4, 0),
             sway=-0.8, blink=True, extras={"wind": 0.6}),
        Pose(x=-1, y=1, lean=-2, head=(-1, 0), near_hand=(-3, -3), far_hand=(-4, -2), sway=-0.3, blink=True, extras={"wind": 0.3}),
        Pose(y=0, lean=0, near_hand=(4, -1), sway=0.2),
    ]
    lying = Pose(x=-2, y=11, squash=12, lean=-16, head=(-2, 4), near_hand=(-10, 2), far_hand=(-10, 3), near_foot=(12, 0),
                 far_foot=(9, 0), blink=True, sway=0.0)
    death = [
        Pose(x=-1, lean=-4, head=(-2, -1), near_hand=(-6, -7), far_hand=(-7, -6), blink=True, sway=-0.8, extras={"wind": 0.5}),
        Pose(x=-2, y=3, squash=2, lean=-6, head=(-2, 0), near_hand=(-6, -4), far_hand=(-6, -3), near_foot=(4, 0), far_foot=(-2, 0),
             blink=True, sway=-0.4),
        Pose(x=-2, y=7, squash=3, lean=-3, near_hand=(2, -2), far_hand=(-3, -2), near_foot=(7, 0), far_foot=(2, 0), blink=True, sway=0.3),
        Pose(x=-2, y=9, squash=5, lean=-9, head=(-1, 1), near_hand=(-2, -6), far_hand=(-6, -4), near_foot=(9, 0), far_foot=(5, 0),
             blink=True, sway=0.6),
        Pose(x=-2, y=11, squash=10, lean=-14, head=(-2, 3), near_hand=(-8, -2), far_hand=(-9, 0), near_foot=(11, 0), far_foot=(8, 0),
             blink=True, sway=0.2),
        lying, lying, lying,
    ]
    return {"idle": idle_cycle(6), "run": run_cycle(8), "dash": dash, "skill": skill or skill_cast(), "hurt": hurt, "death": death}


def _fit(look: Look, pr: Proportions, p: Pose, margin: int = 2):
    """Render p; if it touches the frame border (big heroes lying down), slide
    the pose inward and redraw. Only used for death frames, where the body is
    free to move away from the feet anchor."""
    img = draw(look, pr, p).image()
    for _ in range(12):
        bb = img.getbbox()
        if bb is None:
            return img
        dx = dy = 0.0
        if bb[0] < margin:
            dx = (margin - bb[0]) / pr.k
        elif bb[2] > pr.frame - margin:
            dx = -(bb[2] - (pr.frame - margin)) / pr.k
        if bb[3] > pr.frame - margin:
            dy = -(bb[3] - (pr.frame - margin)) / pr.k
        if bb[1] < margin:
            dy = (margin - bb[1]) / pr.k
        if dx == 0 and dy == 0:
            return img
        p = p.but(x=p.x + math.copysign(math.ceil(abs(dx)), dx) if dx else p.x,
                  y=p.y + math.copysign(math.ceil(abs(dy)), dy) if dy else p.y)
        img = draw(look, pr, p).image()
    return img


def animations(look: Look, pr: Proportions, skill: list[Pose] | None = None) -> dict:
    out = {}
    for name, ps in poses(skill).items():
        out[name] = [(_fit(look, pr, p) if name == "death" else draw(look, pr, p).image()) for p in ps]
    return out
