extends SceneTree

const AnchorMeasureScript = preload("res://scripts/visual/anchor_measure.gd")

const SLOTS: Dictionary = {
	"idle": ["idle_0", "idle_1"],
	"walk-cycle": ["walk_0", "walk_1", "walk_2", "walk_3"],
	"attack": ["attack_0", "attack_1", "attack_2", "attack_3"],
	"attack-heavy": ["heavy_0", "heavy_1", "heavy_2", "heavy_3"],
	"block": ["block_0", "block_1"],
	"hit-react": ["hit_0", "hit_1"],
	"stunned": ["stunned_0", "stunned_1"],
	"dash": ["dash_0", "dash_1"],
	"jump": ["jump_0", "jump_1", "jump_2"],
}

const POSE_SLOT: Dictionary = {
	"guard": "idle_0",
	"breath": "idle_1",
	"walk_0": "walk_0",
	"walk_1": "walk_1",
	"walk_2": "walk_2",
	"walk_3": "walk_3",
	"windup": "attack_1",
	"strike_extended": "attack_2",
	"recover": "attack_3",
	"heavy_windup": "heavy_0",
	"heavy_strike": "heavy_1",
	"heavy_recover": "heavy_2",
}

const DEST: String = "res://assets/sprites/characters/hu/"
const MANIFEST: String = "res://assets/animation_manifests/hu.manifest.json"
const ANIMSET: String = "res://assets/animations/character_hu.json"
const OVERRIDES: String = "res://tools/hu_capsule_overrides.json"
const RENDER_SCALE: float = 2.0

func _init() -> void:
	var run_dir: String = _arg()
	if run_dir.is_empty():
		printerr("usage: --install-pixelized <abs_run_dir>")
		quit(1)
		return

	var selected_entries: Array = []
	for action in SLOTS.keys():
		var pdir: String = run_dir.path_join(str(action)).path_join("pixelize")
		var dir: DirAccess = DirAccess.open(pdir)
		if dir == null:
			printerr("missing pixelize dir: %s" % pdir)
			quit(1)
			return
		var pngs: PackedStringArray = []
		for file_name in dir.get_files():
			if file_name.ends_with(".png"):
				pngs.append(file_name)
		pngs.sort()
		var names: Array = SLOTS[action] as Array
		var idxs: Array = _sample_indices(pngs.size(), names.size())
		if idxs.is_empty():
			printerr("not enough frames for %s (%d < %d)" % [str(action), pngs.size(), names.size()])
			quit(1)
			return
		for i in range(names.size()):
			var src: String = pdir.path_join(pngs[int(idxs[i])])
			var dest_name: String = str(names[i])
			var pixel_sidecar: Dictionary = _read_dict(src.get_basename() + ".json")
			var scale_applied: float = _exact_scale(pixel_sidecar, src)
			var master_sidecar_path: String = _master_sidecar_for(run_dir, str(action), src)
			var master_sidecar: Dictionary = _read_dict(master_sidecar_path)
			var master_foot: Vector2 = _vector(master_sidecar.get("foot_anchor"))
			var foot_px: Vector2 = master_foot * scale_applied

			var source_img: Image = Image.new()
			var load_err: Error = source_img.load(src)
			if load_err != OK:
				printerr("failed to load %s (%s)" % [src, error_string(load_err)])
				quit(1)
				return
			if source_img.is_compressed():
				source_img.decompress()
			var measured: Dictionary = AnchorMeasureScript.measure(source_img)
			measured["footAnchor"] = foot_px
			selected_entries.append({
				"src": src,
				"dest_name": dest_name,
				"action": str(action),
				"master_name": src.get_file().get_basename().replace("pixel", "master"),
				"measured": measured,
			})

	_assert_constant_foot(selected_entries)

	var side_by_slot: Dictionary = {}
	for entry_value in selected_entries:
		var entry: Dictionary = entry_value as Dictionary
		var src: String = str(entry["src"])
		var dest_name: String = str(entry["dest_name"])
		var copy_err: Error = DirAccess.copy_absolute(src, ProjectSettings.globalize_path(DEST + dest_name + ".png"))
		if copy_err != OK:
			printerr("failed to copy %s -> %s (%s)" % [src, DEST + dest_name + ".png", error_string(copy_err)])
			quit(1)
			return
		side_by_slot[dest_name] = entry["measured"] as Dictionary
		print("slot %s <- %s/%s" % [dest_name, str(entry["action"]), str(entry["master_name"])])

	var poses: Dictionary = {}
	for pose_name in POSE_SLOT.keys():
		var slot: String = str(POSE_SLOT[pose_name])
		var meta: Dictionary = side_by_slot.get(slot, {}) as Dictionary
		var foot: Vector2 = meta.get("footAnchor", Vector2.ZERO) as Vector2
		var chest: Vector2 = meta.get("chestAnchor", foot) as Vector2
		var tip: Vector2 = meta.get("weaponTip", foot) as Vector2
		var hurtbox: Rect2 = meta.get("hurtbox", Rect2()) as Rect2
		poses[pose_name] = {
			"path": DEST + slot + ".png",
			"footAnchor": [int(round(foot.x)), int(round(foot.y))],
			"chestAnchor": [int(round(chest.x)), int(round(chest.y))],
			"weaponTip": [int(round(tip.x)), int(round(tip.y))],
			"hurtbox": [int(round(hurtbox.position.x)), int(round(hurtbox.position.y)), int(round(hurtbox.size.x)), int(round(hurtbox.size.y))],
		}

	_apply_capsule_overrides(poses)
	_write_dict(MANIFEST, {"id": "hu", "renderScale": RENDER_SCALE, "weaponClass": "sword", "poses": poses})
	_zero_animset_offsets()

	var idle_meta: Dictionary = side_by_slot.get("idle_0", {}) as Dictionary
	var foot: Vector2 = idle_meta.get("footAnchor", Vector2.ZERO) as Vector2
	var idle_img: Image = Image.new()
	var load_err: Error = idle_img.load(ProjectSettings.globalize_path(DEST + "idle_0.png"))
	if load_err != OK:
		printerr("failed to load installed idle_0.png (%s)" % error_string(load_err))
		quit(1)
		return
	var y_offset: float = (float(idle_img.get_height()) - foot.y) * RENDER_SCALE
	print("installed; profile yOffset = %.3f  renderScale = %.1f" % [y_offset, RENDER_SCALE])
	quit()

