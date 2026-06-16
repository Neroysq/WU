extends SceneTree
# Install staged pixelized video frames as manifest poses.
#
# Usage (via run.sh):
#   ./run.sh --install-video <run-dir> --action=<name> --frames=020,023,... \
#            [--prefix=va] [--foot-x=224] [--manifest=res://assets/animation_manifests/hu.manifest.json]
#            [--transforms=<json>]
#
# ORDER CONTRACT: pixel_001 installs as <prefix>_<first --frames label>,
# pixel_002 as the second, and so on. --frames names destinations; it never
# selects sources. Stage only the approved source frames, renumbered 001..N,
# before running this tool.

const AnchorMeasureScript = preload("res://scripts/visual/anchor_measure.gd")

const DEST_DIR: String = "res://assets/sprites/characters/hu/"

var _transforms: Dictionary = {}

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: install_video_frames <run-dir> --action=x --frames=a,b,c")
		quit(1)
		return

	var run_dir: String = args[0].trim_suffix("/")
	var action: String = _arg("--action", "")
	var frame_labels: PackedStringArray = _arg("--frames", "").split(",", false)
	var prefix: String = _arg("--prefix", action)
	var foot_x: int = int(_arg("--foot-x", "224"))
	var manifest_path: String = _arg("--manifest", "res://assets/animation_manifests/hu.manifest.json")
	var transform_path: String = _arg("--transforms", "")
	if action.is_empty() or frame_labels.is_empty():
		printerr("--action and --frames are required")
		quit(1)
		return
	if not transform_path.is_empty():
		_transforms = _read_transform_file(_global_path(transform_path))

	var staged: Array[Dictionary] = []
	var min_x: float = INF
	var max_x: float = -INF
	for i in range(frame_labels.size()):
		var source_index: int = i + 1
		var pixel_png: String = run_dir.path_join(action).path_join("pixelize").path_join("pixel_%03d.png" % source_index)
		var pixel_sidecar: Dictionary = _read_dict(pixel_png.get_basename() + ".json")
		var master_sidecar: Dictionary = _read_dict(run_dir.path_join(action).path_join("masters").path_join("master_%03d.json" % source_index))
		var scale_applied: Vector2 = _scale_applied(pixel_sidecar, pixel_png)
		if scale_applied.x <= 0.0 or absf(scale_applied.x - scale_applied.y) > 0.0001:
			printerr("frame %03d: non-uniform scale_applied %s — refuse to install" % [source_index, str(scale_applied)])
			quit(1)
			return
		var master_foot: Vector2 = _vector(master_sidecar.get("foot_anchor", master_sidecar.get("footAnchor", [])), "master_%03d foot_anchor" % source_index)
		var foot_px: Vector2 = master_foot * scale_applied
		min_x = minf(min_x, foot_px.x)
		max_x = maxf(max_x, foot_px.x)
		staged.append({"src": pixel_png, "label": str(frame_labels[i]), "foot": foot_px})

	var spread: float = max_x - min_x
	if spread > 2.0:
		printerr("foot-x spread %.1f across batch — masters not normalized; refuse to install" % spread)
		quit(1)
		return

	var root: Dictionary = _read_dict(manifest_path)
	var poses: Dictionary = root.get("poses", {}) as Dictionary
	_cleanup_existing_prefix(poses, prefix)

	for entry_value in staged:
		var entry: Dictionary = entry_value as Dictionary
		var src: String = str(entry["src"])
		var foot: Vector2 = entry["foot"] as Vector2
		var img: Image = Image.new()
		var err: Error = img.load(src)
		if err != OK:
			printerr("load fail %s (%s)" % [src, error_string(err)])
			quit(1)
			return
		if img.is_compressed():
			img.decompress()
		var crop: int = int(round(foot.x)) - foot_x
		var used: Rect2i = img.get_used_rect()
		if crop < 0 or crop >= img.get_width() or used.position.x < crop:
			printerr("crop %d invalid for %s (content min x %d)" % [crop, src, used.position.x])
			quit(1)
			return
		var cropped: Image = Image.create(img.get_width() - crop, img.get_height(), false, Image.FORMAT_RGBA8)
		cropped.fill(Color(0, 0, 0, 0))
		cropped.blit_rect(img, Rect2i(crop, 0, img.get_width() - crop, img.get_height()), Vector2i.ZERO)

		var pose_name: String = "%s_%s" % [prefix, str(entry["label"])]
		cropped = _apply_pose_translation(cropped, _pose_transform(pose_name))
		var dest: String = DEST_DIR + pose_name + ".png"
		var save_err: Error = cropped.save_png(ProjectSettings.globalize_path(dest))
		if save_err != OK:
			printerr("save fail %s (%s)" % [dest, error_string(save_err)])
			quit(1)
			return

		var measured: Dictionary = AnchorMeasureScript.measure(cropped)
		var tip: Vector2 = measured.get("weaponTip", Vector2.ZERO) as Vector2
		var chest: Vector2 = measured.get("chestAnchor", Vector2.ZERO) as Vector2
		var hurtbox: Rect2 = measured.get("hurtbox", Rect2()) as Rect2
		poses[pose_name] = {
			"path": dest,
			"footAnchor": [foot_x, int(round(foot.y))],
			"chestAnchor": [int(round(chest.x)), int(round(chest.y))],
			"weaponTip": [int(round(tip.x)), int(round(tip.y))],
			"hurtbox": [int(round(hurtbox.position.x)), int(round(hurtbox.position.y)), int(round(hurtbox.size.x)), int(round(hurtbox.size.y))],
		}
		print("%-10s foot_y=%d tip=%s" % [pose_name, int(round(foot.y)), str(poses[pose_name]["weaponTip"])])

	root["poses"] = poses
	var out: FileAccess = FileAccess.open(manifest_path, FileAccess.WRITE)
	if out == null:
		printerr("failed to write manifest %s" % manifest_path)
		quit(1)
		return
	out.store_string(JSON.stringify(root, "  "))
	out.close()
	print("manifest: %d poses total" % poses.size())
	quit(0)

