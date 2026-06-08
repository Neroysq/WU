extends RefCounted

const M = preload("res://scripts/visual/collision_shape_math.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var rect: Rect2 = Rect2(0.0, 0.0, 100.0, 40.0)

	if M.capsule_intersects_rect(Vector2(10.0, 10.0), Vector2(30.0, 10.0), 5.0, rect):
		passed += 1
	else:
		failed += 1
		failures.append("capsule inside rect should intersect")

	if not M.capsule_intersects_rect(Vector2(500.0, 500.0), Vector2(520.0, 500.0), 5.0, rect):
		passed += 1
	else:
		failed += 1
		failures.append("far capsule should not intersect")

	if M.capsule_intersects_rect(Vector2(-9.0, 20.0), Vector2(-9.0, 25.0), 10.0, rect):
		passed += 1
	else:
		failed += 1
		failures.append("radius should bridge a small gap to the left edge")

	if not M.capsule_intersects_rect(Vector2(-12.0, 20.0), Vector2(-12.0, 25.0), 10.0, rect):
		passed += 1
	else:
		failed += 1
		failures.append("gap larger than radius should miss")

	if M.capsule_intersects_rect(Vector2(-20.0, 20.0), Vector2(120.0, 20.0), 0.0, rect):
		passed += 1
	else:
		failed += 1
		failures.append("segment crossing the rect interior must intersect")

	if not M.capsule_intersects_rect(Vector2(-20.0, -20.0), Vector2(120.0, -20.0), 0.0, rect):
		passed += 1
	else:
		failed += 1
		failures.append("segment above the rect should miss")

	if M.point_in_rect(Vector2(50.0, 20.0), rect) and not M.point_in_rect(Vector2(50.0, 60.0), rect):
		passed += 1
	else:
		failed += 1
		failures.append("point_in_rect basic check")

	return {"passed": passed, "failed": failed, "failures": failures}
