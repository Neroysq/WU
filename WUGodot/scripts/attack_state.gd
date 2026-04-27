class_name AttackState
extends RefCounted

const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")

var def: Variant = null
var elapsed: float = 0.0
var _was_hit_active: bool = false
var _was_finished: bool = true

func start(definition: Variant) -> void:
	def = definition
	elapsed = 0.0
	_was_hit_active = false
	_was_finished = false

func clear() -> void:
	def = null
	elapsed = 0.0
	_was_hit_active = false
	_was_finished = true

func is_active() -> bool:
	return def != null and not _was_finished

func is_hit_active() -> bool:
	if def == null:
		return false
	return def.is_hit_active(elapsed)

func phase() -> int:
	if def == null:
		return AttackDefinitionScript.Phase.FINISHED
	return def.phase_at(elapsed)

func progress() -> float:
	if def == null or def.duration <= 0.0:
		return 0.0
	return clampf(elapsed / def.duration, 0.0, 1.0)

func progress_in_phase() -> float:
	if def == null or def.duration <= 0.0:
		return 0.0

	match phase():
		AttackDefinitionScript.Phase.WINDUP:
			if def.windup_end <= 0.0:
				return 1.0
			return clampf(elapsed / def.windup_end, 0.0, 1.0)
		AttackDefinitionScript.Phase.ACTIVE:
			var active_span: float = maxf(def.active_end - def.windup_end, 0.0001)
			return clampf((elapsed - def.windup_end) / active_span, 0.0, 1.0)
		AttackDefinitionScript.Phase.RECOVERY:
			var recovery_span: float = maxf(def.duration - def.active_end, 0.0001)
			return clampf((elapsed - def.active_end) / recovery_span, 0.0, 1.0)
		_:
			return 1.0

func advance(dt: float) -> Dictionary:
	var events: Dictionary = {
		"hit_started": false,
		"hit_ended": false,
		"finished": false,
	}
	if def == null or _was_finished:
		return events

	elapsed += dt

	var now_hit_active: bool = def.is_hit_active(elapsed)
	if now_hit_active and not _was_hit_active:
		events["hit_started"] = true
	elif (not now_hit_active) and _was_hit_active:
		events["hit_ended"] = true
	_was_hit_active = now_hit_active

	if def.is_finished(elapsed):
		events["finished"] = true
		_was_finished = true
		elapsed = def.duration
		if _was_hit_active:
			events["hit_ended"] = true
			_was_hit_active = false

	return events
