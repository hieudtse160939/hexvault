extends Node
## Global signal bus. Systems emit here instead of holding references to each other.

@warning_ignore_start("unused_signal")
signal enemy_killed(enemy: Node, is_elite: bool)
signal boss_killed(boss_id: String)
signal boss_phase_changed(phase: int)
signal boss_health_changed(current: int, maximum: int, display_name: String)
signal player_damaged(amount: int)
signal player_died
signal player_stats_changed
signal weapon_changed
signal ammo_changed(current: int, maximum: int, reloading: bool)
signal skill_cooldown_changed(remaining: float, total: float)
signal coins_changed(amount: int)
signal run_shards_changed(amount: int)
signal room_entered(room: Node)
signal room_cleared(room: Node, flawless: bool)
signal floor_started(floor_index: int)
signal floor_cleared(floor_index: int)
signal chest_opened
signal coins_spent(amount: int)
signal interact_hint(text: String)
signal toast(text: String)
signal achievement_unlocked(id: String)
signal save_status(ok: bool, message: String)
signal settings_changed
signal screen_shake(strength: float)
signal hit_stop(duration: float)
signal gold_changed(amount: int)
signal hero_exp_changed(hero_id: String)
signal hero_leveled(hero_id: String, level: int)
signal item_found(item: Dictionary)
signal inventory_changed
signal objective_changed(text: String)
@warning_ignore_restore("unused_signal")
