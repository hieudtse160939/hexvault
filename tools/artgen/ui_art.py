"""Ornate UI pieces (9-patch textures) for the Guild interface, at UI pixel size (1 px = 1 UI px).

Matches the reference mock-up: dark varnished wood panels with a brass/gold border and corner
studs, inset item slots, colour-coded action buttons and a title plate. Used by
scripts/ui/ui_theme.gd (StyleBoxTexture); margins are listed in UI_MARGINS.
"""
from __future__ import annotations

from PIL import Image

INK = (20, 16, 30, 255)
WOOD = (42, 28, 22, 255)
WOOD_D = (30, 20, 16, 255)
WOOD_L = (58, 40, 30, 255)
GOLD_D = (122, 82, 34, 255)
GOLD = (200, 150, 62, 255)
GOLD_L = (242, 210, 122, 255)

UI_MARGINS = {"ui_frame": 8, "ui_slot": 3, "ui_plate": 6, "ui_btn_green": 4, "ui_btn_blue": 4,
              "ui_btn_gold": 4, "ui_btn_red": 4, "ui_tooltip": 4}


def _rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            img.putpixel((x, y), c)


def _border(img, inset, c):
    w, h = img.size
    _rect(img, inset, inset, w - 1 - inset, inset, c)
    _rect(img, inset, h - 1 - inset, w - 1 - inset, h - 1 - inset, c)
    _rect(img, inset, inset, inset, h - 1 - inset, c)
    _rect(img, w - 1 - inset, inset, w - 1 - inset, h - 1 - inset, c)


def frame(size: int = 32) -> Image.Image:
    img = Image.new("RGBA", (size, size), WOOD)
    _border(img, 0, INK)
    _border(img, 1, GOLD_L)
    _border(img, 2, GOLD)
    _border(img, 3, GOLD_D)
    _border(img, 4, INK)
    _border(img, 5, WOOD_L)
    for cx, cy in ((2, 2), (size - 3, 2), (2, size - 3), (size - 3, size - 3)):  # corner studs
        _rect(img, cx - 2, cy - 2, cx + 2, cy + 2, GOLD_D)
        _rect(img, cx - 1, cy - 1, cx + 1, cy + 1, GOLD_L)
        img.putpixel((cx, cy), GOLD)
    return img


def tooltip(size: int = 16) -> Image.Image:
    img = Image.new("RGBA", (size, size), (24, 18, 30, 255))
    _border(img, 0, INK)
    _border(img, 1, GOLD)
    _border(img, 2, (36, 28, 44, 255))
    return img


def slot(size: int = 12) -> Image.Image:
    img = Image.new("RGBA", (size, size), (26, 20, 32, 255))
    _border(img, 0, INK)
    _rect(img, 1, 1, size - 2, 1, (14, 10, 20, 255))         # inset shadow top/left
    _rect(img, 1, 1, 1, size - 2, (14, 10, 20, 255))
    _rect(img, 1, size - 2, size - 2, size - 2, GOLD_D)      # lit bevel bottom/right
    _rect(img, size - 2, 1, size - 2, size - 2, GOLD_D)
    return img


def plate(w: int = 24, h: int = 16) -> Image.Image:
    img = Image.new("RGBA", (w, h), WOOD_D)
    _border(img, 0, INK)
    _border(img, 1, GOLD_L)
    _border(img, 2, GOLD_D)
    for x in (4, w - 5):
        _rect(img, x, 4, x, h - 5, GOLD_D)
    return img


def button(base, light, dark, w: int = 12, h: int = 12) -> Image.Image:
    img = Image.new("RGBA", (w, h), base)
    _border(img, 0, INK)
    _rect(img, 1, 1, w - 2, 1, light)
    _rect(img, 1, h - 2, w - 2, h - 2, dark)
    _rect(img, 1, 2, 1, h - 3, light)
    _rect(img, w - 2, 2, w - 2, h - 3, dark)
    return img


def all_images() -> dict[str, Image.Image]:
    return {
        "ui_frame": frame(), "ui_slot": slot(), "ui_plate": plate(), "ui_tooltip": tooltip(),
        "ui_btn_green": button((52, 120, 58, 255), (110, 186, 96, 255), (24, 66, 34, 255)),
        "ui_btn_blue": button((44, 84, 150, 255), (98, 150, 214, 255), (22, 40, 86, 255)),
        "ui_btn_gold": button((170, 120, 40, 255), (240, 200, 110, 255), (100, 64, 20, 255)),
        "ui_btn_red": button((150, 40, 46, 255), (214, 98, 96, 255), (82, 18, 26, 255)),
    }
