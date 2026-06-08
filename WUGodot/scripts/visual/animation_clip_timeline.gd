class_name AnimationClipTimeline
extends RefCounted

var id: String = "unknown"
var duration_from_attack_def: bool = false
var fixed_duration: float = 0.5
var keyposes: Array[Dictionary] = []
var tracks: Dictionary = {}
var events: Array[Dictionary] = []

static func load_from_file(path: String) -> Variant:
	var clip: Variant = (load("res://scripts/visual/animation_clip_timeline.gd") as Script).new()
	if path.is_empty() or not FileAccess.file_exists(path):
		return clip

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return clip

	var root: Dictionary = parsed as Dictionary
	clip.id = str(root.get("id", "unknown"))
	var dur: Variant = root.get("duration", 0.5)
	if typeof(dur) == TYPE_STRING and str(dur) == "fromAttackDef":
		clip.duration_from_attack_def = true
	else:
		clip.fixed_duration = float(dur)

	for kp_variant in root.get("keyposes", []) as Array:
		var kp: Dictionary = kp_variant as Dictionary
		clip.keyposes.append({"t": float(kp.get("t", 0.0)), "pose": str(kp.get("pose", ""))})
	clip.keyposes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))

	var raw_tracks: Dictionary = root.get("tracks", {}) as Dictionary
	for track_name in raw_tracks.keys():
		var keys: Array[Dictionary] = []
		for k_variant in raw_tracks[track_name] as Array:
			var k: Dictionary = k_variant as Dictionary
			keys.append({"t": float(k.get("t", 0.0)), "v": float(k.get("v", 0.0)), "ease": str(k.get("ease", "linear"))})
		keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
		clip.tracks[str(track_name)] = keys

	for e_variant in root.get("events", []) as Array:
		var e: Dictionary = e_variant as Dictionary
		clip.events.append({"t": e.get("t", 0.0), "event": str(e.get("event", ""))})
	return clip

func sample_track(track_name: String, t: float, default_value: float = 0.0) -> float:
	if not tracks.has(track_name):
		return default_value

	var keys: Array = tracks[track_name] as Array
	if keys.is_empty():
		return default_value
	if t <= float((keys[0] as Dictionary)["t"]):
		return float((keys[0] as Dictionary)["v"])

	for i in range(1, keys.size()):
		var a: Dictionary = keys[i - 1] as Dictionary
		var b: Dictionary = keys[i] as Dictionary
		if t <= float(b["t"]):
			var span: float = maxf(float(b["t"]) - float(a["t"]), 0.0001)
			var local: float = clampf((t - float(a["t"])) / span, 0.0, 1.0)
			return lerpf(float(a["v"]), float(b["v"]), _ease(local, str(b["ease"])))
	return float((keys[keys.size() - 1] as Dictionary)["v"])

func pose_at(t: float) -> String:
	var current: String = ""
	for kp in keyposes:
		if t >= float(kp["t"]):
			current = str(kp["pose"])
		else:
			break
	if current.is_empty() and not keyposes.is_empty():
		current = str((keyposes[0] as Dictionary)["pose"])
	return current

func event_time(event_name: String, attack_def: Variant) -> float:
	for e in events:
		if str(e["event"]) == event_name:
			return _resolve_t(e["t"], attack_def)
	return -1.0

func events_in_window(prev_t: float, cur_t: float, attack_def: Variant) -> Array[String]:
	var fired: Array[String] = []
	for e in events:
		var rt: float = _resolve_t(e["t"], attack_def)
		if rt > prev_t and rt <= cur_t:
			fired.append(str(e["event"]))
	return fired

func _resolve_t(raw: Variant, attack_def: Variant) -> float:
	if typeof(raw) == TYPE_STRING:
		var dur: float = _duration(attack_def)
		if dur <= 0.0 or attack_def == null:
			return 0.0
		match str(raw):
			"windup_end":
				return clampf(float(attack_def.windup_end) / dur, 0.0, 1.0)
			"active_end":
				return clampf(float(attack_def.active_end) / dur, 0.0, 1.0)
			_:
				return 0.0
	return float(raw)

func _duration(attack_def: Variant) -> float:
	if duration_from_attack_def and attack_def != null:
		return float(attack_def.duration)
	return fixed_duration

func _ease(x: float, ease_name: String) -> float:
	match ease_name:
		"in":
			return x * x
		"out":
			return 1.0 - (1.0 - x) * (1.0 - x)
		"inOut":
			return 3.0 * x * x - 2.0 * x * x * x
		_:
			return x
