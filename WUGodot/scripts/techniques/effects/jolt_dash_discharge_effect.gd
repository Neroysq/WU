extends "res://scripts/techniques/technique_effect.gd"

func on_dash_end(_fighter: Variant, enemy: Variant) -> Dictionary:
	if enemy == null or enemy.jolt_timer <= 0.0:
		return {}
	enemy.jolt_timer = 0.0
	return {
		"damage": float(params.get("damage", 6.0)),
		"message": str(params.get("message", "雷!")),
	}
