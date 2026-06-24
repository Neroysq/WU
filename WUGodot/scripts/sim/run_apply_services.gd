class_name RunApplyServices
extends RefCounted

const EncounterResolverScript = preload("res://scripts/encounter_resolver.gd")

static func resolve_node(decision: Dictionary, node: MapNode, player: Fighter, run_state: RunState, player_policy: PlayerPolicy, decision_policy: DecisionPolicy, sim: CombatSim, transcript: RunTranscript) -> String:
	match str(decision.get("scene", "map")):
		"combat":
			return resolve_combat_node(node, player, run_state, player_policy, decision_policy, sim, transcript, int(decision.get("combat_gold_multiplier", 1)))
		"boon_offer":
			resolve_boon_payload(decision, node, run_state, decision_policy)
			return ""
		"event":
			return resolve_event(decision.get("event_data", {}) as Dictionary, node, player, run_state, player_policy, decision_policy, sim, transcript)
		"shop":
			resolve_shop(decision.get("items", []) as Array, player, run_state, decision_policy)
			run_state.mark_current_node_cleared()
			return ""
		"rest":
			resolve_rest(player, run_state, decision_policy)
			return ""
		_:
			if bool(decision.get("mark_cleared", false)):
				run_state.mark_current_node_cleared()
			return ""

static func resolve_combat_node(node: MapNode, player: Fighter, run_state: RunState, player_policy: PlayerPolicy, decision_policy: DecisionPolicy, sim: CombatSim, transcript: RunTranscript, gold_multiplier: int) -> String:
	while true:
		var wave: int = EncounterResolverScript.wave_index_for_node(run_state, node)
		var encounter: Dictionary = EncounterResolverScript.begin_encounter(run_state, node, wave)
		var combat_result: CombatResult = sim.simulate(player, node, player_policy, 60.0, str(encounter.get("archetype", "")), transcript.seed, encounter)
		transcript.combats.append(combat_result.to_dict())
		if combat_result.winner != "player":
			transcript.death = combat_result.to_dict()
			return "defeat"
		var outcome: Dictionary = apply_combat_victory(player, run_state, node, gold_multiplier)
		if str(outcome.get("next", "")) == "combat_again":
			continue
		if str(outcome.get("next", "")) == "victory":
			return "victory"
		if str(outcome.get("next", "")) == "boon_offer":
			var payload: Dictionary = RunFlow.generate_school_choice_payload(run_state, node) if node.node_type == MapNode.NodeType.ELITE else RunFlow.generate_boon_offer_payload(run_state, node)
			resolve_boon_payload(payload, node, run_state, decision_policy)
		return ""
	return "defeat"

static func apply_combat_victory(player: Fighter, run_state: RunState, node: MapNode, gold_multiplier: int = 1) -> Dictionary:
	var outcome: Dictionary = RunFlow.combat_victory_outcome(node, gold_multiplier)
	player.gold += int(outcome.get("gold", 0))
	run_state.insight += int(outcome.get("insight", 0))
	if str(outcome.get("next", "")) != "combat_again":
		run_state.mark_current_node_cleared()
	return outcome

static func resolve_boon_payload(payload: Dictionary, node: MapNode, run_state: RunState, decision_policy: DecisionPolicy) -> void:
	var school_choices: Array = payload.get("school_choices", []) as Array
	if not school_choices.is_empty():
		var school_idx: int = decision_policy.choose("school", school_choices, run_state.boon_loadout, run_state)
		school_idx = clampi(school_idx, 0, school_choices.size() - 1)
		payload = payload_for_school_choice(payload, node, run_state, school_idx)
	var offers: Array = payload.get("offers", []) as Array
	if offers.is_empty():
		run_state.mark_current_node_cleared()
		return
	var pick: int = decision_policy.choose("boon", offers, run_state.boon_loadout, run_state)
	apply_boon_offer(run_state, offers[clampi(pick, 0, offers.size() - 1)] as Dictionary, true)

static func payload_for_school_choice(payload: Dictionary, node: MapNode, run_state: RunState, index: int) -> Dictionary:
	var school_choices: Array = payload.get("school_choices", []) as Array
	if school_choices.is_empty():
		return payload.duplicate(true)
	var school_idx: int = clampi(index, 0, school_choices.size() - 1)
	var school_id: String = str((school_choices[school_idx] as Dictionary).get("school", ""))
	return RunFlow.generate_boon_offer_payload(run_state, node, school_id)

