extends Control
## Screen: title / main menu.

var _t: float = 0.0
var _logo: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#0b0912")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var portal_holder: Control = Control.new()
	portal_holder.set_anchors_preset(Control.PRESET_CENTER)
	add_child(portal_holder)
	var portal: AnimatedSprite2D = AnimatedSprite2D.new()
	SpriteLib.apply(portal, "prop_portal", 3.0)
	portal.play(&"idle")
	portal.position = Vector2(0, -30)
	portal.modulate = Color(1, 1, 1, 0.5)
	portal_holder.add_child(portal)
	for i: int in mini(Db.roster.size(), 5):
		var hero: AnimatedSprite2D = AnimatedSprite2D.new()
		var id: String = Db.roster[i]
		SpriteLib.apply(hero, Db.character(id).sprite)
		hero.play(&"idle")
		hero.position = Vector2(-72 + i * 36, 10)
		portal_holder.add_child(hero)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	_logo = UiTheme.label("HEXVAULT", UiTheme.ACCENT, true)
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo.add_theme_font_size_override("font_size", 24)
	v.add_child(_logo)
	var sub: Label = UiTheme.label("an Adventurers' Guild dungeon RPG", UiTheme.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 52)
	v.add_child(spacer)
	var cont: Button = UiTheme.button("Continue", _continue)
	var has_game: bool = Profile.has_game()
	cont.disabled = not has_game
	if has_game:
		var c: CharacterData = Db.character(Profile.selected_hero())
		cont.text = "Continue  (%s Lv %d)" % [c.display_name if c != null else "?", Profile.hero_level(Profile.selected_hero())]
	else:
		cont.tooltip_text = "No saved adventure yet"
	var newg: Button = UiTheme.button("New Game", func() -> void: Game.goto("select"))
	v.add_child(cont)
	v.add_child(newg)
	if not has_game:
		var none: Label = UiTheme.label("No saved adventure yet", UiTheme.DIM)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(none)
	v.add_child(UiTheme.button("Settings", func() -> void: add_child(SettingsPanel.new())))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		v.add_child(UiTheme.button("Quit", Game.quit_game))
	var play: Button = cont if has_game else newg
	var info: Label = UiTheme.label("v%s  -  %d shards  -  %d/%d achievements" % [
		ProjectSettings.get_setting("application/config/version", "0"), Profile.shards(),
		(Profile.data["achievements"] as Dictionary).size(), Db.achievement_order.size()], UiTheme.DIM)
	info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	info.offset_left = 4
	info.offset_top = -12
	add_child(info)
	if SaveManager.last_profile_load != null and SaveManager.last_profile_load.status in [SaveStore.Status.RECOVERED_FROM_BACKUP, SaveStore.Status.RESET_CORRUPT]:
		var warn: Label = UiTheme.label(SaveManager.last_profile_load.message, UiTheme.RED, true)
		warn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		warn.grow_horizontal = Control.GROW_DIRECTION_BOTH
		warn.offset_top = 4
		add_child(warn)
	Sfx.play_music("hub")
	play.grab_focus.call_deferred()


## Loads the saved profile (already loaded and validated at startup) into the Guild.
func _continue() -> void:
	if not Profile.has_game():
		Sfx.play("ui_deny")
		return
	Profile.select_hero(Profile.selected_hero())
	Game.goto("hub")


func _process(delta: float) -> void:
	_t += delta
	_logo.modulate = Color(1, 1, 1).lerp(Color("#b4fff0"), 0.5 + 0.5 * sin(_t * 2.0))
