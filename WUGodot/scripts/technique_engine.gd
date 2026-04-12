class_name TechniqueEngine
extends RefCounted

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

var _technique_ids: Array[String] = []
var _active_stance_id: String = ""
var _stance_timer: float = 0.0
var _stance_damage_taken: float = 0.0
var _pre_stance_dash_duration: float = 0.0
var _pre_stance_dash_iframe_end: float = 0.0
var _phoenix_used: bool = false
var _echo_active: bool = false
var _flowing_water_heal: bool = false
var _sparrow_timer: float = 0.0
var _gaze_timer: float = 0.0
var _gaze_speed_bonus: float = 0.0
var _gaze_earned: bool = false
var _stat_deltas: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func has(id: String) -> bool:
	return _technique_ids.has(id)

func technique_ids() -> Array[String]:
	return _technique_ids.duplicate()

func add(id: String, fighter: Fighter) -> void:
	if has(id):
		return
	if id.begins_with("D"):
		for existing_id in _technique_ids.duplicate():
			if existing_id.begins_with("D"):
				remove(existing_id, fighter)
	_technique_ids.append(id)
	_apply_on_add(id, fighter)

func remove(id: String, fighter: Fighter) -> void:
	if not has(id):
		return
	if _active_stance_id == id:
		deactivate_stance(fighter)
	if id == "B4":
		if _gaze_speed_bonus > 0.0:
			fighter.move_speed -= _gaze_speed_bonus
		_gaze_timer = 0.0
		_gaze_speed_bonus = 0.0
		_gaze_earned = false
	_technique_ids.erase(id)
	_unapply(id, fighter)

func _apply_on_add(id: String, fighter: Fighter) -> void:
	var delta: Variant = null
	match id:
		"A6":
			delta = {"posture_max": 15.0, "posture_current": 15.0}
			fighter.posture_max += 15.0
			fighter.posture_current += 15.0
		"A7":
			var move_bonus: float = fighter.move_speed * 0.15
			delta = {"move_speed": move_bonus}
			fighter.move_speed += move_bonus
		"A8":
			var recovery_bonus: float = fighter.posture_recovery_rate * 0.25
			delta = {"posture_recovery_rate": recovery_bonus}
			fighter.posture_recovery_rate += recovery_bonus
		"A9":
			delta = {"parry_window": 0.03}
			fighter.parry_window += 0.03
		"A11":
			var dash_bonus: float = fighter.dash_speed * 0.25
			var air_dash_bonus: float = fighter.air_dash_speed * 0.25
			var cooldown_delta: float = -minf(0.15, fighter.dash_cooldown - 0.1)
			delta = {
				"dash_speed": dash_bonus,
				"air_dash_speed": air_dash_bonus,
				"dash_cooldown": cooldown_delta,
			}
			fighter.dash_speed += dash_bonus
			fighter.air_dash_speed += air_dash_bonus
			fighter.dash_cooldown += cooldown_delta
		"A12":
			delta = {"health_max": 20.0, "health_current": 20.0}
			fighter.health_max += 20.0
			fighter.health_current += 20.0
	if delta != null:
		_stat_deltas[id] = delta

func _unapply(id: String, fighter: Fighter) -> void:
	var delta: Variant = _stat_deltas.get(id)
	if delta == null:
		return
	match id:
		"A6":
			fighter.posture_max -= float(delta["posture_max"])
			fighter.posture_current = minf(fighter.posture_current, fighter.posture_max)
		"A7":
			fighter.move_speed -= float(delta["move_speed"])
		"A8":
			fighter.posture_recovery_rate -= float(delta["posture_recovery_rate"])
		"A9":
			fighter.parry_window -= float(delta["parry_window"])
		"A11":
			fighter.dash_speed -= float(delta["dash_speed"])
			fighter.air_dash_speed -= float(delta["air_dash_speed"])
			fighter.dash_cooldown -= float(delta["dash_cooldown"])
		"A12":
			fighter.health_max -= float(delta["health_max"])
			fighter.health_current = minf(fighter.health_current, fighter.health_max)
	_stat_deltas.erase(id)