static func apply_boon_offer(run_state: RunState, offer: Dictionary, mark_cleared: bool = true) -> Dictionary:
	var success: bool = RunFlow.apply_boon_offer_selection(run_state, offer)
	if mark_cleared:
		run_state.mark_current_node_cleared()
	return {"success": success, "boon_id": str(offer.get("boon_id", "")), "tier": str(offer.get("tier", "common"))}

static func resolve_event(event_data: Dictionary, node: MapNode, player: Fighter, run_state: RunState, player_policy: PlayerPolicy, decision_policy: DecisionPolicy, sim: CombatSim, transcript: RunTranscript) -> String:
	var runner: EventRunner = EventRunner.new()
	runner.load_event(event_data)
	var choices: Array[Dictionary] = runner.get_choices()
	if choices.is_empty():
		run_state.mark_current_node_cleared()
		return ""
	var pick: int = decision_policy.choose("event", choices, run_state.boon_loadout, run_state)
	var result: Dictionary = apply_event_choice(runner, clampi(pick, 0, choices.size() - 1), player, run_state)
	if bool(result.get("trigger_combat", false)):
		return resolve_combat_node(node, player, run_state, player_policy, decision_policy, sim, transcript, int(result.get("combat_gold_multiplier", 1)))
	if bool(result.get("open_shop", false)):
		var owned_ids: Array[String] = player.technique_engine.technique_ids() if player.technique_engine != null else []
		resolve_shop(ShopGenerator.generate_shop(owned_ids, bool(result.get("shop_rarity_boost", false))), player, run_state, decision_policy)
	run_state.mark_current_node_cleared()
	return ""

static func apply_event_choice(runner: EventRunner, index: int, player: Fighter, run_state: RunState) -> Dictionary:
	var result: Dictionary = runner.choose(index, player)
	if bool(result.get("blocked", false)):
		result = runner.choose(0, player)
	if bool(result.get("timing_test", false)):
		var rng: RandomNumberGenerator = RngService.stream("event")
		result = runner.apply_timing_result(rng.randf() < 0.5, player)
	var favor_school: String = str(result.get("favor_school", ""))
	if not favor_school.is_empty():
		run_state.favored_school = favor_school
	run_state.insight += int(result.get("insight", 0))
	return result

static func resolve_shop(items_source: Array, player: Fighter, run_state: RunState, decision_policy: DecisionPolicy) -> Dictionary:
	var items: Array = items_source.duplicate(true)
	if items.is_empty():
		return {"success": false, "message": "No items."}
	var pick: int = decision_policy.choose("shop", items, run_state.boon_loadout, run_state)
	return apply_shop_item(items[clampi(pick, 0, items.size() - 1)] as Dictionary, player, run_state)

static func apply_shop_item(item: Dictionary, player: Fighter, run_state: RunState) -> Dictionary:
	var result: Dictionary = ShopGenerator.buy_boon_upgrade(run_state) if str(item.get("type", "")) == "boon_upgrade" else ShopGenerator.buy_item(item, player)
	run_state.insight += int(result.get("insight", 0))
	return result

static func resolve_rest(player: Fighter, run_state: RunState, decision_policy: DecisionPolicy) -> Dictionary:
	var actions: Array[String] = RestService.actions_for(player, run_state)
	if actions.is_empty():
		run_state.mark_current_node_cleared()
		return {"success": false, "message": "No rest actions."}
	var pick: int = decision_policy.choose("rest", actions, run_state.boon_loadout, run_state)
	var result: Dictionary = apply_rest_action(actions[clampi(pick, 0, actions.size() - 1)], player, run_state)
	if str(result.get("next", "")) == "forget":
		resolve_forget(player, run_state, decision_policy)
	return result

static func apply_rest_action(action: String, player: Fighter, run_state: RunState) -> Dictionary:
	return RestService.apply(action, player, run_state)

static func resolve_forget(player: Fighter, run_state: RunState, decision_policy: DecisionPolicy) -> Dictionary:
	var ids: Array[String] = player.technique_engine.technique_ids() if player.technique_engine != null else []
	if ids.is_empty():
		run_state.mark_current_node_cleared()
		return {"success": false, "message": "No technique to forget."}
	var pick: int = decision_policy.choose("forget", ids, run_state.boon_loadout, run_state)
	return apply_forget(ids[clampi(pick, 0, ids.size() - 1)], player, run_state)

static func apply_forget(technique_id: String, player: Fighter, run_state: RunState) -> Dictionary:
	return ForgetService.apply(technique_id, player, run_state)
