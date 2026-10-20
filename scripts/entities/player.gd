class_name Player
extends CharacterBody2D
## The controllable hero.

signal died

enum State { NORMAL, DASH, DEAD }

const DASH_SPEED: float = 270.0
const DASH_TIME: float = 0.17
const BASE_DASH_CD: float = 0.9
const MAX_WEAPONS: int = 2
const INTERACT_RANGE: float = 22.0

var character: CharacterData
var health: Health
var hurtbox: Hurtbox
var body: AnimatedSprite2D
var weapon_holder: Node2D
var weapons: Array[Weapon] = []
var current: int = 0
var state: int = State.NORMAL
var speed: float = 96.0
var facing: int = 1
var skill_cd_left: float = 0.0
var skill_active_left: float = 0.0
var input_enabled: bool = true
var flawless_room: bool = true

var _dash_left: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _knock: Vector2 = Vector2.ZERO
var _last_move: Vector2 = Vector2.RIGHT
var _aim: Vector2 = Vector2.RIGHT
var _anim_lock: float = 0.0
var _ghost_t: float = 0.0
var _shield_vis: Node2D = null
var _interact_target: Node = null
var _mods: Dictionary = {}


static func create(c: CharacterData) -> Player:
	var p: Player = Player.new()
	p.character = c
	return p


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1 << 1
	collision_mask = Level.WORLD_MASK | Level.BREAKABLE_MASK
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 4.0
	cs.shape = shape
	cs.position = Vector2(0, 4)
	add_child(cs)
	var shadow: Sprite2D = Sprite2D.new()
	SpriteLib.apply(shadow, "prop_shadow_s")
	shadow.position = Vector2(0, 7)
	shadow.z_index = -1
	add_child(shadow)
	body = AnimatedSprite2D.new()
	SpriteLib.apply(body, character.sprite)
	body.position = Vector2(0, -1)
	FX.make_flashable(body)
	add_child(body)
	body.play(&"idle")
	weapon_holder = Node2D.new()
	weapon_holder.position = Vector2(0, 2)
	add_child(weapon_holder)
	health = Health.new()
	add_child(health)
	hurtbox = Hurtbox.create(self, 5.0, true)
	hurtbox.position = Vector2(0, 1)
	add_child(hurtbox)
	recompute_stats(true)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.changed.connect(func(_a: int, _b: int, _c: int, _d: int) -> void: Events.player_stats_changed.emit())


## Builds weapons from the run's inventory.
func load_run_weapons(run: RunState) -> void:
	for w: Weapon in weapons:
		w.queue_free()
	weapons.clear()
	for id: String in run.weapons:
		var d: WeaponData = Db.weapon(id)
		if d != null:
			_add_weapon_node(d, int(run.weapon_ammo.get(id, -1)))
	current = 0
	_refresh_weapon_visibility()


func _add_weapon_node(d: WeaponData, ammo_left: int = -1) -> Weapon:
	var w: Weapon = Weapon.new()
	w.owner_actor = self
	weapon_holder.add_child(w)
	w.setup(d, ammo_left)
	w.ammo_changed.connect(func(cur: int, mx: int, rl: bool) -> void:
		if weapons.size() > current and weapons[current] == w:
			Events.ammo_changed.emit(cur, mx, rl))
	weapons.append(w)
	return w


func current_weapon() -> Weapon:
	return weapons[current] if current < weapons.size() else null


func _refresh_weapon_visibility() -> void:
	for i: int in weapons.size():
		weapons[i].visible = i == current
		weapons[i].set_process(i == current)
	var w: Weapon = current_weapon()
	if w != null:
		Events.ammo_changed.emit(w.ammo, w.data.magazine, w.reloading)
	Events.weapon_changed.emit()


func swap_weapon() -> void:
	if weapons.size() < 2:
		return
	current = (current + 1) % weapons.size()
	Sfx.play("ui_move")
	_refresh_weapon_visibility()


## Picks up a weapon; returns the id of the weapon dropped (or "").
func give_weapon(id: String) -> String:
	var d: WeaponData = Db.weapon(id)
	if d == null:
		return ""
	var dropped: String = ""
	if weapons.size() >= MAX_WEAPONS:
		var old: Weapon = weapons[current]
		dropped = old.data.id
		weapons.remove_at(current)
		old.queue_free()
		var w: Weapon = _add_weapon_node(d)
		weapons.erase(w)
		weapons.insert(current, w)
	else:
		_add_weapon_node(d)
		current = weapons.size() - 1
	_sync_run_weapons()
	_refresh_weapon_visibility()
	return dropped


