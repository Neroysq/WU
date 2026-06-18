extends "res://scripts/techniques/technique_effect.gd"

func modify_outgoing_hit(ctx: Variant) -> void:
	if ctx.attack_def == null or not ctx.attack_def.is_heavy or ctx.defender == null:
		return
	var stacks: int = int(ctx.defender.venom_stacks)
	if stacks <= 0:
		return
	ctx.hp_damage += float(stacks) * float(params.get("damage_per_stack", 2.0))
	ctx.consume_venom = true
