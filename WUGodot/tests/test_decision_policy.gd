extends RefCounted

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.reload_data()
	RngService.set_run_seed(21)
	var options: Array = [
		{"school": "venom"},
		{"school": "sword"},
		{"school": "iron"},
	]
	var random_idx: int = RandomPolicy.new().choose("school", options)
	if random_idx >= 0 and random_idx < options.size():
		passed += 1
	else:
		failed += 1
		failures.append("RandomPolicy should pick an in-range option")

	var focused: SchoolFocusedPolicy = SchoolFocusedPolicy.new("sword")
	if focused.choose("school", options) == 1:
		passed += 1
	else:
		failed += 1
		failures.append("SchoolFocusedPolicy should prefer its target school")

	var scripted: ScriptedDecisionPolicy = ScriptedDecisionPolicy.new([2])
	if scripted.choose("school", options) == 2:
		passed += 1
	else:
		failed += 1
		failures.append("ScriptedDecisionPolicy should replay fixed picks")

	RngService.clear_run_seed()
	return {"passed": passed, "failed": failed, "failures": failures}

