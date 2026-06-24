class_name TriggerEngine
extends RefCounted

var _triggers: Array[Dictionary] = []
var _next_id: int = 1

func add_trigger(spec: Dictionary) -> int:
	var trigger: Dictionary = spec.duplicate(true)
	var id: int = _next_id
	_next_id += 1
	trigger["id"] = id
	_triggers.append(trigger)
	return id

func clear(id: Variant) -> void:
	if str(id) == "all":
		_triggers.clear()
		return
	var int_id: int = int(id)
	for i in range(_triggers.size() - 1, -1, -1):
		if int((_triggers[i] as Dictionary).get("id", 0)) == int_id:
			_triggers.remove_at(i)

func list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for trigger in _triggers:
		result.append((trigger as Dictionary).duplicate(true))
	return result

func evaluate(events: Array[Dictionary], state: Dictionary) -> Dictionary:
	for trigger in _triggers:
		var hit: bool = _matches(trigger, events, state)
		if hit:
			return {
				"triggered": true,
				"id": int(trigger.get("id", 0)),
				"event": str(trigger.get("event", "")),
				"screenshot": bool(trigger.get("screenshot", false)),
			}
	return {"triggered": false}

func _matches(trigger: Dictionary, events: Array[Dictionary], state: Dictionary) -> bool:
	var event_name: String = str(trigger.get("event", ""))
	match event_name:
		"hp_below":
			var who: String = str(trigger.get("who", "player"))
			var value: float = float(trigger.get("value", 0.0))
			var fighter: Dictionary = (state.get(who, {}) as Dictionary)
			return float(fighter.get("hp", 999999.0)) <= value
		"frame":
			return int(state.get("frame", -1)) >= int(trigger.get("n", trigger.get("value", -1)))
		"distance_below":
			return float(state.get("distance", 999999.0)) <= float(trigger.get("value", 0.0))

	for event in events:
		if _event_matches(event_name, event as Dictionary):
			return true
	return false

func _event_matches(name: String, event: Dictionary) -> bool:
	var type: String = str(event.get("type", ""))
	match name:
		"enemy_windup_start":
			return type == "attack_started" and str(event.get("fighter", "")) == "enemy"
		"enemy_attack_active":
			return type == "attack_active_started" and str(event.get("fighter", "")) == "enemy"
		"player_attack_active":
			return type == "attack_active_started" and str(event.get("fighter", "")) == "player"
		"player_attack_finished":
			return type == "attack_finished" and str(event.get("fighter", "")) == "player"
		"on_hit":
			return type == "hit" and str(event.get("by", "")) == "player"
		"on_get_hit":
			return type == "hit" and str(event.get("target", "")) == "player"
		"parry":
			return type == "hit" and bool(event.get("parried", false))
		"block":
			return type == "hit" and bool(event.get("blocked", false))
		"whiff":
			return type == "whiff"
		"combat_start":
			return type == "combat_start"
		"combat_end":
			return type == "combat_end"
		"death":
			return type == "death"
		_:
			return type == name

