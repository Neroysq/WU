extends "res://scripts/techniques/technique_effect.gd"

func _init() -> void:
	id = "A3"
	priority = 50

func modify_outgoing_hit(ctx: Variant) -> void:
	if ctx.attack_def == null or not ctx.attack_def.is_heavy:
		return
	ctx.bleed_timer = float(params.get("timer", 3.0))
	ctx.bleed_dps = float(params.get("dps", 1.5))
