extends RefCounted

const ResolverScript = preload("res://scripts/visual/move_skin_resolver.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var slot_cases: Dictionary = {
		"ATTACKING_LIGHT": "light",
		"ATTACKING_HEAVY": "heavy",
		"DASHING": "dash",
		"BLOCKING": "block",
		"JUMPING": "jump",
		"FALLING": "jump",
		"IDLE": "",
		"WALKING": "",
		"HIT_REACTION": "",
		"STUNNED": "",
		"LANDING": "",
		"COMBAT_ENTRY": "",
	}
	var slots_ok: bool = true
	for state_name in slot_cases.keys():
		if ResolverScript.slot_for_state(str(state_name)) != str(slot_cases[state_name]):
			slots_ok = false
	if slots_ok:
		passed += 1
	else:
		failed += 1
		failures.append("slot_for_state must map move states to slots and non-move states to ''")

	var slot_school_map: Dictionary = {"light": "venom", "block": "venom"}
	var variant_ids: Dictionary = {"venom:ATTACKING_LIGHT": "venom_hu_attack_light"}

	var r1: Dictionary = ResolverScript.resolve("ATTACKING_LIGHT", "hu_attack_light", slot_school_map, variant_ids)
	if str(r1["clip_id"]) == "venom_hu_attack_light" and str(r1["recolor_school"]) == "":
		passed += 1
	else:
		failed += 1
		failures.append("resolve: infused slot with a variant clip should pick the variant, no recolor")

	var r2: Dictionary = ResolverScript.resolve("BLOCKING", "held_block", slot_school_map, variant_ids)
	if str(r2["clip_id"]) == "held_block" and str(r2["recolor_school"]) == "venom":
		passed += 1
	else:
		failed += 1
		failures.append("resolve: infused slot without a variant should keep base clip and flag recolor")

	var r3: Dictionary = ResolverScript.resolve("ATTACKING_HEAVY", "hu_attack_heavy", slot_school_map, variant_ids)
	if str(r3["clip_id"]) == "hu_attack_heavy" and str(r3["recolor_school"]) == "":
		passed += 1
	else:
		failed += 1
		failures.append("resolve: uninfused slot should keep base clip, no recolor")

	var r4: Dictionary = ResolverScript.resolve("IDLE", "idle", slot_school_map, variant_ids)
	if str(r4["clip_id"]) == "idle" and str(r4["recolor_school"]) == "":
		passed += 1
	else:
		failed += 1
		failures.append("resolve: non-move states must never be skinned or recolored")

	return {"passed": passed, "failed": failed, "failures": failures}
