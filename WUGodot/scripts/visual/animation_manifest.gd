class_name AnimationManifest
extends RefCounted

var id: String = "unknown"
var source_canvas: Vector2 = Vector2(256, 256)
var render_scale: float = 1.0
var native_facing: int = 1
var weapon_class: String = "sword"
var poses: Dictionary = {}

const _REQUIRED_ANCHORS: Array[String] = ["footAnchor", "weaponTip"]

static func load_from_file(path: String) -> Variant:
	var manifest: Variant = (load("res://scripts/visual/animation_manifest.gd") as Script).new()
	if path.is_empty() or not FileAccess.file_exists(path):
		return manifest

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return manifest

	var root: Dictionary = parsed as Dictionary
	manifest.id = str(root.get("id", "unknown"))
	manifest.source_canvas = _vec2(root.get("sourceCanvas", [256, 256]), Vector2(256, 256))
	manifest.render_scale = float(root.get("renderScale", 1.0))
	manifest.native_facing = _facing(root.get("nativeFacing", root.get("native_facing", 1)))
	manifest.weapon_class = str(root.get("weaponClass", "sword"))

	var raw_poses: Dictionary = root.get("poses", {}) as Dictionary
	for pose_name in raw_poses.keys():
		var entry: Dictionary = raw_poses[pose_name] as Dictionary
		var hurtbox_variant: Variant = entry.get("hurtbox", null)
		manifest.poses[str(pose_name)] = {
			"path": str(entry.get("path", "")),
			"footAnchor": _vec2(entry.get("footAnchor", null), Vector2.ZERO),
			"chestAnchor": _vec2(entry.get("chestAnchor", null), Vector2.ZERO),
			"weaponTip": _vec2(entry.get("weaponTip", null), Vector2.ZERO),
			"hurtbox": _rect(hurtbox_variant),
			"nativeFacing": _facing(entry.get("nativeFacing", entry.get("native_facing", manifest.native_facing))),
			"_has": entry.keys(),
		}
	return manifest

func has_pose(pose_name: String) -> bool:
	return poses.has(pose_name)

func get_pose(pose_name: String) -> Dictionary:
	return poses.get(pose_name, {}) as Dictionary

func get_hurtbox(pose_name: String) -> Variant:
	if not poses.has(pose_name):
		return null
	return (poses[pose_name] as Dictionary).get("hurtbox", null)

func validation_errors(required_poses: Array) -> Array[String]:
	var errors: Array[String] = []
	for pose_name in required_poses:
		if not poses.has(pose_name):
			errors.append("missing pose '%s'" % str(pose_name))
			continue

		var entry: Dictionary = poses[pose_name] as Dictionary
		var present: Array = entry.get("_has", []) as Array
		for anchor in _REQUIRED_ANCHORS:
			if not present.has(anchor):
				errors.append("pose '%s' missing required anchor '%s'" % [str(pose_name), anchor])
	return errors

static func _vec2(raw: Variant, fallback: Vector2) -> Vector2:
	if typeof(raw) == TYPE_ARRAY:
		var list: Array = raw as Array
		if list.size() >= 2:
			return Vector2(float(list[0]), float(list[1]))
	return fallback

static func _facing(raw: Variant) -> int:
	return -1 if int(raw) < 0 else 1

static func _rect(raw: Variant) -> Variant:
	if typeof(raw) == TYPE_ARRAY:
		var list: Array = raw as Array
		if list.size() >= 4:
			return Rect2(float(list[0]), float(list[1]), float(list[2]), float(list[3]))
	return null