func _sync_run_weapons() -> void:
	if Game.run == null:
		return
	Game.run.weapons.clear()
	for w: Weapon in weapons:
		Game.run.weapons.append(w.data.id)


func store_run_state() -> void:
	if Game.run == null:
		return
	_sync_run_weapons()
	Game.run.weapon_ammo.clear()
	for w: Weapon in weapons:
		Game.run.weapon_ammo[w.data.id] = w.ammo
	Game.run.hp = health.hp
	Game.run.armor = health.armor


# --- stats ------------------------------------------------------------------------
func recompute_stats(initial: bool = false) -> void:
	var run: RunState = Game.run
	var b: Callable = func(key: String) -> float: return run.boon_total(key) if run != null else 0.0
	_mods = {
		"damage_mult": b.call("damage_mult"),
		"fire_rate_mult": b.call("fire_rate_mult"),
		"reload_mult": b.call("reload_mult"),
		"crit": b.call("crit") + Profile.upgrade_bonus("crit"),
		"pierce": b.call("pierce"),
		"extra_shots": b.call("extra_shots"),
		"leech": b.call("leech"),
		"magnet": b.call("magnet"),
		"coin_mult": b.call("coin_mult"),
		"free_ammo": 0.0,
	}
	speed = character.speed * (1.0 + float(b.call("speed_mult")))
	var max_hp: int = character.max_hp + int(Profile.upgrade_bonus("max_hp")) + int(b.call("max_hp"))
	var max_armor: int = character.max_armor + int(Profile.upgrade_bonus("max_armor")) + int(b.call("max_armor"))
	if initial:
		health.setup(max_hp, max_armor, 0.8)
		if run != null and run.hp > 0:
			health.hp = mini(run.hp, max_hp)
			health.armor = clampi(run.armor, 0, max_armor)
	else:
		health.set_max(max_hp, max_armor)
	health.regen_mult = 1.0 + float(b.call("armor_regen_mult"))
	Events.player_stats_changed.emit()


func weapon_mod(key: String) -> float:
	var v: float = float(_mods.get(key, 0.0))
	var overclocked: bool = skill_active_left > 0.0 and character.skill == "overclock"
	if overclocked and key == "fire_rate_mult":
		v += 1.0
	elif overclocked and key == "free_ammo":
		v = 1.0
	return v


func dash_cooldown() -> float:
	var run: RunState = Game.run
	var m: float = 1.0 - Profile.upgrade_bonus("dash")
	if run != null:
		m += run.boon_total("dash_cd_mult")
	return BASE_DASH_CD * clampf(m, 0.3, 2.0)


# --- aiming ------------------------------------------------------------------------
func aim_direction() -> Vector2:
	return _aim


func _update_aim() -> void:
	var lvl: Level = Level.current
	var dev: int = Controls.device
	var stick: Vector2 = Controls.stick_aim()
	var assist: bool = bool(Settings.get_value("aim_assist"))
	if dev == Controls.Device.KEYBOARD_MOUSE:
		var m: Vector2 = get_global_mouse_position() - global_position
		if m.length() > 2.0:
			_aim = m.normalized()
		return
	if stick != Vector2.ZERO:
		_aim = stick.normalized()
		if assist and lvl != null:
			var t: Node2D = lvl.nearest_enemy(global_position, 200.0, true)
			if t != null:
				var to_t: Vector2 = (t.global_position - global_position).normalized()
				if absf(_aim.angle_to(to_t)) < deg_to_rad(22.0):
					_aim = to_t
		return
	# No explicit aim: auto-target (touch / gamepad) or face movement.
	if assist and lvl != null:
		var t2: Node2D = lvl.nearest_enemy(global_position, 220.0, true)
		if t2 != null:
			_aim = (t2.global_position - global_position).normalized()
			return
	if _last_move != Vector2.ZERO:
		_aim = _last_move.normalized()


