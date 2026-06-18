extends "res://scripts/techniques/technique_effect.gd"

func _init() -> void:
	priority = 26

func modify_outgoing_hit(ctx: Variant) -> void:
	if ctx.attacker == null or not ctx.attacker.deflect_riposte_armed:
		return
	ctx.hp_damage += float(params.get("damage", 5.0))
