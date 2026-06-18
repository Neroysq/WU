extends "res://scripts/techniques/technique_effect.gd"

func modify_outgoing_hit(ctx: Variant) -> void:
	if ctx.attacker == null or ctx.attack_def == null or ctx.attack_def.is_heavy:
		return
	if ctx.attacker.momentum < float(params.get("threshold", 50.0)):
		return
	ctx.extra_hits.append({
		"damage": float(params.get("damage", 3.0)),
		"offset": Vector2(0.0, -ctx.defender.height * 0.5) if ctx.defender != null else Vector2.ZERO,
		"critical": false,
	})
	ctx.attacker.momentum = maxf(ctx.attacker.momentum - float(params.get("cost", 20.0)), 0.0)
