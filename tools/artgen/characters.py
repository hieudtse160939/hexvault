"""Playable heroes: 16x16 frames, drawn facing right (the game flips for left)."""
from __future__ import annotations

from px import Canvas

HEROES = {
    # Rift Ranger: teal hooded coat, amber visor.
    "ranger": {
        "hood": ("teal0", "teal1"), "coat": ("teal0", "teal1", "teal2"),
        "face": "skin1", "visor": "amber2", "pants": "night", "boots": "ink",
        "accent": "amber1", "hat": "hood",
    },
    # Warden: stone plate armour, moss cape, slit helm.
    "warden": {
        "hood": ("stone1", "stone2"), "coat": ("stone0", "stone1", "stone2"),
        "face": "stone0", "visor": "teal2", "pants": "dusk", "boots": "ink",
        "accent": "moss1", "hat": "helm",
    },
    # Hexer: violet robe, tall hood, glowing eyes.
    "hexer": {
        "hood": ("vio0", "vio1"), "coat": ("vio0", "vio1", "vio2"),
        "face": "night", "visor": "teal3", "pants": "vio0", "boots": "ink",
        "accent": "amber2", "hat": "tall",
    },
    # Tinker: amber work coat, brass goggles, flat cap.
    "tinker": {
        "hood": ("amber0", "amber1"), "coat": ("amber0", "amber1", "amber2"),
        "face": "skin2", "visor": "teal2", "pants": "stone0", "boots": "ink",
        "accent": "stone3", "hat": "cap",
    },
}


def draw_hero(spec: dict, bob: int = 0, leg: int = 0, arm: int = 0, lean: int = 0,
              squash: int = 0, glow: bool = False) -> Canvas:
    """Parametric hero.

    bob: vertical body offset; leg: -1/0/1 stride phase; arm: arm swing;
    lean: horizontal head offset; squash: rows removed (for death frames).
    """
    c = Canvas(16, 16)
    coat0, coat1, coat2 = spec["coat"]
    hood0, hood1 = spec["hood"]
    by = 2 + bob + squash  # top of head

    # legs: two 2px legs with a gap, stride swaps their x offset
    if squash < 3:
        for lx, off in ((5, leg), (8, -leg)):
            x = lx + off
            c.rect(x, 11 + bob // 2, x + 1, 13, spec["pants"])
            c.hline(x, x + 1 + (1 if off >= 0 else 0), 14, spec["boots"])

    # torso / coat (narrower than the head -> readable chibi silhouette)
    ty = min(by + 7, 12)
    bot = min(ty + 3, 13)
    c.rect(5, ty, 10, bot, coat1)
    c.vline(5, ty, bot, coat0)
    c.vline(9, ty, bot, coat2)
    c.hline(5, 10, bot, coat0)
    c.px(7, ty + 1, spec["accent"]); c.px(8, ty + 1, spec["accent"])  # belt clasp

    # arms: back arm (dark) and front arm (lit) with a hand
    c.rect(4, ty - arm, 4, ty + 2 - arm, coat0)
    c.rect(11, ty + arm, 11, ty + 2 + arm, coat2)
    hand = spec["face"] if spec["hat"] != "helm" else "stone2"
    c.px(11, ty + 3 + arm, hand)

    # big rounded head
    hx = 4 + lean
    c.rect(hx, by, hx + 7, by + 6, hood1)
    for (x, y) in ((hx, by), (hx + 7, by), (hx, by + 6), (hx + 7, by + 6)):
        c.px(x, y, None)
    c.vline(hx, by + 1, by + 5, hood0)
    c.hline(hx + 1, hx + 6, by + 6, hood0)
    c.rect(hx + 3, by + 2, hx + 7, by + 5, spec["face"])  # face opening (facing right)
    c.px(hx + 7, by + 5, None)
    c.hline(hx + 4, hx + 7, by + 3, spec["visor"])        # visor / eyes
    c.px(hx + 2, by + 1, hood1); c.px(hx + 3, by + 1, hood1)
    c.px(hx + 4, by + 1, hood0 if spec["hat"] == "tall" else hood1)
    if spec["hat"] == "hood":
        c.px(hx + 1, by - 1, hood1); c.hline(hx + 2, hx + 5, by - 1, hood1)
        c.px(hx + 2, by, "white" if False else hood1)
    elif spec["hat"] == "helm":
        c.rect(hx + 3, by + 4, hx + 7, by + 5, "stone2")  # jaw guard
        c.hline(hx + 2, hx + 4, by - 1, spec["accent"])   # crest
        c.px(hx + 3, by - 2, spec["accent"])
    elif spec["hat"] == "cap":
        c.hline(hx, hx + 8, by, hood0)                   # cap brim
        c.rect(hx + 1, by - 1, hx + 6, by - 1, hood1)
        c.px(hx + 4, by + 2, "stone3"); c.px(hx + 6, by + 2, "stone3")  # goggle rims
    elif spec["hat"] == "tall":
        c.hline(hx + 1, hx + 5, by - 1, hood1)
        c.hline(hx + 1, hx + 3, by - 2, hood1)
        c.px(hx, by - 3, hood1); c.px(hx - 1, by - 4, hood0)

    if glow:
        for (x, y) in ((13, ty - 1), (14, ty + 1), (13, ty + 3), (2, ty)):
            c.px(x, y, "teal3")
    c.outline("ink")
    return c


def death_frames(spec: dict) -> list[Canvas]:
    frames = [draw_hero(spec, lean=-1), draw_hero(spec, bob=1, squash=1, lean=-1),
              draw_hero(spec, squash=3, lean=-1)]
    # fallen: a horizontal heap
    heap = Canvas(16, 16)
    coat0, coat1, coat2 = spec["coat"]
    heap.rect(3, 12, 12, 14, coat1); heap.hline(3, 12, 14, coat0)
    heap.rect(1, 12, 3, 14, spec["hood"][1]); heap.px(2, 13, spec["visor"])
    heap.px(9, 12, spec["accent"])
    heap.outline("ink")
    faded = heap.copy()
    faded.recolor({spec["visor"]: spec["hood"][0]})
    return frames + [heap, faded]


def build(spec: dict) -> dict[str, list[Canvas]]:
    return {
        "idle": [draw_hero(spec, bob=b) for b in (0, 0, 1, 1)],
        "run": [draw_hero(spec, bob=b, leg=l, arm=a)
                for b, l, a in ((0, 1, 1), (1, 0, 0), (0, -1, -1), (0, -1, -1), (1, 0, 0), (0, 1, 1))],
        "hurt": [draw_hero(spec, lean=-1), draw_hero(spec, lean=-1, bob=1)],
        "dash": [draw_hero(spec, lean=1, bob=1, leg=1, arm=1), draw_hero(spec, lean=1, leg=-1, arm=-1)],
        "skill": [draw_hero(spec, arm=-1), draw_hero(spec, arm=-1, glow=True), draw_hero(spec, glow=True)],
        "death": death_frames(spec),
    }


FPS = {"idle": 4, "run": 10, "hurt": 8, "dash": 12, "skill": 10, "death": 8}
LOOP = {"idle": True, "run": True, "hurt": False, "dash": True, "skill": False, "death": False}


def preview_sets():
    return [build(s) for s in HEROES.values()]
