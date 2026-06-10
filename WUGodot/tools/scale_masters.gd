extends SceneTree

const MasterNormalizerScript = preload("res://scripts/visual/master_normalizer.gd")
const MasterGeometryScript = preload("res://scripts/visual/master_geometry.gd")

# 177 texels x R=2 = 354 px on-screen: height parity with the
# enemy roster after fit-mode exact made T literal.
const TARGET_TEXELS: int = 177
const DENSITY: int = 4
const PAD: int = 48

# Manual drift overrides, keyed per source frame: "<action>/<master_basename>".
# Example: "attack/master_003": 1.12
const SCALE_NORM: Dictionary = {}

func _init() -> void:
	var run_dir: String = _arg()
	if run_dir.is_empty():
		printerr("usage: --scale-masters <abs_run_dir>")
		quit(1)
		return

	_ensure_fresh(run_dir)

	var frames: Array = _collect(run_dir)
	if frames.is_empty():
		printerr("no master frames found in %s" % run_dir)
		quit(1)
		return

	var ref_px: float = _resolved_idle_reference(frames)
	if ref_px <= 0.0:
		printerr("no resolvable idle master in %s" % run_dir)
		quit(1)
		return

	var base: float = MasterNormalizerScript.base_scale(ref_px, TARGET_TEXELS, DENSITY)

	var max_left: float = 0.0
	var max_right: float = 0.0
	var max_up: float = 0.0
	var max_down: float = 0.0
	for frame in frames:
		var frame_dict: Dictionary = frame as Dictionary
		var scale: float = base * float(SCALE_NORM.get(_norm_key(frame_dict), 1.0))
		var bbox: Rect2 = frame_dict["bbox"] as Rect2
		var foot: Vector2 = frame_dict["foot"] as Vector2
		max_left = maxf(max_left, (foot.x - bbox.position.x) * scale)
		max_right = maxf(max_right, (bbox.position.x + bbox.size.x - foot.x) * scale)
		max_up = maxf(max_up, (foot.y - bbox.position.y) * scale)
		max_down = maxf(max_down, (bbox.position.y + bbox.size.y - foot.y) * scale)

	var half_width: float = maxf(max_left, max_right)
	var canvas_w: int = _round_up(int(ceil(half_width * 2.0)) + PAD * 2, DENSITY)
	var canvas_h: int = _round_up(int(ceil(max_up + max_down)) + PAD * 2, DENSITY)
	var foot_canvas: Vector2 = Vector2(float(canvas_w) * 0.5, float(PAD) + max_up)

	for frame in frames:
		var frame_dict: Dictionary = frame as Dictionary
		var norm: float = float(SCALE_NORM.get(_norm_key(frame_dict), 1.0))
		var p: Dictionary = MasterNormalizerScript.plan(
			base,
			frame_dict["native"] as Vector2,
			frame_dict["bbox"] as Rect2,
			frame_dict["foot"] as Vector2,
			norm
		)
		var img: Image = (frame_dict["img"] as Image).duplicate()
		var scaled_size: Vector2 = p["scaled_size"] as Vector2
		var source_bbox: Rect2 = frame_dict["bbox"] as Rect2
		var source_aspect: float = source_bbox.size.x / maxf(source_bbox.size.y, 1.0)
		img.resize(maxi(1, int(round(scaled_size.x))), maxi(1, int(round(scaled_size.y))), Image.INTERPOLATE_LANCZOS)
		var canvas: Image = Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0, 0, 0, 0))
		var scaled_foot: Vector2 = p["scaled_foot"] as Vector2
		var dst: Vector2i = Vector2i(int(round(foot_canvas.x - scaled_foot.x)), int(round(foot_canvas.y - scaled_foot.y)))
		canvas.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), dst)
		var measured: Rect2 = _alpha_bbox(canvas)
		var measured_aspect: float = measured.size.x / maxf(measured.size.y, 1.0)
		if measured.size.x <= 0.0 or measured.size.y <= 0.0 or absf(measured_aspect / maxf(source_aspect, 0.0001) - 1.0) > 0.02:
			printerr("UNIFORMITY VIOLATION %s: content aspect %.3f -> %.3f" % [str(frame_dict["png"]), source_aspect, measured_aspect])
			quit(1)
			return
		var save_err: Error = canvas.save_png(str(frame_dict["png"]))
		if save_err != OK:
			printerr("failed to save %s (%s)" % [str(frame_dict["png"]), error_string(save_err)])
			quit(1)
			return

		var meta: Dictionary = _read_dict(str(frame_dict["side"]))
		meta["native_size"] = [canvas_w, canvas_h]
		meta["foot_anchor"] = [foot_canvas.x, foot_canvas.y]
		var scaled_bbox: Rect2 = p["scaled_bbox"] as Rect2
		meta["bbox"] = [
			scaled_bbox.position.x + float(dst.x),
			scaled_bbox.position.y + float(dst.y),
			scaled_bbox.size.x,
			scaled_bbox.size.y,
		]
		_write_dict(str(frame_dict["side"]), meta)
		print("%s/%s scale=%.3f norm=%.2f" % [str(frame_dict["action"]), String(str(frame_dict["png"])).get_file(), float(p["scale"]), norm])

	print("common canvas %dx%d  out-size for pixelize: %d:%d" % [canvas_w, canvas_h, canvas_w / DENSITY, canvas_h / DENSITY])
	quit()

