extends "res://scripts/techniques/technique_effect.gd"

func modify_outgoing_hit(ctx: Variant) -> void:
	if ctx.defender == null or ctx.defender.jolt_timer <= 0.0:
		return
	ctx.hp_damage *= float(params.get("multiplier", 1.25))
