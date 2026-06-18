extends "res://scripts/techniques/technique_effect.gd"

func modify_outgoing_hit(ctx: Variant) -> void:
	if ctx.venom_stacks <= 0:
		return
	ctx.venom_slow_multiplier = minf(ctx.venom_slow_multiplier, float(params.get("multiplier", 0.75)))