func _apply_capsule_overrides(poses: Dictionary) -> void:
	if not FileAccess.file_exists(OVERRIDES):
		return
	var overrides: Dictionary = _read_dict(OVERRIDES)
	for pose_name in overrides.keys():
		if not poses.has(pose_name):
			push_warning("capsule override for unknown pose: %s" % str(pose_name))
			continue
		var pose_overrides: Dictionary = overrides[pose_name] as Dictionary
		if pose_overrides.has("chestAnchor"):
			poses[pose_name]["chestAnchor"] = pose_overrides["chestAnchor"]
		if pose_overrides.has("weaponTip"):
			poses[pose_name]["weaponTip"] = pose_overrides["weaponTip"]

func _zero_animset_offsets() -> void:
	var anim: Dictionary = _read_dict(ANIMSET)
	var clips: Dictionary = anim.get("clips", {}) as Dictionary
	for clip_value in clips.values():
		var clip: Dictionary = clip_value as Dictionary
		var frames: Array = clip.get("frames", []) as Array
		for frame_value in frames:
			var frame: Dictionary = frame_value as Dictionary
			frame["offset"] = [0, 0]
	_write_dict(ANIMSET, anim)

func _sample_indices(src_n: int, want_n: int) -> Array:
	if src_n < want_n:
		return []
	if want_n <= 1:
		return [0]
	if src_n == want_n:
		return range(src_n)
	var out: Array = []
	for i in range(want_n):
		out.append(int(round(float(i) * float(src_n - 1) / float(want_n - 1))))
	return out

func _assert_constant_foot(entries: Array) -> void:
	var min_x: float = INF
	var max_x: float = -INF
	for entry_value in entries:
		var entry: Dictionary = entry_value as Dictionary
		var measured: Dictionary = entry["measured"] as Dictionary
		var foot: Vector2 = measured.get("footAnchor", Vector2.ZERO) as Vector2
		min_x = minf(min_x, foot.x)
		max_x = maxf(max_x, foot.x)
	var spread: float = max_x - min_x
	if spread > 1.0:
		printerr("exact-mode root footAnchor.x spread %.3f texels; expected <= 1.0 from scaled-master transform" % spread)
		quit(1)

func _master_sidecar_for(run_dir: String, action: String, pixel_path: String) -> String:
	var master_name: String = pixel_path.get_file().get_basename().replace("pixel", "master") + ".json"
	var path: String = run_dir.path_join(action).path_join("masters").path_join(master_name)
	if not FileAccess.file_exists(path):
		printerr("missing scaled-master sidecar for %s: %s" % [pixel_path, path])
		quit(1)
	return path

func _exact_scale(sidecar: Dictionary, source_path: String) -> float:
	var raw: Variant = sidecar.get("scale_applied")
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 2:
		printerr("missing exact-mode scale_applied in %s.json" % source_path.get_basename())
		quit(1)
		return 0.0
	var arr: Array = raw as Array
	var sx: float = float(arr[0])
	var sy: float = float(arr[1])
	if sx <= 0.0 or absf(sx - sy) > 0.0001:
		printerr("invalid exact-mode scale_applied in %s.json: %s" % [source_path.get_basename(), str(arr)])
		quit(1)
		return 0.0
	return sx

func _arg() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		return ""
	return args[args.size() - 1]

func _read_dict(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	return {}

func _write_dict(path: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "  "))
	file.close()

func _vector(raw: Variant) -> Vector2:
	if typeof(raw) == TYPE_ARRAY:
		var arr: Array = raw as Array
		if arr.size() >= 2:
			return Vector2(float(arr[0]), float(arr[1]))
	return Vector2.ZERO
