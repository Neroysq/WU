extends SceneTree

const AnchorMeasureScript = preload("res://scripts/visual/anchor_measure.gd")
const MANIFEST_PATH: String = "res://assets/animation_manifests/hu.manifest.json"

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
		pose["footAnchor"] = _iv(m["footAnchor"] as Vector2)
		pose["weaponTip"] = _iv(m["weaponTip"] as Vector2)
		pose["chestAnchor"] = _iv(m["chestAnchor"] as Vector2)
		var hb: Rect2 = m["hurtbox"] as Rect2
		pose["hurtbox"] = [int(round(hb.position.x)), int(round(hb.position.y)), int(round(hb.size.x)), int(round(hb.size.y))]
		poses[pose_name] = pose
		print("%-18s foot=%s tip=%s" % [pose_name, str(pose["footAnchor"]), str(pose["weaponTip"])])
	root["poses"] = poses
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(root, "  "))
	f.close()
	print("WROTE %s" % MANIFEST_PATH)
	quit()

func _iv(v: Vector2) -> Array:
	return [int(round(v.x)), int(round(v.y))]
