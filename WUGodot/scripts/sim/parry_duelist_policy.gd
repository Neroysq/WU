class_name ParryDuelistPolicy
extends PlayerPolicy

const REACTION_LEAD_SECONDS := 0.12

func next_input(player: Fighter, enemy: Fighter, _world: Dictionary = {}) -> Dictionary:
	var input: Dictionary = PlayerPolicy.neutral_input()
	if player == null or enemy == null:
		return input

	var dist: float = enemy.position.x - player.position.x
	var adist: float = absf(dist)
	var dir: float = signf(dist)
	if is_zero_approx(dir):
		dir = float(player.facing)

	var reach: float = player.current_attack_range() + enemy.half_width
	if enemy.is_stunned:
		if adist <= reach and player.can_attack():
			input["heavy_pressed"] = true
		else:
			input["move"] = dir
		return input

	if _should_react_to_enemy_attack(enemy) and adist <= enemy.current_attack_range() + player.half_width + 24.0:
		var attack_def: Variant = enemy._attack_state.def
		if attack_def != null and not attack_def.is_parryable and player.can_dash():
			input["dash_pressed"] = true
			input["move"] = -dir
		else:
			input["block_down"] = true
			input["block_pressed"] = true
		return input

	if adist > reach * 0.82:
		input["move"] = dir
	elif player.can_attack():
		if enemy.posture_current <= enemy.posture_max * 0.45 and adist <= player.current_attack_range() * 0.75:
			input["heavy_pressed"] = true
		else:
			input["light_pressed"] = true
	return input

func _should_react_to_enemy_attack(enemy: Fighter) -> bool:
	if enemy._attack_state == null or not enemy._attack_state.is_active():
		return false
	if enemy._attack_state.is_hit_active():
		return true
	var attack_def: Variant = enemy._attack_state.def
	if attack_def == null:
		return false
	var time_until_active: float = float(attack_def.windup_end) - enemy._attack_state.elapsed
	return time_until_active >= 0.0 and time_until_active <= REACTION_LEAD_SECONDS
