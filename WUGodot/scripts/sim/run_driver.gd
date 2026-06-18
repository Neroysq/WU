class_name RunDriver
extends RefCounted

const MAX_NODE_STEPS: int = 64
const EncounterResolverScript = preload("res://scripts/encounter_resolver.gd")

func run(seed: int, player_policy: PlayerPolicy = null, decision_policy: DecisionPolicy = null, build: Dictionary = {}) -> RunTranscript:
	RngService.set_run_seed(seed)
	if player_policy == null:
		player_policy = HeuristicPlayer.new(float(build.get("skill", 0.8)))
	if decision_policy == null:
		decision_policy = GreedySynergyPolicy.new()

	var transcript: RunTranscript = RunTranscript.new()
	transcript.seed = seed
	transcript.player_policy = player_policy.get_script().resource_path.get_file().get_basename()
	transcript.decision_policy = decision_policy.get_script().resource_path.get_file().get_basename()

	var player: Fighter = EnemyFactory.create_player()
	var run_state: RunState = build.get("run_state_override", null) as RunState
	if run_state == null:
		run_state = RunState.create_procedural_run()
	run_state.bind_boon_loadout(player.technique_engine, player)
	var sim: CombatSim = CombatSim.new()

	for _step in range(MAX_NODE_STEPS):
		var next_nodes: Array[MapNode] = run_state.get_available_next()
		if next_nodes.is_empty():
			transcript.outcome = "victory"
			break
		var next_index: int = decision_policy.choose("map", next_nodes, run_state.boon_loadout, run_state)
		next_index = clampi(next_index, 0, next_nodes.size() - 1)
		var node: MapNode = next_nodes[next_index]
		run_state.advance_to(node.id)
		transcript.depth_reached = maxi(transcript.depth_reached, node.tier)
		transcript.nodes.append({"id": node.id, "tier": node.tier, "type": node.node_type})

		var decision: Dictionary = RunFlow.travel_decision(node, player, run_state)
		var node_result: String = _resolve_node(decision, node, player, run_state, player_policy, decision_policy, sim, transcript)
		_snapshot_build(transcript, run_state, node)
		if node_result == "defeat":
			transcript.outcome = "defeat"
			if transcript.death.is_empty():
				transcript.death = {"node_id": node.id, "tier": node.tier, "type": node.node_type}
			break
		if node_result == "victory":
			transcript.outcome = "victory"
			break

	if transcript.outcome.is_empty():
		transcript.outcome = "defeat"
	transcript.gold = player.gold
	transcript.insight = run_state.insight
	transcript.totals = _totals(transcript)
	return transcript

func _resolve_node(decision: Dictionary, node: MapNode, player: Fighter, run_state: RunState, player_policy: PlayerPolicy, decision_policy: DecisionPolicy, sim: CombatSim, transcript: RunTranscript) -> String:
	match str(decision.get("scene", "map")):
		"combat":
			return _resolve_combat_node(node, player, run_state, player_policy, decision_policy, sim, transcript, int(decision.get("combat_gold_multiplier", 1)))
		"boon_offer":
			_resolve_boon_payload(decision, node, run_state, decision_policy)
			return ""
		"event":
			return _resolve_event(decision.get("event_data", {}) as Dictionary, node, player, run_state, player_policy, decision_policy, sim, transcript)
		"shop":
			_resolve_shop(decision.get("items", []) as Array, player, run_state, decision_policy)
			run_state.mark_current_node_cleared()
			return ""
		"rest":
			_resolve_rest(player, run_state, decision_policy)
			return ""
		_:
			if bool(decision.get("mark_cleared", false)):
				run_state.mark_current_node_cleared()
			return ""

func _resolve_combat_node(node: MapNode, player: Fighter, run_state: RunState, player_policy: PlayerPolicy, decision_policy: DecisionPolicy, sim: CombatSim, transcript: RunTranscript, gold_multiplier: int) -> String:
	while true:
		var wave: int = EncounterResolverScript.wave_index_for_node(run_state, node)
		var encounter: Dictionary = EncounterResolverScript.begin_encounter(run_state, node, wave)
		var combat_result: CombatResult = sim.simulate(player, node, player_policy, 60.0, str(encounter.get("archetype", "")), transcript.seed, encounter)
		transcript.combats.append(combat_result.to_dict())
		if combat_result.winner != "player":
			transcript.death = combat_result.to_dict()
			return "defeat"
		var outcome: Dictionary = RunFlow.combat_victory_outcome(node, gold_multiplier)
		var gold_gained: int = int(outcome.get("gold", 0))
		player.gold += gold_gained
		run_state.insight += int(outcome.get("insight", 0))
		if str(outcome.get("next", "")) == "combat_again":
			continue
		run_state.mark_current_node_cleared()
		if str(outcome.get("next", "")) == "victory":
			return "victory"
		if str(outcome.get("next", "")) == "boon_offer":
			var payload: Dictionary = RunFlow.generate_school_choice_payload(run_state, node) if node.node_type == MapNode.NodeType.ELITE else RunFlow.generate_boon_offer_payload(run_state, node)
			_resolve_boon_payload(payload, node, run_state, decision_policy)
		return ""
	return "defeat"

