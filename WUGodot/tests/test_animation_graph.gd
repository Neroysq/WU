extends RefCounted

const AnimationGraphScript = preload("res://scripts/visual/animation_graph.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var graph: Variant = AnimationGraphScript.load_from_file("res://assets/animation_graphs/humanoid.graph.json")
	if graph.has_state("ATTACKING_LIGHT") and graph.clip_for("ATTACKING_LIGHT") == "hu_attack_light":
		passed += 1
	else:
		failed += 1
		failures.append("graph should map ATTACKING_LIGHT to its clip")

	if graph.has_state("ATTACKING_HEAVY") and graph.clip_for("ATTACKING_HEAVY") == "hu_attack_heavy":
		passed += 1
	else:
		failed += 1
		failures.append("graph should map ATTACKING_HEAVY to its clip")

	if graph.has_state("COMBAT_ENTRY") and graph.clip_for("COMBAT_ENTRY") == "entry_draw":
		passed += 1
	else:
		failed += 1
		failures.append("graph should map scene-local COMBAT_ENTRY to entry_draw")

	var held_expected: Dictionary = {
		"BLOCKING": "held_block",
		"HIT_REACTION": "held_hit",
		"STUNNED": "held_stunned",
		"DASHING": "held_dash",
		"JUMPING": "held_jump",
		"FALLING": "held_fall",
		"LANDING": "held_land",
	}
	var held_ok: bool = true
	for state_name in held_expected.keys():
		if not graph.has_state(str(state_name)) or graph.clip_for(str(state_name)) != str(held_expected[state_name]):
			held_ok = false
	if held_ok:
		passed += 1
	else:
		failed += 1
		failures.append("graph should map every Phase 5 held state to its held clip")

	var atk_enter: Dictionary = graph.enter_for("ATTACKING_LIGHT")
	var idle_enter: Dictionary = graph.enter_for("IDLE")
	if str(atk_enter.get("mode", "")) == "snap" and str(idle_enter.get("mode", "")) == "dither":
		passed += 1
	else:
		failed += 1
		failures.append("committed states snap, ambient states dither")

	if graph.can_cancel_into("ATTACKING_LIGHT", "DASH") and graph.can_cancel_into("ATTACKING_HEAVY", "DASH") and not graph.can_cancel_into("ATTACKING_LIGHT", "WALKING"):
		passed += 1
	else:
		failed += 1
		failures.append("cancelInto should permit DASH and reject WALKING")

	if graph.clip_for("BOGUS") == "idle":
		passed += 1
	else:
		failed += 1
		failures.append("unknown state should fall back to idle clip")

	return {"passed": passed, "failed": failed, "failures": failures}
