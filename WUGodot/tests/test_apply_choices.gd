extends RefCounted

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.reload_data()
	var fighter: Fighter = EnemyFactory.create_player()
	fighter.health_current = 10.0
	var run_state: RunState = RunState.create_procedural_run(3)
	run_state.bind_boon_loadout(fighter.technique_engine, fighter)

	RestService.apply("heal", fighter, run_state)
	if fighter.health_current > 10.0 and run_state.get_current_node().cleared:
		passed += 1
	else:
		failed += 1
		failures.append("RestService heal should restore HP and mark node cleared")

	fighter.technique_engine.add("A6", fighter)
	if ForgetService.apply("A6", fighter).get("success", false) and not fighter.technique_engine.has("A6"):
		passed += 1
	else:
		failed += 1
		failures.append("ForgetService should remove a selected legacy technique")

	fighter.gold = 100
	var result: Dictionary = ShopGenerator.buy_item({"type": "hp_potion", "price": 20}, fighter)
	if bool(result.get("success", false)) and fighter.gold == 80:
		passed += 1
	else:
		failed += 1
		failures.append("ShopGenerator.buy_item should remain a pure purchase apply path")

	return {"passed": passed, "failed": failed, "failures": failures}

