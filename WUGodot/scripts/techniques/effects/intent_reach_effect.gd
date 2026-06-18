extends "res://scripts/techniques/technique_effect.gd"

var _delta: float = 0.0

func on_add(fighter: Variant) -> void:
	_delta = float(params.get("range", 16.0))
	fighter.attack_range_bonus += _delta

func on_remove(fighter: Variant) -> void:
	fighter.attack_range_bonus -= _delta
	_delta = 0.0

func state() -> Dictionary:
	return {"delta": _delta}

func restore(data: Dictionary) -> void:
	_delta = float(data.get("delta", _delta))
