class_name Hud
extends Control
## In-run HUD. Pixel bars are drawn directly for crisp 1px edges.

var player: Player
var _hp: Vector2i = Vector2i(1, 1)
var _armor: Vector2i = Vector2i(0, 0)
var _coins: Label
var _shards: Label
var _weapon_icon: TextureRect
var _weapon_name: Label
var _ammo: Label
var _alt_icon: TextureRect
var _skill_icon: TextureRect
var _skill_label: Label
var _hint: Label
var _boss_name: Label
var _boss: Vector2i = Vector2i.ZERO
var _boss_visible: bool = false
var _save_dot: Label
var _floor: Label
var _level: Label
var _objective: Label
var _exp_ratio: float = 0.0

const X: float = 4.0
const BAR_W: float = 64.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon("icon_heart", Vector2(X, 3))
	_icon("icon_shield", Vector2(X, 15))
	_icon("icon_coin", Vector2(X, 28))
	_coins = _label(Vector2(X + 17, 32), UiTheme.GOLD)
	_icon("icon_shard", Vector2(X + 52, 28))
	_shards = _label(Vector2(X + 69, 32), UiTheme.ACCENT)
	_weapon_icon = TextureRect.new()
	_weapon_icon.position = Vector2(X, 46)
	_weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_weapon_icon)
	_weapon_name = _label(Vector2(X + 27, 44), UiTheme.TEXT)
	_ammo = _label(Vector2(X + 27, 53), UiTheme.DIM)
	_alt_icon = TextureRect.new()
	_alt_icon.position = Vector2(X, 62)
	_alt_icon.modulate = Color(1, 1, 1, 0.45)
	_alt_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_alt_icon)
	_skill_icon = TextureRect.new()
	_skill_icon.position = Vector2(X, 78)
	_skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skill_icon)
	_skill_label = _label(Vector2(X + 19, 82), UiTheme.TEXT)
	_hint = UiTheme.label("", UiTheme.TEXT, true)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.offset_top = -44
	_hint.offset_bottom = -34
	add_child(_hint)
	_boss_name = UiTheme.label("", UiTheme.RED, true)
	_boss_name.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_name.offset_top = 4
	_boss_name.visible = false
	add_child(_boss_name)
	_save_dot = UiTheme.label("", UiTheme.GREEN, true)
	_save_dot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_save_dot.offset_left = -60
	_save_dot.offset_top = -12
	add_child(_save_dot)
	_level = _label(Vector2(X, 101), UiTheme.GOLD)
	_objective = _label(Vector2(X, 114), Color("#ffe28a"))
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(120, 0)
	Events.objective_changed.connect(func(t: String) -> void: _objective.text = t)
	Events.hero_exp_changed.connect(func(_h: String) -> void: _refresh_level())
	Events.player_stats_changed.connect(_refresh_stats)
	Events.coins_changed.connect(func(_n: int) -> void: _refresh_stats())
	Events.run_shards_changed.connect(func(_n: int) -> void: _refresh_stats())
	Events.weapon_changed.connect(_refresh_weapon)
	Events.ammo_changed.connect(_on_ammo)
	Events.interact_hint.connect(_on_hint)
	Events.boss_health_changed.connect(_on_boss)
	Events.save_status.connect(_on_save)
	if player != null:
		SpriteLib.fit_icon(_skill_icon, player.skill_icon())
	_refresh_stats()
	_refresh_weapon()
	_refresh_level()


func _refresh_level() -> void:
	if player == null or not is_instance_valid(player):
		return
	var rec: Dictionary = Profile.character_record(player.character.id)
	var lvl: int = int(rec["level"])
	_level.text = "Lv %d" % lvl
	_exp_ratio = 1.0 if lvl >= HeroProgress.max_level() else float(rec["exp"]) / float(maxi(HeroProgress.xp_to_next(lvl), 1))
	queue_redraw()


func _icon(key: String, pos: Vector2) -> TextureRect:
	var t: TextureRect = TextureRect.new()
	t.texture = SpriteLib.texture(key)
	t.position = pos
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


func _label(pos: Vector2, c: Color) -> Label:
	var l: Label = UiTheme.label("", c, true)
	l.position = pos
	add_child(l)
	return l


func _refresh_stats() -> void:
	if player == null or not is_instance_valid(player):
		return
	_hp = Vector2i(player.health.hp, player.health.max_hp)
	_armor = Vector2i(player.health.armor, player.health.max_armor)
	if Game.run != null:
		_coins.text = str(Game.run.coins)
		_shards.text = str(Game.run.shards)
	queue_redraw()


