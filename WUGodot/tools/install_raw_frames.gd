extends SceneTree
# Install approved canon PNG frames directly into the base Hu manifest.
#
# Usage (via run.sh):
#   ./run.sh --install-raw-frames --src=art/canon/hu/clips/attack_light \
#       --prefix=hu_light --native-facing=1 --set-root-native=1
#   ./run.sh --install-raw-frames --src=art/canon/hu \
#       --files=k1.png,k2.png --labels=k1,k2 --prefix=hu --native-facing=1

const AnchorMeasureScript = preload("res://scripts/visual/anchor_measure.gd")

const DEFAULT_MANIFEST: String = "res://assets/animation_manifests/hu.manifest.json"
const DEFAULT_DEST_DIR: String = "res://assets/sprites/characters/hu"
const FOOT_SPREAD_WARN: float = 4.0

func _init() -> void:
	var src_dir: String = _arg("--src", "")
	var prefix: String = _arg("--prefix", "")
	var aliases: Dictionary = _aliases_arg(_arg("--aliases", ""))
	if (src_dir.is_empty() or prefix.is_empty()) and aliases.is_empty():
		printerr("usage: install_raw_frames --src=<dir> --prefix=<pose-prefix> [--files=a.png,b.png] [--labels=a,b] [--mirror=true] [--native-facing=1] [--foot-x=px] [--foot-y=px] [--aliases=alias:source,...]")
		quit(1)
		return

	var manifest_path: String = _arg("--manifest", DEFAULT_MANIFEST)
	var dest_dir: String = _arg("--dest-dir", DEFAULT_DEST_DIR).trim_suffix("/")
	var mirror: bool = _bool_arg("--mirror", false)
	var native_facing: int = _native_facing(_arg("--native-facing", "1"))
	var root_native_raw: String = _arg("--set-root-native", "")
	var foot_x_override: float = float(_arg("--foot-x", "-1"))
	var foot_y_override: float = float(_arg("--foot-y", "-1"))
	var files: PackedStringArray = _source_files(src_dir)
	var labels: PackedStringArray = _labels(files)
	if files.is_empty() and aliases.is_empty():
		printerr("no source pngs found in %s" % src_dir)
		quit(1)
		return
	if labels.size() != files.size():
		printerr("--labels count %d does not match source file count %d" % [labels.size(), files.size()])
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest_dir))
	var root: Dictionary = _read_dict(manifest_path)
	var previous_root_native: int = _native_facing(root.get("nativeFacing", root.get("native_facing", 1)))
	var poses: Dictionary = root.get("poses", {}) as Dictionary
	if not root_native_raw.is_empty():
		for pose_name in poses.keys():
			var pose: Dictionary = poses[pose_name] as Dictionary
			if not pose.has("nativeFacing") and not pose.has("native_facing"):
				pose["nativeFacing"] = previous_root_native
				poses[pose_name] = pose
		root["nativeFacing"] = _native_facing(root_native_raw)

	var foot_bounds: Dictionary = {}
	for i in range(files.size()):
		var src_path: String = _path_join(src_dir, files[i])
		var img: Image = Image.new()
		var err: Error = img.load(_global_path(src_path))
		if err != OK:
			printerr("load fail %s (%s)" % [src_path, error_string(err)])
			quit(1)
			return
		if img.is_compressed():
			img.decompress()
		if mirror:
			img.flip_x()

		var label: String = str(labels[i])
		var pose_name: String = "%s_%s" % [prefix, label]
		var dest: String = "%s/%s.png" % [dest_dir, pose_name]
		var save_err: Error = img.save_png(ProjectSettings.globalize_path(dest))
		if save_err != OK:
			printerr("save fail %s (%s)" % [dest, error_string(save_err)])
			quit(1)
			return

		var measured: Dictionary = AnchorMeasureScript.measure(img, native_facing)
		var measured_foot: Vector2 = measured.get("footAnchor", Vector2.ZERO) as Vector2
		var foot: Vector2 = measured_foot
		if foot_x_override >= 0.0:
			foot.x = foot_x_override
		if foot_y_override >= 0.0:
			foot.y = foot_y_override
		_track_foot_bounds(foot_bounds, _clip_stem(pose_name), foot)
		var chest: Vector2 = measured.get("chestAnchor", Vector2.ZERO) as Vector2
		var tip: Vector2 = measured.get("weaponTip", Vector2.ZERO) as Vector2
		var hurtbox: Rect2 = measured.get("hurtbox", Rect2()) as Rect2
		poses[pose_name] = {
			"path": dest,
			"footAnchor": _iv(foot),
			"chestAnchor": _iv(chest),
			"weaponTip": _iv(tip),
			"hurtbox": _ir(hurtbox),
			"nativeFacing": native_facing,
		}
		print("%-18s foot=%s tip=%s native=%d" % [pose_name, str(poses[pose_name]["footAnchor"]), str(poses[pose_name]["weaponTip"]), native_facing])

	_warn_foot_bounds(foot_bounds)

	for alias_name in aliases.keys():
		var source_name: String = str(aliases[alias_name])
		if not poses.has(source_name):
			printerr("alias source missing: %s -> %s" % [str(alias_name), source_name])
			quit(1)
			return
		poses[str(alias_name)] = (poses[source_name] as Dictionary).duplicate(true)
		print("alias %-18s -> %s" % [str(alias_name), source_name])

	root["poses"] = poses
	var out: FileAccess = FileAccess.open(manifest_path, FileAccess.WRITE)
	if out == null:
		printerr("failed to write manifest %s" % manifest_path)
		quit(1)
		return
	out.store_string(JSON.stringify(root, "  "))
	out.close()
	print("WROTE %s (%d poses)" % [manifest_path, poses.size()])
	quit(0)

