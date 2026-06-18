extends "res://scripts/techniques/technique_effect.gd"

func on_combat_start(fighter: Variant) -> void:
	fighter.momentum = 0.0
	fighter.momentum_landing_burst_ready = false

func update(dt: float, fighter: Variant) -> void:
	var max_momentum: float = float(params.get("max", 100.0))
	if absf(fighter.velocity.x) > float(params.get("move_threshold", 10.0)):
		fighter.momentum = minf(fighter.momentum + float(params.get("move_gain_per_second", 0.0)) * dt, max_momentum)
	if fighter.momentum > 0.0:
		fighter.momentum = maxf(fighter.momentum - float(params.get("decay", 8.0)) * dt, 0.0)

func on_dash_end(fighter: Variant, _enemy: Variant) -> Dictionary:
	fighter.momentum = minf(fighter.momentum + float(params.get("dash_gain", 25.0)), float(params.get("max", 100.0)))
	return {}
