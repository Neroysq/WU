extends RefCounted

const AnchorMathScript = preload("res://scripts/visual/anchor_math.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var root: Vector2 = Vector2(360, 900)
	var scale: float = 1.625

	var foot_right: Vector2 = AnchorMathScript.pose_to_world(Vector2(128, 238), Vector2(128, 238), root, scale, 1)
	var foot_left: Vector2 = AnchorMathScript.pose_to_world(Vector2(128, 238), Vector2(128, 238), root, scale, -1)
	if foot_right.is_equal_approx(root) and foot_left.is_equal_approx(root):
		passed += 1
	else:
		failed += 1
		failures.append("foot anchor must map to root for both facings")

	var drift_a: Vector2 = AnchorMathScript.pose_to_world(Vector2(128, 200), Vector2(128, 200), root, scale, 1)
	var drift_b: Vector2 = AnchorMathScript.pose_to_world(Vector2(128, 230), Vector2(128, 230), root, scale, 1)
	if drift_a.is_equal_approx(root) and drift_b.is_equal_approx(root):
		passed += 1
	else:
		failed += 1
		failures.append("foot-row drift must not move the grounded point")

	var tip: Vector2 = AnchorMathScript.pose_to_world(Vector2(218, 134), Vector2(128, 238), root, scale, 1)
	var expected: Vector2 = root + Vector2((218 - 128) * scale, (134 - 238) * scale)
	if tip.is_equal_approx(expected):
		passed += 1
	else:
		failed += 1
		failures.append("right-facing offset should scale from foot anchor")

	var tip_left: Vector2 = AnchorMathScript.pose_to_world(Vector2(218, 134), Vector2(128, 238), root, scale, -1)
	var expected_left: Vector2 = root + Vector2(-(218 - 128) * scale, (134 - 238) * scale)
	if tip_left.is_equal_approx(expected_left):
		passed += 1
	else:
		failed += 1
		failures.append("facing -1 should mirror X about the foot anchor")

	return {"passed": passed, "failed": failed, "failures": failures}
