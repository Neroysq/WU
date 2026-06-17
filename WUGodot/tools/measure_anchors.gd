extends SceneTree

const AnchorMeasureScript = preload("res://scripts/visual/anchor_measure.gd")
const MANIFEST_PATH: String = "res://assets/animation_manifests/hu.manifest.json"
const STABLE_ROOTS: Dictionary = {
	"vi": [132, 198],
	"vd": [224, 382],
	"vh": [224, 382],
	"vl": [224, 382],
	"vw": [224, 382],
	"vp": [334, 382],
}
const ALIASES: Dictionary = {
	"breath": "vi_050",
	"guard": "vi_002",
	"heavy_recover": "vh_080",
	"heavy_strike": "vh_064",
	"heavy_windup": "vh_001",
	"recover": "vl_081",
	"strike_extended": "vl_051",
	"windup": "vl_001",
}

func _init() -> void:
	var root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
	var poses: Dictionary = root.get("poses", {}) as Dictionary
	for pose_name in poses.keys():
		var pose: Dictionary = poses[pose_name] as Dictionary
		var tex: Texture2D = load(str(pose.get("path", ""))) as Texture2D
		if tex == null:
			print("SKIP %s" % pose_name)
			continue
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		var m: Dictionary = AnchorMeasureScript.measure(img)
		pose["footAnchor"] = _stable_root(pose_name, _iv(m["footAnchor"] as Vector2))
		pose["weaponTip"] = _iv(m["weaponTip"] as Vector2)
		pose["chestAnchor"] = _iv(m["chestAnchor"] as Vector2)
		var hb: Rect2 = m["hurtbox"] as Rect2
		pose["hurtbox"] = [int(round(hb.position.x)), int(round(hb.position.y)), int(round(hb.size.x)), int(round(hb.size.y))]
		poses[pose_name] = pose
		print("%-18s foot=%s tip=%s" % [pose_name, str(pose["footAnchor"]), str(pose["weaponTip"])])
	_refresh_aliases(poses)
	root["poses"] = poses
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(root, "  "))
	f.close()
	print("WROTE %s" % MANIFEST_PATH)
	quit()

func _iv(v: Vector2) -> Array:
	return [int(round(v.x)), int(round(v.y))]

func _stable_root(pose_name: String, fallback: Array) -> Array:
	var prefix: String = pose_name.get_slice("_", 0)
	if STABLE_ROOTS.has(prefix):
		return (STABLE_ROOTS[prefix] as Array).duplicate()
	return fallback

func _refresh_aliases(poses: Dictionary) -> void:
	for alias_name in ALIASES.keys():
		var source_name: String = str(ALIASES[alias_name])
		if not poses.has(alias_name) or not poses.has(source_name):
			continue
		var alias_pose: Dictionary = poses[alias_name] as Dictionary
		var source_pose: Dictionary = poses[source_name] as Dictionary
		for key in ["path", "footAnchor", "weaponTip", "chestAnchor", "hurtbox"]:
			alias_pose[key] = source_pose.get(key)
		poses[alias_name] = alias_pose
