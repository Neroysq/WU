extends RefCounted

const TimelineScript = preload("res://scripts/visual/animation_clip_timeline.gd")
const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")
const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

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
	# Video frames carry pose motion; light attack keeps its deliberate presenter travel
	# in fighter.animation_offset, not in synthetic timeline tracks.
	if clip.use_fighter_offset and is_equal_approx(clip.sample_track("offsetX", 0.42, 0.0), 0.0) and clip.sample_track("smear", 0.45) > 0.5 and is_equal_approx(clip.sample_track("smear", 0.30), 0.0):
		passed += 1
	else:
		failed += 1
		failures.append("light video clip should use fighter offset, no offsetX track, and smear covering the active window")

	if is_equal_approx(clip.sample_track("nonexistent", 0.5, 3.0), 3.0):
		passed += 1
	else:
		failed += 1
		failures.append("missing track should return default")

	var hu_light: Variant = AttackCatalogScript.hu_light()
	var hu_active_start_t: float = clip.event_time("attack_active_start", hu_light)
	var hu_active_end_t: float = clip.event_time("attack_active_end", hu_light)
	if clip.pose_at(0.0, hu_light) == "hu_light_000" and clip.pose_at(0.12, hu_light) == "hu_light_008" and clip.pose_at(hu_active_start_t - 0.01, hu_light) == "hu_light_024" and clip.pose_at(hu_active_start_t, hu_light) == "hu_light_030" and clip.pose_at(hu_active_end_t + 0.01, hu_light) == "hu_light_046" and clip.pose_at(0.67, hu_light) == "hu_light_056" and clip.pose_at(1.0, hu_light) == "hu_light_096":
		passed += 1
	else:
		failed += 1
		failures.append("light pose_at should use final canon frame ids, no strike art before active, strike at active start, and retract after active")

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
	if idle.pose_at(0.0) == "hu_k1" and idle.pose_at(0.5) == "hu_k1" and idle.pose_at(0.94) == "hu_k1" and not idle.duration_from_attack_def and is_equal_approx(idle.fixed_duration, 2.0) and not idle.has_track("offsetX") and not idle.has_track("scaleY") and not idle.has_track("rotation"):
		passed += 1
	else:
		failed += 1
		failures.append("idle clip should pin to approved k1 without synthetic breathing tracks")

	var heavy_clip: Variant = TimelineScript.load_from_file("res://assets/animation_clips/hu_attack_heavy.timeline.json")
	var hu_heavy: Variant = AttackCatalogScript.hu_heavy()
	var heavy_active_start_t: float = heavy_clip.event_time("attack_active_start", hu_heavy)
	var heavy_active_end_t: float = heavy_clip.event_time("attack_active_end", hu_heavy)
	if heavy_clip.pose_at(0.26, hu_heavy) == "hu_heavy_020" and heavy_clip.pose_at(heavy_active_start_t - 0.01, hu_heavy) == "hu_heavy_040" and heavy_clip.pose_at(heavy_active_start_t, hu_heavy) == "hu_heavy_058" and heavy_clip.pose_at(heavy_active_end_t, hu_heavy) == "hu_heavy_070" and not heavy_clip.use_fighter_offset and is_equal_approx(heavy_clip.sample_track("offsetX", 0.50, 0.0), 0.0) and not heavy_clip.has_track("scaleX") and heavy_clip.sample_track("smear", 0.60) > 0.5:
		passed += 1
	else:
		failed += 1
		failures.append("heavy video clip should use final canon frame ids, hold readable anticipation, cleave at active start, recover at recovery start, and remain presenter-stationary")

	var walk: Variant = TimelineScript.load_from_file("res://assets/animation_clips/walk.timeline.json")
	if walk.rate_mode == "velocity" and walk.pose_at(0.0) == "hu_k1" and walk.pose_at(0.5) == "hu_k1" and walk.pose_at(0.99) == "hu_k1" and not walk.has_track("offsetY") and not walk.has_track("rotation"):
		passed += 1
	else:
		failed += 1
		failures.append("walk clip should opt into velocity rate matching, pin to k1, and drop synthetic bob/lean tracks")

	var jump: Variant = TimelineScript.load_from_file("res://assets/animation_clips/held_jump.timeline.json")
	var stunned: Variant = TimelineScript.load_from_file("res://assets/animation_clips/held_stunned.timeline.json")
	if jump.use_fighter_offset and jump.pose_at(0.0) == "hu_jump_000" and jump.pose_at(0.67) == "hu_jump_056" and stunned.use_fighter_offset and stunned.pose_at(0.5) == "hu_stun_b":
		passed += 1
	else:
		failed += 1
		failures.append("held timelines should use final Hu canon poses, including jump peak and stunned pair")

	var entry: Variant = TimelineScript.load_from_file("res://assets/animation_clips/entry_draw.timeline.json")
	if not entry.duration_from_attack_def and not entry.loop and is_equal_approx(entry.fixed_duration, 1.6) and entry.pose_at(0.0) == "hu_entry_000" and entry.pose_at(0.5) == "hu_entry_050" and entry.pose_at(1.0) == "hu_entry_096":
		passed += 1
	else:
		failed += 1
		failures.append("entry draw clip should use the installed non-looping Hu entry sequence over a fixed 1.6s duration")

	return {"passed": passed, "failed": failed, "failures": failures}
