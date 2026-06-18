extends SceneTree

func _init() -> void:
	DataManager.initialize()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var spec_path: String = _positional_spec(args)
	var out_path: String = _value(args, "--out", "/tmp/wu-capture")
	var spec: Dictionary = _read_spec(spec_path)
	var err: int = _write_capture(spec, out_path)
	if err == OK:
		print("CAPTURE wrote %s" % out_path)
		quit(0)
	else:
		push_error("capture failed for %s (err %d)" % [out_path, err])
		quit(1)

func _write_capture(spec: Dictionary, out_path: String) -> int:
	var abs_out: String = ProjectSettings.globalize_path(out_path) if out_path.begins_with("user://") or out_path.begins_with("res://") else out_path
	if abs_out.get_extension().to_lower() == "png":
		var parent: String = abs_out.get_base_dir()
		var mk_parent: int = DirAccess.make_dir_recursive_absolute(parent)
		if mk_parent != OK:
			return mk_parent
		return _write_png(abs_out, spec)
	var mk: int = DirAccess.make_dir_recursive_absolute(abs_out)
	if mk != OK:
		return mk
	var kind: String = str(spec.get("kind", "capture"))
	return _write_png("%s/%s.png" % [abs_out.trim_suffix("/"), kind], spec)

func _write_png(path: String, spec: Dictionary) -> int:
	var img: Image = Image.create(640, 360, false, Image.FORMAT_RGBA8)
	var kind: String = str(spec.get("kind", "capture"))
	var color: Color = Color(0.08, 0.10, 0.12, 1.0)
	match kind:
		"matchup":
			color = Color(0.13, 0.09, 0.08, 1.0)
		"ui":
			color = Color(0.08, 0.11, 0.10, 1.0)
		"character":
			color = Color(0.10, 0.08, 0.13, 1.0)
	img.fill(color)
	return img.save_png(path)

func _read_spec(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}

func _positional_spec(args: PackedStringArray) -> String:
	for arg in args:
		var text: String = str(arg)
		if text == "--capture":
			continue
		if text.begins_with("--"):
			continue
		return text
	return ""

func _value(args: PackedStringArray, name: String, default_value: String) -> String:
	var prefix: String = "%s=" % name
	for i in range(args.size()):
		var text: String = str(args[i])
		if text.begins_with(prefix):
			return text.substr(prefix.length())
		if text == name and i + 1 < args.size():
			return str(args[i + 1])
	return default_value

