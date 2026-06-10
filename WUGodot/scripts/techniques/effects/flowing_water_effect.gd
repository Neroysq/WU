extends "res://scripts/techniques/technique_effect.gd"

var _armed: bool = false

func _init() -> void:
	id = "B3"
	priority = 40

func on_combat_start(_fighter: Variant) -> void:
	_armed = false

func on_dash_through(_fighter: Variant) -> void:
	_armed = true

func modify_outgoing_hit(ctx: Variant) -> void:
	if not _armed:
		return
	_armed = false
	ctx.heal_attacker += float(params.get("heal", 5.0))
	ctx.messages.append(str(params.get("message", "流水!")))

func consume_flowing_water() -> bool:
	if _armed:
		_armed = false
		return true
	return false

func state() -> Dictionary:
	return {"armed": _armed}

func restore(data: Dictionary) -> void:
	_armed = bool(data.get("armed", false))
