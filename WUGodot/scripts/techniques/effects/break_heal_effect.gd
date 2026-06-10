extends "res://scripts/techniques/technique_effect.gd"

func _init() -> void:
	id = "B2"

func on_posture_break_dealt(fighter: Variant) -> void:
	fighter.health_current = minf(fighter.health_current + float(params.get("heal", 15.0)), fighter.health_max)
