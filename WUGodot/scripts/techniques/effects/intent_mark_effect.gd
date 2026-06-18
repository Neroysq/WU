extends "res://scripts/techniques/technique_effect.gd"

func modify_outgoing_hit(ctx: Variant) -> void:
	if ctx.defender == null:
		return
	ctx.intent_mark_cap = int(params.get("max", 3))
	if ctx.attack_def != null and ctx.attack_def.is_heavy and ctx.defender.intent_marks > 0:
		ctx.hp_damage += float(ctx.defender.intent_marks) * float(params.get("burst_per_mark", 6.0))
		ctx.consume_intent_marks = true
		ctx.messages.append(str(params.get("message", "INTENT!")))
		return
	ctx.intent_marks += int(params.get("marks", 1))
