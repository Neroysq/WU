class_name RunConductor
extends RefCounted

const EncounterResolverScript = preload("res://scripts/encounter_resolver.gd")
const RunApplyServicesScript = preload("res://scripts/sim/run_apply_services.gd")
const CombatControllerScript = preload("res://scripts/sim/combat_controller.gd")

var seed: int = 1
var player: Fighter = null
var run_state: RunState = null
var pause_kind: String = ""
var decision_kind: String = ""
var options: Array = []
var current_node: MapNode = null
var current_payload: Dictionary = {}
var combat: Variant = null
var outcome: String = ""
var forced_archetype: String = ""

func start(seed_value: int = 1, build: Dictionary = {}) -> Dictionary:
	seed = seed_value
	RngService.set_run_seed(seed)
	player = EnemyFactory.create_player()
	run_state = build.get("run_state_override", null) as RunState
	if run_state == null:
		run_state = RunState.create_procedural_run()
	run_state.bind_boon_loadout(player.technique_engine, player)
	_apply_build(build.get("build", []))
	forced_archetype = str(build.get("forced_archetype", ""))
	outcome = ""
	combat = null
	_pause_map()
	return observe()

func choose(index: int) -> Dictionary:
	if pause_kind != "decision":
		return _error("choose is only valid at decision pauses")
	match decision_kind:
		"map":
			return _choose_map(index)
		"school_choice":
			var payload: Dictionary = RunApplyServicesScript.payload_for_school_choice(current_payload, current_node, run_state, index)
			_pause_boon_offer(payload)
			return observe()
		"boon_offer":
			if options.is_empty():
				run_state.mark_current_node_cleared()
			else:
				RunApplyServicesScript.apply_boon_offer(run_state, options[clampi(index, 0, options.size() - 1)] as Dictionary, true)
			_pause_map()
			return observe()
		"event":
			return _choose_event(index)
		"shop":
			return _choose_shop(index)
		"rest":
			return _choose_rest(index)
		"forget":
			return _choose_forget(index)
		_:
			return _error("unknown decision kind %s" % decision_kind)

func advance_combat(actions: Array = [], frames: int = 1) -> Dictionary:
	if pause_kind != "combat" or combat == null:
		return _error("advance is only valid during combat")
	var result: Dictionary = combat.advance(actions, frames)
	var reason: String = str(result.get("reason", "budget_spent"))
	if str(result.get("winner", "")) == "player":
		return _finish_combat_victory(result)
	if str(result.get("winner", "")) == "enemy":
		outcome = "defeat"
		reason = "combat_end"
	var response: Dictionary = observe({"reason": reason})
	if response.has("combat"):
		var combat_observation: Dictionary = response["combat"] as Dictionary
		combat_observation["events"] = result.get("events", [])
		combat_observation["state"] = result.get("state", combat_observation.get("state", {}))
		combat_observation["pause"] = {"kind": "combat", "reason": reason, "winner": str(result.get("winner", ""))}
		response["combat"] = combat_observation
	response["advance"] = result
	return response

func step(frames: int = 1) -> Dictionary:
	return advance_combat([], frames)

func observe(extra: Dictionary = {}) -> Dictionary:
	var response: Dictionary = {
		"context": {"pause_kind": pause_kind, "decision": decision_kind, "outcome": outcome},
		"pause": {"kind": pause_kind, "decision": decision_kind},
		"options": _serialize_options(),
	}
	if pause_kind == "combat" and combat != null:
		response["combat"] = combat.observe(true)
	if not extra.is_empty():
		response["extra"] = extra
	return response

func projection_snapshot() -> Dictionary:
	var data: Dictionary = {
		"pause_kind": pause_kind,
		"decision": decision_kind,
		"options": _serialize_options(),
		"outcome": outcome,
	}
	if pause_kind == "combat" and combat != null:
		data["combat"] = combat.state()
	return data

