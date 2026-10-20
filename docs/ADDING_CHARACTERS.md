# Adding a hero

A hero is **data + two small scripts + an art module**. Nothing in `Player`, the HUD or the
Hero Shrine changes. Tests pick the new hero up automatically.

## 1. Data — `data/characters.json`

```json
{
 "id": "ember_knight", "name": "Aster", "title": "Ember Knight", "class": "paladin", "difficulty": 2,
 "description": "One or two sentences the player reads in the Hero Shrine.",
 "sprite": "hero_ember_knight", "start_weapon": "ember_blade", "tags": ["melee", "fire"],
 "stats": {"max_hp": 7, "max_armor": 4, "speed": 94, "crit": 0.05},
 "skill": {"id": "ember_charge", "name": "Ember Charge", "cooldown": 10.0, "duration": 0.4,
           "icon": "icon_skill_ember_charge", "description": "...", "params": {"damage": 6}},
 "passive": {"id": "smoulder", "name": "Smoulder", "description": "...", "params": {"chance": 0.3}},
 "unlock": {"type": "shards", "cost": 450},
 "mastery": [
  {"level": 2, "xp": 120, "bonus": {"crit": 0.03}, "text": "+3% crit"},
  {"level": 3, "xp": 300, "bonus": {"max_armor": 1}, "text": "+1 armour"}
 ]
}
```

- `class` must exist in `data/classes.json` (add one there if needed: id, name, archetype,
  colour, description). Archetypes drive the Hero Shrine filter.
- `stats` keys: `max_hp, max_armor, speed, crit, damage_mult, fire_rate_mult, reload_mult,
  cooldown_mult, dash_cd_mult, dodge, pierce, magnet, coin_mult, armor_regen_mult, blast_mult,
  move_speed_mult` (`CharacterData.STAT_KEYS`). Unknown keys fail validation.
- `unlock.type`: `default`, `shards` (with `cost`) or `achievement` (with an achievement `id`).
- `mastery` levels must increase; bonuses use the same stat keys. XP per run =
  floor × 20 + rooms × 4 + 60 for a win.

## 2. Skill — `scripts/characters/skills/<skill id>.gd`

```gdscript
extends HeroSkill
## Aster - EMBER CHARGE: dash forward and burn what you pass.

func activate() -> void:
	var dir: Vector2 = player.move_or_aim_direction()
	player.global_position += dir * player.ray_distance(dir, float(param("distance", 60.0)))
	var info: HitInfo = HitInfo.make(Damage.compute(int(param("damage", 6)), damage_mult(), false),
			Vector2.ZERO, true, player.global_position)
	info.element = "fire"
	info.status_chance = 1.0
	Combat.melee(player.global_position, dir, 30.0, 360.0, info)
```

Hooks (all optional): `can_activate`, `activate`, `tick(delta)` while active, `end`,
`modify(key, value)` for modifiers while active, `keeps_invulnerable`, `hides_player`,
`modify_outgoing(info, target)`. The Player owns cooldown (with cooldown reduction) and the
active duration from data. Useful helpers: `player.grant_invulnerability`,
`player.ray_distance`, `player.move_or_aim_direction`, `player.heal`, `Combat.melee/explode/chain`,
`level().pool` for projectiles, `level().add_entity` for summons.

Elements are `fire`, `frost`, `shock`, `hex` (see `StatusEffects`).

## 3. Passive — `scripts/characters/passives/<passive id>.gd`

```gdscript
extends HeroPassive

func on_kill(enemy: Node) -> void:
	if randf() < float(param("chance", 0.3)):
		Combat.explode((enemy as Node2D).global_position, 24.0, 3, false, true)
```

Hooks: `tick`, `modify(key, value)`, `modify_outgoing(info, target)`, `negate_hit(info)`,
`on_kill`, `on_damaged`, `on_dash`, `on_skill`, `on_room_entered`, `on_room_cleared`.

## 4. Art — `tools/artgen/hd/heroes/<id>.py`

Build the hero with the shared kit so anatomy, light, outline, anime face and animation
timing match every other hero (see `docs/ART_STYLE_GUIDE.md`):

```python
import kit
from kit import Look

PR = kit.proportions(k=1.25)
PIVOT = (int(PR.cx), int(PR.ground))
FPS, LOOP = kit.FPS, kit.LOOP
SPEC = {"id": "ember_knight", "sprite": "hero_ember_knight", "version": 1,
        "source": "procedural: tools/artgen/hd/heroes/ember_knight.py"}

LOOK = Look(skin="skin_fair", hair="hair_red", iris="amber", torso="crimson", trim="amber",
            head="hair", hair_style="spiky", body="armor", torso_form="plate", cape="flame")

def animations() -> dict:
    return kit.animations(LOOK, PR, kit.skill_slash())   # or the default cast pose
```

Give it a silhouette of its own (head gear, body, cape, a back prop through `extra_back`,
`extra_head`, `extra_front`) and its own iris/hair colour. Register it in
`tools/artgen/hd/hd_registry.py::HEROES`. A skill icon goes in `tools/artgen/hd/icons.py`.

## 5. Build and verify

```bash
python tools/artgen/build.py        # sheet + manifest entry (density, pivot, version, source)
python tools/check.py               # palette, QA (clipping, anchor, noise), data validation, all tests
$GODOT_BIN --path . --resolution 1920x1080 -- --tour=<abs dir> --tour-hero=ember_knight
```

`tests/test_characters.gd` checks every hero: schema, class, scripts, sprite animations,
unlock references; spawns it in an arena, casts the skill through its full duration and
calls every passive hook. Add a focused test when the hero has a rule worth pinning down.
