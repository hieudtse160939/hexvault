class_name Portal
extends Interactable
## Floor exit. Leads to the next floor, the hub, or ends the run in victory.

enum Mode { NEXT_FLOOR, VICTORY, HUB_START }

var mode: int = Mode.NEXT_FLOOR
var used: bool = false
var character_id: String = ""


static func create(m: int, pos: Vector2) -> Portal:
	var p: Portal = Portal.new()
	p.mode = m
	p.position = pos
	return p


func _ready() -> void:
	super._ready()
	var s: AnimatedSprite2D = AnimatedSprite2D.new()
	s.sprite_frames = SpriteLib.frames("prop_portal")
	s.play(&"idle")
	s.offset = Vector2(0, -6)
	add_child(s)
	match mode:
		Mode.NEXT_FLOOR:
			set_caption("Descend", UiTheme.ACCENT, 12.0)
		Mode.VICTORY:
			set_caption("Escape", UiTheme.GOLD, 12.0)
		Mode.HUB_START:
			set_caption("Enter the Vault", UiTheme.ACCENT, 12.0)


func can_interact(_p: Player) -> bool:
	return not used


func interact_text() -> String:
	match mode:
		Mode.VICTORY:
			return "Escape the Vault"
		Mode.HUB_START:
			return "Start a run"
	return "Descend deeper"


func interact(p: Player) -> void:
	used = true
	Sfx.play("portal")
	p.input_enabled = false
	p.store_run_state()
	var tw: Tween = p.create_tween()
	tw.tween_property(p, "global_position", global_position, 0.25)
	tw.parallel().tween_property(p, "scale", Vector2(0.2, 1.6), 0.35)
	tw.tween_callback(_go)


func _go() -> void:
	match mode:
		Mode.NEXT_FLOOR:
			Game.next_floor()
		Mode.VICTORY:
			Game.end_run(true)
		Mode.HUB_START:
			Game.start_run(character_id)
