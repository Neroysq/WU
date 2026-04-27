extends RefCounted

const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")
const AttackStateScript = preload("res://scripts/attack_state.gd")
const FighterScript = preload("res://scripts/fighter.gd")

func _make_light():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "hu_light"
	def.duration = 0.50
	def.windup_end = 0.18
	def.active_end = 0.30
	return def

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var state: Variant = AttackStateScript.new()

	if not state.is_active() and not state.is_hit_active():
		passed += 1
	else:
		failed += 1
		failures.append("fresh state should be inactive")

	var def: Variant = _make_light()
	state.start(def)
	if state.is_active():
		passed += 1
	else:
		failed += 1
		failures.append("after start, should be active")

	var hit_start_seen: bool = false
	var hit_end_seen: bool = false
	var finished_seen: bool = false
	for i in range(60):
		var events: Dictionary = state.advance(0.05)
		if bool(events.get("hit_started", false)):
			hit_start_seen = true
			if absf(state.elapsed - def.windup_end) > 0.06:
				failed += 1
				failures.append("hit_started fired at elapsed %.3f, expected ~%.3f" % [state.elapsed, def.windup_end])
		if bool(events.get("hit_ended", false)):
			hit_end_seen = true
		if bool(events.get("finished", false)):
			finished_seen = true
			break

	if hit_start_seen:
		passed += 1
	else:
		failed += 1
		failures.append("hit_started event never fired")
	if hit_end_seen:
		passed += 1
	else:
		failed += 1
		failures.append("hit_ended event never fired")
	if finished_seen:
		passed += 1
	else:
		failed += 1
		failures.append("finished event never fired")
	if not state.is_active():
		passed += 1
	else:
		failed += 1
		failures.append("state should be inactive after finished event")

	state.start(_make_light())
	state.clear()
	if not state.is_active() and state.elapsed == 0.0:
		passed += 1
	else:
		failed += 1
		failures.append("clear() did not reset state")

	var phase_state: Variant = AttackStateScript.new()
	var phase_def: Variant = _make_light()
	phase_state.start(phase_def)
	var phase_cases: Array[Dictionary] = [
		{"elapsed": 0.0, "phase": AttackDefinitionScript.Phase.WINDUP, "progress": 0.0, "label": "windup start"},
		{"elapsed": 0.09, "phase": AttackDefinitionScript.Phase.WINDUP, "progress": 0.5, "label": "windup midpoint"},
		{"elapsed": phase_def.windup_end, "phase": AttackDefinitionScript.Phase.ACTIVE, "progress": 0.0, "label": "active boundary"},
		{"elapsed": 0.24, "phase": AttackDefinitionScript.Phase.ACTIVE, "progress": 0.5, "label": "active midpoint"},
		{"elapsed": phase_def.active_end, "phase": AttackDefinitionScript.Phase.RECOVERY, "progress": 0.0, "label": "recovery boundary"},
		{"elapsed": phase_def.duration, "phase": AttackDefinitionScript.Phase.FINISHED, "progress": 1.0, "label": "finished boundary"},
	]
	for phase_case in phase_cases:
		phase_state.elapsed = float(phase_case["elapsed"])
		var expected_phase: int = int(phase_case["phase"])
		var expected_progress: float = float(phase_case["progress"])
		var actual_phase: int = phase_state.phase()
		var actual_progress: float = phase_state.progress_in_phase()
		if actual_phase == expected_phase and absf(actual_progress - expected_progress) <= 0.001:
			passed += 1
		else:
			failed += 1
			failures.append("%s expected phase/progress %d/%.3f, got %d/%.3f" % [
				str(phase_case["label"]),
				expected_phase,
				expected_progress,
				actual_phase,
				actual_progress,
			])

	var fighter: Variant = FighterScript.new()
	var active_signal_seen: Array[bool] = [false]
	fighter.attack_active_started.connect(func() -> void:
		active_signal_seen[0] = true
	)
	fighter.start_light_attack()
	fighter.update_timers(0.18)
	if active_signal_seen[0]:
		passed += 1
	else:
		failed += 1
		failures.append("fighter did not emit attack_active_started when hit window opened")

	return {"passed": passed, "failed": failed, "failures": failures}