func update(dt: float, fighter: Fighter) -> void:
	# B4 deferred gaze: apply the buff at the start of the next fight.
	if _gaze_earned and _gaze_timer <= 0.0:
		_gaze_speed_bonus = fighter.move_speed * 0.5
		fighter.move_speed += _gaze_speed_bonus
		_gaze_timer = 3.0
		_gaze_earned = false

	if _sparrow_timer > 0.0:
		_sparrow_timer -= dt
	if _gaze_timer > 0.0:
		_gaze_timer -= dt
		if _gaze_timer <= 0.0:
			fighter.move_speed -= _gaze_speed_bonus
			_gaze_speed_bonus = 0.0
	if _active_stance_id == "D2" and _stance_timer > 0.0:
		_stance_timer -= dt
		if _stance_timer <= 0.0:
			deactivate_stance(fighter)

func activate_stance(fighter: Fighter) -> bool:
	if _active_stance_id != "":
		return false

	var d_id: String = ""
	for technique_id in _technique_ids:
		if technique_id.begins_with("D"):
			d_id = technique_id
			break
	if d_id.is_empty():
		return false
	if fighter.rage_current < fighter.rage_max:
		return false

	fighter.rage_current = 0.0
	_active_stance_id = d_id
	_stance_damage_taken = 0.0
	match d_id:
		"D1":
			_pre_stance_dash_duration = fighter.dash_duration
			_pre_stance_dash_iframe_end = fighter.dash_iframe_end
			fighter.dash_duration = 0.30
			# i-frame phase = 0.22s; absolute end = DASH_STARTUP_END(0.04) + 0.22 = 0.26
			fighter.dash_iframe_end = 0.26
		"D2":
			_stance_timer = 15.0
	return true

func deactivate_stance(fighter: Fighter) -> void:
	if _active_stance_id.is_empty():
		return
	match _active_stance_id:
		"D1":
			fighter.dash_duration = _pre_stance_dash_duration
			fighter.dash_iframe_end = _pre_stance_dash_iframe_end
	_active_stance_id = ""
	_stance_timer = 0.0
	_stance_damage_taken = 0.0

func is_stance_active() -> bool:
	return not _active_stance_id.is_empty()

func active_stance() -> String:
	return _active_stance_id

func get_light_override() -> Variant:
	match _active_stance_id:
		"D1":
			return AttackCatalogScript.drunken_light()
		"D2":
			return AttackCatalogScript.tiger_light()
	return null

func get_heavy_override() -> Variant:
	match _active_stance_id:
		"D1":
			return AttackCatalogScript.drunken_heavy()
		"D2":
			return AttackCatalogScript.tiger_heavy()
	return null

func set_echo() -> void:
	_echo_active = true

func consume_echo() -> bool:
	if _echo_active:
		_echo_active = false
		return true
	return false

func consume_flowing_water() -> bool:
	if _flowing_water_heal:
		_flowing_water_heal = false
		return true
	return false

func on_dash_through() -> void:
	if has("B3"):
		_flowing_water_heal = true

func on_dash_end() -> void:
	if has("A4"):
		_sparrow_timer = 0.6

func has_sparrow_bonus() -> bool:
	return _sparrow_timer > 0.0

func consume_sparrow() -> void:
	_sparrow_timer = 0.0

func on_kill(_fighter: Fighter) -> void:
	if not has("B4"):
		return
	if _gaze_timer > 0.0:
		# Already active in a multi-enemy fight; refresh timer.
		_gaze_timer = 3.0
		return
	# Deferred: buff applies at the start of the next fight's first update tick.
	_gaze_earned = true

func on_posture_break(fighter: Fighter) -> void:
	if has("B2"):
		fighter.health_current = minf(fighter.health_current + 15.0, fighter.health_max)

func check_lethal_save(fighter: Fighter) -> bool:
	if not has("B6") or _phoenix_used:
		return false
	_phoenix_used = true
	fighter.health_current = fighter.health_max * 0.2
	fighter._phoenix_invuln_timer = 2.0
	return true

func on_stance_damage(amount: float, fighter: Fighter) -> bool:
	if _active_stance_id != "D1":
		return false
	_stance_damage_taken += amount
	if _stance_damage_taken >= 20.0:
		deactivate_stance(fighter)
		return true
	return false

func roll_stagger() -> bool:
	return has("A2") and _rng.randf() < 0.2

func reset_combat_state(fighter: Fighter) -> void:
	_echo_active = false
	_flowing_water_heal = false
	_sparrow_timer = 0.0
	if _gaze_speed_bonus > 0.0:
		fighter.move_speed -= _gaze_speed_bonus
	_gaze_timer = 0.0
	_gaze_speed_bonus = 0.0
	# _gaze_earned intentionally persists; it carries the buff into the next fight.
	_stance_damage_taken = 0.0
