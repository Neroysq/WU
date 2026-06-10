extends "res://scripts/techniques/technique_effect.gd"

var _used: bool = false

func _init() -> void:
	id = "B6"
	once_per_run = true

func try_lethal_save(fighter: Variant) -> bool:
	if _used:
		return false
	_used = true
	fighter.health_current = fighter.health_max * float(params.get("heal_ratio", 0.2))
	fighter._phoenix_invuln_timer = float(params.get("invuln", 2.0))
	return true

func state() -> Dictionary:
	return {"used": _used}

func restore(data: Dictionary) -> void:
	_used = bool(data.get("used", false))
