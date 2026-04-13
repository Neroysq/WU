class_name BossController
extends RefCounted

var current_phase: int = 1
var _phase_transitioned: bool = false
var _mountain_breaker_used: bool = false
var _bear_crush_cooldown: float = 0.0

const BEAR_CRUSH_COOLDOWN: float = 8.0

const PHASE_1_TABLE: Array[String] = [
	"bear_swipe",
	"bear_swipe",
	"bear_overhead",
	"bear_stomp",
	"bear_crush_grab",
]

const PHASE_2_TABLE: Array[String] = [
	"bear_swipe",
	"bear_overhead",
	"bear_stomp",
	"bear_crush_grab",
	"bear_roar_aoe",
]

func check_phase_transition(boss: Fighter) -> bool:
	if _phase_transitioned:
		return false
	if boss.health_current <= boss.health_max * 0.5:
		current_phase = 2
		_phase_transitioned = true
		_mountain_breaker_used = false
		return true
	return false

func get_phase_attack_table() -> Array[String]:
	if current_phase == 2:
		return PHASE_2_TABLE.duplicate()
	return PHASE_1_TABLE.duplicate()

func can_use_mountain_breaker() -> bool:
	return not _mountain_breaker_used

func consume_mountain_breaker() -> void:
	_mountain_breaker_used = true

func can_use_bear_crush() -> bool:
	return _bear_crush_cooldown <= 0.0

func consume_bear_crush() -> void:
	_bear_crush_cooldown = BEAR_CRUSH_COOLDOWN

func update_cooldowns(dt: float) -> void:
	if _bear_crush_cooldown > 0.0:
		_bear_crush_cooldown -= dt
