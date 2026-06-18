class_name CombatStep
extends RefCounted

static func advance(combat_system: CombatSystem, player: Fighter, enemy: Fighter, input_state: Dictionary, dt: float) -> void:
	combat_system.update_facing(player, enemy)
	combat_system.update_player(player, input_state, dt, enemy)
	combat_system.update_ai(enemy, player, dt)
	combat_system.resolve_hits(player, enemy)
	combat_system.resolve_hits(enemy, player)
	combat_system.tick_effects(player, dt)
	combat_system.tick_effects(enemy, dt)
	combat_system.clamp_world_bounds(player)
	combat_system.clamp_world_bounds(enemy)

static func check_death(player: Fighter, enemy: Fighter) -> Variant:
	if player.health_current <= 0.0:
		return player
	if enemy.health_current <= 0.0:
		return enemy
	return null

static func death_state(player: Fighter, enemy: Fighter) -> String:
	var dead: Variant = check_death(player, enemy)
	if dead == player:
		return "player"
	if dead == enemy:
		return "enemy"
	return ""

static func fire_player_kill(player: Fighter) -> void:
	if player != null and player.technique_engine != null:
		player.technique_engine.on_kill(player)

