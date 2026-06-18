extends "res://scripts/techniques/technique_effect.gd"

func on_dash_end(fighter: Variant, enemy: Variant) -> Dictionary:
	if fighter == null or enemy == null:
		return {}
	var range: float = float(params.get("range", 120.0))
	if absf(enemy.position.x - fighter.position.x) > range + enemy.half_width:
		return {}
	enemy.intent_marks = mini(enemy.intent_marks + int(params.get("marks", 1)), int(params.get("max", 3)))
	return {}