# --- frame ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = velocity.move_toward(Vector2.ZERO, 400 * delta)
		move_and_slide()
		return
	_dash_cd -= delta
	_anim_lock -= delta
	if skill_cd_left > 0.0:
		skill_cd_left = maxf(skill_cd_left - delta, 0.0)
		Events.skill_cooldown_changed.emit(skill_cd_left, character.skill_cooldown)
	if skill_active_left > 0.0:
		skill_active_left -= delta
		_skill_tick(delta)
		if skill_active_left <= 0.0:
			_skill_end()
	var move: Vector2 = Controls.move_vector() if input_enabled else Vector2.ZERO
	if move.length() > 0.1:
		_last_move = move
	_update_aim()
	if state == State.DASH:
		_dash_left -= delta
		velocity = _dash_dir * DASH_SPEED
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.03
			_spawn_ghost()
		if _dash_left <= 0.0:
			state = State.NORMAL
			if skill_active_left <= 0.0 or character.skill != "bulwark":
				health.invulnerable = false
	else:
		var target_v: Vector2 = move * speed
		velocity = velocity.move_toward(target_v, speed * 12.0 * delta)
	velocity += _knock
	_knock = _knock.move_toward(Vector2.ZERO, 600.0 * delta)
	move_and_slide()
	# weapon + facing
	for w: Weapon in weapons:
		w.set_aim(_aim)
	if absf(_aim.x) > 0.15:
		facing = 1 if _aim.x > 0.0 else -1
	body.flip_h = facing < 0
	weapon_holder.position = Vector2(2 * facing, 2)
	if input_enabled:
		_handle_actions()
	_update_interact()
	_update_anim()


func _handle_actions() -> void:
	var w: Weapon = current_weapon()
	if w != null and Controls.fire_held() and state != State.DASH:
		w.try_fire(_aim, true)
	if Input.is_action_just_pressed("reload") and w != null:
		w.start_reload()
	if Input.is_action_just_pressed("swap_weapon"):
		swap_weapon()
	if Input.is_action_just_pressed("dash"):
		try_dash()
	if Input.is_action_just_pressed("skill"):
		try_skill()
	if Input.is_action_just_pressed("interact"):
		try_interact()


func try_dash() -> bool:
	if state != State.NORMAL or _dash_cd > 0.0:
		return false
	state = State.DASH
	_dash_left = DASH_TIME
	_dash_cd = dash_cooldown()
	_dash_dir = (_last_move if Controls.move_vector().length() > 0.1 else _aim).normalized()
	health.invulnerable = true
	Sfx.play("dash")
	return true


func dash_ready_ratio() -> float:
	return 1.0 - clampf(_dash_cd / dash_cooldown(), 0.0, 1.0)


func _spawn_ghost() -> void:
	if Settings.reduced_effects():
		return
	var lvl: Level = Level.current
	if lvl == null:
		return
	var g: Sprite2D = Sprite2D.new()
	g.texture = body.sprite_frames.get_frame_texture(body.animation, body.frame)
	g.flip_h = body.flip_h
	g.scale = body.scale
	g.texture_filter = body.texture_filter
	g.global_position = body.global_position
	g.modulate = Color(0.45, 0.95, 0.9, 0.55)
	lvl.fx_layer.add_child(g)
	var tw: Tween = g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.2)
	tw.tween_callback(g.queue_free)


# --- skills -------------------------------------------------------------------------
func try_skill() -> bool:
	if skill_cd_left > 0.0 or state == State.DEAD:
		return false
	skill_cd_left = character.skill_cooldown
	skill_active_left = character.skill_duration
	_anim_lock = 0.3
	body.play(&"skill")
	Sfx.play("skill")
	FX.burst("sparkle_teal", global_position + Vector2(0, -8))
	match character.skill:
		"bulwark":
			health.invulnerable = true
			_shield_vis = _make_shield()
			add_child(_shield_vis)
		"phase":
			_do_phase()
		"turret":
			var lvl: Level = Level.current
			if lvl != null:
				var t: Turret = Turret.create(global_position + _aim * 10.0, character.skill_duration, self)
				lvl.add_entity(t)
		"overclock":
			FX.float_text(global_position, "OVERCLOCK", Color("#f2b23a"))
	return true


func _skill_tick(_delta: float) -> void:
	if character.skill == "bulwark":
		var lvl: Level = Level.current
		if lvl != null:
			lvl.pool.erase_hostile_in(global_position, 34.0)


func _skill_end() -> void:
	if character.skill == "bulwark":
		health.invulnerable = state == State.DASH
		if _shield_vis != null:
			_shield_vis.queue_free()
			_shield_vis = null


func _make_shield() -> Node2D:
	var n: Node2D = Node2D.new()
	var ring: Line2D = Line2D.new()
	var pts: PackedVector2Array = []
	for i: int in 25:
		pts.append(Vector2.from_angle(i * TAU / 24.0) * 30.0)
	ring.points = pts
	ring.width = 1.0
	ring.default_color = Color("#6fb0ff")
	n.add_child(ring)
	var tw: Tween = n.create_tween().set_loops()
	tw.tween_property(ring, "modulate:a", 0.4, 0.25)
	tw.tween_property(ring, "modulate:a", 1.0, 0.25)
	return n


