extends Node
## Run lifecycle and top-level screen flow.

signal screen_changed(screen_name: String)

const SCREENS: Dictionary = {
	"title": "res://scripts/ui/title_screen.gd",
	"hub": "res://scripts/world/hub.gd",
	"dungeon": "res://scripts/world/dungeon_floor.gd",
	"results": "res://scripts/ui/results_screen.gd",
	"select": "res://scripts/ui/new_game_screen.gd",
}

var run: RunState = null
var main: Node = null            # set by scripts/main.gd
var current_screen: String = ""
var last_summary: Dictionary = {}
var debug_show_full_map: bool = false
var god_mode: bool = false
var forced_seed: int = 0          # dev menu override (0 = random)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.boss_killed.connect(_on_boss_killed)
	Events.room_cleared.connect(_on_room_cleared)
	Events.chest_opened.connect(func() -> void: Profile.add_stat("chests"))
	Events.coins_spent.connect(func(n: int) -> void: Profile.add_stat("coins_spent", n))


## Clean shutdown: save, stop audio, let the audio server release playbacks, quit.
func quit_game() -> void:
	Profile.save()
	Sfx.stop_all()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func goto(screen: String, args: Dictionary = {}) -> void:
	if main == null:
		push_error("Game.goto before main scene registered")
		return
	get_tree().paused = false
	current_screen = screen
	var script: GDScript = load(SCREENS[screen]) as GDScript
	var node: Node = script.new()
	if node.has_method("setup"):
		node.call("setup", args)
	main.call("set_screen", node)
	screen_changed.emit(screen)


# --- run lifecycle ---------------------------------------------------------------
func new_seed() -> int:
	if forced_seed != 0:
		return forced_seed
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, 2147483646)


## Starts a dungeon run. With a mission id the run takes that mission's floors,
## difficulty and loot level; without one it is a 3-floor free dive.
func start_run(character_id: String, seed_value: int = 0, mission_id: String = "") -> void:
	run = RunState.new()
	run.seed_value = seed_value if seed_value != 0 else new_seed()
	run.character_id = character_id
	run.difficulty = clampi(int(Settings.get_value("difficulty")), 0, int(Profile.data["difficulty_unlocked"]))
	var m: Dictionary = Db.mission(mission_id)
	if not m.is_empty():
		run.mission_id = mission_id
		run.total_floors = maxi(int(m.get("floors", RunState.TOTAL_FLOORS)), 1)
		run.difficulty = int(m.get("difficulty_tier", 0))
		run.item_level = maxi(int(m.get("item_level", 1)), 1)
		run.rarity_bonus = float(m.get("rarity_bonus", 0.0))
		Profile.mission_record(mission_id)["attempts"] = int(Profile.mission_record(mission_id).get("attempts", 0)) + 1
	run.item_level = maxi(run.item_level, Profile.hero_level(character_id) / 2)
	run.coins = int(Profile.upgrade_bonus("start_coins"))
	var c: CharacterData = Db.character(character_id)
	# The weapon item in the Weapon slot decides the starting gun; else the hero's own.
	var w_item: Dictionary = Inventory.equipped_in(Profile.data, character_id, "weapon")
	var w_id: String = str(ItemGen.template(str(w_item.get("base", ""))).get("weapon", ""))
	if w_id == "" or Db.weapon(w_id) == null:
		w_id = c.start_weapon if c != null else "rift_pistol"
	run.weapons = [w_id]
	run.started_msec = Time.get_ticks_msec()
	Profile.data["selected_character"] = character_id
	Profile.add_stat("runs_started", 1)
	Profile.save()
	goto("dungeon", {"floor": 1})


## Launches a Guild mission with the selected hero. Returns false if locked/unknown.
func start_mission(mission_id: String, seed_value: int = 0) -> bool:
	if Db.mission(mission_id).is_empty() or not Profile.mission_unlocked(mission_id):
		return false
	start_run(Profile.selected_hero(), seed_value, mission_id)
	return true


func next_floor() -> void:
	if run == null:
		return
	Profile.add_stat("floors_cleared")
	Events.floor_cleared.emit(run.floor_index)
	run.floor_index += 1
	Profile.set_stat_max("max_floor", run.floor_index)
	goto("dungeon", {"floor": run.floor_index})


func end_run(victory: bool) -> void:
	if run == null or run.ended:
		return
	run.ended = true
	run.victory = victory
	last_summary = run.summary()
	last_summary["earned_shards"] = Profile.bank_run(last_summary)
	goto("results", last_summary)


func return_to_guild() -> void:
	run = null
	goto("hub")


func abandon_run() -> void:
	end_run(false)


func is_in_run() -> bool:
	return run != null and not run.ended


# --- stat hooks ---------------------------------------------------------------------
func _on_enemy_killed(enemy: Node, is_elite: bool) -> void:
	Profile.add_stat("kills")
	if is_elite:
		Profile.add_stat("elites")
	if run != null:
		run.kills += 1
		if is_elite:
			run.elites += 1
		var cost: int = 1
		if enemy is Enemy and (enemy as Enemy).data != null:
			cost = (enemy as Enemy).data.cost
		_give_run_exp(HeroProgress.enemy_xp(cost, is_elite))


func _on_boss_killed(_id: String) -> void:
	Profile.add_stat("bosses")
	if run != null:
		_give_run_exp(int((Db.guild.get("xp", {}) as Dictionary).get("boss", 100)))


## Experience is permanent the moment it is earned (death keeps it).
func _give_run_exp(amount: int) -> void:
	run.exp_gained += amount
	var lv: int = Profile.grant_exp(run.character_id, amount)
	run.levels_gained += lv
	if lv > 0 and Level.current != null and Level.current.player != null and is_instance_valid(Level.current.player):
		Level.current.player.refresh_equipment()


func _on_room_cleared(_room: Node, flawless: bool) -> void:
	Profile.add_stat("rooms_cleared")
	if flawless:
		Profile.add_stat("flawless_rooms")
	if run != null:
		run.rooms_cleared += 1