func _source_files(src_dir: String) -> PackedStringArray:
	var explicit: String = _arg("--files", "")
	if not explicit.is_empty():
		return explicit.split(",", false)
	if src_dir.is_empty():
		return PackedStringArray()
	var dir := DirAccess.open(_global_path(src_dir))
	if dir == null:
		return PackedStringArray()
	var files := PackedStringArray()
	for file in dir.get_files():
		if file.begins_with("f") and file.ends_with(".png"):
			files.append(file)
	files.sort()
	return files

func _track_foot_bounds(bounds: Dictionary, key: String, foot: Vector2) -> void:
	var record: Dictionary = bounds.get(key, {
		"min": Vector2(INF, INF),
		"max": Vector2(-INF, -INF),
		"count": 0,
	}) as Dictionary
	var min_v: Vector2 = record.get("min", Vector2(INF, INF)) as Vector2
	var max_v: Vector2 = record.get("max", Vector2(-INF, -INF)) as Vector2
	record["min"] = Vector2(minf(min_v.x, foot.x), minf(min_v.y, foot.y))
	record["max"] = Vector2(maxf(max_v.x, foot.x), maxf(max_v.y, foot.y))
	record["count"] = int(record.get("count", 0)) + 1
	bounds[key] = record

func _warn_foot_bounds(bounds: Dictionary) -> void:
	for key in bounds.keys():
		var record: Dictionary = bounds[key] as Dictionary
		if int(record.get("count", 0)) <= 1:
			continue
		var spread: Vector2 = (record.get("max", Vector2.ZERO) as Vector2) - (record.get("min", Vector2.ZERO) as Vector2)
		if spread.x > FOOT_SPREAD_WARN or spread.y > FOOT_SPREAD_WARN:
			push_warning("%s footAnchor spread is %.1fx%.1f px; registered clips should stay under %.1f px" % [str(key), spread.x, spread.y, FOOT_SPREAD_WARN])

func _clip_stem(pose_name: String) -> String:
	var parts: PackedStringArray = pose_name.split("_")
	if parts.size() > 1:
		var last: String = parts[parts.size() - 1]
		if last.is_valid_int():
			parts.remove_at(parts.size() - 1)
			return "_".join(parts)
	return pose_name

func _labels(files: PackedStringArray) -> PackedStringArray:
	var explicit: String = _arg("--labels", "")
	if not explicit.is_empty():
		return explicit.split(",", false)
	var labels := PackedStringArray()
	for file in files:
		var stem: String = file.get_basename()
		if stem.begins_with("f"):
			labels.append("%03d" % int(stem.substr(1)))
		else:
			labels.append(stem)
	return labels

func _aliases_arg(text: String) -> Dictionary:
	var aliases: Dictionary = {}
	if text.is_empty():
		return aliases
	for item in text.split(",", false):
		var pair: PackedStringArray = str(item).split(":", false, 2)
		if pair.size() != 2:
			continue
		aliases[str(pair[0])] = str(pair[1])
	return aliases

func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		var text: String = str(a)
		if text.begins_with(name + "="):
			return text.substr(name.length() + 1)
	return fallback

func _bool_arg(name: String, fallback: bool) -> bool:
	var text: String = _arg(name, "true" if fallback else "false").to_lower()
	return text in ["1", "true", "yes", "on"]

func _native_facing(raw: Variant) -> int:
	return -1 if int(raw) < 0 else 1

func _global_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	var repo_relative: String = ProjectSettings.globalize_path("res://../%s" % path)
	if FileAccess.file_exists(repo_relative) or DirAccess.dir_exists_absolute(repo_relative):
		return repo_relative
	return path

func _path_join(base: String, file: String) -> String:
	if base.ends_with("/"):
		return base + file
	return base + "/" + file

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

func _iv(v: Vector2) -> Array:
	return [int(round(v.x)), int(round(v.y))]

func _ir(r: Rect2) -> Array:
	return [int(round(r.position.x)), int(round(r.position.y)), int(round(r.size.x)), int(round(r.size.y))]
