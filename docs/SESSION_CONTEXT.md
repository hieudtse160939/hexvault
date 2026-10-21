# Session context (handoff)

_Branch `claude/hd-pixel-art-roguelike-6d4lcx` · last updated 2026-10-20 · last pushed commit `99615cc`_

## Project
Hexvault: Godot 4.7.2 / GDScript top-down action game. First master prompt: HD pixel art,
anime RPG style roguelike with a data-driven hero roster. Second master prompt ("ANIME FANTASY
DUNGEON CRAWLER RPG"): Adventurers' Guild hub + dungeon expeditions + randomized equipment +
persistent progression - implemented, see below and `docs/GUILD_RPG.md`.
Git rule from the user: do not commit/push unless the user explicitly asks.
The user writes in Vietnamese; answer in Vietnamese.

## Commands
```bash
python tools/check.py                 # assets + asset QA + import + 86 tests (must be ALL CHECKS PASSED)
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
  ossifex boss), `weapons.py` (all 14 HD weapons), `guild.py` (guild tiles 16-23, furniture, dummy, item icons), `tiles.py` (HD tileset), `icons.py`.
- **QA:** `tools/validate_assets.py` (palette, binary alpha, grid) + `tools/asset_qa.py`
  (clipping, anchor drift, jitter, noise, colour budget 56, metadata) -> `docs/qa/`.
- **External art:** `tools/artgen/import_external.py` (pixel-art-studio cleanup: background
  key-out, true-pixel recovery, palette lock) reading `art_src/raw/`.
- **Characters:** 12 heroes / 12 classes in `data/characters.json` + `data/classes.json`;
  skills `scripts/characters/skills/<id>.gd`, passives `scripts/characters/passives/<id>.gd`
  (HeroSkill / HeroPassive hooks, found by id); mastery XP per run; save schema v3 with
  migration (now v4); Hero Shrine (paging, archetype filter, sort, search), listing only the
  Guild roster. Guide: `docs/ADDING_CHARACTERS.md`.
- **Weapons:** 14, all HD. In-run: treasure-room weapon chest and dungeon shop
  (`WeaponPickup.roll`: common 10, rare 7, epic 2.5+floor, legendary 0.5+0.5*floor, unlocked only).
  Permanent: every weapon is also an equipment template (`w_<id>` in `data/items.json`); the item in
  the Weapon slot decides the starting gun of an expedition.
- **Builds:** `build/Hexvault-0.9.0-linux-x86_64.tar.gz` (smoke-run OK, exit 0) and
  `build/Hexvault-0.9.0-windows-x64.zip` (exported, not run: no Windows here), both from `99615cc`,
  sent to the user. Android/iOS not built.

## Adventurers' Guild RPG (master prompt "ANIME FANTASY DUNGEON CRAWLER RPG")
Implemented: Title New Game / Continue, 5-hero New Game selection, playable Guild hall (reception,
mission board + gate, equipment rack, skill library, shop, training dummies, hero shrine, forge,
quest board), 3 missions on the existing dungeon, randomized equipment (6 slots, 5 rarities, 13
affixes, 31 templates incl. all 14 weapons), HeroStats, levels/XP, skill trees (5 x 9 talents),
12 skill books + Tome of Insight, loot tables, gold economy, save v4. Design: `docs/GUILD_RPG.md`.
Tests: `tests/test_rpg.gd` (21), `tests/test_guild.gd` (7, full expedition loop through real screens).
Roster = duelist, assassin, warden, pyromancer, necromancer (user: more heroes later).
Key code: `scripts/items/item_gen.gd`, `scripts/items/inventory.gd`, `scripts/core/hero_stats.gd`,
`scripts/core/hero_progress.gd`, `scripts/world/hub.gd`, `scripts/ui/{inventory_panel,shop_panel,
mission_board,skill_tree_panel,new_game_screen}.gd`, `Game.start_mission / return_to_guild`.
Reward policy: items + XP permanent on pickup; coins -> gold (100 % win, 50 % loss); mission
rewards only on victory. Guild NPCs reuse non-roster hero sheets (Rime = cryomancer, Cog = tinker).
Verified: 86/86 tests, asset QA 0 errors, visual tour screenshots (Xvfb). Not verified: hands-on
play by a human, Windows build run.

Known limitations / next ideas
- Supplied hero art is downscaled ~3.3x (needed for game scale) and quantized to 52 colours
  (pipeline choice, not required) - the brief asks to avoid unnecessary quantization: revisit
  `tools/artgen/ref_heroes.py` / `ref_runs.py` (MAX_COLOURS) and the asset-QA colour budget.
- No separate attack animation for heroes (weapons show attacks); idle/dash/skill/hurt/death are
  cut-out animations of the reference pose, run is the user's 8-frame sheet.
- One boss (Ossifex) and one dungeon tileset for all missions.
- Exit leak warning of the ogg music stream comes from the dummy audio driver in the container.

## Still 16 px (to convert)
Props (crate, barrel, pillar, lamp, chest, portal, fountain, statue, pedestal, turret,
barrier, spawn rune, shadows), pickups, projectiles, FX, UI icons other than skills, title/hub art.

## Open requests from the user
1. DONE: hero sprites now come from the user's reference sheet
   `art_src/raw/heroes_reference.png` via `tools/artgen/ref_heroes.py` (shared 3.3x downscale,
   per-hero palette, ink outline, cut-out animation from the single pose). Kit art is the
   fallback when the file is absent.
   Real 8-frame run cycles from the user (Gemini sheets, copied from `main` into
   `art_src/raw/runs/<id>_run.png`) replace the cut-out run for duelist, assassin, warden,
   pyromancer, necromancer (`tools/artgen/ref_runs.py`).
2. DONE: Guild RPG master prompt + "đa dạng vũ khí, skill, sách kỹ năng, cây kỹ năng; nhân vật
   chỉ 5 người, mai mốt thêm sau".
3. Waiting: the user's next prompt (more heroes later).

## Style decisions made with the user
- Anime RPG chibi, heads in **profile** (same facing as bodies, one eye), not 3/4 with two eyes.
- Eyes from hand-made pixel templates, light flat-shaded skin.
- Docs in `docs/` (AUDIT_REPORT.md in Vietnamese; ART_STYLE_GUIDE.md, ADDING_CHARACTERS.md in English).

## IN PROGRESS: "World scale & combat animation directive" (3rd master prompt)
User rule: when quota runs low, stop, update this file and commit + push everything.
Directive priorities (in order): animation asset audit -> weapon-aware animation architecture ->
staff casting that reads as magic (not gunfire) -> other weapon categories -> equipment/skill
integration (weapon-conditional talents, class weapon rules) -> tests + visual QA -> then world:
region architecture (World map > regions > towns/landmarks > quests/dungeons), first ONE complete
playable region (e.g. Kingdom of Dawn outskirts + Whispering Woods) reached on foot from the Guild,
then expand; skill-tree UI/data that scales to hundreds of nodes; crafting/upgrades; endgame.
Audit facts: hero sheets (128 px, density 4, pivot 64,112) have idle 6, run 8, dash 4, skill 6,
hurt 3, death 8 frames, right-facing only (flip_h for left). NO attack frames for any hero.
Weapons are single-frame 96x48 sprites (pivot 24,28, muzzle in manifest) on a rotating holder;
every ranged weapon used the same gun recoil + fx_muzzle; melee = instant Combat.melee + fx_slash.
Plan: `category` per weapon (gun, bow, staff, wand, orb, sword, dagger, spear, heavy) in
data/weapons.json + attack profiles (windup / release / recovery, motion style, cast FX) in a
WeaponAnimator; projectiles/hits spawn at the release frame from the manifest muzzle point.
Progress (checkpoint 1): DONE weapon `style` field + data/weapon_styles.json profiles; Weapon
state machine READY/WINDUP/ACTIVE/RECOVER (scripts/combat/weapon.gd): aim committed at attack
start, hit/projectile only at release/contact, emission from the posed weapon tip, cancel on swap
and death; procedural motions per style; staff/wand/orb = magic (charge glow + ring at tip, cast
body pose "skill", sparkle burst, no recoil, no gun muzzle flash); Thornbow has real draw/release
frames; new weapons Shadow Fang (dagger) and Wardpike (spear) with HD art + item templates; class
weapon rules (data/classes.json "weapons", Inventory.style_allowed). 86/86 tests pass.
NEXT: tests for styles; weapon-conditional talents (node "requires_weapon"); scalable skill-tree
UI; anim coverage report docs/qa/animation_coverage.md; visual QA screenshots per style; then the
world-region architecture.
Progress (checkpoint 2): DONE weapon-conditional talents (`requires_weapon` in
data/skill_trees.json, one "Weapon Mastery" node per hero; HeroStats.for_hero(d, hero, style);
recompute on swap/load), scrollable skill-tree UI, equip refusal message for class rules,
tests/test_weapon_styles.gd (9), tools/anim_coverage.py -> docs/qa/animation_coverage.md,
visual QA `--style-tour=<dir>` (scripts/debug/style_tour.gd, slow-motion captures per phase;
contact sheets docs/qa/weapon_styles_1.png / _2.png - verified by eye: staff raise+charge+tip
release+ring, wand flick, lantern raise, bow draw/release frames, sword arc, dagger stab, spear
thrust, mace overhead slam, gun recoil+muzzle). check.py: 95/95 tests, ALL CHECKS PASSED.
NOT DONE (next session): open-world region architecture (World > regions > towns/landmarks >
quests/dungeons), first playable region reached on foot from the Guild door (outdoor HD tiles:
grass/path/trees/water/cliffs/buildings; roaming enemies; landmarks; a cave entrance into the
existing dungeon generator; region boss; world-state save), hundreds-of-nodes skill tree content
(UI already scrolls), crafting/upgrades, endgame; dedicated hero cast/attack sheets (art needed).
Tip: start a NEW session with this file - a fresh context is much cheaper per step.
Guild visual/UI pass (2026-10-21): long flat-shaded floorboards (tiles 16-17), new HD props
guild_fireplace (4-frame fire), guild_bench, guild_bar, guild_banner, guild_rug (floor decal);
hub.gd: warm CanvasModulate + additive light pools (lanterns, hearth, candles, gate), benches by
tables, banners at the gate; HUD plate (portrait, name/level, rank, EXP bar, gold/shards, skill
points) and quick buttons (Missions / Bag / Skills / Menu); guild menus use UiTheme.guild_box()
(wood + brass). Screenshot docs/qa/guild_hall.png. 95/95 tests.
Guild MAP (2026-10-21, user: "chia từng map làm từ từ, làm map guild trước" = build the world map by
map, Guild first): data/maps/guild.json (32x22 after the user found 40x29 too wide, 6 rooms joined by doorways: Hall of Heroes,
Great Hall, Armory & Library, Training Yard, Guild Shop, Entrance) built by the shared
scripts/world/map_loader.gd (legend -> floor tiles, auto walls with wooden wall-top tile 24,
decals, props, NPCs, room labels, light pools, mood); hub.gd only wires station ids to services.
MapLoader.problems() validated in tests/test_guild.gd. Screens docs/qa/guild_map.png. 96/96 tests.
NEXT MAP (when the user asks): town outside the Guild (Kingdom of Dawn) as data/maps/<id>.json
+ outdoor tiles; the Entrance gate is where a map transition would go.
Guild redesign to the user's reference art (2026-10-21): open-plan hall (data/maps/guild.json v2,
34x25: training, missions, lounge, library, shop stall with striped awning, armory & forge,
courtyard with steps/hedges/bushes) divided by low railings ("rails" in the map file), tall north
wall with windows, compass rug + tables on blue rugs, chandelier; new art in tools/artgen/hd/guild.py
(rails, stall, forge, bush, long table, rugs, chandelier, target, armchair, round table, window,
grass, hedge tiles 25-27); talkable NPCs with speech bubbles (scripts/entities/guild_npc.gd);
HUD = portrait + HP/SHIELD bars (game has no MP) + "Lv. N Class" + Active Quests from real data;
inventory = ornate frame (tools/artgen/ui_art.py 9-patches), HEXVAULT plate, paper doll with 6 slots,
bag grid, tooltip, EQUIP/UNEQUIP/SELL/CLOSE colour buttons. Comparison docs/qa/guild_vs_reference.png.
97/97 tests.
