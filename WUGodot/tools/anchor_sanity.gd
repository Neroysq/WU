extends SceneTree

const AnchorMeasureScript = preload("res://scripts/visual/anchor_measure.gd")
const MANIFEST_PATH: String = "res://assets/animation_manifests/hu.manifest.json"
const TIP_DISTANCE_CEILING_WORLD: float = 430.0
const ANCHOR_TOLERANCE: float = 12.0
const FOOT_X_SPREAD_CEILING: float = 24.0
# Keep empty by default so corrected PixelForge sidecars are checked against
# the installed pixels. Add only documented, pose-specific exceptions here.
const OVERRIDE_ALLOWLIST: Dictionary = {}

func _init() -> void:
	var root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
	var scale: float = float(root.get("renderScale", 1.0))
	var poses: Dictionary = root.get("poses", {}) as Dictionary
	var fails: Array[String] = []
	var min_foot_x: float = INF
	var max_foot_x: float = -INF
	for pose_name in poses.keys():
		var pose: Dictionary = poses[pose_name] as Dictionary
		var foot: Vector2 = _v(pose.get("footAnchor"))
		var tip: Vector2 = _v(pose.get("weaponTip"))
		var hb: Rect2 = _r(pose.get("hurtbox"))
		var img: Image = _load_pose_image(pose)
		if img.is_empty():
			fails.append("%s: no texture" % pose_name)
			continue
		var canvas_w: float = float(img.get_width())
		var canvas_h: float = float(img.get_height())

		if foot.y < canvas_h * 0.4:
			fails.append("%s: stored foot too high (y=%.0f)" % [pose_name, foot.y])
		if hb.size.x < 8.0 or hb.size.y < 30.0:
			fails.append("%s: stored body box degenerate (%s)" % [pose_name, str(hb.size)])
		if hb.size.x > canvas_w * 0.85:
			fails.append("%s: stored body box too wide (%.0f) -> blade not excluded" % [pose_name, hb.size.x])
		var tip_dist_world: float = absf(tip.x - foot.x) * scale
		if tip_dist_world > TIP_DISTANCE_CEILING_WORLD:
			fails.append("%s: tip-distance %.0f world-px beyond coarse ceiling %.0f" % [pose_name, tip_dist_world, TIP_DISTANCE_CEILING_WORLD])
		min_foot_x = minf(min_foot_x, foot.x)
		max_foot_x = maxf(max_foot_x, foot.x)

		if not OVERRIDE_ALLOWLIST.has(pose_name):
			var m: Dictionary = AnchorMeasureScript.measure(img)
			var measured_tip: Vector2 = m["weaponTip"] as Vector2
			if tip.distance_to(measured_tip) > ANCHOR_TOLERANCE:
				fails.append("%s: stored weaponTip drifts from measured (%s vs %s) - regenerate or allowlist" % [pose_name, str(tip), str(measured_tip)])

	var foot_x_spread: float = max_foot_x - min_foot_x
	if foot_x_spread > FOOT_X_SPREAD_CEILING:
		fails.append("stored footAnchor.x spread %.0f exceeds ceiling %.0f; use body-center foot X to avoid presenter lurch" % [foot_x_spread, FOOT_X_SPREAD_CEILING])

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

func _load_pose_image(pose: Dictionary) -> Image:
	var tex: Texture2D = load(str(pose.get("path", ""))) as Texture2D
	if tex == null:
		return Image.new()
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	return img
