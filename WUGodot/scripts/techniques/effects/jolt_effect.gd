extends "res://scripts/techniques/technique_effect.gd"

func modify_outgoing_hit(ctx: Variant) -> void:
	ctx.jolt_timer = maxf(ctx.jolt_timer, float(params.get("timer", 2.0)))
