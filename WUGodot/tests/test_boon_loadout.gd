extends RefCounted

const FighterScript = preload("res://scripts/fighter.gd")
const Registry = preload("res://scripts/techniques/technique_registry.gd")
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	var fighter: Variant = FighterScript.new()
	fighter.health_max = 100.0
	fighter.health_current = 100.0
	var engine: Variant = TechniqueEngineScript.new()

	if not engine.has_method("add_effect") or not engine.has_method("remove_effect"):
		failed += 1
		failures.append("TechniqueEngine should expose add_effect/remove_effect for prebuilt boon effects")
		return {"passed": passed, "failed": failed, "failures": failures}

	var effect: Variant = Registry.create_effect_from_data({
		"type": "stat_delta",
		"flat": {"health_max": 20.0},
	}, "boon_stat#0")

	engine.add_effect(effect, fighter)
	if engine.has_effect("boon_stat#0") and is_equal_approx(fighter.health_max, 120.0):
		passed += 1
	else:
		failed += 1
		failures.append("add_effect should install and activate a prebuilt boon effect")

	if engine.technique_ids().is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("boon add_effect should not add fake ids to technique_ids (got %s)" % str(engine.technique_ids()))

	var saved: Dictionary = engine.save_state()
	var saved_ids: Array = saved.get("technique_ids", []) as Array
	if saved_ids.is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("boon add_effect should not add fake ids to engine save_state technique_ids (got %s)" % str(saved_ids))

	engine.remove_effect(effect, fighter)
	if not engine.has_effect("boon_stat#0") and is_equal_approx(fighter.health_max, 100.0):
		passed += 1
	else:
		failed += 1
		failures.append("remove_effect should remove and deactivate a prebuilt boon effect")

	return {"passed": passed, "failed": failed, "failures": failures}
