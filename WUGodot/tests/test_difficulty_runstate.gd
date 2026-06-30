extends RefCounted

const EncounterResolverScript = preload("res://scripts/encounter_resolver.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.reload_data()
	var curve: Dictionary = DataManager.get_difficulty_curve(1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 18
	var tier1_ok: bool = true
	for i in range(12):
		if RunState._pick_node_type(rng, 1, i) != MapNode.NodeType.BATTLE:
			tier1_ok = false
	if tier1_ok:
		passed += 1
	else:
		failed += 1
		failures.append("tier 1 node weights should only produce BATTLE")

	var saw_elite_or_ambush: bool = false
	rng.seed = 19
	for i in range(40):
		var node_type: int = RunState._pick_node_type(rng, 4, i)
		if node_type == MapNode.NodeType.ELITE or node_type == MapNode.NodeType.AMBUSH:
			saw_elite_or_ambush = true
	if saw_elite_or_ambush:
		passed += 1
	else:
		failed += 1
		failures.append("tier 4 node weights should allow elite/ambush")

	if EncounterResolverScript.ambush_length(curve, 1) == 3 and EncounterResolverScript.ambush_length(curve, 2) == 3 and EncounterResolverScript.ambush_length(curve, 4) == 3:
		passed += 1
	else:
		failed += 1
		failures.append("ambush_length should use exact tier, nearest lower tier, then default 3")

	var ambush: MapNode = MapNode.new(30, 4, MapNode.NodeType.AMBUSH, [])
	ambush.ambush_remaining = 0
	var player: Fighter = EnemyFactory.create_player()
	RunFlow.travel_decision(ambush, player, RunState.new())
	if ambush.ambush_remaining == 3:
		passed += 1
	else:
		failed += 1
		failures.append("RunFlow.travel_decision should reset ambush length from the shared helper")

	var result: Dictionary = _drive_crafted_sequence()
	if bool(result.get("ok", false)):
		passed += 1
	else:
		failed += 1
		failures.append(str(result.get("message", "crafted sequence did not satisfy difficulty semantics")))

	return {"passed": passed, "failed": failed, "failures": failures}

func _drive_crafted_sequence() -> Dictionary:
	var run: RunState = RunState.new()
	var player: Fighter = EnemyFactory.create_player()
	player.health_max = 10000.0
	player.health_current = player.health_max
	player.attack_damage = 200.0
	player.attack_posture_damage = 200.0
	run.bind_boon_loadout(player.technique_engine, player)
	var policy: PlayerPolicy = HeuristicPlayer.new(1.0)
	var decision: DecisionPolicy = GreedySynergyPolicy.new()
	var sim: CombatSim = CombatSim.new()
	var transcript: RunTranscript = RunTranscript.new()
	transcript.seed = 444
	var driver: RunDriver = RunDriver.new()

	var battle_1: MapNode = MapNode.new(101, 1, MapNode.NodeType.BATTLE, [])
	var elite: MapNode = MapNode.new(102, 2, MapNode.NodeType.ELITE, [])
	var battle_2: MapNode = MapNode.new(103, 2, MapNode.NodeType.BATTLE, [])
	var ambush: MapNode = MapNode.new(104, 2, MapNode.NodeType.AMBUSH, [])
	ambush.ambush_remaining = 3
	run.nodes = [battle_1, elite, battle_2, ambush]

	for node in [battle_1, elite, battle_2, ambush]:
		run.current_node_id = node.id
		var outcome: String = driver._resolve_combat_node(node, player, run, policy, decision, sim, transcript, 1)
		if outcome == "defeat":
			return {"ok": false, "message": "crafted combat sequence should not defeat the overpowered test player"}

	var combats: Array = transcript.combats
	if combats.size() != 6:
		return {"ok": false, "message": "expected 6 combats (battle, elite, battle, 3-wave ambush), got %d" % combats.size()}
	var c0: Dictionary = combats[0] as Dictionary
	var c1: Dictionary = combats[1] as Dictionary
	var c2: Dictionary = combats[2] as Dictionary
	var c3: Dictionary = combats[3] as Dictionary
	var c4: Dictionary = combats[4] as Dictionary
	var c5: Dictionary = combats[5] as Dictionary
	if str(c0.get("pool_class", "")) != "weak" or int(c0.get("normal_combat_ordinal", -1)) != 0:
		return {"ok": false, "message": "first normal combat should be weak ordinal 0"}
	if str(c1.get("pool_class", "")) != "elite" or int(c1.get("normal_combat_ordinal", -1)) != 1:
		return {"ok": false, "message": "elite should not consume a normal ordinal"}
	if str(c2.get("pool_class", "")) != "weak" or int(c2.get("normal_combat_ordinal", -1)) != 1:
		return {"ok": false, "message": "second normal combat should be weak ordinal 1"}
	if str(c3.get("pool_class", "")) != "strong" or int(c3.get("normal_combat_ordinal", -1)) != 2:
		return {"ok": false, "message": "third normal combat should be strong ordinal 2"}
	if int(c3.get("ambush_wave", -1)) != 0 or int(c4.get("ambush_wave", -1)) != 1 or int(c5.get("ambush_wave", -1)) != 2:
		return {"ok": false, "message": "ambush waves should be recorded as 0,1,2"}
	if run.normal_combats_started != 5:
		return {"ok": false, "message": "normal_combats_started should be 5 after battle,battle,3 ambush waves"}
	return {"ok": true}
