extends RefCounted

const MasterGeometryScript = preload("res://scripts/visual/master_geometry.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []
	var img: Image = _img()

	var honest := {"native_size": [120, 80], "bbox": [30, 10, 30, 60], "foot_anchor": [45, 69]}
	var honest_geo: Dictionary = MasterGeometryScript.resolve(img, honest)
	if (honest_geo["native"] as Vector2).is_equal_approx(Vector2(120.0, 80.0)) \
			and (honest_geo["bbox"] as Rect2).is_equal_approx(Rect2(30.0, 10.0, 30.0, 60.0)) \
			and not bool(honest_geo["remeasured"]):
		passed += 1
	else:
		failed += 1
		failures.append("honest sidecar should be trusted (got %s)" % str(honest_geo))

	var lying := {"native_size": [80, 80], "bbox": [30, 10, 30, 60], "foot_anchor": [45, 69]}
	var lying_geo: Dictionary = MasterGeometryScript.resolve(img, lying)
	var lying_bbox: Rect2 = lying_geo["bbox"] as Rect2
	if (lying_geo["native"] as Vector2).is_equal_approx(Vector2(120.0, 80.0)) and bool(lying_geo["remeasured"]) \
			and lying_bbox.is_equal_approx(Rect2(30.0, 10.0, 30.0, 60.0)):
		passed += 1
	else:
		failed += 1
		failures.append("lying native_size should force image dims + pixel remeasure (got %s)" % str(lying_geo))

	var lying_foot: Vector2 = lying_geo["foot"] as Vector2
	if lying_foot.is_equal_approx(Vector2(44.5, 69.0)):
		passed += 1
	else:
		failed += 1
		failures.append("remeasured foot should be bottom-row center (got %s)" % str(lying_foot))

	var oob := {"native_size": [120, 80], "bbox": [100, 10, 50, 60], "foot_anchor": [45, 69]}
	var oob_geo: Dictionary = MasterGeometryScript.resolve(img, oob)
	if bool(oob_geo["remeasured"]) and (oob_geo["bbox"] as Rect2).is_equal_approx(Rect2(30.0, 10.0, 30.0, 60.0)):
		passed += 1
	else:
		failed += 1
		failures.append("out-of-bounds bbox should force pixel remeasure (got %s)" % str(oob_geo))

	var empty := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	empty.fill(Color(0, 0, 0, 0))
	var empty_geo: Dictionary = MasterGeometryScript.resolve(empty, {"native_size": [8, 8]})
	if bool(empty_geo["remeasured"]) and (empty_geo["bbox"] as Rect2).is_equal_approx(Rect2(0.0, 0.0, 16.0, 16.0)):
		passed += 1
	else:
		failed += 1
		failures.append("empty images should fail closed to full canvas (got %s)" % str(empty_geo))

	return {"passed": passed, "failed": failed, "failures": failures}

func _img() -> Image:
	var img := Image.create(120, 80, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(10, 70):
		for x in range(30, 60):
			img.set_pixel(x, y, Color(1, 1, 1, 1))
	return img
