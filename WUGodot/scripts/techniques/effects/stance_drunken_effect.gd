extends "res://scripts/techniques/technique_effect.gd"

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

var _pre_dash_duration: float = 0.0
var _pre_dash_iframe_end: float = 0.0
var _damage_taken: float = 0.0

func _init() -> void:
	id = "D1"
	exclusive_group = "stance"

func on_stance_activate(fighter: Variant) -> void:
	_pre_dash_duration = fighter.dash_duration
	_pre_dash_iframe_end = fighter.dash_iframe_end
	fighter.dash_duration = float(params.get("dash_duration", 0.30))
	fighter.dash_iframe_end = float(params.get("dash_iframe_end", 0.26))

func on_stance_deactivate(fighter: Variant) -> void:
	fighter.dash_duration = _pre_dash_duration
	fighter.dash_iframe_end = _pre_dash_iframe_end
	_damage_taken = 0.0

func attack_override(is_heavy: bool) -> Variant:
	return AttackCatalogScript.drunken_heavy() if is_heavy else AttackCatalogScript.drunken_light()

func on_stance_damage(amount: float, _fighter: Variant) -> bool:
	_damage_taken += amount
	return _damage_taken >= float(params.get("break_damage", 20.0))

func state() -> Dictionary:
	return {
		"pre_dash_duration": _pre_dash_duration,
		"pre_dash_iframe_end": _pre_dash_iframe_end,
		"damage_taken": _damage_taken,
	}

func restore(data: Dictionary) -> void:
	_pre_dash_duration = float(data.get("pre_dash_duration", 0.0))
	_pre_dash_iframe_end = float(data.get("pre_dash_iframe_end", 0.0))
	_damage_taken = float(data.get("damage_taken", 0.0))
