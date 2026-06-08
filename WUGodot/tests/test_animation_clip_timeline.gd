extends RefCounted

const TimelineScript = preload("res://scripts/visual/animation_clip_timeline.gd")
const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")

func _light_def() -> Variant:
	var def: Variant = AttackDefinitionScript.new()
	def.duration = 0.50
	def.windup_end = 0.20
	def.active_end = 0.32
	return def

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var clip: Variant = TimelineScript.load_from_file("res://assets/animation_clips/hu_attack_light.timeline.json")
	if is_equal_approx(clip.sample_track("offsetX", 0.0), 0.0) and clip.sample_track("offsetX", 0.55) > 17.0:
		passed += 1
	else:
		failed += 1
		failures.append("offsetX should ramp from 0 to ~18")

	if is_equal_approx(clip.sample_track("nonexistent", 0.5, 3.0), 3.0):
		passed += 1
	else:
		failed += 1
		failures.append("missing track should return default")

	if clip.pose_at(0.0) == "guard" and clip.pose_at(0.40) == "windup" and clip.pose_at(0.99) == "strike_extended" and clip.pose_at(1.0) == "recover":
		passed += 1
	else:
		failed += 1
		failures.append("pose_at should hold the most recent keypose")

	var def: Variant = _light_def()
	var active_start_t: float = clip.event_time("attack_active_start", def)
	if is_equal_approx(active_start_t, 0.40):
		passed += 1
	else:
		failed += 1
		failures.append("attack_active_start should resolve to windup_end/duration=0.40, got %f" % active_start_t)

	var fired: Array[String] = clip.events_in_window(0.30, 0.45, def)
	if fired.size() == 1 and fired[0] == "attack_active_start":
		passed += 1
	else:
		failed += 1
		failures.append("active_start should fire once when crossing t=0.40, got %s" % str(fired))

	var none_again: Array[String] = clip.events_in_window(0.45, 0.50, def)
	if none_again.is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("active_start should not refire after its window passed")

	var idle: Variant = TimelineScript.load_from_file("res://assets/animation_clips/idle.timeline.json")
	if idle.pose_at(0.0) == "guard" and idle.pose_at(0.6) == "breath" and not idle.duration_from_attack_def and is_equal_approx(idle.fixed_duration, 1.6):
		passed += 1
	else:
		failed += 1
		failures.append("idle ambient clip should expose fixed duration and cycle poses")

	return {"passed": passed, "failed": failed, "failures": failures}
