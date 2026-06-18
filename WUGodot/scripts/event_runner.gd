class_name EventRunner
extends RefCounted

var _event_data: Dictionary = {}
var _resolved: bool = false

func load_event(data: Dictionary) -> void:
	_event_data = data.duplicate(true)
	_resolved = false

func get_title() -> String:
	return str(_event_data.get("title", ""))

func get_title_cn() -> String:
	return str(_event_data.get("title_cn", ""))

func get_text() -> String:
	return str(_event_data.get("text", ""))

func get_choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_choices: Variant = _event_data.get("choices", [])
	if typeof(raw_choices) == TYPE_ARRAY:
		for entry in raw_choices as Array:
			if typeof(entry) == TYPE_DICTIONARY:
				result.append((entry as Dictionary).duplicate(true))
	return result

func choose(index: int, fighter: Fighter) -> Dictionary:
	var choices: Array[Dictionary] = get_choices()
	if index < 0 or index >= choices.size():
		return {"message": "Invalid choice.", "blocked": true}

	var outcome_key: String = str(choices[index].get("outcome", ""))
	var outcomes: Dictionary = _event_data.get("outcomes", {}) as Dictionary
	var outcome: Dictionary = (outcomes.get(outcome_key, {}) as Dictionary).duplicate(true)
	_resolved = true
	return _apply_outcome(outcome, fighter)

func apply_timing_result(passed_test: bool, fighter: Fighter) -> Dictionary:
	var choices: Array[Dictionary] = get_choices()
	var outcomes: Dictionary = _event_data.get("outcomes", {}) as Dictionary
	for choice in choices:
		var outcome_key: String = str(choice.get("outcome", ""))
		var outcome: Dictionary = outcomes.get(outcome_key, {}) as Dictionary
		if not outcome.has("timing_test"):
			continue
		var sub_outcome: Dictionary = {}
		if passed_test:
			sub_outcome = (outcome.get("pass", {}) as Dictionary).duplicate(true)
		else:
			sub_outcome = (outcome.get("fail", {}) as Dictionary).duplicate(true)
		return _apply_outcome(sub_outcome, fighter)
	return {"message": "Test complete."}

func _apply_outcome(outcome: Dictionary, fighter: Fighter) -> Dictionary:
	var result: Dictionary = {}
	result["message"] = str(outcome.get("message", ""))

	var gold_change: int = int(outcome.get("gold", 0))
	if gold_change < 0 and fighter.gold < absi(gold_change):
		result["message"] = "Not enough gold."
		result["blocked"] = true
		return result
	fighter.gold += gold_change

	var hp_change: float = float(outcome.get("hp", 0.0))
	if hp_change != 0.0:
		fighter.health_current = clampf(fighter.health_current + hp_change, 1.0, fighter.health_max)

	var grant_type: String = str(outcome.get("grant_technique", ""))
	if not grant_type.is_empty() and fighter.technique_engine != null:
		var technique_id: String = _resolve_technique_grant(grant_type, fighter)
		if not technique_id.is_empty():
			fighter.technique_engine.add(technique_id, fighter)
			result["granted_technique"] = technique_id

	if outcome.has("open_shop"):
		result["open_shop"] = true
		result["shop_rarity_boost"] = bool(outcome.get("shop_rarity_boost", false))
	if outcome.has("trigger_combat"):
		result["trigger_combat"] = true
		result["combat_gold_multiplier"] = int(outcome.get("combat_gold_multiplier", 1))
	if outcome.has("timing_test"):
		result["timing_test"] = true
	if outcome.has("favor_school"):
		result["favor_school"] = str(outcome.get("favor_school", ""))
	if outcome.has("insight"):
		result["insight"] = int(outcome.get("insight", 0))

	return result

func _resolve_technique_grant(grant_type: String, fighter: Fighter) -> String:
	var all_techniques: Dictionary = DataManager.get_all_techniques()
	var owned_ids: Array[String] = fighter.technique_engine.technique_ids() if fighter.technique_engine != null else []

	if all_techniques.has(grant_type) and not owned_ids.has(grant_type):
		return grant_type

	var pool: Array[String] = []
	for tech_id in all_techniques.keys():
		var tech_id_str: String = str(tech_id)
		if owned_ids.has(tech_id_str):
			continue
		var technique: Dictionary = all_techniques[tech_id] as Dictionary
		match grant_type:
			"random_A":
				if str(technique.get("type", "")) == "A":
					pool.append(tech_id_str)
			"random_B":
				if str(technique.get("type", "")) == "B":
					pool.append(tech_id_str)
			_:
				pool.append(tech_id_str)

	if pool.is_empty():
		return ""
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return pool[rng.randi_range(0, pool.size() - 1)]
