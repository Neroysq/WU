extends "res://scripts/techniques/technique_effect.gd"

var _timer: float = 0.0

func _init() -> void:
	id = "A4"
	priority = 20

func update(dt: float, _fighter: Variant) -> void:
	if _timer > 0.0:
		_timer = maxf(_timer - dt, 0.0)

func on_combat_start(_fighter: Variant) -> void:
	_timer = 0.0

func on_dash_end(_fighter: Variant, _enemy: Variant) -> Dictionary:
	_timer = float(params.get("window", 0.6))
	return {}

func modify_outgoing_hit(ctx: Variant) -> void:
	if _timer <= 0.0 or ctx.attack_def == null or ctx.attack_def.is_heavy:
		return
	ctx.hp_damage *= float(params.get("multiplier", 1.30))
	_timer = 0.0
	ctx.messages.append(str(params.get("message", "雀翼!")))

func has_bonus() -> bool:
	return _timer > 0.0

func consume_bonus() -> void:
	_timer = 0.0

func state() -> Dictionary:
	return {"timer": _timer}

func restore(data: Dictionary) -> void:
	_timer = float(data.get("timer", 0.0))
