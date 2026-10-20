"""Vex, the Rift Ranger - HD reference hero (style guide sample).

Silhouette: pointed teal hood, long split coat flaring behind the knees,
crimson scarf trailing back, chunky boots. Accent: amber goggle lens + buckle.
Drawn at figure scale K = 1.3 on a 128 px frame (body ~80 px tall).
"""
from __future__ import annotations

import math

from canvas import HDCanvas
from canvas import shift as shift_mask
from rig import Pose, Proportions, body_point as bp, head_point as hp, solve

K = 1.3
PR = Proportions(k=K, frame=128, cx=64, ground=112, pelvis_y=57.0, torso=17.0, head_r=11.0, head_off=(2.5, -9.5),
                 thigh=10.0, shin=9.5, upper_arm=8.5, forearm=8.0, hip_w=3.0, shoulder_w=3.5)
FRAME = PR.frame
PIVOT = (int(PR.cx), int(PR.ground))   # feet point, stored in the manifest

COAT = "teal"
LINING = "night"
SCARF = "crimson"
SKIN = "skin_fair"
HAIR = "hair_brown"
PANTS = "slate"
BOOT = "leather"
GLOVE = "hair_ink"
VISOR = "amber"
SHIRT = "night"


def R(v: float) -> float:
    """Base-unit length -> canvas px."""
    return v * K


def at(p, dx: float, dy: float):
    return (p[0] + dx * K, p[1] + dy * K)


def _along(a, b, t: float):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _limb(c: HDCanvas, a, b, r0, r1, ramp, form="cloth", bias=0, name=""):
    return c.draw(c.capsule(a[0], a[1], b[0], b[1], R(r0), R(r1)), ramp, form, bias=bias, name=name)


def _arm(c: HDCanvas, sh, el, hd, bias: int, front: bool) -> None:
    arm = c.capsule(sh[0], sh[1], el[0], el[1], R(3.3), R(3.0)) | c.capsule(el[0], el[1], hd[0], hd[1], R(3.0), R(2.8))
    c.draw(arm, COAT, "cloth", bias=bias + (1 if front else 0), name="sleeve")
    # elbow crease
    ex, ey = el
    c.px(int(ex - R(0.5)), int(ey), COAT, max(1 + bias, 0))
    # turned-back cuff in the lining colour + amber piping, then a chunky glove
    cf = _along(el, hd, 0.68)
    c.draw(c.capsule(cf[0], cf[1], hd[0], hd[1], R(3.2), R(3.0)) & arm, LINING, "soft", bias=bias, name="cuff")
    if front:
        pe = _along(cf, hd, 0.22)
        c.draw(c.capsule(cf[0], cf[1], pe[0], pe[1], R(3.2), R(3.2)) & arm, VISOR, "flat", name="piping")
    g = at(hd, 0.4, 1.2)
    c.draw(c.ellipse(g[0], g[1], R(3.0), R(2.8)), GLOVE, "round", bias=bias + 1, name="glove")
    if front:
        c.draw(c.ellipse(g[0] + R(1.4), g[1] - R(0.6), R(1.3), R(1.1)), GLOVE, "round", bias=bias + 1, name="thumb")


def _leg(c: HDCanvas, hip, knee, foot, bias: int) -> None:
    _limb(c, hip, knee, 3.4, 3.0, PANTS, "cloth", bias, "thigh")
    _limb(c, knee, foot, 3.0, 2.6, PANTS, "cloth", bias, "shin")
    # boot: shaft with a folded top + foot + steel toe cap
    s = _along(knee, foot, 0.42)
    _limb(c, s, foot, 3.2, 3.0, BOOT, "round", bias, "boot_shaft")
    fold = _along(knee, foot, 0.48)
    c.draw(c.ellipse(fold[0], fold[1], R(3.5), R(1.6)), BOOT, "plate", bias=bias + 1, name="boot_fold")
    b = at(foot, 1.6, 1.0)
    c.draw(c.ellipse(b[0], b[1], R(4.3), R(2.5)), BOOT, "round", bias=bias, name="boot")
    t = at(foot, 4.1, 1.2)
    c.draw(c.ellipse(t[0], t[1], R(1.9), R(1.8)), "steel", "metal", bias=bias, name="toecap")
    # sole line
    so = at(foot, -2.4, 3.2)
    c.line(so[0], so[1], so[0] + R(7.6), so[1], "hair_ink", 1 + bias if bias > -1 else 0)


