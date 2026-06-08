extends RefCounted

const AnimationClockScript = preload("res://scripts/visual/animation_clock.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var normal: Dictionary = AnimationClockScript.resolve(0.016, 1.0)
	if is_equal_approx(float(normal["combat"]), 0.016) and is_equal_approx(float(normal["presentation"]), 0.016) and bool(normal["input_active"]):
		passed += 1
	else:
		failed += 1
		failures.append("normal play should run all three clocks")

	var frozen: Dictionary = AnimationClockScript.resolve(0.016, 0.0)
	if is_equal_approx(float(frozen["combat"]), 0.0) and is_equal_approx(float(frozen["presentation"]), 0.016) and not bool(frozen["input_active"]):
		passed += 1
	else:
		failed += 1
		failures.append("hitstop should freeze combat + input but keep presentation")

	var slow: Dictionary = AnimationClockScript.resolve(0.016, 0.6)
	if is_equal_approx(float(slow["combat"]), 0.016 * 0.6) and bool(slow["input_active"]):
		passed += 1
	else:
		failed += 1
		failures.append("slow-mo should scale combat but keep input active")

	return {"passed": passed, "failed": failed, "failures": failures}
