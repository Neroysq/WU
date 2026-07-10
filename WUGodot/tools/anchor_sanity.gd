extends SceneTree

const AnchorMeasureScript = preload("res://scripts/visual/anchor_measure.gd")
const MANIFEST_PATH: String = "res://assets/animation_manifests/hu.manifest.json"
# Coarse absurdity guard only — gameplay reach is gated by the reach-consistency tests.
# 560 accommodates the video-generated thrust frames (va_strike tip-foot 265 src x2),
# which legitimately extend further than the still-art family.
const TIP_DISTANCE_CEILING_WORLD: float = 560.0
const ANCHOR_TOLERANCE: float = 12.0
const FOOT_X_GROUP_SPREAD_CEILING: float = 4.0
# Correctly measured, non-collision smear frames whose sword tips exceed the
# coarse distance guard by a few pixels. Add only documented, pose-specific
# exceptions here.
const OVERRIDE_ALLOWLIST: Dictionary = {
	"hu_light_028": true,
	"hu_light_029": true,
}

func _init() -> void:
	var root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
	var scale: float = float(root.get("renderScale", 1.0))
	var root_native_facing: int = _native_facing(root.get("nativeFacing", root.get("native_facing", 1)))
	var poses: Dictionary = root.get("poses", {}) as Dictionary
	var fails: Array[String] = []
	var foot_groups: Dictionary = {}
	for pose_name in poses.keys():
		var pose: Dictionary = poses[pose_name] as Dictionary
		var native_facing: int = _native_facing(pose.get("nativeFacing", root_native_facing))
		var foot: Vector2 = _v(pose.get("footAnchor"))
		var tip: Vector2 = _v(pose.get("weaponTip"))
		var hb: Rect2 = _r(pose.get("hurtbox"))
		var img: Image = _load_pose_image(pose)
		if img.is_empty():
			fails.append("%s: no texture" % pose_name)
			continue
		var canvas_w: float = float(img.get_width())
		var canvas_h: float = float(img.get_height())
		var group_key: String = "%s:%.0f:%d" % [_clip_stem(pose_name), canvas_w, native_facing]
		if not foot_groups.has(group_key):
			foot_groups[group_key] = {"min": foot.x, "max": foot.x}
		else:
			var group: Dictionary = foot_groups[group_key] as Dictionary
			group["min"] = minf(float(group["min"]), foot.x)
			group["max"] = maxf(float(group["max"]), foot.x)

		if foot.y < 0.0 or foot.y >= canvas_h:
			fails.append("%s: stored foot outside canvas (y=%.0f canvas_h=%.0f)" % [pose_name, foot.y, canvas_h])
		elif foot.y < canvas_h * 0.4:
			fails.append("%s: stored foot too high (y=%.0f)" % [pose_name, foot.y])
		if hb.size.x < 8.0 or hb.size.y < 30.0:
			fails.append("%s: stored body box degenerate (%s)" % [pose_name, str(hb.size)])
		if hb.size.x > canvas_w * 0.85:
			fails.append("%s: stored body box too wide (%.0f) -> blade not excluded" % [pose_name, hb.size.x])
		var tip_dist_world: float = absf(tip.x - foot.x) * scale
		if not OVERRIDE_ALLOWLIST.has(pose_name) and tip_dist_world > TIP_DISTANCE_CEILING_WORLD:
			fails.append("%s: tip-distance %.0f world-px beyond coarse ceiling %.0f" % [pose_name, tip_dist_world, TIP_DISTANCE_CEILING_WORLD])

		if not OVERRIDE_ALLOWLIST.has(pose_name):
			var m: Dictionary = AnchorMeasureScript.measure(img, native_facing)
			var measured_tip: Vector2 = m["weaponTip"] as Vector2
			if tip.distance_to(measured_tip) > ANCHOR_TOLERANCE:
				fails.append("%s: stored weaponTip drifts from measured (%s vs %s) - regenerate or allowlist" % [pose_name, str(tip), str(measured_tip)])

	for group_key in foot_groups.keys():
		var group: Dictionary = foot_groups[group_key] as Dictionary
		var spread: float = float(group["max"]) - float(group["min"])
		if spread > FOOT_X_GROUP_SPREAD_CEILING:
			fails.append("stored footAnchor.x spread %.0f in %spx-wide sprites exceeds ceiling %.0f; root must be stable within each canvas family" % [spread, group_key, FOOT_X_GROUP_SPREAD_CEILING])

	if fails.is_empty():
		print("ANCHOR SANITY: OK")
		quit(0)
	else:
		for fail in fails:
			print("ANCHOR SANITY FAIL: %s" % fail)
		quit(1)

func _v(raw: Variant) -> Vector2:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO

func _r(raw: Variant) -> Rect2:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 4:
		return Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
	return Rect2()

func _native_facing(raw: Variant) -> int:
	return -1 if int(raw) < 0 else 1

func _clip_stem(pose_name: String) -> String:
	var parts: PackedStringArray = pose_name.split("_", false)
	if parts.size() < 2:
		return pose_name
	var last: String = parts[parts.size() - 1]
	if not last.is_valid_int():
		return pose_name
	var stem_parts: PackedStringArray = PackedStringArray()
	for i in range(parts.size() - 1):
		stem_parts.append(parts[i])
	return "_".join(stem_parts)

func _load_pose_image(pose: Dictionary) -> Image:
	var tex: Texture2D = load(str(pose.get("path", ""))) as Texture2D
	if tex == null:
		return Image.new()
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	return img
