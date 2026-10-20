# Asset manifest & licensing

All assets in `assets/` are **original** and were produced for Hexvault by scripts in this
repository. No third-party art, audio, fonts or code from other games are included.

| Category | Source script | Output | Notes |
| --- | --- | --- | --- |
| Heroes (4 × idle/run/hurt/dash/skill/death) | `tools/artgen/characters.py` | `assets/sprites/heroes/*.png` | 16×16 frames, facing right |
| Enemies (5 × idle/move/attack/hurt/death) | `tools/artgen/enemies.py` | `assets/sprites/enemies/*.png` | Golem 24×24 |
| Boss Ossifex (idle/cast/slam/phase/idle2/cast2/hurt/death) | `tools/artgen/enemies.py` | `assets/sprites/enemies/ossifex.png` | 48×48 |
| Weapons (11) | `tools/artgen/items.py` | `assets/sprites/weapons/*.png` | 24×12, grip pivot (6,7) |
| Projectiles, pickups, FX | `tools/artgen/items.py` | `assets/sprites/{projectiles,pickups,fx}/` | 8×8 / 16×16 / 24×24 / 32×32 |
| Tileset (16 tiles) | `tools/artgen/world.py` | `assets/tiles/dungeon.png` | index contract in `scripts/world/tiles.gd` |
| Props | `tools/artgen/world.py` | `assets/sprites/props/*.png` | |
| UI + touch icons | `tools/artgen/items.py` | `assets/ui/` | |
| Pixel font (95 glyphs) | `tools/artgen/font.py` | `assets/fonts/hexvault.{fnt,png}` | BMFont text format |
| App icons | `tools/artgen/build.py` | `assets/icon/` | 192, 256, 1024, Android adaptive 432 |
| SFX (39) | `tools/audiogen/build.py` | `assets/audio/sfx/*.wav` | 22.05 kHz mono |
| Music (hub, dungeon, boss) | `tools/audiogen/build.py` | `assets/audio/music/*.ogg` | seamless loops |

Machine-readable index: **`assets/manifest.json`** (every sprite sheet: path, frame size,
animations with row/frame count/fps/loop, pivot, content hash) and
`assets/audio/audio_manifest.json`.

Pipeline guarantees (checked by `tools/validate_assets.py`, run by `tools/check.py`):
every pixel comes from the 39-colour master palette in `tools/artgen/px.py`; alpha is
binary (no blur under nearest filtering); sheet sizes match the frame grid; no empty
frames. Generation is deterministic — rerunning produces identical images.

The sheets are plain PNGs and can be opened and hand-edited in LibreSprite/Aseprite; if
you hand-edit, stop regenerating that file (or port the change into the generator), and
keep the frame layout recorded in `manifest.json`.

Third-party *tools* used during development (not shipped in the game): Godot Engine (MIT),
haxqer/godot-skill (MIT) and jame581/GodotPrompter skills (MIT) under `.claude/skills/`,
Pillow, NumPy, ffmpeg/libvorbis (music encoding).
