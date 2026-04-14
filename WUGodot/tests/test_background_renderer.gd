extends RefCounted

const BackgroundRendererScript = preload("res://scripts/visual/background_renderer.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var bg: Variant = BackgroundRendererScript.new()

	if bg.current_arena_id == "":
		passed += 1
	else:
		failed += 1
		failures.append("default arena_id should be empty (got '%s')" % bg.current_arena_id)

	bg.set_arena("chapter1_bamboo_dusk")
	if bg.current_arena_id == "chapter1_bamboo_dusk":
		passed += 1
	else:
		failed += 1
		failures.append("set_arena should store id (got '%s')" % bg.current_arena_id)

	bg.set_arena("chapter1_boss_clearing")
	if bg.current_arena_id == "chapter1_boss_clearing":
		passed += 1
	else:
		failed += 1
		failures.append("set_arena should switch id (got '%s')" % bg.current_arena_id)

	bg.set_arena("nonexistent_arena")
	if bg.current_arena_id == "nonexistent_arena":
		passed += 1
	else:
		failed += 1
		failures.append("set_arena should accept any id (got '%s')" % bg.current_arena_id)

	if bg.has_method("draw"):
		passed += 1
	else:
		failed += 1
		failures.append("BackgroundRenderer should have a draw() method")

	if bg._texture == null:
		passed += 1
	else:
		failed += 1
		failures.append("unknown arena should have null texture (fallback)")

	bg.set_arena("chapter1_bamboo_dusk")
	passed += 1

	return {"passed": passed, "failed": failed, "failures": failures}
