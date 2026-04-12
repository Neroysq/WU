extends RefCounted

const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")
const AttackStateScript = preload("res://scripts/attack_state.gd")

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

	return {"passed": passed, "failed": failed, "failures": failures}
