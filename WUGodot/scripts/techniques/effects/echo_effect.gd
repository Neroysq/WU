extends "res://scripts/techniques/technique_effect.gd"

var _armed: bool = false

func _init() -> void:
	id = "B1"
	priority = 30

func on_combat_start(_fighter: Variant) -> void:
	_armed = false

func on_parry_success(_fighter: Variant) -> void:
	_armed = true

func handles_parry_success() -> bool:
	return true

func modify_outgoing_hit(ctx: Variant) -> void:
	if not _armed:
		return
	_armed = false
	ctx.posture_damage = ctx.defender.posture_current + 1.0
	ctx.messages.append(str(params.get("message", "山谷回響!")))

func set_armed() -> void:
	_armed = true

func consume_echo() -> bool:
	if _armed:
		_armed = false
		return true
	return false

func state() -> Dictionary:
	return {"armed": _armed}

func restore(data: Dictionary) -> void:
	_armed = bool(data.get("armed", false))