def draw(p: Pose) -> HDCanvas:
    c = HDCanvas(FRAME, FRAME)
    sk = solve(p, PR)
    sway = p.sway

    # 1. scarf tail (behind everything): two ribbons; hang down when still,
    #    stream back when moving (pose.extras["wind"] 0..1)
    n = sk.neck
    wind = float(p.extras.get("wind", 0.0))
    for k, (ln, w) in enumerate(((16.0, 3.0), (12.0, 2.5))):
        pts = []
        segs = 9
        ang = math.radians(100 - 85 * wind + k * 14)      # 90 = straight down, 0 = straight back
        for i in range(segs + 1):
            t = i / segs
            dirx, diry = -math.cos(ang), math.sin(ang)
            flutter = math.sin(t * 3.4 + sway * 1.8 + k * 1.3) * (0.4 + 2.0 * t) * (0.4 + wind)
            pts.append((n[0] + R(-2.5 + dirx * t * ln - diry * flutter * 0.5),
                        n[1] + R(-0.5 + diry * t * ln + flutter * (0.3 + 0.7 * wind))))
        top = [(x, y - R(w * (1 - 0.5 * i / segs))) for i, (x, y) in enumerate(pts)]
        bot = [(x + R(0.8), y + R(w * (1 - 0.5 * i / segs) * 0.5)) for i, (x, y) in enumerate(pts)]
        c.draw(c.poly(top + bot[::-1]), SCARF, "cloth", bias=-1 if k else 0, name="scarf_tail")
        if k == 0:  # frayed end
            ex, ey = pts[-1]
            c.px(int(ex - R(0.8)), int(ey + R(1.2)), SCARF, 2)

    # 2. far arm
    _arm(c, sk.sh_far, sk.elbow_far, sk.hand_far, -1, False)

    # 3. coat back panel (flares behind the legs)
    flare = 2.0 + max(sway, 0) * 1.5
    back = [bp(sk, 14.0, -7.0), bp(sk, 14.0, 2.0), bp(sk, -2.0, 3.0), bp(sk, -13.0, 1.0),
            bp(sk, -14.0 - flare * 0.4, -6.5 - flare), bp(sk, -8.0, -10.0 - flare * 0.6), bp(sk, 2.0, -8.5)]
    c.draw(c.poly(back), COAT, "cloth", bias=-1, name="coat_back")
    lining = [bp(sk, -1.0, -5.0), bp(sk, -1.0, 1.0), bp(sk, -11.0, 0.0), bp(sk, -12.5 - flare * 0.4, -4.0 - flare)]
    c.draw(c.poly(lining), LINING, "soft", bias=-1, name="coat_lining")

    # 4. legs (far then near)
    _leg(c, sk.hip_far, sk.knee_far, sk.foot_far, -1)
    _leg(c, sk.hip_near, sk.knee_near, sk.foot_near, 0)

    # 5. torso: coat body, shirt, front skirt, lapel, belt, buttons
    torso = [bp(sk, 16.0, -6.5), bp(sk, 16.5, 5.5), bp(sk, 2.0, 6.5), bp(sk, -1.0, 6.0), bp(sk, -1.0, -6.5), bp(sk, 3.0, -7.5)]
    body_mask = c.poly(torso)
    c.draw(body_mask, COAT, "cloth", name="coat_body")
    shirt = [bp(sk, 15.0, 2.0), bp(sk, 15.0, 5.5), bp(sk, 0.0, 6.0), bp(sk, 0.0, 3.0)]
    c.draw(c.poly(shirt), SHIRT, "soft", name="shirt", light_mask=body_mask)
    skirt = [bp(sk, 0.0, -6.5), bp(sk, 0.0, 6.2), bp(sk, -9.5, 7.5 + flare * 0.3), bp(sk, -10.5, 2.5),
             bp(sk, -10.0, -7.5 - flare * 0.4)]
    c.draw(c.poly(skirt), COAT, "cloth", name="coat_skirt")
    # skirt split + hem trim
    s0, s1 = bp(sk, -1.0, 1.5), bp(sk, -9.8, 2.6)
    c.line(s0[0], s0[1], s1[0], s1[1], COAT, 1)
    lapel = [bp(sk, 15.0, 2.0), bp(sk, 9.0, 4.4), bp(sk, 1.0, 3.0), bp(sk, 1.0, 1.6), bp(sk, 9.0, 2.2)]
    c.draw(c.poly(lapel), COAT, "flat", bias=1, name="lapel")
    for u in (11.5, 7.0):
        bx0, by0 = bp(sk, u, 1.4)
        c.px(int(bx0), int(by0), VISOR, 4)
    belt = [bp(sk, 2.6, -6.8), bp(sk, 2.6, 6.6), bp(sk, -1.0, 6.8), bp(sk, -1.0, -7.0)]
    c.draw(c.poly(belt), BOOT, "plate", name="belt")
    bx, by = bp(sk, 0.8, 4.2)
    c.draw(c.ellipse(bx, by, R(1.6), R(1.5)), VISOR, "metal", name="buckle")
    c.px(int(bx), int(by), BOOT, 0)
    # holster strap + pouch on the hip
    h0, h1 = bp(sk, 2.0, -5.5), bp(sk, -5.5, -3.0)
    c.draw(c.capsule(h0[0], h0[1], h1[0], h1[1], R(0.9), R(0.9)), BOOT, "flat", bias=-1, name="holster_strap")
    hx, hy = bp(sk, -2.8, -4.6)
    c.draw(c.ellipse(hx, hy, R(2.5), R(3.3)), BOOT, "round", bias=-1, name="pouch")
    c.px(int(hx), int(hy - R(1.6)), VISOR, 3)

    # 6. head: hood, face, goggles
    h = sk.head
    hood_mask = c.ellipse(h[0] - R(0.5), h[1], R(PR.head_r), R(PR.head_r - 0.5), rot=sk.angle)
    tip = [hp(sk, -7.0, -6.0), hp(sk, -14.0 - sway * 1.5, 1.0 + sway), hp(sk, -6.0, 5.0)]
    hood_full = hood_mask | c.poly(tip)
    c.draw(hood_full, COAT, "cloth", name="hood")
    # hood seam from crown to tip
    q0, q1 = hp(sk, -1.0, -9.5), hp(sk, -11.0 - sway, 0.5 + sway * 0.8)
    c.line(q0[0], q0[1], (q0[0] + q1[0]) / 2, (q0[1] + q1[1]) / 2 - R(1.0), COAT, 2)
    c.line((q0[0] + q1[0]) / 2, (q0[1] + q1[1]) / 2 - R(1.0), q1[0], q1[1], COAT, 2)
    fx, fy = hp(sk, 4.4, 1.4)
    face_mask = (c.ellipse(fx, fy, R(6.4), R(6.9), rot=sk.angle)
                 & c.ellipse(h[0] - R(0.5), h[1], R(PR.head_r - 1.0), R(PR.head_r - 1.3), rot=sk.angle))
    c.draw(face_mask, SKIN, "skin", bias=1, name="face", selout=False)
    # recess: the hood throws a shadow on the upper face
    c.relight(face_mask & ~shift_mask(face_mask, 0, -2), 0)
    c.relight(face_mask & ~shift_mask(face_mask, 2, 2), -1)
    rim = c.ellipse(fx, fy, R(7.6), R(8.0), rot=sk.angle) & hood_mask & ~face_mask
    c.relight(rim, +1)
    # fringe of hair under the hood
    fr = c.ellipse(*hp(sk, 2.4, -3.8), R(5.2), R(2.2), rot=sk.angle - 0.2) & face_mask
    c.draw(fr, HAIR, "round", name="fringe", selout=False)
    # goggle strap + glowing lens
    s0, s1 = hp(sk, -2.0, -0.4), hp(sk, 7.0, -0.2)
    strap = c.capsule(s0[0], s0[1], s1[0], s1[1], R(1.1), R(1.1)) & (face_mask | hood_mask)
    c.draw(strap, "slate", "flat", name="strap", selout=False)
    lx, ly = hp(sk, 8.2, -0.3)
    c.draw(c.ellipse(lx, ly, R(2.7), R(2.2), rot=sk.angle), "slate", "plate", bias=-1, name="goggle_frame")
    c.draw(c.ellipse(lx + R(0.3), ly, R(1.7), R(1.2), rot=sk.angle), VISOR, "metal",
           bias=(-2 if p.blink else 1), name="lens", selout=False)
    if not p.blink:
        gx, gy = hp(sk, 8.0, -0.8)
        c.px(int(gx), int(gy), "glow_amber")
        c.px(int(gx) - 1, int(gy), "glow_amber")
    # cheek, nose tip and mouth
    cx2, cy2 = hp(sk, 6.4, 2.6)
    c.px(int(cx2), int(cy2), "rose", 3)
    nx, ny = hp(sk, 9.6, 1.8)
    if face_mask[int(round(ny)), int(round(nx))]:
        c.px(int(round(nx)), int(round(ny)), SKIN, 5)
    mx, my = hp(sk, 8.0, 4.6)
    c.line(mx, my, mx + R(1.4), my, SKIN, 1)

    # 7. scarf wrap around the neck (front of hood bottom)
    sw = c.ellipse(*hp(sk, 0.5, 8.6), R(7.6), R(3.2), rot=sk.angle) & ~face_mask
    c.draw(sw, SCARF, "cloth", name="scarf_wrap")
    w0, w1 = hp(sk, -5.0, 8.4), hp(sk, 5.0, 9.4)
    c.line(w0[0], w0[1], w1[0], w1[1], SCARF, 2)
    knot = [hp(sk, 4.5, 9.0), hp(sk, 7.5, 9.5), hp(sk, 6.0 - sway, 15.0), hp(sk, 4.0 - sway, 14.0)]
    c.draw(c.poly(knot), SCARF, "cloth", bias=-1, name="scarf_knot")

    # 8. near arm in front
    _arm(c, sk.sh_near, sk.elbow_near, sk.hand_near, 0, True)

    # 9. skill glow sparks around the goggles / hand
    if p.glow > 0:
        hx2, hy2 = sk.hand_near
        r = R(3.5 + p.glow * 3.0)
        ring = c.ellipse(hx2, hy2, r, r) & ~c.ellipse(hx2, hy2, r - 1.5, r - 1.5) & ~c.opaque()
        c.fixed(ring, "glow_amber")
        for k in range(8):
            a = k / 8 * math.tau + p.glow * 2
            c.px(int(hx2 + math.cos(a) * (r + R(2.5))), int(hy2 + math.sin(a) * (r + R(2.5))), "glow_amber")

    c.outline("ink")
    c.despeckle()
    return c


