extends "res://scripts/techniques/technique_effect.gd"

func modify_aerial_hit(ctx: Variant) -> void:
	if ctx.attacker == null or ctx.attacker.is_grounded:
		return
	ctx.hp_damage *= float(params.get("multiplier", 1.25))
	ctx.posture_damage *= float(params.get("posture_multiplier", 1.5))
	ctx.attacker.momentum_landing_burst_ready = true

func on_land(fighter: Variant) -> void:
	if not fighter.momentum_landing_burst_ready:
		return
	fighter.momentum = minf(fighter.momentum + float(params.get("landing_gain", 10.0)), float(params.get("max", 100.0)))
	fighter.momentum_landing_burst_ready = false
