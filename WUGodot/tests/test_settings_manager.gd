extends RefCounted

const SettingsManagerScript = preload("res://scripts/settings_manager.gd")
const TEST_PATH: String = "user://settings_test.json"

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	_remove_test_file()
	SettingsManagerScript.configure_for_tests(TEST_PATH, false)
	SettingsManagerScript.load()
	var defaults: Dictionary = SettingsManagerScript.keybinds()
	if int(defaults.get("left", KEY_NONE)) == KEY_A and int(defaults.get("attack", KEY_NONE)) == KEY_J:
		passed += 1
	else:
		failed += 1
		failures.append("missing settings file should load default keybinds")

	var bind_result: Dictionary = SettingsManagerScript.try_bind("attack", KEY_U)
	if bool(bind_result.get("ok", false)) and int(SettingsManagerScript.keybinds().get("attack", KEY_NONE)) == KEY_U:
		passed += 1
	else:
		failed += 1
		failures.append("try_bind should store a free physical key")

	var duplicate_result: Dictionary = SettingsManagerScript.try_bind("attack", KEY_A)
	if not bool(duplicate_result.get("ok", true)) and str(duplicate_result.get("reason", "")).find("Already bound") >= 0:
		passed += 1
	else:
		failed += 1
		failures.append("try_bind should reject duplicate combat keys")

	var reserved_result: Dictionary = SettingsManagerScript.try_bind("attack", KEY_F5)
	if not bool(reserved_result.get("ok", true)) and str(reserved_result.get("reason", "")) == "Reserved key":
		passed += 1
	else:
		failed += 1
		failures.append("try_bind should reject F5 as globally reserved")

	var returned: Dictionary = SettingsManagerScript.keybinds()
	returned["left"] = KEY_U
	if int(SettingsManagerScript.keybinds().get("left", KEY_NONE)) == KEY_A:
		passed += 1
	else:
		failed += 1
		failures.append("keybinds() should return a copy, not manager state")

	SettingsManagerScript.reset_defaults()
	var controls: Dictionary = Fighter.player_controls()
	controls["left"] = KEY_U
	var fresh_controls: Dictionary = Fighter.player_controls()
	if int(fresh_controls.get("left", KEY_NONE)) == KEY_A and int(Fighter.DEFAULT_CONTROLS.get("left", KEY_NONE)) == KEY_A:
		passed += 1
	else:
		failed += 1
		failures.append("player_controls() should return independent copies")

	SettingsManagerScript.try_bind("attack", KEY_U)
	SettingsManagerScript.set_fullscreen(true)
	SettingsManagerScript.configure_for_tests(TEST_PATH, false)
	SettingsManagerScript.load()
	if int(SettingsManagerScript.keybinds().get("attack", KEY_NONE)) == KEY_U and SettingsManagerScript.fullscreen() and SettingsManagerScript.last_applied_fullscreen_for_tests() == true:
		passed += 1
	else:
		failed += 1
		failures.append("load() should round-trip settings and apply stored fullscreen")

	_write_text(TEST_PATH, "{not json")
	SettingsManagerScript.configure_for_tests(TEST_PATH, false)
	SettingsManagerScript.load()
	if int(SettingsManagerScript.keybinds().get("attack", KEY_NONE)) == KEY_J and not SettingsManagerScript.fullscreen():
		passed += 1
	else:
		failed += 1
		failures.append("corrupt settings should fall back to defaults")

	_remove_test_file()
	SettingsManagerScript.reset_test_overrides()
	return {"passed": passed, "failed": failed, "failures": failures}

func _write_text(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(content)
	file.close()

func _remove_test_file() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)
