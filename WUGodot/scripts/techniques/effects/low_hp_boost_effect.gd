extends "res://scripts/techniques/technique_effect.gd"

func _init() -> void:
	id = "B5"
	priority = 10

func modify_outgoing_hit(ctx: Variant) -> void:
	var threshold: float = float(params.get("hp_threshold", 0.3))
	var multiplier: float = float(params.get("multiplier", 1.25))
	if ctx.attacker.health_current <= ctx.attacker.health_max * threshold:
		ctx.hp_damage *= multiplier
		ctx.posture_damage *= multiplier
