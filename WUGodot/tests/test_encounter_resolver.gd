extends RefCounted

const EncounterResolverScript = preload("res://scripts/encounter_resolver.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager._difficulty_curves.clear()
	var curve: Dictionary = DataManager.get_difficulty_curve(1)
	if not curve.is_empty() and (curve.get("weak_pool", []) as Array).has("bandit_swordsman") and not (curve.get("strong_pool", []) as Array).has("masked_assassin") and (curve.get("elite_pool", []) as Array).has("masked_assassin") and str(curve.get("boss", "")) == "iron_bear" and int(curve.get("weak_count", 0)) == 1 and not (curve.get("archetype_rank", {}) as Dictionary).is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("DataManager.get_difficulty_curve should cold-load chapter 1 pools/ranks")

	var cold_run: RunState = RunState.create_procedural_run(91)
	if cold_run.nodes.size() > 0:
		passed += 1
	else:
		failed += 1
		failures.append("RunState.create_procedural_run should work without explicit DataManager.initialize")

	DataManager.reload_data()
	var node: MapNode = MapNode.new(10, 1, MapNode.NodeType.BATTLE, [])
	var run: RunState = RunState.new()
	RngService.set_run_seed(100)
	var first: Dictionary = EncounterResolverScript.begin_encounter(run, node, 0)
	var second: Dictionary = EncounterResolverScript.begin_encounter(run, node, 0)
	if str(first.get("pool_class", "")) == "weak" and int(first.get("normal_combat_ordinal", -1)) == 0 and run.normal_combats_started == 2 and str(second.get("pool_class", "")) == "strong" and int(second.get("normal_combat_ordinal", -1)) == 1:
		passed += 1
	else:
		failed += 1
		failures.append("begin_encounter should select on pre-increment ordinal and mutate once")

	var elite: MapNode = MapNode.new(11, 4, MapNode.NodeType.ELITE, [])
	var before_elite: int = run.normal_combats_started
	var elite_result: Dictionary = EncounterResolverScript.begin_encounter(run, elite, 0)
	if str(elite_result.get("pool_class", "")) == "elite" and run.normal_combats_started == before_elite:
		passed += 1
	else:
		failed += 1
		failures.append("elite encounters should not advance normal_combats_started")

	run = RunState.new()
	run.normal_combats_started = 1
	run.last_archetype_by_pool = {"elite": "sect_disciple", "strong": "wandering_ronin"}
	RngService.set_run_seed(7)
	var scoped: Dictionary = EncounterResolverScript.begin_encounter(run, node, 0)
	if str(scoped.get("pool_class", "")) == "strong" and str(scoped.get("archetype", "")) == "sect_disciple":
		passed += 1
	else:
		failed += 1
		failures.append("anti-repeat should be scoped per pool, not global across elite/strong")

	var a_run: RunState = RunState.new()
	var b_run: RunState = RunState.new()
	RngService.set_run_seed(42)
	var a: Dictionary = EncounterResolverScript.begin_encounter(a_run, node, 0)
	RngService.set_run_seed(42)
	var b: Dictionary = EncounterResolverScript.begin_encounter(b_run, node, 0)
	if str(a.get("archetype", "")) == str(b.get("archetype", "")) and str(a.get("pool_class", "")) == str(b.get("pool_class", "")):
		passed += 1
	else:
		failed += 1
		failures.append("begin_encounter should reproduce after resetting RngService seed")

	run = RunState.new()
	run.normal_combats_started = int(curve.get("weak_count", 1))
	var after_gate: Dictionary = EncounterResolverScript.begin_encounter(run, node, 0)
	if str(after_gate.get("pool_class", "")) != "weak" and not (curve.get("weak_pool", []) as Array).has(str(after_gate.get("archetype", ""))):
		passed += 1
	else:
		failed += 1
		failures.append("weak-pool archetypes should not appear after normal_combat_ordinal >= weak_count")

	var strong_has_assassin: bool = false
	run = RunState.new()
	run.normal_combats_started = 1
	for seed in range(20):
		RngService.set_run_seed(500 + seed)
		var strong_result: Dictionary = EncounterResolverScript.begin_encounter(run, node, 0)
		if str(strong_result.get("archetype", "")) == "masked_assassin":
			strong_has_assassin = true
	var elite_assassin_possible: bool = (curve.get("elite_pool", []) as Array).has("masked_assassin")
	if not strong_has_assassin and elite_assassin_possible:
		passed += 1
	else:
		failed += 1
		failures.append("masked_assassin should be elite-only in chapter 1")

	var stats_match: bool = true
	for archetype in ["bandit_swordsman", "bandit_spearman", "wandering_ronin", "sect_disciple", "masked_assassin", "iron_bear"]:
		var enemy: Fighter = EnemyFactory.create_enemy_by_archetype(archetype)
		var enemy_data: Dictionary = DataManager.get_enemy(archetype)
		if not is_equal_approx(enemy.health_max, float(enemy_data.get("healthMax", enemy.health_max))):
			stats_match = false
	if stats_match:
		passed += 1
	else:
		failed += 1
		failures.append("resolved archetypes should create enemies at authored stats, with no inflation")

	run = RunState.new()
	run.normal_combats_started = 1
	var ambush: MapNode = MapNode.new(20, 2, MapNode.NodeType.AMBUSH, [])
	var ranks: Dictionary = curve.get("archetype_rank", {}) as Dictionary
	var last_rank: int = 0
	var nondecreasing: bool = true
	RngService.set_run_seed(900)
	for wave in range(3):
		var ambush_result: Dictionary = EncounterResolverScript.begin_encounter(run, ambush, wave)
		var rank: int = int(ranks.get(str(ambush_result.get("archetype", "")), 0))
		if rank < last_rank:
			nondecreasing = false
		last_rank = rank
	if nondecreasing:
		passed += 1
	else:
		failed += 1
		failures.append("ambush waves should escalate by archetype_rank")

	RngService.clear_run_seed()
	return {"passed": passed, "failed": failed, "failures": failures}