func transcript_state() -> Dictionary:
	return {
		"pause_kind": pause_kind,
		"decision": decision_kind,
		"outcome": outcome,
		"run_state": run_state.serialize() if run_state != null else {},
		"player_hp": player.health_current if player != null else 0.0,
		"combat": combat.state() if combat != null else {},
	}

func add_trigger(spec: Dictionary) -> Dictionary:
	if pause_kind != "combat" or combat == null:
		return _error("trigger_add is only valid during combat")
	return {"id": combat.add_trigger(spec)}

func clear_trigger(id: Variant) -> Dictionary:
	if pause_kind != "combat" or combat == null:
		return _error("trigger_clear is only valid during combat")
	combat.clear_trigger(id)
	return {"success": true}

func trigger_list() -> Dictionary:
	if pause_kind != "combat" or combat == null:
		return _error("trigger_list is only valid during combat")
	return {"triggers": combat.trigger_list()}

func _choose_map(index: int) -> Dictionary:
	var next_nodes: Array[MapNode] = run_state.get_available_next()
	if next_nodes.is_empty():
		outcome = "victory"
		return observe()
	current_node = next_nodes[clampi(index, 0, next_nodes.size() - 1)]
	run_state.advance_to(current_node.id)
	var decision: Dictionary = RunFlow.travel_decision(current_node, player, run_state)
	return _route_decision(decision)

func _route_decision(decision: Dictionary) -> Dictionary:
	current_payload = decision.duplicate(true)
	match str(decision.get("scene", "map")):
		"combat":
			_start_combat(int(decision.get("combat_gold_multiplier", 1)))
		"boon_offer":
			if not (decision.get("school_choices", []) as Array).is_empty():
				_pause_school_choice(decision)
			else:
				_pause_boon_offer(decision)
		"event":
			_pause_event(decision)
		"shop":
			_pause_decision("shop", decision.get("items", []) as Array)
		"rest":
			_pause_decision("rest", RestService.actions_for(player, run_state))
		_:
			if bool(decision.get("mark_cleared", false)):
				run_state.mark_current_node_cleared()
			_pause_map()
	return observe()

func _start_combat(gold_multiplier: int = 1) -> void:
	var wave: int = EncounterResolverScript.wave_index_for_node(run_state, current_node)
	var encounter: Dictionary = EncounterResolverScript.begin_encounter(run_state, current_node, wave)
	if not forced_archetype.is_empty():
		encounter["archetype"] = forced_archetype
	combat = CombatControllerScript.new()
	combat.start(player, current_node, str(encounter.get("archetype", "")), seed, encounter)
	current_payload["combat_gold_multiplier"] = gold_multiplier
	pause_kind = "combat"
	decision_kind = ""
	options = []

func _finish_combat_victory(combat_result: Dictionary) -> Dictionary:
	var gold_multiplier: int = int(current_payload.get("combat_gold_multiplier", 1))
	var victory: Dictionary = RunApplyServicesScript.apply_combat_victory(player, run_state, current_node, gold_multiplier)
	match str(victory.get("next", "")):
		"combat_again":
			_start_combat(gold_multiplier)
		"victory":
			outcome = "victory"
			pause_kind = "decision"
			decision_kind = "complete"
			options = []
		"boon_offer":
			var payload: Dictionary = RunFlow.generate_school_choice_payload(run_state, current_node) if current_node.node_type == MapNode.NodeType.ELITE else RunFlow.generate_boon_offer_payload(run_state, current_node)
			if not (payload.get("school_choices", []) as Array).is_empty():
				_pause_school_choice(payload)
			else:
				_pause_boon_offer(payload)
	return observe({"reason": "combat_end", "combat": combat_result, "victory": victory})

func _pause_map() -> void:
	var next_nodes: Array[MapNode] = run_state.get_available_next()
	if next_nodes.is_empty():
		outcome = "victory"
	pause_kind = "decision"
	decision_kind = "map"
	options = []
	for node in next_nodes:
		options.append(node)

