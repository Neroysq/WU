extends RefCounted

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")
const Registry = preload("res://scripts/techniques/technique_registry.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.reload_data()
	RngService.set_run_seed(31)
	var player: Fighter = EnemyFactory.create_player()
	var node: MapNode = MapNode.new(10, 1, MapNode.NodeType.BATTLE, [])
	var setup: Dictionary = CombatSetup.prepare(player, node, "bandit_swordsman")
	var enemy: Fighter = setup["enemy"] as Fighter
	enemy.position = player.position + Vector2(70.0, 0.0)
	var combat_system: CombatSystem = setup["combat_system"] as CombatSystem
	var input: Dictionary = PlayerPolicy.neutral_input()
	input["light_pressed"] = true
	for i in range(24):
		CombatStep.advance(combat_system, player, enemy, input if i == 0 else PlayerPolicy.neutral_input(), 1.0 / 60.0)
	if enemy.health_current < enemy.health_max:
		passed += 1
	else:
		failed += 1
		failures.append("CombatStep should run the full frame block so attacks deal damage")

	player = EnemyFactory.create_player()
	var effect: Variant = Registry.create_effect_from_data({"type": "venom", "stacks": 1, "timer": 2.0, "dps": 1.0}, "test_venom#0")
	player.technique_engine.add_effect(effect, player)
	setup = CombatSetup.prepare(player, node, "bandit_swordsman")
	enemy = setup["enemy"] as Fighter
	enemy.position = player.position + Vector2(70.0, 0.0)
	combat_system = setup["combat_system"] as CombatSystem
	input = PlayerPolicy.neutral_input()
	input["light_pressed"] = true
	ProcRecorder.begin()
	for i in range(24):
		CombatStep.advance(combat_system, player, enemy, input if i == 0 else PlayerPolicy.neutral_input(), 1.0 / 60.0)
	var proc_data: Dictionary = ProcRecorder.end()
	if int((proc_data.get("status_applications", {}) as Dictionary).get("venom", 0)) >= 1 and int((proc_data.get("boon_procs", {}) as Dictionary).get("test_venom", 0)) >= 1:
		passed += 1
	else:
		failed += 1
		failures.append("ProcRecorder should capture boon procs and status applications during sim frames")

	RngService.set_run_seed(32)
	var encounter: Dictionary = {
		"node_id": node.id,
		"normal_combat_ordinal": 0,
		"pool_class": "weak",
		"ambush_wave": 0,
	}
	var result: CombatResult = CombatSim.new().simulate(EnemyFactory.create_player(), node, HeuristicPlayer.new(0.8), 3.0, "bandit_swordsman", 32, encounter)
	if not result.winner.is_empty() and result.frames > 0:
		passed += 1
	else:
		failed += 1
		failures.append("CombatSim should return a terminal result or timeout")

	var result_dict: Dictionary = result.to_dict()
	if int(result_dict.get("node_id", -1)) == node.id and int(result_dict.get("normal_combat_ordinal", -1)) == 0 and str(result_dict.get("pool_class", "")) == "weak" and int(result_dict.get("ambush_wave", -1)) == 0:
		passed += 1
	else:
		failed += 1
		failures.append("CombatSim should copy encounter metadata into CombatResult")

	RngService.clear_run_seed()
	return {"passed": passed, "failed": failed, "failures": failures}
