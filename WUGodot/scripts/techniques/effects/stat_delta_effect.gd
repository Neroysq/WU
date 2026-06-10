extends "res://scripts/techniques/technique_effect.gd"

var _deltas: Dictionary = {}

func on_add(fighter: Variant) -> void:
	_deltas.clear()
	var flat: Dictionary = params.get("flat", {}) as Dictionary
	for field in flat.keys():
		var delta: float = float(flat[field])
		_deltas[str(field)] = delta
		fighter.set(str(field), float(fighter.get(str(field))) + delta)

	var scaled: Dictionary = params.get("scaled", {}) as Dictionary
	for field in scaled.keys():
		var delta: float = float(fighter.get(str(field))) * float(scaled[field])
		_deltas[str(field)] = delta
		fighter.set(str(field), float(fighter.get(str(field))) + delta)

	if params.has("dash_cooldown_reduction"):
		var floor_value: float = float(params.get("dash_cooldown_floor", 0.1))
		var reduction: float = float(params.get("dash_cooldown_reduction", 0.15))
		var delta: float = -minf(reduction, fighter.dash_cooldown - floor_value)
		_deltas["dash_cooldown"] = delta
		fighter.dash_cooldown += delta

func on_remove(fighter: Variant) -> void:
	for field in _deltas.keys():
		fighter.set(str(field), float(fighter.get(str(field))) - float(_deltas[field]))
	if _deltas.has("posture_max"):
		fighter.posture_current = minf(fighter.posture_current, fighter.posture_max)
	if _deltas.has("health_max"):
		fighter.health_current = minf(fighter.health_current, fighter.health_max)
	_deltas.clear()

func state() -> Dictionary:
	return {"deltas": _deltas.duplicate(true)}

func restore(data: Dictionary) -> void:
	_deltas = (data.get("deltas", {}) as Dictionary).duplicate(true)
