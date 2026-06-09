extends RefCounted

const MasterNormalizerScript = preload("res://scripts/visual/master_normalizer.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var base: float = MasterNormalizerScript.base_scale(900.0, 145, 4)
	if absf(base - (580.0 / 900.0)) <= 0.0001:
		passed += 1
	else:
		failed += 1
		failures.append("base_scale should map idle reference height to target texels*density")

	var drift_scale: float = MasterNormalizerScript.base_scale(1200.0, 145, 4)
	if absf(drift_scale - (580.0 / 1200.0)) <= 0.0001:
		passed += 1
	else:
		failed += 1
		failures.append("base_scale should not normalize each frame's own silhouette height")

	var p: Dictionary = MasterNormalizerScript.plan(
		base,
		Vector2(1000.0, 1200.0),
		Rect2(250.0, 120.0, 400.0, 900.0),
		Vector2(450.0, 1020.0),
		1.25
	)
	var expected_scale: float = base * 1.25
	if absf(float(p["scale"]) - expected_scale) <= 0.0001:
		passed += 1
	else:
		failed += 1
		failures.append("plan scale should equal base*scaleNorm")

	var scaled_foot: Vector2 = p["scaled_foot"] as Vector2
	if scaled_foot.is_equal_approx(Vector2(450.0, 1020.0) * expected_scale):
		passed += 1
	else:
		failed += 1
		failures.append("plan should scale foot anchor in smooth space")

	var scaled_bbox: Rect2 = p["scaled_bbox"] as Rect2
	if scaled_bbox.position.is_equal_approx(Vector2(250.0, 120.0) * expected_scale) and scaled_bbox.size.is_equal_approx(Vector2(400.0, 900.0) * expected_scale):
		passed += 1
	else:
		failed += 1
		failures.append("plan should scale bbox position and size")

	if is_zero_approx(MasterNormalizerScript.base_scale(0.0, 145, 4)):
		passed += 1
	else:
		failed += 1
		failures.append("base_scale should fail closed for empty reference height")

	return {"passed": passed, "failed": failed, "failures": failures}
