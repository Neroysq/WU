class_name HeuristicPlayer
extends PlayerPolicy

var skill: float = 0.8

func _init(skill_value: float = 0.8) -> void:
	skill = clampf(skill_value, 0.0, 1.0)

func next_input(player: Fighter, enemy: Fighter, _world: Dictionary = {}) -> Dictionary:
	var input: Dictionary = PlayerPolicy.neutral_input()
	if player == null or enemy == null:
		return input
	var rng: RandomNumberGenerator = RngService.stream("policy")

	var distance: float = enemy.position.x - player.position.x
	var abs_distance: float = absf(distance)
	var direction: float = signf(distance)
	if is_zero_approx(direction):
		direction = float(player.facing)

	var reaction_allowed: bool = rng.randf() <= skill
	if enemy._attack_state != null and enemy._attack_state.is_active() and abs_distance <= enemy.current_attack_range() + player.half_width + 28.0:
		if reaction_allowed:
			var attack_def: Variant = enemy._attack_state.def
			if attack_def != null and not attack_def.is_parryable and player.can_dash():
				input["dash_pressed"] = true
				input["move"] = -direction
			else:
				input["block_down"] = true
				input["block_pressed"] = true
			return input

	var attack_range: float = player.current_attack_range() + enemy.half_width
	if abs_distance > attack_range * 0.82:
		input["move"] = direction
	elif player.can_attack():
		if abs_distance <= attack_range * 0.55 and rng.randf() < 0.25:
			input["heavy_pressed"] = true
		else:
			input["light_pressed"] = true
	return input