func _resolve_boon_payload(payload: Dictionary, node: MapNode, run_state: RunState, decision_policy: DecisionPolicy) -> void:
	var school_choices: Array = payload.get("school_choices", []) as Array
	if not school_choices.is_empty():
		var school_idx: int = decision_policy.choose("school", school_choices, run_state.boon_loadout, run_state)
		school_idx = clampi(school_idx, 0, school_choices.size() - 1)
		var school_id: String = str((school_choices[school_idx] as Dictionary).get("school", ""))
		payload = RunFlow.generate_boon_offer_payload(run_state, node, school_id)
	var offers: Array = payload.get("offers", []) as Array
	if offers.is_empty():
		run_state.mark_current_node_cleared()
		return
	var pick: int = decision_policy.choose("boon", offers, run_state.boon_loadout, run_state)
	pick = clampi(pick, 0, offers.size() - 1)
	RunFlow.apply_boon_offer_selection(run_state, offers[pick] as Dictionary)
	run_state.mark_current_node_cleared()

func _resolve_event(event_data: Dictionary, node: MapNode, player: Fighter, run_state: RunState, player_policy: PlayerPolicy, decision_policy: DecisionPolicy, sim: CombatSim, transcript: RunTranscript) -> String:
	var runner: EventRunner = EventRunner.new()
	runner.load_event(event_data)
	var choices: Array[Dictionary] = runner.get_choices()
	if choices.is_empty():
		run_state.mark_current_node_cleared()
		return ""
	var pick: int = decision_policy.choose("event", choices, run_state.boon_loadout, run_state)
	pick = clampi(pick, 0, choices.size() - 1)
	var result: Dictionary = runner.choose(pick, player)
	if bool(result.get("blocked", false)):
		result = runner.choose(0, player)
	if bool(result.get("timing_test", false)):
		var rng: RandomNumberGenerator = RngService.stream("event")
		result = runner.apply_timing_result(rng.randf() < 0.5, player)
	var favor_school: String = str(result.get("favor_school", ""))
	if not favor_school.is_empty():
		run_state.favored_school = favor_school
	run_state.insight += int(result.get("insight", 0))
	if bool(result.get("trigger_combat", false)):
		return _resolve_combat_node(node, player, run_state, player_policy, decision_policy, sim, transcript, int(result.get("combat_gold_multiplier", 1)))
	if bool(result.get("open_shop", false)):
		var owned_ids: Array[String] = player.technique_engine.technique_ids() if player.technique_engine != null else []
		_resolve_shop(ShopGenerator.generate_shop(owned_ids, bool(result.get("shop_rarity_boost", false))), player, run_state, decision_policy)
	run_state.mark_current_node_cleared()
	return ""

func _resolve_shop(items_source: Array, player: Fighter, run_state: RunState, decision_policy: DecisionPolicy) -> void:
	var items: Array = items_source.duplicate(true)
	if items.is_empty():
		return
	var pick: int = decision_policy.choose("shop", items, run_state.boon_loadout, run_state)
	pick = clampi(pick, 0, items.size() - 1)
	var item: Dictionary = items[pick] as Dictionary
	var result: Dictionary = ShopGenerator.buy_boon_upgrade(run_state) if str(item.get("type", "")) == "boon_upgrade" else ShopGenerator.buy_item(item, player)
	run_state.insight += int(result.get("insight", 0))
	if bool(result.get("open_forget", false)):
		_resolve_forget(player, run_state, decision_policy)

func _resolve_rest(player: Fighter, run_state: RunState, decision_policy: DecisionPolicy) -> void:
	var actions: Array[String] = RestService.actions_for(player, run_state)
	var pick: int = decision_policy.choose("rest", actions, run_state.boon_loadout, run_state)
	pick = clampi(pick, 0, actions.size() - 1)
	var result: Dictionary = RestService.apply(actions[pick], player, run_state)
	if str(result.get("next", "")) == "forget":
		_resolve_forget(player, run_state, decision_policy)

func _resolve_forget(player: Fighter, run_state: RunState, decision_policy: DecisionPolicy) -> void:
	var ids: Array[String] = player.technique_engine.technique_ids() if player.technique_engine != null else []
	if ids.is_empty():
		run_state.mark_current_node_cleared()
		return
	var pick: int = decision_policy.choose("forget", ids, run_state.boon_loadout, run_state)
	pick = clampi(pick, 0, ids.size() - 1)
	ForgetService.apply(ids[pick], player, run_state)

func _snapshot_build(transcript: RunTranscript, run_state: RunState, node: MapNode) -> void:
	transcript.build_snapshots.append({
		"node_id": node.id,
		"after_node": node.id,
		"tier": node.tier,
		"loadout": run_state.boon_loadout.serialize(),
		"active_schools": run_state.boon_loadout.active_schools(),
		"insight": run_state.insight,
	})

func _totals(transcript: RunTranscript) -> Dictionary:
	var damage_dealt: float = 0.0
	var damage_taken: float = 0.0
	for combat in transcript.combats:
		damage_dealt += float((combat as Dictionary).get("damage_dealt", 0.0))
		damage_taken += float((combat as Dictionary).get("damage_taken", 0.0))
	return {
		"combats": transcript.combats.size(),
		"damage_dealt": damage_dealt,
		"damage_taken": damage_taken,
	}