func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		var text: String = str(a)
		if text.begins_with(name + "="):
			return text.substr(name.length() + 1)
	return fallback

func _global_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path

func _read_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		printerr("missing file: %s" % path)
		quit(1)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("invalid json: %s" % path)
		quit(1)
		return {}
	return parsed as Dictionary

func _read_transform_file(path: String) -> Dictionary:
	var root: Dictionary = _read_dict(path)
	if root.has("transforms"):
		return root.get("transforms", {}) as Dictionary
	return root

func _scale_applied(sidecar: Dictionary, source_path: String) -> Vector2:
	var raw: Variant = sidecar.get("scale_applied", sidecar.get("scaleApplied", []))
	if typeof(raw) == TYPE_ARRAY:
		var arr: Array = raw as Array
		if arr.size() >= 2:
			return Vector2(float(arr[0]), float(arr[1]))
	elif typeof(raw) == TYPE_DICTIONARY:
		var dict: Dictionary = raw as Dictionary
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	printerr("missing scale_applied in %s.json" % source_path.get_basename())
	quit(1)
	return Vector2.ZERO

func _pose_transform(pose_name: String) -> Dictionary:
	var raw: Variant = _transforms.get(pose_name, {})
	if typeof(raw) == TYPE_DICTIONARY:
		return raw as Dictionary
	return {}

func _apply_pose_translation(img: Image, transform: Dictionary) -> Image:
	var offset_x: int = int(round(float(transform.get("offsetX", 0.0))))
	var offset_y: int = int(round(float(transform.get("offsetY", 0.0))))
	if offset_x == 0 and offset_y == 0:
		return img

	var src_rect := Rect2i(
		maxi(0, -offset_x),
		maxi(0, -offset_y),
		img.get_width() - maxi(0, -offset_x),
		img.get_height() - maxi(0, -offset_y)
	)
	if src_rect.size.x <= 0 or src_rect.size.y <= 0:
		printerr("transform crops entire image: %s" % str(transform))
		quit(1)
		return img

	var out_w: int = src_rect.size.x + maxi(0, offset_x)
	var out_h: int = src_rect.size.y + maxi(0, offset_y)
	var out: Image = Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(img, src_rect, Vector2i(maxi(0, offset_x), maxi(0, offset_y)))
	return out

func _vector(raw: Variant, label: String) -> Vector2:
	if typeof(raw) == TYPE_ARRAY:
		var arr: Array = raw as Array
		if arr.size() >= 2:
			return Vector2(float(arr[0]), float(arr[1]))
	printerr("missing vector %s" % label)
	quit(1)
	return Vector2.ZERO

func _cleanup_existing_prefix(poses: Dictionary, prefix: String) -> void:
	for existing in poses.keys().duplicate():
		if not str(existing).begins_with(prefix + "_"):
			continue
		poses.erase(existing)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DEST_DIR + str(existing) + ".png"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DEST_DIR + str(existing) + ".png.import"))
