extends RefCounted

const BoonLoadoutScript = preload("res://scripts/boons/boon_loadout.gd")
const BoonOfferScript = preload("res://scripts/boons/boon_offer.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const MapNodeScript = preload("res://scripts/map_node.gd")
const RunFlowScript = preload("res://scripts/run_flow.gd")
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")

func _seed_offer_boons() -> void:
	DataManager.reload_data()
	DataManager._boons["offer_light"] = {
		"id": "offer_light",
		"school": "offer",
		"kind": "move",
		"slot": "light",
		"tiers": {"common": {"effect": {"type": "stat_delta", "flat": {"health_max": 1.0}}}},
	}
	DataManager._boons["offer_dash"] = {
		"id": "offer_dash",
		"school": "offer",
		"kind": "move",
		"slot": "dash",
		"tiers": {"common": {"effect": {"type": "stat_delta", "flat": {"posture_max": 1.0}}}},
	}
	DataManager._boons["offer_heavy"] = {
		"id": "offer_heavy",
		"school": "offer",
		"kind": "move",
		"slot": "heavy",
		"tiers": {"common": {"effect": {"type": "stat_delta", "flat": {"rage_max": 1.0}}}},
	}
	DataManager._boons["offer_block"] = {
		"id": "offer_block",
		"school": "offer",
		"kind": "move",
		"slot": "block",
		"tiers": {"common": {"effect": {"type": "stat_delta", "flat": {"parry_window": 0.01}}}},
	}
	DataManager._boons["offer_passive"] = {
		"id": "offer_passive",
		"school": "offer",
		"kind": "passive",
		"tiers": {"common": {"effect": {"type": "stat_delta", "scaled": {"move_speed": 0.01}}}},
	}
	DataManager._boons["other_passive"] = {
		"id": "other_passive",
		"school": "other",
		"kind": "passive",
		"tiers": {"common": {"effect": {"type": "stat_delta", "flat": {"health_max": 1.0}}}},
	}
	DataManager._boons["duo_offer_move"] = {
		"id": "duo_offer_move",
		"school": "duo_offer",
		"kind": "move",
		"slot": "light",
		"tiers": {"common": {"effect": {"type": "stat_delta", "flat": {"health_max": 1.0}}}},
	}
	DataManager._boons["duo_offer_passive"] = {
		"id": "duo_offer_passive",
		"school": "duo_offer",
		"kind": "passive",
		"tiers": {"common": {"effect": {"type": "stat_delta", "flat": {"posture_max": 1.0}}}},
	}
	DataManager._boons["duo_offer_duo"] = {
		"id": "duo_offer_duo",
		"school": "duo_offer",
		"kind": "duo",
		"requires": {"schools": ["other"]},
		"effect": {"type": "stat_delta", "flat": {"rage_max": 1.0}},
	}
	DataManager._boons["duo_offer_mastery"] = {
		"id": "duo_offer_mastery",
		"school": "duo_offer",
		"kind": "mastery",
		"requires": {"counts": {"duo_offer": 2}},
		"effect": {"type": "stat_delta", "flat": {"health_max": 2.0}},
	}

func _ids(offers: Array) -> Array[String]:
	var ids: Array[String] = []
	for offer in offers:
		ids.append(str((offer as Dictionary).get("boon_id", "")))
	return ids

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	_seed_offer_boons()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var loadout: Variant = BoonLoadoutScript.new()
	var offers: Array = BoonOfferScript.generate(loadout, "offer", 0, rng)
	var ids: Array[String] = _ids(offers)
	var unique_ids: Dictionary = {}
	for id in ids:
		unique_ids[id] = true
	var all_from_school := true
	for offer in offers:
		if str(((offer as Dictionary).get("boon", {}) as Dictionary).get("school", "")) != "offer":
			all_from_school = false
	if offers.size() == 3 and unique_ids.size() == 3 and all_from_school:
		passed += 1
	else:
		failed += 1
		failures.append("BoonOffer.generate should return 3 distinct offers from the requested school")

	loadout.add_boon("offer_light", "common")
	rng.seed = 8
	offers = BoonOfferScript.generate(loadout, "offer", 0, rng)
	ids = _ids(offers)
	if ids.has("offer_dash") and ids.has("offer_heavy") and ids.has("offer_block"):
		passed += 1
	else:
		failed += 1
		failures.append("BoonOffer.generate should prefer empty move slots before replacements/passives")

	loadout = BoonLoadoutScript.new()
	rng.seed = 9
	offers = BoonOfferScript.generate(loadout, "duo_offer", 0, rng)
	ids = _ids(offers)
	if not ids.has("duo_offer_duo"):
		passed += 1
	else:
		failed += 1
		failures.append("BoonOffer.generate should not include ineligible duos")

	loadout.add_boon("other_passive", "common")
	rng.seed = 10
	offers = BoonOfferScript.generate(loadout, "duo_offer", 0, rng)
	ids = _ids(offers)
	if not ids.has("duo_offer_duo"):
		passed += 1
	else:
		failed += 1
		failures.append("BoonOffer.generate should hold eligible duos until Master-depth offers")

	rng.seed = 11
	offers = BoonOfferScript.generate(loadout, "duo_offer", 3, rng)
	ids = _ids(offers)
	if ids.has("duo_offer_duo"):
		passed += 1
	else:
		failed += 1
		failures.append("BoonOffer.generate should include eligible duos at Master-depth")

	loadout.add_boon("duo_offer_move", "common")
	loadout.add_boon("duo_offer_passive", "common")
	rng.seed = 12
	offers = BoonOfferScript.generate(loadout, "duo_offer", 3, rng)
	ids = _ids(offers)
	if ids.has("duo_offer_mastery"):
		passed += 1
	else:
		failed += 1
		failures.append("BoonOffer.generate should include eligible masteries at Master-depth")

	var fighter: Variant = FighterScript.new()
	var engine: Variant = TechniqueEngineScript.new()
	var bound_loadout: Variant = BoonLoadoutScript.new(engine, fighter)
	if bound_loadout.add_boon("duo_offer_mastery", "legendary") and engine.has_effect("duo_offer_mastery#0") and bound_loadout.masteries.size() == 1:
		passed += 1
	else:
		failed += 1
		failures.append("BoonLoadout should install mastery effects as single-tier payoffs")

	var shallow: Dictionary = BoonOfferScript.tier_weights(0)
	var deep: Dictionary = BoonOfferScript.tier_weights(9)
	if float(deep.get("epic", 0.0)) > float(shallow.get("epic", 0.0)) and float(deep.get("legendary", 0.0)) > float(shallow.get("legendary", 0.0)):
		passed += 1
	else:
		failed += 1
		failures.append("BoonOffer tier weights should skew higher with depth")

	DataManager.reload_data()
	var run: Variant = RunState.create_procedural_run(123)
	var master: Variant = MapNodeScript.new(100, 3, MapNodeScript.NodeType.MASTER, [])
	var choice_payload: Dictionary = RunFlowScript.generate_school_choice_payload(run, master)
	if str(choice_payload.get("scene", "")) == "boon_offer" and (choice_payload.get("school_choices", []) as Array).size() >= 2:
		passed += 1
	else:
		failed += 1
		failures.append("school-choice payload should provide at least 2 school options")

	return {"passed": passed, "failed": failed, "failures": failures}
