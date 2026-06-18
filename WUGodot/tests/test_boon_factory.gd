extends RefCounted

const Registry = preload("res://scripts/techniques/technique_registry.gd")

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	var effect: Variant = Registry.create_effect_from_data({
		"type": "stat_delta",
		"flat": {"health_max": 20.0},
	}, "boon_test")
	if effect != null and effect.id == "boon_test" and float((effect.params.get("flat", {}) as Dictionary).get("health_max", 0.0)) == 20.0:
		passed += 1
	else:
		failed += 1
		failures.append("create_effect_from_data should build stat_delta from raw effect data with a supplied id")

	DataManager.reload_data()
	var school: Dictionary = DataManager.get_school("venom")
	if str(school.get("signature", "")) == "venom":
		passed += 1
	else:
		failed += 1
		failures.append("DataManager.get_school should load the venom school")

	var boon: Dictionary = DataManager.get_boon("venom_light")
	var tiers: Dictionary = boon.get("tiers", {}) as Dictionary
	var common: Dictionary = tiers.get("common", {}) as Dictionary
	if str(boon.get("kind", "")) == "move" and str(boon.get("slot", "")) == "light" and typeof(common.get("effect", {})) == TYPE_DICTIONARY:
		passed += 1
	else:
		failed += 1
		failures.append("DataManager.get_boon should load venom_light with common effect data")

	var venom_boons: Array[Dictionary] = DataManager.get_boons_for_school("venom")
	if venom_boons.size() == 1 and str(venom_boons[0].get("id", "")) == "venom_light":
		passed += 1
	else:
		failed += 1
		failures.append("DataManager.get_boons_for_school should return venom boons")

	return {"passed": passed, "failed": failed, "failures": failures}
