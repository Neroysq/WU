extends RefCounted

const BoonFactoryScript = preload("res://scripts/boons/boon_factory.gd")

const REHOMED: Dictionary = {
	"A1": {"boon": "wind_descending_leaf", "kind": "move", "slot": "dash"},
	"A2": {"boon": "soft_iron_palm", "kind": "move", "slot": "light"},
	"A3": {"boon": "sword_widows_kiss", "kind": "move", "slot": "heavy"},
	"A4": {"boon": "wind_sparrow_wing", "kind": "move", "slot": "dash"},
	"A5": {"boon": "iron_stone_posture", "kind": "move", "slot": "block"},
	"A6": {"boon": "iron_heart_of_bamboo", "kind": "passive"},
	"A7": {"boon": "wind_crane_step", "kind": "passive"},
	"A8": {"boon": "iron_mountain_root", "kind": "passive"},
	"A9": {"boon": "soft_cloud_hands", "kind": "passive"},
	"A10": {"boon": "sword_twin_dragons", "kind": "move", "slot": "heavy"},
	"A11": {"boon": "wind_sleeve_wind", "kind": "passive"},
	"A12": {"boon": "iron_inkstone_discipline", "kind": "passive"},
	"B1": {"boon": "soft_mountain_echo", "kind": "move", "slot": "block"},
	"B2": {"boon": "soft_returning_spring", "kind": "passive"},
	"B3": {"boon": "wind_flowing_water", "kind": "move", "slot": "dash"},
	"B4": {"boon": "wind_thousand_mile_gaze", "kind": "passive"},
	"B5": {"boon": "iron_scar_of_the_past", "kind": "passive"},
	"B6": {"boon": "iron_phoenix_rising", "kind": "passive"},
	"D1": {"boon": "soft_drunken_form", "kind": "move", "slot": "stance"},
	"D2": {"boon": "iron_tiger_stance", "kind": "move", "slot": "stance"},
}

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	DataManager.reload_data()
	for technique_id in REHOMED.keys():
		var expected: Dictionary = REHOMED[technique_id] as Dictionary
		var technique: Dictionary = DataManager.get_technique(technique_id)
		var original_effect: Dictionary = technique.get("effect", {}) as Dictionary
		var boon: Dictionary = DataManager.get_boon(str(expected.get("boon", "")))
		var effects: Array = BoonFactoryScript.build_boon_effects(boon, "common")
		var expected_slot: String = str(expected.get("slot", ""))
		var has_slot: bool = expected_slot.is_empty() or str(boon.get("slot", "")) == expected_slot
		var type_matches: bool = not effects.is_empty() and str(effects[0].params.get("type", "")) == str(original_effect.get("type", ""))
		if not boon.is_empty() and str(boon.get("kind", "")) == str(expected.get("kind", "")) and has_slot and type_matches:
			passed += 1
		else:
			failed += 1
			failures.append("%s should re-home to %s as %s/%s with effect %s" % [
				technique_id,
				str(expected.get("boon", "")),
				str(expected.get("kind", "")),
				expected_slot,
				str(original_effect.get("type", "")),
			])

	if REHOMED.size() == 20:
		passed += 1
	else:
		failed += 1
		failures.append("re-home test should cover all 20 legacy techniques")

	return {"passed": passed, "failed": failed, "failures": failures}
