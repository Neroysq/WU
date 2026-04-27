class_name AnimationSet
extends RefCounted

const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")

var set_id: String = "unknown"
var default_scale: float = 2.0
var clips: Dictionary = {}

static func load_from_file(path: String, catalog: AssetCatalog) -> AnimationSet:
	var set: AnimationSet = AnimationSet.new()
	if path.is_empty() or not FileAccess.file_exists(path):
		set._build_fallback(catalog)
		return set

	var raw_text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		set._build_fallback(catalog)
		return set

	var root: Dictionary = parsed as Dictionary
	set.set_id = str(root.get("setId", path.get_file().get_basename()))

	var meta: Dictionary = root.get("meta", {}) as Dictionary
	set.default_scale = float(meta.get("defaultScale", 2.0))

	var raw_clips: Dictionary = root.get("clips", {}) as Dictionary
	for state_name in raw_clips.keys():
		var clip_entry: Variant = raw_clips[state_name]
		if typeof(clip_entry) != TYPE_DICTIONARY:
			continue

		var clip_data: Dictionary = clip_entry as Dictionary
		var fps: float = maxf(float(clip_data.get("fps", 8.0)), 1.0)
		var looped: bool = bool(clip_data.get("loop", true))

		var built_frames: Array[Dictionary] = []
		var raw_frames: Variant = clip_data.get("frames", [])
		if typeof(raw_frames) == TYPE_ARRAY:
			for frame_variant in raw_frames as Array:
				if typeof(frame_variant) != TYPE_DICTIONARY:
					continue
				var frame_data: Dictionary = frame_variant as Dictionary
				var texture_path: String = str(frame_data.get("path", ""))
				var texture: Texture2D = catalog.get_texture(texture_path)
				var offset: Vector2 = _parse_offset(frame_data.get("offset", [0, 0]))
				built_frames.append({
					"texture": texture,
					"offset": offset,
				})

		if built_frames.is_empty():
			built_frames.append({
				"texture": catalog.get_texture(""),
				"offset": Vector2.ZERO,
			})

		var built_phases: Array[Dictionary] = _parse_phases(clip_data.get("phases", []), built_frames.size())
		set.clips[str(state_name).to_upper()] = {
			"fps": fps,
			"loop": looped,
			"frames": built_frames,
			"phases": built_phases,
		}

	if set.clips.is_empty():
		set._build_fallback(catalog)

	return set

func has_clip(name: String) -> bool:
	return clips.has(name.to_upper())

func get_clip(name: String) -> Dictionary:
	var key: String = name.to_upper()
	if clips.has(key):
		return clips[key] as Dictionary
	if clips.has("IDLE"):
		return clips["IDLE"] as Dictionary

	for value in clips.values():
		if typeof(value) == TYPE_DICTIONARY:
			return value as Dictionary
	return {}

static func _parse_offset(raw: Variant) -> Vector2:
	if typeof(raw) == TYPE_VECTOR2:
		return raw as Vector2
	if typeof(raw) == TYPE_ARRAY:
		var list: Array = raw as Array
		if list.size() >= 2:
			return Vector2(float(list[0]), float(list[1]))
	if typeof(raw) == TYPE_DICTIONARY:
		var map: Dictionary = raw as Dictionary
		return Vector2(float(map.get("x", 0.0)), float(map.get("y", 0.0)))
	return Vector2.ZERO

static func _parse_phases(raw: Variant, frame_count: int) -> Array[Dictionary]:
	var phases: Array[Dictionary] = []
	if typeof(raw) != TYPE_ARRAY:
		return phases

	for phase_variant in raw as Array:
		if typeof(phase_variant) != TYPE_DICTIONARY:
			continue
		var phase_data: Dictionary = phase_variant as Dictionary
		var phase_id: int = _parse_phase_id(phase_data.get("phase", ""))
		if phase_id == -1:
			continue

		var frame_indices: Array[int] = []
		var raw_frames: Variant = phase_data.get("frames", [])
		if typeof(raw_frames) == TYPE_ARRAY:
			for frame_variant in raw_frames as Array:
				var idx: int = int(frame_variant)
				if idx >= 0 and idx < frame_count:
					frame_indices.append(idx)

		if not frame_indices.is_empty():
			phases.append({
				"phase": phase_id,
				"frames": frame_indices,
			})

	return phases

static func _parse_phase_id(raw: Variant) -> int:
	match str(raw).to_lower():
		"windup":
			return AttackDefinitionScript.Phase.WINDUP
		"active":
			return AttackDefinitionScript.Phase.ACTIVE
		"recovery":
			return AttackDefinitionScript.Phase.RECOVERY
		"finished":
			return AttackDefinitionScript.Phase.FINISHED
		_:
			return -1

func _build_fallback(catalog: AssetCatalog) -> void:
	set_id = "fallback"
	default_scale = 2.0
	clips.clear()
	var fallback_frame: Dictionary = {
		"texture": catalog.get_texture(""),
		"offset": Vector2.ZERO,
	}
	clips["IDLE"] = {
		"fps": 1.0,
		"loop": true,
		"frames": [fallback_frame],
		"phases": [],
	}
