extends "res://scripts/techniques/technique_effect.gd"

func _init() -> void:
	id = "A10"
	priority = 10

func post_hit(ctx: Variant) -> void:
	if ctx.attack_def == null or not ctx.attack_def.is_heavy:
		return
	ctx.extra_hits.append({
		"damage": ctx.hp_damage * float(params.get("multiplier", 0.5)),
		"offset": Vector2(float(ctx.defender.facing) * -8.0, -ctx.defender.height - 30.0),
		"critical": true,
	})
