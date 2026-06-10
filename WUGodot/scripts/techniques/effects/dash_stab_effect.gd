extends "res://scripts/techniques/technique_effect.gd"

func _init() -> void:
	id = "A1"

func on_dash_end(fighter: Variant, enemy: Variant) -> Dictionary:
	if fighter == null or enemy == null:
		return {}
	var stab_range: float = float(params.get("range", 60.0))
	var dist: float = absf(enemy.position.x - fighter.position.x)
	if dist > stab_range + enemy.half_width:
		return {}
	var facing_enemy: bool = (1 if enemy.position.x > fighter.position.x else -1) == fighter.facing
	if not facing_enemy:
		return {}
	return {
		"damage": float(params.get("damage", 8.0)),
		"message": str(params.get("message", "落葉!")),
	}
