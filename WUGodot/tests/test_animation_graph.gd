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

	var atk_enter: Dictionary = graph.enter_for("ATTACKING_LIGHT")
	var idle_enter: Dictionary = graph.enter_for("IDLE")
	if str(atk_enter.get("mode", "")) == "snap" and str(idle_enter.get("mode", "")) == "dither":
		passed += 1
	else:
		failed += 1
		failures.append("committed states snap, ambient states dither")

	if graph.can_cancel_into("ATTACKING_LIGHT", "DASH") and not graph.can_cancel_into("ATTACKING_LIGHT", "WALKING"):
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
