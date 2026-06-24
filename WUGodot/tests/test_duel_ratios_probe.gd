extends RefCounted

const Probe = preload("res://tools/probe_duel_ratios.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.reload_data()
	RngService.set_run_seed(2468)
	var metrics: Dictionary = Probe.measure("bandit_swordsman")
	var light_break: Dictionary = metrics["hits_to_posture_break_light"] as Dictionary
	var hp_kill: Dictionary = metrics["hits_to_hp_kill_light"] as Dictionary
	var parries: Dictionary = metrics["parries_to_break"] as Dictionary
	var blocked: Dictionary = metrics["blocked_pressure_break_light"] as Dictionary
	var posture_path: Dictionary = metrics["posture_path"] as Dictionary

	if int(light_break.get("count", -1)) > 0 and not bool(light_break.get("timeout", false)) \
			and int(hp_kill.get("count", -1)) > 0 and not bool(hp_kill.get("timeout", false)) \
			and int(parries.get("count", -1)) >= 1 and not bool(parries.get("timeout", false)) \
			and int(blocked.get("count", -1)) > 0 and not bool(blocked.get("timeout", false)):
		passed += 1
	else:
		failed += 1
		failures.append("bandit metrics should be finite/positive/non-timeout: %s" % str(metrics))

	if int(parries.get("count", 99)) <= 4:
		passed += 1
	else:
		failed += 1
		failures.append("weak-enemy parries_to_break should be small, got %d" % int(parries.get("count", -1)))

	if int(posture_path.get("hits_to_break", -1)) > 0 and float(posture_path.get("duration", 0.0)) > 0.0:
		passed += 1
	else:
		failed += 1
		failures.append("posture path should report break/punish payoff data: %s" % str(posture_path))

	RngService.clear_run_seed()
	return {"passed": passed, "failed": failed, "failures": failures}