func _pause_school_choice(payload: Dictionary) -> void:
	current_payload = payload.duplicate(true)
	_pause_decision("school_choice", payload.get("school_choices", []) as Array)

func _pause_boon_offer(payload: Dictionary) -> void:
	current_payload = payload.duplicate(true)
	_pause_decision("boon_offer", payload.get("offers", []) as Array)

func _pause_event(payload: Dictionary) -> void:
	current_payload = payload.duplicate(true)
	var runner: EventRunner = EventRunner.new()
	runner.load_event(payload.get("event_data", {}) as Dictionary)
	_pause_decision("event", runner.get_choices())

func _pause_decision(kind: String, decision_options: Array) -> void:
	pause_kind = "decision"
	decision_kind = kind
	options = decision_options.duplicate(true)

func _choose_event(index: int) -> Dictionary:
	var runner: EventRunner = EventRunner.new()
	runner.load_event(current_payload.get("event_data", {}) as Dictionary)
	var result: Dictionary = RunApplyServicesScript.apply_event_choice(runner, index, player, run_state)
	if bool(result.get("trigger_combat", false)):
		current_payload["combat_gold_multiplier"] = int(result.get("combat_gold_multiplier", 1))
		_start_combat(int(result.get("combat_gold_multiplier", 1)))
	elif bool(result.get("open_shop", false)):
		var owned_ids: Array[String] = player.technique_engine.technique_ids() if player.technique_engine != null else []
		_pause_decision("shop", ShopGenerator.generate_shop(owned_ids, bool(result.get("shop_rarity_boost", false))))
	else:
		run_state.mark_current_node_cleared()
		_pause_map()
	return observe({"event_result": result})

func _choose_shop(index: int) -> Dictionary:
	if options.is_empty():
		run_state.mark_current_node_cleared()
		_pause_map()
		return observe()
	var result: Dictionary = RunApplyServicesScript.apply_shop_item(options[clampi(index, 0, options.size() - 1)] as Dictionary, player, run_state)
	if bool(result.get("open_forget", false)):
		_pause_decision("forget", player.technique_engine.technique_ids() if player.technique_engine != null else [])
	else:
		run_state.mark_current_node_cleared()
		_pause_map()
	return observe({"shop_result": result})

func _choose_rest(index: int) -> Dictionary:
	if options.is_empty():
		run_state.mark_current_node_cleared()
		_pause_map()
		return observe()
	var result: Dictionary = RunApplyServicesScript.apply_rest_action(str(options[clampi(index, 0, options.size() - 1)]), player, run_state)
	if str(result.get("next", "")) == "forget":
		_pause_decision("forget", player.technique_engine.technique_ids() if player.technique_engine != null else [])
	else:
		_pause_map()
	return observe({"rest_result": result})

func _choose_forget(index: int) -> Dictionary:
	if options.is_empty():
		run_state.mark_current_node_cleared()
	else:
		RunApplyServicesScript.apply_forget(str(options[clampi(index, 0, options.size() - 1)]), player, run_state)
	_pause_map()
	return observe()

func _serialize_options() -> Array:
	var result: Array = []
	for option in options:
		if option is MapNode:
			var node: MapNode = option as MapNode
			result.append({"id": node.id, "tier": node.tier, "type": node.node_type, "cleared": node.cleared})
		elif typeof(option) == TYPE_DICTIONARY:
			result.append((option as Dictionary).duplicate(true))
		else:
			result.append(option)
	return result

func _apply_build(value: Variant) -> void:
	if typeof(value) != TYPE_ARRAY:
		return
	for item in value as Array:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		RunFlow.apply_boon_offer_selection(run_state, item as Dictionary)

func _error(message: String) -> Dictionary:
	return {"status": "error", "error": message, "pause": {"kind": pause_kind, "decision": decision_kind}}
