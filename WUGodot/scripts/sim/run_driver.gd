class_name RunDriver
extends RefCounted

const MAX_NODE_STEPS: int = 64
const RunApplyServicesScript = preload("res://scripts/sim/run_apply_services.gd")

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
		var node_result: String = RunApplyServicesScript.resolve_node(decision, node, player, run_state, player_policy, decision_policy, sim, transcript)
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

func _snapshot_build(transcript: RunTranscript, run_state: RunState, node: MapNode) -> void:
	transcript.build_snapshots.append({
		"node_id": node.id,
		"after_node": node.id,
		"tier": node.tier,
		"loadout": run_state.boon_loadout.serialize(),
		"active_schools": run_state.boon_loadout.active_schools(),
		"insight": run_state.insight,
	})

func _resolve_combat_node(node: MapNode, player: Fighter, run_state: RunState, player_policy: PlayerPolicy, decision_policy: DecisionPolicy, sim: CombatSim, transcript: RunTranscript, gold_multiplier: int) -> String:
	return RunApplyServicesScript.resolve_combat_node(node, player, run_state, player_policy, decision_policy, sim, transcript, gold_multiplier)

func _resolve_node(decision: Dictionary, node: MapNode, player: Fighter, run_state: RunState, player_policy: PlayerPolicy, decision_policy: DecisionPolicy, sim: CombatSim, transcript: RunTranscript) -> String:
	return RunApplyServicesScript.resolve_node(decision, node, player, run_state, player_policy, decision_policy, sim, transcript)

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
