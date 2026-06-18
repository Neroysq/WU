extends "res://scripts/techniques/technique_effect.gd"

var _delta: float = 0.0

func on_add(fighter: Variant) -> void:
	_delta = float(params.get("move_speed", 20.0))
	fighter.move_speed += _delta

func on_remove(fighter: Variant) -> void:
	fighter.move_speed -= _delta
	_delta = 0.0

func state() -> Dictionary:
	return {"delta": _delta}

func restore(data: Dictionary) -> void:
	_delta = float(data.get("delta", _delta))
