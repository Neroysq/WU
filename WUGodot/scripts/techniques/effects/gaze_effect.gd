extends "res://scripts/techniques/technique_effect.gd"

var _timer: float = 0.0
var _speed_bonus: float = 0.0
var _earned: bool = false

func _init() -> void:
	id = "B4"

func update(dt: float, fighter: Variant) -> void:
	if _earned and _timer <= 0.0:
		_speed_bonus = fighter.move_speed * float(params.get("speed_multiplier", 0.5))
		fighter.move_speed += _speed_bonus
		_timer = float(params.get("duration", 3.0))
		_earned = false
	if _timer > 0.0:
		_timer -= dt
		if _timer <= 0.0:
			fighter.move_speed -= _speed_bonus
			_timer = 0.0
			_speed_bonus = 0.0

func on_remove(fighter: Variant) -> void:
	_clear_active_bonus(fighter)
	_earned = false

func on_combat_start(fighter: Variant) -> void:
	_clear_active_bonus(fighter)

func on_kill(_fighter: Variant) -> void:
	if _timer > 0.0:
		_timer = float(params.get("duration", 3.0))
		return
	_earned = true

func _clear_active_bonus(fighter: Variant) -> void:
	if _speed_bonus > 0.0:
		fighter.move_speed -= _speed_bonus
	_timer = 0.0
	_speed_bonus = 0.0

func state() -> Dictionary:
	return {
		"timer": _timer,
		"speed_bonus": _speed_bonus,
		"earned": _earned,
	}

func restore(data: Dictionary) -> void:
	_timer = float(data.get("timer", 0.0))
	_speed_bonus = float(data.get("speed_bonus", 0.0))
	_earned = bool(data.get("earned", false))

func after_restore(fighter: Variant) -> void:
	if _timer > 0.0 and _speed_bonus > 0.0:
		fighter.move_speed += _speed_bonus
