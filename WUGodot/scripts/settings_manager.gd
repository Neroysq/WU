class_name SettingsManager
extends RefCounted

const SETTINGS_VERSION: int = 1
const DEFAULT_SETTINGS_PATH: String = "user://settings.json"
const ACTION_ORDER: Array[String] = ["left", "right", "attack", "block", "dash", "jump", "stance"]
const ACTION_LABELS: Dictionary = {
	"left": "Move Left",
	"right": "Move Right",
	"attack": "Attack",
	"block": "Block / Parry",
	"dash": "Dash",
	"jump": "Jump",
	"stance": "Stance",
}
const RESERVED_KEYS: Array[int] = [
	KEY_ESCAPE,
	KEY_F5,
	KEY_R,
	KEY_P,
	KEY_QUOTELEFT,
	KEY_ENTER,
	KEY_KP_ENTER,
]

static var _settings_path: String = DEFAULT_SETTINGS_PATH
static var _keybinds: Dictionary = {}
static var _fullscreen: bool = false
static var _loaded: bool = false
static var _apply_window_mode_enabled: bool = true
static var _last_applied_fullscreen: Variant = null

static func load() -> void:
	var loaded_from_file: bool = false
	var should_rewrite: bool = false
	var data: Dictionary = {}
	if FileAccess.file_exists(_settings_path):
		var parser: JSON = JSON.new()
		var parse_err: int = parser.parse(FileAccess.get_file_as_string(_settings_path))
		if parse_err == OK and typeof(parser.data) == TYPE_DICTIONARY:
			data = parser.data as Dictionary
			loaded_from_file = true
		else:
			should_rewrite = true
	else:
		should_rewrite = true

	if loaded_from_file and int(data.get("version", -1)) == SETTINGS_VERSION:
		_keybinds = _merge_keybinds(data.get("keybinds", {}))
		_fullscreen = bool(data.get("fullscreen", false))
	else:
		_keybinds = _default_keybinds()
		_fullscreen = false
		should_rewrite = true

	_loaded = true
	_apply_fullscreen(_fullscreen)
	if should_rewrite:
		save()

static func keybinds() -> Dictionary:
	_ensure_loaded()
	return _keybinds.duplicate(true)

static func fullscreen() -> bool:
	_ensure_loaded()
	return _fullscreen

static func try_bind(action: String, physical_keycode: int) -> Dictionary:
	_ensure_loaded()
	if not ACTION_ORDER.has(action):
		return {"ok": false, "reason": "Unknown action"}
	if physical_keycode == KEY_NONE or RESERVED_KEYS.has(physical_keycode):
		return {"ok": false, "reason": "Reserved key"}
	for existing_action in ACTION_ORDER:
		if existing_action == action:
			continue
		if int(_keybinds.get(existing_action, KEY_NONE)) == physical_keycode:
			return {
				"ok": false,
				"reason": "Already bound to %s" % action_label(str(existing_action)),
			}
	_keybinds[action] = physical_keycode
	save()
	return {"ok": true, "reason": ""}

static func reset_defaults() -> void:
	_keybinds = _default_keybinds()
	_loaded = true
	save()

static func set_fullscreen(on: bool) -> void:
	_ensure_loaded()
	_fullscreen = on
	_apply_fullscreen(on)
	save()

static func save() -> void:
	_ensure_loaded()
	var data: Dictionary = {
		"version": SETTINGS_VERSION,
		"keybinds": _keybinds.duplicate(true),
		"fullscreen": _fullscreen,
	}
	var file: FileAccess = FileAccess.open(_settings_path, FileAccess.WRITE)
	if file == null:
		push_warning("settings: failed to write %s" % _settings_path)
		return
	file.store_string(JSON.stringify(data, "  ") + "\n")
	file.close()

static func action_label(action: String) -> String:
	return str(ACTION_LABELS.get(action, action.capitalize()))

static func key_label(physical_keycode: int) -> String:
	if physical_keycode == KEY_NONE:
		return "None"
	var label_keycode: int = physical_keycode
	if DisplayServer.get_name().to_lower() != "headless":
		var resolved: int = DisplayServer.keyboard_get_keycode_from_physical(physical_keycode)
		if resolved != KEY_NONE:
			label_keycode = resolved
	var label: String = OS.get_keycode_string(label_keycode)
	if label.is_empty():
		label = OS.get_keycode_string(physical_keycode)
	return label if not label.is_empty() else str(physical_keycode)

static func configure_for_tests(path: String, apply_window_mode: bool = false) -> void:
	_settings_path = path
	_apply_window_mode_enabled = apply_window_mode
	_keybinds = {}
	_fullscreen = false
	_loaded = false
	_last_applied_fullscreen = null

static func reset_test_overrides() -> void:
	_settings_path = DEFAULT_SETTINGS_PATH
	_apply_window_mode_enabled = true
	_keybinds = {}
	_fullscreen = false
	_loaded = false
	_last_applied_fullscreen = null

static func last_applied_fullscreen_for_tests() -> Variant:
	return _last_applied_fullscreen

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_keybinds = _default_keybinds()
	_fullscreen = false
	_loaded = true

static func _default_keybinds() -> Dictionary:
	return Fighter.DEFAULT_CONTROLS.duplicate(true)

static func _merge_keybinds(value: Variant) -> Dictionary:
	var merged: Dictionary = _default_keybinds()
	if typeof(value) != TYPE_DICTIONARY:
		return merged
	var raw: Dictionary = value as Dictionary
	for action in ACTION_ORDER:
		if not raw.has(action):
			continue
		var physical_keycode: int = int(raw[action])
		if physical_keycode == KEY_NONE or RESERVED_KEYS.has(physical_keycode):
			continue
		if _has_duplicate_value(merged, action, physical_keycode):
			continue
		merged[action] = physical_keycode
	return merged

static func _has_duplicate_value(values: Dictionary, action: String, physical_keycode: int) -> bool:
	for existing_action in ACTION_ORDER:
		if existing_action == action:
			continue
		if int(values.get(existing_action, KEY_NONE)) == physical_keycode:
			return true
	return false

static func _apply_fullscreen(on: bool) -> void:
	_last_applied_fullscreen = on
	if not _apply_window_mode_enabled:
		return
	var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
