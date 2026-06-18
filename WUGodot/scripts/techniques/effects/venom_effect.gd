extends "res://scripts/techniques/technique_effect.gd"

func modify_outgoing_hit(ctx: Variant) -> void:
	if ctx.attack_def != null and ctx.attack_def.is_heavy and str(params.get("attack", "light")) == "light":
		return
	ctx.venom_stacks += int(params.get("stacks", 1))
	ctx.venom_timer = maxf(ctx.venom_timer, float(params.get("timer", 3.0)))
	ctx.venom_dps = maxf(ctx.venom_dps, float(params.get("dps", 1.0)))
