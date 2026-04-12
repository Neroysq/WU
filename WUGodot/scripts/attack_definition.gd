class_name AttackDefinition
extends RefCounted

enum Phase {
	WINDUP,
	ACTIVE,
	RECOVERY,
	FINISHED,
}

var id: String = ""
var duration: float = 0.5
var windup_end: float = 0.18
var active_end: float = 0.30
var damage: float = 12.0
var posture_damage: float = 22.0
var is_heavy: bool = false
var is_perilous: bool = false
var is_parryable: bool = true
var range_units: float = 72.0
var knockback_units: float = 300.0
var ignores_block: bool = false

func phase_at(elapsed: float) -> int:
	if elapsed < windup_end:
		return Phase.WINDUP
	if elapsed < active_end:
		return Phase.ACTIVE
	if elapsed < duration:
		return Phase.RECOVERY
	return Phase.FINISHED

func is_hit_active(elapsed: float) -> bool:
	return elapsed >= windup_end and elapsed < active_end

func is_finished(elapsed: float) -> bool:
	return elapsed >= duration
