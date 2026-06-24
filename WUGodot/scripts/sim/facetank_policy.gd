class_name FacetankPolicy
extends PlayerPolicy

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
	if adist > reach * 0.82:
		input["move"] = dir
	elif player.can_attack():
		input["light_pressed"] = true
	return input