# --- animations -------------------------------------------------------------------
SPEC = {
    "id": "ranger",
    "sprite": "hero_ranger",
    "version": 2,
    "source": "procedural: tools/artgen/hd/heroes/ranger.py",
}

FPS = {"idle": 6, "run": 12, "dash": 16, "skill": 12, "hurt": 12, "death": 9}
LOOP = {"idle": True, "run": True, "dash": True, "skill": False, "hurt": False, "death": False}


def poses() -> dict[str, list[Pose]]:
    from rig import idle_cycle, run_cycle
    dash = [Pose(y=-1, lean=6, near_foot=(7, -3), far_foot=(-9, -2), near_hand=(-7, -3), far_hand=(-6, -4),
                 head=(1, 1), sway=s, extras={"wind": 1.0}) for s in (-1.0, -0.4, 0.3, 0.9)]
    skill = [
        Pose(y=2, squash=1, lean=-1, near_hand=(-2, -4), sway=0.2),                           # anticipation
        Pose(y=1, lean=1, near_hand=(5, -18), far_hand=(-4, -2), glow=0.3, sway=0.5, extras={"wind": 0.4}),
        Pose(y=-1, lean=2, near_hand=(6, -25), far_hand=(-5, -3), glow=0.7, sway=0.9, extras={"wind": 0.7}),
        Pose(y=-1, lean=2, near_hand=(6, -25), far_hand=(-5, -3), glow=1.0, sway=0.4, extras={"wind": 0.7}),
        Pose(y=0, lean=1, near_hand=(6, -14), glow=0.5, sway=-0.2, extras={"wind": 0.3}),
        Pose(y=0, near_hand=(5, -1), sway=-0.4),
    ]
    hurt = [
        Pose(x=-2, lean=-4, head=(-2, -1), near_hand=(-6, -6), far_hand=(-7, -5), near_foot=(3, 0), far_foot=(-4, 0),
             sway=-0.8, blink=True, extras={"wind": 0.6}),
        Pose(x=-1, y=1, lean=-2, head=(-1, 0), near_hand=(-3, -3), far_hand=(-4, -2), sway=-0.3, blink=True,
             extras={"wind": 0.3}),
        Pose(y=0, lean=0, near_hand=(4, -1), sway=0.2),
    ]
    death = [
        Pose(x=-1, lean=-4, head=(-2, -1), near_hand=(-6, -7), far_hand=(-7, -6), blink=True, sway=-0.8, extras={"wind": 0.5}),
        Pose(x=-2, y=3, squash=2, lean=-6, head=(-2, 0), near_hand=(-6, -4), far_hand=(-6, -3), near_foot=(4, 0),
             far_foot=(-2, 0), blink=True, sway=-0.4),
        Pose(x=-2, y=7, squash=3, lean=-3, near_hand=(2, -2), far_hand=(-3, -2), near_foot=(7, 0), far_foot=(2, 0),
             blink=True, sway=0.3),                                                         # knees
        Pose(x=-2, y=9, squash=5, lean=-9, head=(-1, 1), near_hand=(-2, -6), far_hand=(-6, -4), near_foot=(9, 0),
             far_foot=(5, 0), blink=True, sway=0.6),
        Pose(x=-2, y=11, squash=10, lean=-14, head=(-2, 3), near_hand=(-8, -2), far_hand=(-9, 0), near_foot=(11, 0),
             far_foot=(8, 0), blink=True, sway=0.2),
        Pose(x=-2, y=11, squash=12, lean=-16, head=(-2, 4), near_hand=(-10, 2), far_hand=(-10, 3), near_foot=(12, 0),
             far_foot=(9, 0), blink=True, sway=0.0),
        Pose(x=-2, y=11, squash=12, lean=-16, head=(-2, 4), near_hand=(-10, 2), far_hand=(-10, 3), near_foot=(12, 0),
             far_foot=(9, 0), blink=True, sway=0.0),
        Pose(x=-2, y=11, squash=12, lean=-16, head=(-2, 4), near_hand=(-10, 2), far_hand=(-10, 3), near_foot=(12, 0),
             far_foot=(9, 0), blink=True, sway=0.0),
    ]
    return {"idle": idle_cycle(6), "run": run_cycle(8), "dash": dash, "skill": skill, "hurt": hurt, "death": death}


def animations() -> dict:
    out = {}
    for name, ps in poses().items():
        out[name] = [draw(p).image() for p in ps]
    # death: fade the last frame's lens glow (already blinking) - keep frames distinct for QA
    return out