func _resolved_idle_reference(frames: Array) -> float:
	for frame in frames:
		var frame_dict: Dictionary = frame as Dictionary
		if str(frame_dict["action"]) == "idle":
			var bbox: Rect2 = frame_dict["bbox"] as Rect2
			return bbox.size.y
	return 0.0

func _collect(run_dir: String) -> Array:
	var out: Array = []
	var root: DirAccess = DirAccess.open(run_dir)
	if root == null:
		return out
	var actions: PackedStringArray = root.get_directories()
	actions.sort()
	for action in actions:
		var masters: String = run_dir.path_join(action).path_join("masters")
		var dir: DirAccess = DirAccess.open(masters)
		if dir == null:
			continue
		var files: PackedStringArray = dir.get_files()
		files.sort()
		for file_name in files:
			if not file_name.ends_with(".png"):
				continue
			var png: String = masters.path_join(file_name)
			var sidecar: String = png.get_basename() + ".json"
			if not FileAccess.file_exists(sidecar):
				printerr("missing sidecar for %s" % png)
				quit(1)
				return []
			var meta: Dictionary = _read_dict(sidecar)
			var img: Image = Image.new()
			var load_err: Error = img.load(png)
			if load_err != OK:
				printerr("failed to load %s (%s)" % [png, error_string(load_err)])
				quit(1)
				return []
			var geo: Dictionary = MasterGeometryScript.resolve(img, meta)
			if bool(geo["remeasured"]):
				print("NOTE %s/%s: sidecar geometry untrusted (native/bbox/foot mismatch) -> pixel-remeasured" % [action, file_name])
			out.append({
				"png": png,
				"side": sidecar,
				"action": action,
				"img": img,
				"native": geo["native"] as Vector2,
				"bbox": geo["bbox"] as Rect2,
				"foot": geo["foot"] as Vector2,
			})
	return out

func _alpha_bbox(img: Image) -> Rect2:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var left: int = w
	var right: int = -1
	var top: int = h
	var bottom: int = -1
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			if img.get_pixel(x, y).a > 0.1:
				left = mini(left, x)
				right = maxi(right, x)
				top = mini(top, y)
				bottom = maxi(bottom, y)
	if right < 0:
		return Rect2()
	return Rect2(float(left), float(top), float(right - left + 1), float(bottom - top + 1))

func _ensure_fresh(run_dir: String) -> void:
	var root: DirAccess = DirAccess.open(run_dir)
	if root == null:
		printerr("run dir not found: %s" % run_dir)
		quit(1)
		return
	var actions: PackedStringArray = root.get_directories()
	actions.sort()
	for action in actions:
		var masters: String = run_dir.path_join(action).path_join("masters")
		if DirAccess.open(masters) == null:
			continue
		var pristine: String = run_dir.path_join(action).path_join("masters_pristine")
		if DirAccess.open(pristine) != null:
			_copy_dir(pristine, masters)
		else:
			_copy_dir(masters, pristine)

func _copy_dir(src: String, dst: String) -> void:
	var src_dir: DirAccess = DirAccess.open(src)
	if src_dir == null:
		printerr("missing source dir: %s" % src)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(dst)
	var dst_dir: DirAccess = DirAccess.open(dst)
	if dst_dir != null:
		for existing in dst_dir.get_files():
			DirAccess.remove_absolute(dst.path_join(existing))
	var files: PackedStringArray = src_dir.get_files()
	files.sort()
	for file_name in files:
		var err: Error = DirAccess.copy_absolute(src.path_join(file_name), dst.path_join(file_name))
		if err != OK:
			printerr("failed to copy %s -> %s (%s)" % [src.path_join(file_name), dst.path_join(file_name), error_string(err)])
			quit(1)
			return

func _norm_key(frame: Dictionary) -> String:
	return "%s/%s" % [str(frame["action"]), String(str(frame["png"])).get_file().get_basename()]

func _round_up(value: int, multiple: int) -> int:
	return int(ceil(float(value) / float(multiple))) * multiple

func _arg() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		return ""
	return args[args.size() - 1]

func _vector(raw: Variant) -> Vector2:
	if typeof(raw) == TYPE_ARRAY:
		var arr: Array = raw as Array
		if arr.size() >= 2:
			return Vector2(float(arr[0]), float(arr[1]))
	return Vector2.ZERO

func _rect(raw: Variant) -> Rect2:
	if typeof(raw) == TYPE_ARRAY:
		var arr: Array = raw as Array
		if arr.size() >= 4:
			return Rect2(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
	return Rect2()

func _read_dict(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	return {}

func _write_dict(path: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "  "))
	file.close()
