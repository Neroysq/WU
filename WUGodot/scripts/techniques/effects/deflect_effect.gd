extends "res://scripts/techniques/technique_effect.gd"

func _init() -> void:
	priority = 25

func on_combat_start(fighter: Variant) -> void:
	fighter.deflect_riposte_armed = false

func on_parry_success(fighter: Variant) -> void:
	fighter.deflect_riposte_armed = true

func handles_parry_success() -> bool:
	return true

func modify_outgoing_hit(ctx: Variant) -> void:
	if ctx.attacker == null or not ctx.attacker.deflect_riposte_armed:
		return
	ctx.hp_damage += float(params.get("damage", 4.0))
	ctx.messages.append(str(params.get("message", "DEFLECT!")))

func post_hit(ctx: Variant) -> void:
	if ctx.attacker != null:
		ctx.attacker.deflect_riposte_armed = false
