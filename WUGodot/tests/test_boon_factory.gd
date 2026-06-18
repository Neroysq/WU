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

	return {"passed": passed, "failed": failed, "failures": failures}
