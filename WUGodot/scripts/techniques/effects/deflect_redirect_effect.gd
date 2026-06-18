extends "res://scripts/techniques/technique_effect.gd"

func modify_block(ctx: Variant) -> void:
	if ctx.attack_def == null or ctx.attack_def.is_heavy:
		return
	ctx.reflect_to_attacker += ctx.base_hp_damage * float(params.get("reflect", 0.2))
