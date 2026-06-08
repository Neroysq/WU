extends RefCounted

const T = preload("res://scripts/visual/hitbox_template.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var chest: Vector2 = Vector2(128.0, 150.0)
	var tip: Vector2 = Vector2(218.0, 134.0)

	var spear: Dictionary = T.build("spear", chest, tip, false, false)
	if (spear["a"] as Vector2) == chest and (spear["b"] as Vector2) == tip and float(spear["radius"]) <= 14.0:
		passed += 1
	else:
		failed += 1
		failures.append("spear should span chest->tip with a thin radius")

	var sword: Dictionary = T.build("sword", chest, tip, false, false)
	if float(sword["radius"]) >= float(spear["radius"]) and (sword["b"] as Vector2) == tip:
		passed += 1
	else:
		failed += 1
		failures.append("sword should be fatter than spear and reach the tip")

	var sword_heavy: Dictionary = T.build("sword", chest, tip, true, false)
	if float(sword_heavy["radius"]) > float(sword["radius"]):
		passed += 1
	else:
		failed += 1
		failures.append("heavy should widen the radius")

	var grab: Dictionary = T.build("sword", chest, tip, false, true)
	if (grab["a"] as Vector2) == (grab["b"] as Vector2) and float(grab["radius"]) >= 24.0:
		passed += 1
	else:
		failed += 1
		failures.append("grab should be a large disc at the tip")

	var unknown: Dictionary = T.build("bogus", chest, tip, false, false)
	if float(unknown["radius"]) > 0.0:
		passed += 1
	else:
		failed += 1
		failures.append("unknown weapon class should still yield a capsule")

	return {"passed": passed, "failed": failed, "failures": failures}
