"""2D humanoid rig for HD heroes (side / three-quarter view, facing right).

A Pose is a handful of numbers (pelvis offset, lean, feet and hand targets,
secondary-motion phase). Skeleton.solve() turns it into joint positions with
two-bone IK for arms and legs; hero modules then draw their own parts on
those joints with HDCanvas. Animation = a list of Poses, so every frame of
every hero shares one consistent anatomy and anchor (feet on GROUND_Y).

Poses and proportions are written in *base units* (a 96 px frame with feet
on y = 76, body on x = 48). Proportions.k scales the whole figure and
Proportions.frame / cx / ground place it on the real canvas, so a hero can be
drawn bigger or smaller with more (not stretched) pixels. Hero modules scale
their own radii with Proportions.k.

Canvas contract (HD heroes, density 4): 128 x 128 px frames (32 x 32 world
units), feet on y = ground, body centred on x = cx; the feet point is stored
as the sheet pivot so the game can stand the sprite on the actor's feet.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field, replace

FRAME = 96
CX = 48
GROUND_Y = 76


Vec = tuple[float, float]


def add(a: Vec, b: Vec) -> Vec:
    return (a[0] + b[0], a[1] + b[1])


def sub(a: Vec, b: Vec) -> Vec:
    return (a[0] - b[0], a[1] - b[1])


def mul(a: Vec, k: float) -> Vec:
    return (a[0] * k, a[1] * k)


def length(a: Vec) -> float:
    return math.hypot(a[0], a[1])


def norm(a: Vec) -> Vec:
    l = length(a)
    return (a[0] / l, a[1] / l) if l > 1e-6 else (0.0, -1.0)


def perp(a: Vec) -> Vec:
    """Rotate 90 degrees clockwise on screen (x right, y down)."""
    return (-a[1], a[0])


def lerp(a: Vec, b: Vec, t: float) -> Vec:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def rot(a: Vec, ang: float) -> Vec:
    c, s = math.cos(ang), math.sin(ang)
    return (a[0] * c - a[1] * s, a[0] * s + a[1] * c)


def ik2(root: Vec, target: Vec, l1: float, l2: float, bend: float) -> tuple[Vec, Vec]:
    """Two-bone IK. bend = +1 / -1 picks the side the middle joint bulges to.

    Returns (middle joint, end effector); the end is clamped to reach.
    """
    d = sub(target, root)
    dist = length(d)
    reach = l1 + l2 - 0.01
    if dist > reach:
        target = add(root, mul(norm(d), reach))
        d = sub(target, root)
        dist = reach
    dist = max(dist, abs(l1 - l2) + 0.01)
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    u = norm(d)
    mid = add(add(root, mul(u, a)), mul(perp(u), h * bend))
    return mid, target


@dataclass
class Proportions:
    k: float = 1.0                # figure scale (base units -> canvas px)
    frame: int = FRAME            # canvas size in px
    cx: float = CX                # canvas x of the body centre line
    ground: float = GROUND_Y      # canvas y of the soles
    pelvis_y: float = 58.0        # pelvis height (y) when standing
    torso: float = 16.0           # pelvis -> neck
    head_r: float = 10.5          # head radius
    head_off: Vec = (2.0, -9.0)   # neck -> head centre (upright)
    thigh: float = 9.5
    shin: float = 9.5
    upper_arm: float = 8.0
    forearm: float = 7.5
    hip_w: float = 2.5            # half spacing of hips (along x for depth)
    shoulder_w: float = 3.0


@dataclass
class Pose:
    x: float = 0.0                # whole-body x offset
    y: float = 0.0                # pelvis bob (+ = down)
    lean: float = 0.0             # neck x offset relative to pelvis (+ = forward)
    head: Vec = (0.0, 0.0)        # extra head offset (follow-through)
    near_foot: Vec = (2.0, 0.0)   # feet relative to (CX, GROUND_Y); y < 0 lifts
    far_foot: Vec = (-3.0, 0.0)
    near_hand: Vec = (4.0, 0.0)   # hands relative to their shoulder
    far_hand: Vec = (-3.0, 1.0)
    sway: float = 0.0             # secondary motion phase (-1..1): scarf / coat tails
    squash: float = 0.0           # torso shortening in px
    blink: bool = False
    glow: float = 0.0             # skill glow strength 0..1
    extras: dict = field(default_factory=dict)

    def but(self, **kw) -> "Pose":
        return replace(self, **kw)


@dataclass
class Skeleton:
    """Joint positions in canvas pixels. bp()/hp() map body / head local
    coordinates (u along the spine, s toward the facing side) to the canvas."""

    pelvis: Vec
    neck: Vec
    head: Vec
    axis: Vec                     # unit pelvis -> neck
    angle: float                  # spine rotation from upright (radians, + = clockwise)
    hip_near: Vec
    hip_far: Vec
    knee_near: Vec
    knee_far: Vec
    foot_near: Vec
    foot_far: Vec
    sh_near: Vec
    sh_far: Vec
    elbow_near: Vec
    elbow_far: Vec
    hand_near: Vec
    hand_far: Vec
    k: float = 1.0


def body_point(sk: "Skeleton", u: float, s: float) -> Vec:
    """Point u px up the spine from the pelvis and s px toward the front."""
    side = perp(sk.axis)
    return add(add(sk.pelvis, mul(sk.axis, u * sk.k)), mul(side, s * sk.k))


def head_point(sk: "Skeleton", dx: float, dy: float) -> Vec:
    return add(sk.head, rot((dx * sk.k, dy * sk.k), sk.angle))


def solve(p: Pose, pr: Proportions) -> Skeleton:
    pelvis = (CX + p.x, pr.pelvis_y + p.y)
    neck = (pelvis[0] + p.lean, pelvis[1] - (pr.torso - p.squash))
    axis = norm(sub(neck, pelvis))
    side = perp(axis)  # points "right" relative to the spine
    angle = math.atan2(axis[1], axis[0]) + math.pi / 2
    head = add(add(neck, rot((pr.head_off[0] + p.lean * 0.15, pr.head_off[1]), angle)), p.head)
    hip_near = add(pelvis, mul(side, -pr.hip_w * 0.4))
    hip_far = add(pelvis, mul(side, pr.hip_w))
    hip_near = (hip_near[0] - 0.5, hip_near[1])
    foot_near_t = (CX + p.near_foot[0], GROUND_Y + p.near_foot[1] - 1.5)
    foot_far_t = (CX + p.far_foot[0], GROUND_Y + p.far_foot[1] - 1.5)
    knee_near, foot_near = ik2(hip_near, foot_near_t, pr.thigh, pr.shin, -1.0)
    knee_far, foot_far = ik2(hip_far, foot_far_t, pr.thigh, pr.shin, -1.0)
    chest = lerp(pelvis, neck, 0.82)
    sh_near = add(chest, rot((-pr.shoulder_w * 0.2, 1.0), angle))
    sh_far = add(chest, rot((pr.shoulder_w * 0.6, 0.0), angle))
    elbow_near, hand_near = ik2(sh_near, add(sh_near, add((0.0, pr.upper_arm + pr.forearm - 2.0), p.near_hand)),
                                pr.upper_arm, pr.forearm, 1.0)
    elbow_far, hand_far = ik2(sh_far, add(sh_far, add((0.0, pr.upper_arm + pr.forearm - 2.0), p.far_hand)),
                              pr.upper_arm, pr.forearm, 1.0)
    def m(v: Vec) -> Vec:  # base units -> canvas px
        return (pr.cx + (v[0] - CX) * pr.k, pr.ground + (v[1] - GROUND_Y) * pr.k)

    return Skeleton(m(pelvis), m(neck), m(head), axis, angle, m(hip_near), m(hip_far), m(knee_near), m(knee_far),
                    m(foot_near), m(foot_far), m(sh_near), m(sh_far), m(elbow_near), m(elbow_far), m(hand_near),
                    m(hand_far), pr.k)


# --- standard cycles -------------------------------------------------------------
def run_cycle(n: int = 8, stride: float = 7.0, lift: float = 4.0, bob: float = 1.5, lean: float = 2.5) -> list[Pose]:
    """Run cycle: contact - down - passing - up, mirrored. Arms counter-swing."""
    out = []
    for i in range(n):
        ph = i / n * 2 * math.pi
        nf = (math.cos(ph) * stride, -max(0.0, math.sin(ph)) * lift)
        ff = (math.cos(ph + math.pi) * stride - 2.0, -max(0.0, math.sin(ph + math.pi)) * lift)
        b = -abs(math.sin(ph)) * bob + bob * 0.5
        out.append(Pose(y=b, lean=lean, near_foot=nf, far_foot=ff,
                        near_hand=(-math.cos(ph) * 5.0, -1.0 + abs(math.cos(ph)) * -1.0),
                        far_hand=(math.cos(ph) * 4.0, -1.0),
                        head=(0.0, -b * 0.4), sway=math.sin(ph), extras={"wind": 1.0}))
    return out


def idle_cycle(n: int = 6, breath: float = 1.0) -> list[Pose]:
    out = []
    for i in range(n):
        ph = i / n * 2 * math.pi
        b = (1 - math.cos(ph)) * 0.5 * breath   # 0 .. breath
        out.append(Pose(y=round(b), squash=0.0, head=(0.0, round((1 - math.cos(ph - 0.9)) * 0.5 * breath)),
                        near_hand=(5.0, -round(b) - 1.0), far_hand=(-3.0, -round(b) + 1.0), sway=math.sin(ph) * 0.5,
                        blink=(i == n - 2)))
    return out
