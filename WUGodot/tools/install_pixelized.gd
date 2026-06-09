extends SceneTree

const SLOTS: Dictionary = {
	"idle": ["idle_0", "idle_1"],
	"walk-cycle": ["walk_0", "walk_1", "walk_2", "walk_3"],
	"attack": ["attack_0", "attack_1", "attack_2", "attack_3"],
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

	var side_by_slot: Dictionary = {}
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
			var copy_err: Error = DirAccess.copy_absolute(src, ProjectSettings.globalize_path(DEST + dest_name + ".png"))
			if copy_err != OK:
				printerr("failed to copy %s -> %s (%s)" % [src, DEST + dest_name + ".png", error_string(copy_err)])
				quit(1)
				return
			var sidecar: String = src.get_basename() + ".json"
			side_by_slot[dest_name] = _read_dict(sidecar)
			print("slot %s <- %s/%s" % [dest_name, str(action), pngs[int(idxs[i])].get_basename().replace("pixel", "master")])

	var poses: Dictionary = {}
	for pose_name in POSE_SLOT.keys():
		var slot: String = str(POSE_SLOT[pose_name])
		var meta: Dictionary = side_by_slot.get(slot, {}) as Dictionary
		var foot: Array = meta.get("foot_anchor", [0, 0]) as Array
		var bbox: Array = meta.get("bbox", [0, 0, 0, 0]) as Array
		poses[pose_name] = {
			"path": DEST + slot + ".png",
			"footAnchor": [int(round(float(foot[0]))), int(round(float(foot[1])))],
			"chestAnchor": [int(round(float(foot[0]))), int(round(float(foot[1])) - 95)],
			"weaponTip": [int(round(float(bbox[0]) + float(bbox[2]))), int(round(float(foot[1])) - 80)],
			"hurtbox": [int(round(float(bbox[0]))), int(round(float(bbox[1]))), int(round(float(bbox[2]))), int(round(float(bbox[3])))],
		}

	_apply_capsule_overrides(poses)
	_write_dict(MANIFEST, {"id": "hu", "renderScale": RENDER_SCALE, "weaponClass": "sword", "poses": poses})
	_zero_animset_offsets()

	var idle_meta: Dictionary = side_by_slot.get("idle_0", {}) as Dictionary
	var foot_arr: Array = idle_meta.get("foot_anchor", [0, 0]) as Array
	var idle_img: Image = Image.new()
	var load_err: Error = idle_img.load(ProjectSettings.globalize_path(DEST + "idle_0.png"))
	if load_err != OK:
		printerr("failed to load installed idle_0.png (%s)" % error_string(load_err))
		quit(1)
		return
	var y_offset: float = (float(idle_img.get_height()) - float(foot_arr[1])) * RENDER_SCALE
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
