extends RefCounted

const BoonTextScript = preload("res://scripts/boons/boon_text.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.reload_data()

	var venom: Dictionary = DataManager.get_boon("venom_light")
	var epic_text: String = BoonTextScript.describe(venom, "epic")
	var common_text: String = BoonTextScript.describe(venom, "common")
	if epic_text.find("applies") >= 0 and epic_text.find("venom slows") >= 0 and epic_text.find("spreads") >= 0 and epic_text != "Adds move effects.":
		passed += 1
	else:
		failed += 1
		failures.append("BoonText.describe should include cumulative base+rare+epic rider text for venom_light epic; got '%s'" % epic_text)

	if common_text.find("applies") >= 0 and common_text.find("slows") < 0 and common_text.find("spreads") < 0:
		passed += 1
	else:
		failed += 1
		failures.append("BoonText.describe(common) should include only the common base effect; got '%s'" % common_text)

	if BoonTextScript.name(venom) == "Coiling Venom":
		passed += 1
	else:
		failed += 1
		failures.append("BoonText.name should use the authored readable name")

	if BoonTextScript.label(venom, "legendary").begins_with("Legendary · "):
		passed += 1
	else:
		failed += 1
		failures.append("Move/passive boon labels should surface rarity")

	var duo: Dictionary = DataManager.get_boon("venom_thunder_duo")
	var mastery: Dictionary = DataManager.get_boon("venom_mastery")
	if BoonTextScript.label(duo, "legendary").begins_with("Duo · ") and BoonTextScript.label(mastery, "epic").begins_with("Mastery · "):
		passed += 1
	else:
		failed += 1
		failures.append("Duo/mastery labels should use kind instead of rolled rarity")

	if BoonTextScript.describe(duo, "legendary").find("jolt") >= 0 and BoonTextScript.describe(mastery, "legendary").find("detonates") >= 0:
		passed += 1
	else:
		failed += 1
		failures.append("BoonText.describe should support flat duo/mastery effects")

	var legendary_description: String = BoonTextScript.describe(venom, "legendary")
	var summary: String = BoonTextScript.summary(venom, "legendary")
	if summary.length() <= 48 and summary != legendary_description and summary.find("heavy detonates") < 0 and summary.find("spreads") < 0:
		passed += 1
	else:
		failed += 1
		failures.append("BoonText.summary should stay short and not repeat the full cumulative description; got '%s'" % summary)

	var missing_template_types: Array[String] = []
	var bad_names: Array[String] = []
	for raw_boon in DataManager.get_all_boons().values():
		var boon: Dictionary = raw_boon as Dictionary
		var boon_id: String = str(boon.get("id", ""))
		var boon_name: String = str(boon.get("name", ""))
		if boon_name.is_empty() or boon_name == boon_id or boon_name.find("_") >= 0:
			bad_names.append(boon_id)
		for effect_data in _effect_data_for(boon):
			var effect_type: String = str((effect_data as Dictionary).get("type", ""))
			if effect_type.is_empty() or not BoonTextScript.has_template(effect_type):
				if not missing_template_types.has(effect_type):
					missing_template_types.append(effect_type)

	if missing_template_types.is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("Every Boons.json effect type should have a BoonText describer template; missing %s" % str(missing_template_types))

	if bad_names.is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("Every boon should have a readable non-raw name; bad ids %s" % str(bad_names))

	if not BoonTextScript.has_template("__unknown_effect__"):
		passed += 1
	else:
		failed += 1
		failures.append("Unknown BoonText effect types should fail loudly")

	return {"passed": passed, "failed": failed, "failures": failures}

func _effect_data_for(boon: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var kind: String = str(boon.get("kind", ""))
	if kind == "duo" or kind == "mastery":
		var effect_data: Dictionary = boon.get("effect", {}) as Dictionary
		if not effect_data.is_empty():
			out.append(effect_data)
		return out

	for tier_data_raw in (boon.get("tiers", {}) as Dictionary).values():
		var tier_data: Dictionary = tier_data_raw as Dictionary
		if tier_data.has("effect"):
			out.append(tier_data.get("effect", {}) as Dictionary)
		for rider in tier_data.get("riders", []) as Array:
			if typeof(rider) == TYPE_DICTIONARY:
				out.append(rider as Dictionary)
	return out
