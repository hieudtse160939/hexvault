# Session context (handoff)

_Branch `claude/hd-pixel-art-roguelike-6d4lcx` · last updated 2026-10-20_

## Project
Hexvault: Godot 4.7.2 / GDScript top-down action roguelite (Soul Knight-like). Goal from the
user's master prompt: turn it into a high-quality **HD pixel art, anime RPG style** roguelike
with a large, data-driven hero roster, without rewriting the engine or breaking gameplay.
The user writes in Vietnamese; answer in Vietnamese.

## Commands
```bash
python tools/check.py                 # assets + asset QA + import + 58 tests (must be ALL CHECKS PASSED)
python tools/artgen/build.py          # regenerate all art + assets/manifest.json
xvfb-run -a $GODOT_BIN --path . --resolution 1920x1080 --rendering-driver opengl3 -- --tour=<abs dir> [--tour-hero=<id>]
python tools/package.py linux|windows # exports (templates in .tools/editor_data/export_templates/4.7.2.stable)
```
Godot binary: `tools/godot_bin.py` (Linux: `.tools/Godot_v4.7.2-stable_linux.x86_64`, gitignored,
download per BUILD_GUIDE.md).

## What exists now
- **Rendering:** stretch `canvas_items`, integer scale; per-asset `density` in the manifest
  (HD = 4 art px per world unit); `SpriteLib.apply()` / `fit_icon()`; pixel-aware sampling in
  `shaders/flash.gdshader`; HD sprites stand on a feet `pivot`.
- **HD art pipeline:** `tools/artgen/hd/` - `palette.py` (frozen 24×6 ramps), `canvas.py`
  (part masks, dome lighting, selout, outline, despeckle), `rig.py` (2D skeleton + IK),
  `heroes/kit.py` (Look-driven hero painter, anime profile face, hand-made eye templates,
  standard animation set), hero modules, `enemies/` (golem, gloop, sparkeye, skitter, acolyte,
  ossifex boss), `weapons.py` (4 HD weapons), `tiles.py` (HD tileset), `icons.py`.
- **QA:** `tools/validate_assets.py` (palette, binary alpha, grid) + `tools/asset_qa.py`
  (clipping, anchor drift, jitter, noise, colour budget 56, metadata) -> `docs/qa/`.
- **External art:** `tools/artgen/import_external.py` (pixel-art-studio cleanup: background
  key-out, true-pixel recovery, palette lock) reading `art_src/raw/`.
- **Characters:** 12 heroes / 12 classes in `data/characters.json` + `data/classes.json`;
  skills `scripts/characters/skills/<id>.gd`, passives `scripts/characters/passives/<id>.gd`
  (HeroSkill / HeroPassive hooks, found by id); mastery XP per run; save schema v3 with
  migration; Hero Shrine (paging, archetype filter, sort, search). Guide: `docs/ADDING_CHARACTERS.md`.
- **Weapons:** 14 (3 common default, others unlocked with shards / achievement). Drops only
  from the treasure-room weapon chest and the shop, weighted by rarity
  (`WeaponPickup.roll`: common 10, rare 7, epic 2.5+floor, legendary 0.5+0.5*floor), only
  from unlocked weapons.
- **Builds:** Linux export built and run-verified; Windows exported, not run; Android/iOS not built.

## Still 16 px (to convert)
Props (crate, barrel, pillar, lamp, chest, portal, fountain, statue, pedestal, turret,
barrier, spawn rune, shadows), pickups, projectiles, FX, UI icons other than skills, title/hub art.

## Open requests from the user
1. **Use the user's reference sheet as the hero art** ("lấy luôn mẫu này"): 12 heroes in
   profile anime style, one idle pose each. Waiting for the file at
   `art_src/raw/heroes_reference.png` (upload via GitHub web to this branch). Plan: slice each
   hero, run `import_external.py`, animate with cut-out puppeting (idle bob, run bounce + leg
   swap, dash lean, hurt recoil, death fall) unless the user sends more frames.
2. Optional: give elites / boss a small chance to drop epic / legendary weapons; balance pass.

## Style decisions made with the user
- Anime RPG chibi, heads in **profile** (same facing as bodies, one eye), not 3/4 with two eyes.
- Eyes from hand-made pixel templates, light flat-shaded skin.
- Docs in `docs/` (AUDIT_REPORT.md in Vietnamese; ART_STYLE_GUIDE.md, ADDING_CHARACTERS.md in English).
