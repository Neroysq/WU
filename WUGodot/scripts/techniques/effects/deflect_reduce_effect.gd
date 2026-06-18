extends "res://scripts/techniques/technique_effect.gd"

func modify_block(ctx: Variant) -> void:
	ctx.hp_damage *= float(params.get("multiplier", 0.75))