func _do_phase() -> void:
	var lvl: Level = Level.current
	var dir: Vector2 = (_last_move if Controls.move_vector().length() > 0.1 else _aim).normalized()
	var dist: float = 72.0
	if lvl != null:
		var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, global_position + dir * dist,
				Level.WORLD_MASK | Level.BREAKABLE_MASK)
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			dist = maxf(global_position.distance_to(hit["position"]) - 7.0, 0.0)
	FX.burst("puff", global_position)
	global_position += dir * dist
	health.invulnerable = true
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		if state != State.DASH and not (skill_active_left > 0.0 and character.skill == "bulwark"):
			health.invulnerable = false)
	FX.burst("explosion", global_position, 0.0, 0.8)
	FX.shake(2.0)
	var info: HitInfo = HitInfo.make(Damage.compute(8, 1.0 + float(_mods.get("damage_mult", 0.0)), false), Vector2.ZERO, true, global_position)
	info.element = "hex"
	info.status_chance = 1.0
	Combat.melee(global_position, dir, 34.0, 360.0, info)


# --- damage --------------------------------------------------------------------------
func receive_hit(info: HitInfo) -> bool:
	if state == State.DEAD:
		return false
	if Game.god_mode:
		return false
	var taken: int = health.take(info)
	if taken <= 0:
		return false
	_knock = info.knockback.limit_length(160.0)
	return true


func _on_damaged(amount: int, _info: HitInfo) -> void:
	flawless_room = false
	if Game.run != null:
		Game.run.damage_taken += amount
	Events.player_damaged.emit(amount)
	FX.flash(body, Color("#e8455a"), 0.18)
	FX.shake(5.0)
	FX.hit_stop(0.06)
	Sfx.play("player_hurt")
	_anim_lock = 0.2
	body.play(&"hurt")
	# Visible invulnerability blink.
	var tw: Tween = body.create_tween()
	for i: int in 4:
		tw.tween_property(body, "modulate:a", 0.35, 0.08)
		tw.tween_property(body, "modulate:a", 1.0, 0.08)


func _on_died() -> void:
	state = State.DEAD
	health.invulnerable = true
	for w: Weapon in weapons:
		w.visible = false
	body.play(&"death")
	Sfx.play("player_die")
	FX.shake(8.0)
	Events.player_died.emit()
	died.emit()


func revive() -> void:
	state = State.NORMAL
	health.invulnerable = false
	health.revive(health.max_hp / 2 + 1)
	health.restore_armor(health.max_armor)
	_refresh_weapon_visibility()
	body.play(&"idle")
	var lvl: Level = Level.current
	if lvl != null:
		lvl.pool.erase_hostile_in(global_position, 200.0)
		Combat.melee(global_position, Vector2.RIGHT, 48.0, 360.0, HitInfo.make(5, Vector2.ZERO, true, global_position))
	FX.burst("explosion", global_position)


func is_alive() -> bool:
	return state != State.DEAD


func heal(amount: int) -> int:
	var h: int = health.heal(amount)
	if h > 0:
		FX.float_text(global_position, "+%d HP" % h, Color("#7dc94a"))
		Sfx.play("heal")
	return h


func on_enemy_killed() -> void:
	var leech: float = float(_mods.get("leech", 0.0))
	if leech > 0.0 and randf() < leech:
		heal(1)


# --- interaction ---------------------------------------------------------------------
func _update_interact() -> void:
	var best: Node = null
	var best_d: float = INTERACT_RANGE * INTERACT_RANGE
	for n: Node in get_tree().get_nodes_in_group("interactables"):
		var n2: Node2D = n as Node2D
		if n2 == null or not n2.has_method("can_interact") or not bool(n2.call("can_interact", self)):
			continue
		var d: float = n2.global_position.distance_squared_to(global_position)
		if d < best_d:
			best = n2
			best_d = d
	if best != _interact_target:
		_interact_target = best
		Events.interact_hint.emit(str(best.call("interact_text")) if best != null else "")


func has_interact_target() -> bool:
	return _interact_target != null and is_instance_valid(_interact_target)


func try_interact() -> void:
	if has_interact_target():
		_interact_target.call("interact", self)
		_interact_target = null
		Events.interact_hint.emit("")


# --- animation -----------------------------------------------------------------------
func _update_anim() -> void:
	if _anim_lock > 0.0:
		return
	var want: StringName
	if state == State.DASH:
		want = &"dash"
	elif velocity.length() > 12.0:
		want = &"run"
	else:
		want = &"idle"
	if body.animation != want:
		body.play(want)
