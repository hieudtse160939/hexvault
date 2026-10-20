# Adventurers' Guild RPG layer

How the Guild hub, missions, randomized equipment, hero levels, the skill tree
and skill books fit on top of the existing dungeon game. Everything is
data-driven; the files below are the only places to edit for content.

## Flow

```
Title (New Game / Continue / Settings / Quit)
  New Game -> new_game_screen.gd (roster of 5) -> Profile.new_game(hero) -> Guild
  Continue -> (enabled only when profile.guild_started) -> Guild
Guild (scripts/world/hub.gd)
  Mission Board / Expedition Gate -> MissionBoard -> Game.start_mission(id) -> dungeon floors
Dungeon (existing generator, rooms, enemies, boss)
  victory portal -> Game.end_run(true)  -> results (rewards) -> Return to the Guild
  death -> DeathScreen -> Game.end_run(false) -> results -> Return to the Guild
```

`Game.start_mission` takes floors, difficulty tier, item level and loot bonus from
the mission. `Game.start_run(hero, seed)` without a mission is still a 3-floor
free dive (used by older tests and `--smoke-dungeon`).

## Data files

| File | Holds |
| --- | --- |
| `data/guild.json` | playable `roster`, starting gold, leveling curve and stat growth, XP per kill, defense constants, death gold policy, `missions`, guild `ranks` |
| `data/items.json` | slots, stat definitions and limits, rarities (weight, affix count, stat and value multipliers, colour, letter tag), affixes (stat, range, allowed slots, min item level), equipment templates, skill books, loot tables, bag size, shop rules |
| `data/skill_trees.json` | per-hero talent trees (generated once by a script; edit freely): 3 branches x 3 nodes, ranks, prerequisites, per-rank stats |

## Code

| Script | Role |
| --- | --- |
| `scripts/items/item_gen.gd` (`ItemGen`) | rolls instances from templates with a given RNG (seeded = reproducible), rarity picking, loot tables, validation, descriptions |
| `scripts/items/inventory.gd` (`Inventory`) | ownership rules: add (unique `itNNNNNN` uid), equip / unequip / replace, sell, `sanitize()` after loading |
| `scripts/core/hero_progress.gd` (`HeroProgress`) | per-hero record: level, exp, skill points, talents, learned skills, active skill slot, reading books |
| `scripts/core/hero_stats.gd` (`HeroStats`) | the single definition of final stats (order below) |
| `scripts/entities/item_pickup.gd` | dropped items in the dungeon; walk over to collect once |
| `scripts/entities/training_dummy.gd` | Guild dummies: real hurtbox, damage numbers, DPS |
| `scripts/ui/inventory_panel.gd`, `shop_panel.gd`, `mission_board.gd`, `skill_tree_panel.gd`, `new_game_screen.gd`, `item_ui.gd` | the screens |

## Final stats (HeroStats)

1. **Base**: `leveling.base` (Attack 10, Defense 0, Crit 5 %, Crit Damage x2) + hero data (HP, shield, crit, attack speed, move speed, cooldown) + `growth` x (level - 1).
2. **Flat**: + every equipped item (template stats + affixes) + flat talent ranks.
3. **Percent**: Attack x (1 + attack_pct), Defense x (1 + defense_pct), Max HP x (1 + hp_pct).
4. **Clamp** to `HeroStats.LIMITS` (crit <= 75 %, crit damage 1..4, attack speed -50..+100 %, move speed -30..+50 %, skill haste <= 50 %).

Always recomputed from the sources, never accumulated. The player turns them
into combat modifiers in `Player.recompute_stats()`: weapon and skill damage x
(Attack / 10), crit chance, crit multiplier, fire rate (+attack speed), move
speed, skill cooldown (-skill haste), skill damage (+skill power), incoming
damage x (1 - Defense / (Defense + 40)) capped at 60 % with the fraction kept as
a chance (`Damage.mitigate`), max HP and shield. Raising max HP mid-run (equip
from the pause menu, level-up) raises current HP by the same amount.

## Reward policy

- Items and experience are permanent the moment they are picked up / earned.
- Run coins become gold at the end: 100 % on victory, 50 % (`death_gold_keep`) on defeat or retreat.
- Mission rewards (gold, exp, shards) and completion are granted only on victory, once per run (`RunState.ended` guards `Game.end_run`).
- The Guild shop restocks after each finished expedition; a sold entry cannot be bought again.

## Save (profile v4)

`SaveManager.PROFILE_VERSION = 4`. New keys: `guild_started`, `gold`, `items`
(uid -> exact instance), `bag`, `next_uid`, `missions`, `expeditions`, `shop`, and
per-hero `level / exp / sp / tree / skills / active_skill / equipment / starter_kit`.
`migrate_profile_v3` keeps everything from older saves. `Profile.repair()` runs
`Inventory.sanitize()` after loading (drops invalid items, fixes duplicate or
dangling references; never re-rolls). Pct rolls are stored with 3 decimals so a
JSON round trip is exact. New Game first copies the old file to
`profile.previous.save`.

## Adding content

| Want | Do |
| --- | --- |
| Equipment base | template in `data/items.json` (`slot`, `base` ranges, `rarity` range, `level` range, `value`; weapons add `"weapon": "<weapon id>"`) |
| Affix | entry in `affixes` with its stat, range and slots |
| Skill book | entry in `books` with `"skill": "<skill id>"` (any hero's skill) or `"kind": "points"` |
| Mission | entry in `data/guild.json` `missions` (floors, difficulty_tier, item_level, rarity_bonus, rewards, unlock) |
| Playable hero | add the id to `roster` and a tree to `data/skill_trees.json` (`Db.rpg_problems()` reports what is missing) |