func _refresh_weapon() -> void:
	if player == null or not is_instance_valid(player):
		return
	var w: Weapon = player.current_weapon()
	if w != null:
		SpriteLib.fit_icon(_weapon_icon, "weapon_" + w.data.id)
		_weapon_name.text = w.data.display_name
		_weapon_name.add_theme_color_override("font_color", w.data.rarity_color())
		_on_ammo(w.ammo, w.data.magazine, w.reloading)
	var alt: Weapon = null
	if player.weapons.size() > 1:
		alt = player.weapons[(player.current + 1) % player.weapons.size()]
	SpriteLib.fit_icon(_alt_icon, "weapon_" + alt.data.id if alt != null else "")


func _on_ammo(cur: int, mx: int, reloading: bool) -> void:
	if mx <= 0:
		_ammo.text = "INF"
	elif reloading:
		_ammo.text = "RELOADING"
	else:
		_ammo.text = "%d / %d" % [cur, mx]
	_ammo.add_theme_color_override("font_color", UiTheme.RED if (mx > 0 and cur == 0) else UiTheme.DIM)


func _on_hint(text: String) -> void:
	if text.is_empty():
		_hint.text = ""
		return
	_hint.text = "Press %s: %s" % [Controls.action_label("interact"), text]


func _on_boss(cur: int, mx: int, name_text: String) -> void:
	_boss = Vector2i(cur, mx)
	_boss_visible = cur > 0
	_boss_name.visible = _boss_visible
	_boss_name.text = name_text
	queue_redraw()


func _on_save(ok: bool, msg: String) -> void:
	_save_dot.text = ("Saved" if ok else msg.substr(0, 40))
	_save_dot.add_theme_color_override("font_color", UiTheme.GREEN if ok else UiTheme.RED)
	var tw: Tween = _save_dot.create_tween()
	_save_dot.modulate.a = 1.0
	tw.tween_interval(1.5)
	tw.tween_property(_save_dot, "modulate:a", 0.0, 0.5)


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var cd: float = player.skill_cd_left
	_skill_label.text = "READY" if cd <= 0.0 else "%.1f" % cd
	_skill_label.add_theme_color_override("font_color", UiTheme.ACCENT if cd <= 0.0 else UiTheme.DIM)
	_skill_icon.modulate = Color.WHITE if cd <= 0.0 else Color(0.5, 0.5, 0.6)
	queue_redraw()


func _bar(pos: Vector2, w: float, h: float, ratio: float, fill: Color, back: Color = UiTheme.INK) -> void:
	draw_rect(Rect2(pos - Vector2.ONE, Vector2(w + 2, h + 2)), UiTheme.INK)
	draw_rect(Rect2(pos, Vector2(w, h)), back)
	draw_rect(Rect2(pos, Vector2(roundf(w * clampf(ratio, 0.0, 1.0)), h)), fill)
	draw_rect(Rect2(pos, Vector2(roundf(w * clampf(ratio, 0.0, 1.0)), 1)), fill.lightened(0.35))


func _draw() -> void:
	var font: Font = SpriteLib.font()
	_bar(Vector2(X + 18, 7), BAR_W, 6, float(_hp.x) / maxf(_hp.y, 1), UiTheme.RED, Color("#3b1020"))
	draw_string(font, Vector2(X + 20 + BAR_W + 2, 14), "%d/%d" % [_hp.x, _hp.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.TEXT)
	if _armor.y > 0:
		_bar(Vector2(X + 18, 19), BAR_W, 6, float(_armor.x) / maxf(_armor.y, 1), Color("#2f6fd6"), Color("#101a3a"))
		draw_string(font, Vector2(X + 20 + BAR_W + 2, 26), "%d/%d" % [_armor.x, _armor.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.TEXT)
	if player != null and is_instance_valid(player):
		var w: Weapon = player.current_weapon()
		if w != null and w.reloading:
			_bar(Vector2(X + 27, 62), 40, 2, w.reload_progress(), UiTheme.GOLD)
		# skill cooldown sweep (vertical fill over the icon)
		var cd: float = player.skill_cd_left
		if cd > 0.0:
			var k: float = cd / maxf(player.skill_cooldown_total(), 0.01)
			draw_rect(Rect2(Vector2(X, 78), Vector2(16, roundf(16 * k))), Color(0, 0, 0, 0.55))
		# dash pips
		var dr: float = player.dash_ready_ratio()
		_bar(Vector2(X, 96), 16, 2, dr, UiTheme.ACCENT if dr >= 1.0 else UiTheme.DIM)
		# experience toward the next level, right of "Lv N"
		_bar(Vector2(X + 26, 106), 44, 2, _exp_ratio, UiTheme.GOLD)
	if _boss_visible:
		var bw: float = minf(size.x * 0.45, 200.0)
		_bar(Vector2((size.x - bw) / 2.0, 15), bw, 5, float(_boss.x) / maxf(_boss.y, 1), UiTheme.RED, Color("#3b1020"))
