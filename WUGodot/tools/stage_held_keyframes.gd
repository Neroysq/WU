extends SceneTree

const AnchorMeasureScript = preload("res://scripts/visual/anchor_measure.gd")

const CHROMA_GREEN: Color = Color(0.0, 1.0, 0.0, 1.0)
const BG_GREEN_MIN: float = 0.45
const BG_RED_MAX: float = 0.38
const BG_BLUE_MAX: float = 0.38

const IDLE_SOURCE: String = "../art/keyframes/hu/guard/stance.png"
const HELD_SOURCES: Array[Dictionary] = [
	{"label": "hit", "path": "../art/keyframes/hu/hit/hit.png"},
	{"label": "stun_a", "path": "../art/keyframes/hu/stunned/stun_a.png"},
	{"label": "stun_b", "path": "../art/keyframes/hu/stunned/stun_b.png"},
	{"label": "block", "path": "../art/keyframes/hu/block/block.png"},
	{"label": "dash", "path": "../art/keyframes/hu/dash/dash.png"},
	{"label": "rise", "path": "../art/keyframes/hu/jump/rise.png"},
	{"label": "peak", "path": "../art/keyframes/hu/jump/peak.png"},
	{"label": "fall", "path": "../art/keyframes/hu/jump/fall.png"},
	{"label": "land", "path": "../art/keyframes/hu/jump/land.png"},
]

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: --stage-held-keyframes <abs_run_dir>")
		quit(1)
		return

	var run_dir: String = args[0].trim_suffix("/")
	if not (run_dir.begins_with("/tmp/") or run_dir.begins_with("/private/tmp/")):
		printerr("stage-held-keyframes only writes scratch dirs under /tmp: %s" % run_dir)
		quit(1)
		return
	if DirAccess.dir_exists_absolute(run_dir):
		_remove_dir_recursive(run_dir)
	DirAccess.make_dir_recursive_absolute(run_dir)
	_clear_action(run_dir, "idle")
	_clear_action(run_dir, "held")

	_stage_one(_repo_path(IDLE_SOURCE), run_dir.path_join("idle").path_join("masters"), 1, "idle")
	for i in range(HELD_SOURCES.size()):
		var src: Dictionary = HELD_SOURCES[i]
		_stage_one(_repo_path(str(src["path"])), run_dir.path_join("held").path_join("masters"), i + 1, str(src["label"]))

	print("held labels: hit,stun_a,stun_b,block,dash,rise,peak,fall,land")
	quit(0)

func _repo_path(relative_from_wugodot: String) -> String:
	return ProjectSettings.globalize_path("res://" + relative_from_wugodot)

func _clear_action(run_dir: String, action: String) -> void:
	var action_dir: String = run_dir.path_join(action)
	if DirAccess.dir_exists_absolute(action_dir):
		_remove_dir_recursive(action_dir)
	DirAccess.make_dir_recursive_absolute(action_dir.path_join("masters"))

func _stage_one(source_path: String, masters_dir: String, index: int, label: String) -> void:
	var img := Image.new()
	var err: Error = img.load(source_path)
	if err != OK:
		printerr("failed to load keyframe %s (%s)" % [source_path, error_string(err)])
		quit(1)
		return
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	_chroma_to_alpha(img)

	var measured: Dictionary = AnchorMeasureScript.measure(img)
	var bbox: Rect2 = _alpha_bbox(img)
	var foot: Vector2 = measured.get("footAnchor", Vector2(float(img.get_width()) * 0.5, float(img.get_height() - 1))) as Vector2
	if bbox.size.x <= 1.0 or bbox.size.y <= 1.0:
		printerr("empty measured bbox for %s" % source_path)
		quit(1)
		return

	var stem: String = "master_%03d" % index
	var png_path: String = masters_dir.path_join(stem + ".png")
	var json_path: String = masters_dir.path_join(stem + ".json")
	var save_err: Error = img.save_png(png_path)
	if save_err != OK:
		printerr("failed to save %s (%s)" % [png_path, error_string(save_err)])
		quit(1)
		return

	var meta: Dictionary = {
		"label": label,
		"native_size": [img.get_width(), img.get_height()],
		"bbox": [bbox.position.x, bbox.position.y, bbox.size.x, bbox.size.y],
		"foot_anchor": [foot.x, foot.y],
		"space": "image",
		"source": source_path,
	}
	var f: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if f == null:
		printerr("failed to write %s" % json_path)
		quit(1)
		return
	f.store_string(JSON.stringify(meta, "  "))
	f.close()
	print("%s -> %s bbox=%s foot=%s" % [label, png_path, str(bbox), str(foot)])

func _chroma_to_alpha(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var background := PackedByteArray()
	background.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in range(w):
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in range(h):
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))

	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.x >= w or p.y < 0 or p.y >= h:
			continue
		var idx: int = p.y * w + p.x
		if background[idx] == 1:
			continue
		var c: Color = img.get_pixel(p.x, p.y)
		if not _is_background_green(c):
			continue
		background[idx] = 1
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))

	for y in range(h):
		for x in range(w):
			if background[y * w + x] == 1:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

func _is_background_green(c: Color) -> bool:
	var dr: float = c.r - CHROMA_GREEN.r
	var dg: float = c.g - CHROMA_GREEN.g
	var db: float = c.b - CHROMA_GREEN.b
	var dist: float = sqrt(dr * dr + dg * dg + db * db)
	return c.g >= BG_GREEN_MIN and c.r <= BG_RED_MAX and c.b <= BG_BLUE_MAX and dist < 0.85

func _alpha_bbox(img: Image) -> Rect2:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var left: int = w
	var right: int = -1
	var top: int = h
	var bottom: int = -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.05:
				left = mini(left, x)
				right = maxi(right, x)
				top = mini(top, y)
				bottom = maxi(bottom, y)
	if right < 0:
		return Rect2()
	return Rect2(float(left), float(top), float(right - left + 1), float(bottom - top + 1))

func _remove_dir_recursive(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for child_dir in dir.get_directories():
		_remove_dir_recursive(path.path_join(child_dir))
	for file_name in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
