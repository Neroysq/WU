extends RefCounted

const BoonFactoryScript = preload("res://scripts/boons/boon_factory.gd")
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

	var test_boon: Dictionary = {
		"id": "test_light",
		"kind": "move",
		"tiers": {
			"common": {"effect": {"type": "stat_delta", "flat": {"health_max": 10.0}}},
			"rare": {"riders": [{"type": "stat_delta", "flat": {"posture_max": 5.0}}]},
			"epic": {"riders": [{"type": "stat_delta", "scaled": {"move_speed": 0.1}}]},
			"legendary": {"riders": [{"type": "stat_delta", "flat": {"rage_max": 10.0}}]},
		},
	}
	var common_effects: Array = BoonFactoryScript.build_boon_effects(test_boon, "common")
	var epic_effects: Array = BoonFactoryScript.build_boon_effects(test_boon, "epic")
	if common_effects.size() == 1 and epic_effects.size() == 3 and str(epic_effects[0].id).begins_with("test_light#") and str(epic_effects[2].params.get("type", "")) == "stat_delta":
		passed += 1
	else:
		failed += 1
		failures.append("BoonFactory should compose cumulative effects through the requested tier")

	var duo_boon: Dictionary = {
		"id": "test_duo",
		"kind": "duo",
		"effect": {"type": "stat_delta", "flat": {"health_max": 1.0}},
	}
	var duo_effects: Array = BoonFactoryScript.build_boon_effects(duo_boon, "legendary")
	if duo_effects.size() == 1 and duo_effects[0].id == "test_duo#0":
		passed += 1
	else:
		failed += 1
		failures.append("BoonFactory should build duo/mastery boons as single-tier effects")

	return {"passed": passed, "failed": failed, "failures": failures}
