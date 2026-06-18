extends "res://scripts/techniques/technique_effect.gd"

func modify_outgoing_hit(ctx: Variant) -> void:
	if ctx.attack_def == null or not ctx.attack_def.is_heavy:
		return
	# V1 combat has one enemy, so nova jolts the current defender only.
	ctx.jolt_timer = maxf(ctx.jolt_timer, float(params.get("timer", 2.5)))
