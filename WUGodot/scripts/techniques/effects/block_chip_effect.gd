extends "res://scripts/techniques/technique_effect.gd"

func _init() -> void:
	id = "A5"
	priority = 10

func modify_block(ctx: Variant) -> void:
	ctx.hp_damage *= float(params.get("multiplier", 0.5))
