extends RefCounted

const BoonLoadoutScript = preload("res://scripts/boons/boon_loadout.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const Registry = preload("res://scripts/techniques/technique_registry.gd")
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")

func _seed_test_boons() -> void:
	DataManager.reload_data()
	DataManager._boons["test_light"] = {
		"id": "test_light",
		"school": "venom",
		"kind": "move",
		"slot": "light",
		"tiers": {
			"common": {"effect": {"type": "stat_delta", "flat": {"health_max": 10.0}}},
			"rare": {"riders": [{"type": "stat_delta", "flat": {"rage_max": 5.0}}]},
		},
	}
	DataManager._boons["test_light_alt"] = {
		"id": "test_light_alt",
		"school": "venom",
		"kind": "move",
		"slot": "light",
		"tiers": {
			"common": {"effect": {"type": "stat_delta", "flat": {"posture_max": 7.0}}},
			"rare": {"riders": [{"type": "stat_delta", "flat": {"health_max": 5.0}}]},
		},
	}
	DataManager._boons["test_passive"] = {
		"id": "test_passive",
		"school": "thunder",
		"kind": "passive",
		"tiers": {
			"common": {"effect": {"type": "stat_delta", "flat": {"move_speed": 3.0}}},
		},
	}
	DataManager._boons["test_duo"] = {
		"id": "test_duo",
		"school": "venom",
		"kind": "duo",
		"requires": {"schools": ["venom", "thunder"]},
		"effect": {"type": "stat_delta", "flat": {"health_max": 1.0}},
	}

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

	_seed_test_boons()
	var loadout: Variant = BoonLoadoutScript.new(engine, fighter)
	if loadout.add_boon("test_light", "common") and loadout.slots.has("light") and engine.has_effect("test_light#0") and is_equal_approx(fighter.health_max, 110.0):
		passed += 1
	else:
		failed += 1
		failures.append("add_boon should fill a move slot and install its effects")

	if loadout.add_boon("test_light_alt", "common") and str((loadout.slots["light"] as Dictionary).get("boon_id", "")) == "test_light_alt" \
			and not engine.has_effect("test_light#0") and engine.has_effect("test_light_alt#0") \
			and is_equal_approx(fighter.health_max, 100.0) and is_equal_approx(fighter.posture_max, 107.0):
		passed += 1
	else:
		failed += 1
		failures.append("adding a move boon to a filled slot should replace and remove the old effects")

	if loadout.upgrade_boon("test_light_alt") and str((loadout.slots["light"] as Dictionary).get("tier", "")) == "rare" \
			and engine.has_effect("test_light_alt#0") and engine.has_effect("test_light_alt#1") \
			and is_equal_approx(fighter.posture_max, 107.0) and is_equal_approx(fighter.health_max, 105.0):
		passed += 1
	else:
		failed += 1
		failures.append("upgrade_boon should recompile the slot with cumulative tier riders")

	var duo: Dictionary = DataManager.get_boon("test_duo")
	if not loadout.is_duo_eligible(duo):
		passed += 1
	else:
		failed += 1
		failures.append("duo should be ineligible before both required schools are held")

	loadout.add_boon("test_passive", "common")
	var schools: Array[String] = loadout.active_schools()
	if schools.has("venom") and schools.has("thunder") and loadout.is_duo_eligible(duo):
		passed += 1
	else:
		failed += 1
		failures.append("active_schools and duo eligibility should reflect held boons")

	return {"passed": passed, "failed": failed, "failures": failures}
