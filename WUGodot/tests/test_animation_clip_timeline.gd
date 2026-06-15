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
	# Video frames carry ALL body motion (including real lunge travel in-frame);
	# the only remaining track is the active-window smear.
	if is_equal_approx(clip.sample_track("offsetX", 0.42, 0.0), 0.0) and clip.sample_track("smear", 0.45) > 0.5 and is_equal_approx(clip.sample_track("smear", 0.30), 0.0):
		passed += 1
	else:
		failed += 1
		failures.append("video-frame clip should have no offsetX track and smear covering the active window")

	if is_equal_approx(clip.sample_track("nonexistent", 0.5, 3.0), 3.0):
		passed += 1
	else:
		failed += 1
		failures.append("missing track should return default")

	var hu_light: Variant = AttackCatalogScript.hu_light()
	var hu_active_start_t: float = clip.event_time("attack_active_start", hu_light)
	var hu_active_end_t: float = clip.event_time("attack_active_end", hu_light)
	if clip.pose_at(0.0, hu_light) == "guard" and clip.pose_at(0.07, hu_light) == "va_020" and clip.pose_at(hu_active_start_t - 0.01, hu_light) == "va_050" and clip.pose_at(hu_active_start_t, hu_light) == "va_053" and clip.pose_at(hu_active_end_t + 0.01, hu_light) == "va_068" and clip.pose_at(1.0, hu_light) == "va_091":
		passed += 1
	else:
		failed += 1
		failures.append("pose_at should show the draw within 2 frames, no strike art before active, strike at active start, retract after active end")

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
	if idle.pose_at(0.0) == "vi_002" and idle.pose_at(0.5) == "vi_050" and idle.pose_at(0.94) == "vi_097" and not idle.duration_from_attack_def and is_equal_approx(idle.fixed_duration, 2.0) and not idle.has_track("offsetX") and not idle.has_track("scaleY") and not idle.has_track("rotation"):
		passed += 1
	else:
		failed += 1
		failures.append("idle video clip should expose a 2s vi_* pose cycle without synthetic breathing tracks")

	var heavy_clip: Variant = TimelineScript.load_from_file("res://assets/animation_clips/hu_attack_heavy.timeline.json")
	var hu_heavy: Variant = AttackCatalogScript.hu_heavy()
	var heavy_active_start_t: float = heavy_clip.event_time("attack_active_start", hu_heavy)
	var heavy_active_end_t: float = heavy_clip.event_time("attack_active_end", hu_heavy)
	if heavy_clip.pose_at(0.26, hu_heavy) == "guard" and heavy_clip.pose_at(heavy_active_start_t - 0.01, hu_heavy) == "heavy_windup" and heavy_clip.pose_at(heavy_active_start_t, hu_heavy) == "heavy_strike" and heavy_clip.pose_at(heavy_active_end_t, hu_heavy) == "heavy_recover" and heavy_clip.sample_track("offsetX", 0.50) > 33.0 and heavy_clip.has_track("scaleX"):
		passed += 1
	else:
		failed += 1
		failures.append("heavy clip should hold readable anticipation, strike at active start, recover at recovery start, and use numeric track timing")

	var walk: Variant = TimelineScript.load_from_file("res://assets/animation_clips/walk.timeline.json")
	if walk.rate_mode == "velocity" and walk.pose_at(0.0) == "vw_002" and walk.pose_at(0.5) == "vw_049" and walk.pose_at(0.99) == "vw_096" and not walk.has_track("offsetY") and not walk.has_track("rotation"):
		passed += 1
	else:
		failed += 1
		failures.append("walk video clip should opt into velocity rate matching, use vw_* poses, and drop synthetic bob/lean tracks")

	return {"passed": passed, "failed": failed, "failures": failures}
