---
name: hexvault-dev
description: Project workflow for the Hexvault Godot 4.7 roguelite in this repo - where systems live, how to add weapons/enemies/rooms/art/sounds as data, and the exact commands to validate, test, screenshot and export. Use before changing gameplay, data, assets or builds in this project.
---

# Hexvault development workflow

Engine: Godot 4.7.2 (portable, `.tools/`, self-contained via `.tools/_sc_`).
Binary: `$GODOT_BIN`, else `tools/godot_bin.py` picks `.tools/Godot_v4.7.2-stable_win64_console.exe` (Windows)
or `.tools/Godot_v4.7.2-stable_linux.x86_64` (Linux; on a headless box run visual tools under `xvfb-run -a`).

## Always finish with
```bash
python tools/check.py            # assets + import + all tests; must print ALL CHECKS PASSED
```
For visual changes also run the tour and LOOK at the PNGs:
```bash
$GODOT_BIN --path . --resolution 1920x1080 -- --tour=<abs dir>
```
(`tour_report.json` holds frame timings incl. a 40-enemy/300-projectile stress test.)

## Adding content (data first, code last)
| Want | Do |
| --- | --- |
| Weapon | entry in `data/weapons.json` (pattern single/spread/melee/hitscan/chain) + sprite function in `tools/artgen/items.py::WEAPONS`, rebuild art. No new script. |
| Enemy | entry in `data/enemies.json` with an existing `behavior` + sheet in `tools/artgen/enemies.py::SHEETS` (needs idle/move/attack/hurt/death). New behaviours go in `scripts/entities/enemy.gd` match blocks. |
| Room | template in `data/rooms.json` (odd width/height, door approaches open). `tests/test_data.gd` flood-fills every template. |
| Boon / upgrade / achievement / quest | `data/progression.json` only. |
| Sound | add to `sfx_defs()` in `tools/audiogen/build.py`, rebuild, call `Sfx.play("name")`. |

## Rules that bit us
- Type every variable; `:=` from Variant/dictionary reads is a parse error in 4.7.
- `set_anchors_preset()` on an in-tree Control keeps its zero rect: use `set_anchors_and_offsets_preset()`.
- World-space Labels do not inherit the UI theme: use `UiTheme.label()` (sets font + size 8).
- Do not `watch_signals(Events)` in tests (global autoload keeps recorders alive); connect/disconnect counters instead (see `tests/test_gameplay.gd::_count`).
- A `match` inside a multi-line lambda passed as an argument fails to parse - use a method.
- Input actions are registered at runtime in `scripts/autoload/controls.gd`; the skill linter reports them as undefined (false positive).

## Exports
`python tools/package.py windows|android|ios` - see BUILD_GUIDE.md. Never commit keystores or passwords.
