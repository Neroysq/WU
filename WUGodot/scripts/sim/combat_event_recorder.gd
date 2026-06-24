class_name CombatEventRecorder
extends RefCounted

var _events: Array[Dictionary] = []
var _seq: int = 0
var _contact_by_role: Dictionary = {}

func record(event_type: String, data: Dictionary = {}) -> void:
	var event: Dictionary = data.duplicate(true)
	event["type"] = event_type
	event["seq"] = _seq
	_seq += 1
	_events.append(event)

func events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in _events:
		result.append((event as Dictionary).duplicate(true))
	return result

func event_count() -> int:
	return _events.size()

func events_from(index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(clampi(index, 0, _events.size()), _events.size()):
		result.append((_events[i] as Dictionary).duplicate(true))
	return result

func drain() -> Array[Dictionary]:
	var result: Array[Dictionary] = events()
	_events.clear()
	return result

func clear() -> void:
	_events.clear()
	_contact_by_role.clear()

func begin_attack(role: String, fighter: Fighter) -> void:
	_contact_by_role[role] = false
	record("attack_started", _attack_data(role, fighter))

func attack_active_started(role: String, fighter: Fighter) -> void:
	record("attack_active_started", _attack_data(role, fighter))

func finish_attack(role: String, fighter: Fighter) -> void:
	record("attack_finished", _attack_data(role, fighter))
	_contact_by_role.erase(role)

func active_window_closed(role: String, fighter: Fighter) -> void:
	if not bool(_contact_by_role.get(role, false)):
		record("whiff", _attack_data(role, fighter))

func phase_changed(role: String, fighter: Fighter, phase: int) -> void:
	var data: Dictionary = _attack_data(role, fighter)
	data["phase"] = _phase_name(phase)
	record("phase_changed", data)

func record_hit(attacker: Fighter, defender: Fighter, hp_damage: float, posture_damage: float, blocked: bool, parried: bool, critical: bool) -> void:
	var role: String = _role(attacker)
	_contact_by_role[role] = true
	record("hit", {
		"by": role,
		"target": _role(defender),
		"attack_id": _attack_id(attacker),
		"hp_damage": hp_damage,
		"posture_damage": posture_damage,
		"blocked": blocked,
		"parried": parried,
		"critical": critical,
	})

func record_status_applied(target: Fighter, status_type: String, stacks: int = 1) -> void:
	record("status_applied", {"target": _role(target), "status": status_type, "stacks": stacks})

func record_boon_proc(boon_id: String, amount: int = 1) -> void:
	record("boon_proc", {"id": boon_id, "amount": amount})

func record_dash(fighter: Fighter) -> void:
	record("dash", {"fighter": _role(fighter), "iframes": fighter.dash_iframe_end})

func record_stun(fighter: Fighter, duration: float) -> void:
	record("stun", {"fighter": _role(fighter), "duration": duration})

func record_enemy_decision(action: String, attack_id: String = "") -> void:
	record("enemy_decision", {"action": action, "attack_id": attack_id})

func record_death(fighter: Fighter) -> void:
	record("death", {"fighter": _role(fighter)})

func _attack_data(role: String, fighter: Fighter) -> Dictionary:
	return {
		"fighter": role,
		"attack_id": _attack_id(fighter),
		"elapsed": fighter._attack_state.elapsed if fighter != null and fighter._attack_state != null else 0.0,
	}

func _attack_id(fighter: Fighter) -> String:
	if fighter == null or fighter._attack_state == null or fighter._attack_state.def == null:
		return ""
	return str(fighter._attack_state.def.id)

func _role(fighter: Fighter) -> String:
	return "enemy" if fighter != null and fighter.is_ai else "player"

func _phase_name(phase: int) -> String:
	match phase:
		AttackDefinition.Phase.WINDUP:
			return "windup"
		AttackDefinition.Phase.ACTIVE:
			return "active"
		AttackDefinition.Phase.RECOVERY:
			return "recovery"
		_:
			return "finished"
