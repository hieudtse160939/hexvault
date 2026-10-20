class_name DeathScreen
extends Modal
## Shown when the hero falls: one shard-paid revive per run, or end the run.

signal revive
signal give_up

var can_revive: bool = false
var revive_cost: int = 40
var revive_used: bool = false


func _ready() -> void:
	add_title("YOU HAVE FALLEN", UiTheme.RED)
	var run: RunState = Game.run
	if run != null:
		add_text("Floor %d  -  %d enemies defeated  -  %d shards found" % [run.floor_index, run.kills, run.shards], UiTheme.DIM)
	var b: Button = add_button("Revive (%d shards)" % revive_cost, func() -> void:
		revive.emit()
		queue_free())
	b.disabled = not can_revive
	if revive_used:
		add_text("Revive already used this run.", UiTheme.DIM)
	elif not can_revive:
		add_text("You have %d shards." % Profile.shards(), UiTheme.DIM)
	add_button("Return to the Hub", func() -> void:
		give_up.emit()
		queue_free())
	add_text("Unlocks and banked shards are always kept.", UiTheme.ACCENT)
	super._ready()
