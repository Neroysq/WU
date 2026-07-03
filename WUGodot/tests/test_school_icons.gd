extends RefCounted

const UiDrawScript = preload("res://scripts/ui/ui_draw.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.reload_data()

	for school_id in ["iron", "thunder", "soft", "wind", "venom", "sword"]:
		var school: Dictionary = DataManager.get_school(school_id)
		var icon_path: String = str(school.get("icon", ""))
		if not icon_path.is_empty():
			passed += 1
		else:
			failed += 1
			failures.append("%s should have a non-empty icon path" % school_id)

		if not icon_path.is_empty() and (ResourceLoader.exists(icon_path) or FileAccess.file_exists(icon_path)):
			passed += 1
		else:
			failed += 1
			failures.append("%s icon file should exist at %s" % [school_id, icon_path])

	var fallback_used_icon: bool = UiDrawScript.school_mark(null, {"id": "panda", "hanzi": "貓"}, Vector2.ZERO, 24.0)
	if not fallback_used_icon:
		passed += 1
	else:
		failed += 1
		failures.append("school_mark should fall back to hanzi when icon is missing")

	return {"passed": passed, "failed": failed, "failures": failures}
