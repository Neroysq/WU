extends RefCounted

const Registry = preload("res://scripts/techniques/technique_registry.gd")

const REQUIRED_SCHOOLS: Array[String] = ["venom", "thunder", "soft", "iron", "wind", "sword"]
const REQUIRED_TIERS: Array[String] = ["common", "rare", "epic", "legendary"]

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	DataManager.reload_data()
	var school_ids: Array[String] = []
	for school_id in REQUIRED_SCHOOLS:
		if not DataManager.get_school(school_id).is_empty():
			school_ids.append(school_id)
	if school_ids.size() == REQUIRED_SCHOOLS.size():
		passed += 1
	else:
		failed += 1
		failures.append("Schools.json should define the 6 v1 schools")

	for school_id in REQUIRED_SCHOOLS:
		var boons: Array[Dictionary] = DataManager.get_boons_for_school(school_id)
		var move_count: int = 0
		var passive_count: int = 0
		var duo_count: int = 0
		var mastery_count: int = 0
		var slots: Dictionary = {}
		for boon in boons:
			match str(boon.get("kind", "")):
				"move":
					move_count += 1
					slots[str(boon.get("slot", ""))] = true
				"passive":
					passive_count += 1
				"duo":
					duo_count += 1
				"mastery":
					mastery_count += 1
		if move_count >= 3 and slots.size() >= 3 and passive_count >= 2 and duo_count >= 1 and mastery_count >= 1:
			passed += 1
		else:
			failed += 1
			failures.append("%s should have >=3 move boons across >=3 slots, >=2 passives, >=1 duo, >=1 mastery" % school_id)

	for raw_boon in DataManager.get_all_boons().values():
		var boon: Dictionary = raw_boon as Dictionary
		var kind: String = str(boon.get("kind", ""))
		if kind == "move" or kind == "passive":
			var tiers: Dictionary = boon.get("tiers", {}) as Dictionary
			var has_all_tiers := true
			for tier in REQUIRED_TIERS:
				if not tiers.has(tier):
					has_all_tiers = false
			if has_all_tiers:
				passed += 1
			else:
				failed += 1
				failures.append("%s should define common/rare/epic/legendary tiers" % str(boon.get("id", "")))

			for tier in tiers.keys():
				var tier_data: Dictionary = tiers[tier] as Dictionary
				var riders: Array = tier_data.get("riders", []) as Array
				if not tier_data.has("effect") and riders.is_empty():
					failures.append("%s.%s should define an effect or riders" % [str(boon.get("id", "")), str(tier)])
				if tier_data.has("effect"):
					_check_effect_data(tier_data.get("effect", {}) as Dictionary, "%s.%s.effect" % [str(boon.get("id", "")), str(tier)], failures)
				for rider in riders:
					if typeof(rider) == TYPE_DICTIONARY:
						_check_effect_data(rider as Dictionary, "%s.%s.rider" % [str(boon.get("id", "")), str(tier)], failures)
		elif kind == "duo" or kind == "mastery":
			_check_effect_data(boon.get("effect", {}) as Dictionary, "%s.effect" % str(boon.get("id", "")), failures)
			var requires: Dictionary = boon.get("requires", {}) as Dictionary
			var valid_requires := true
			for school in requires.get("schools", []) as Array:
				if not REQUIRED_SCHOOLS.has(str(school)):
					valid_requires = false
			for school_id in (requires.get("counts", {}) as Dictionary).keys():
				if not REQUIRED_SCHOOLS.has(str(school_id)):
					valid_requires = false
			if valid_requires:
				passed += 1
			else:
				failed += 1
				failures.append("%s should reference valid required schools" % str(boon.get("id", "")))

	if failures.is_empty():
		passed += 1
	else:
		failed += failures.size()

	return {"passed": passed, "failed": failed, "failures": failures}

func _check_effect_data(effect_data: Dictionary, label: String, failures: Array[String]) -> void:
	if effect_data.is_empty():
		failures.append("%s should define an effect type" % label)
		return
	var effect: Variant = Registry.create_effect_from_data(effect_data, "content_check")
	if effect == null:
		failures.append("%s should use a registered effect type" % label)
