class_name AggressiveDashPolicy
extends PlayerPolicy

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")
const REACTION_LEAD_SECONDS := 0.30

func next_input(player: Fighter, enemy: Fighter, _world: Dictionary = {}) -> Dictionary:
	var input: Dictionary = PlayerPolicy.neutral_input()
	if player == null or enemy == null:
		return input

	var dist: float = enemy.position.x - player.position.x
	var adist: float = absf(dist)
	var dir: float = signf(dist)
	if is_zero_approx(dir):
		dir = float(player.facing)

	if not _is_weak_archetype(enemy):
		return _non_weak_input(player, enemy, adist, dir)

	var enemy_threat_range: float = enemy.current_attack_range() + player.half_width + 28.0
	if _should_dash_threat(enemy) and adist <= enemy_threat_range and player.can_dash():
		input["dash_pressed"] = true
		input["move"] = _dash_direction(player, enemy, dir)
		return input
	if _should_dash_threat(enemy) and adist <= enemy_threat_range and player.can_jump():
		input["jump_pressed"] = true
		input["move"] = -dir
		return input

	var light_reach: float = _light_reach(enemy)
	var heavy_reach: float = _heavy_reach(enemy)
	if adist > light_reach * 0.92:
		input["move"] = dir
	elif player.can_attack():
		if enemy.is_stunned and adist <= heavy_reach:
			input["heavy_pressed"] = true
		else:
			input["light_pressed"] = true
	return input

func _non_weak_input(player: Fighter, enemy: Fighter, adist: float, dir: float) -> Dictionary:
	var input: Dictionary = PlayerPolicy.neutral_input()
	var enemy_threat_range: float = enemy.current_attack_range() + player.half_width + 28.0
	if _should_dash_threat(enemy) and adist <= enemy_threat_range and player.can_dash():
		input["dash_pressed"] = true
		input["move"] = _dash_direction(player, enemy, dir)
		return input
	if _should_dash_threat(enemy) and adist <= enemy_threat_range and player.can_jump():
		input["jump_pressed"] = true
		input["move"] = -dir
		return input

	var light_reach: float = _light_reach(enemy)
	var heavy_reach: float = _heavy_reach(enemy)
	var poke_floor: float = _enemy_engage_range(player, enemy) + 40.0
	if enemy.is_stunned:
		if adist <= heavy_reach and player.can_attack():
			input["heavy_pressed"] = true
		else:
			input["move"] = dir
	elif adist < poke_floor and enemy.can_attack():
		if player.can_dash():
			input["dash_pressed"] = true
		input["move"] = -dir
	elif adist > light_reach * 0.92:
		input["move"] = dir
	elif player.can_attack():
		if enemy.posture_current <= enemy.posture_max * 0.45 and adist <= heavy_reach:
			input["heavy_pressed"] = true
		else:
			input["light_pressed"] = true
	return input

func _should_dash_threat(enemy: Fighter) -> bool:
	if enemy._attack_state == null or not enemy._attack_state.is_active():
		return false
	var attack_def: Variant = enemy._attack_state.def
	if attack_def == null:
		return false
	if enemy._attack_state.is_hit_active():
		return true
	var time_until_active: float = float(attack_def.windup_end) - enemy._attack_state.elapsed
	return time_until_active >= 0.0 and time_until_active <= REACTION_LEAD_SECONDS

func _is_weak_archetype(enemy: Fighter) -> bool:
	return enemy.archetype_id == "bandit_swordsman" or enemy.archetype_id == "bandit_spearman"

func _dash_direction(player: Fighter, _enemy: Fighter, dir_to_enemy: float) -> float:
	var away_x: float = player.position.x - dir_to_enemy * player.dash_speed * player.dash_duration
	if away_x > GameConstants.WORLD_BOUNDS_LEFT and away_x < GameConstants.WORLD_BOUNDS_RIGHT:
		return -dir_to_enemy
	return dir_to_enemy

func _light_reach(enemy: Fighter) -> float:
	return AttackCatalogScript.hu_light().range_units + enemy.half_width

func _heavy_reach(enemy: Fighter) -> float:
	return AttackCatalogScript.hu_heavy().range_units + enemy.half_width

func _enemy_engage_range(player: Fighter, enemy: Fighter) -> float:
	if enemy.ai_brain != null:
		return enemy.ai_brain.preferred_range + player.half_width + enemy.half_width
	return enemy.attack_range + player.half_width + enemy.half_width
