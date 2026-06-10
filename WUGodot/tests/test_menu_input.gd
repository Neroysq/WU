extends RefCounted

const MenuInputScript = preload("res://scripts/ui/menu_input.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var input: Variant = MenuInputScript.new()
	input.down = true
	if MenuInputScript.step_index(0, 2, input) == 1:
		passed += 1
	else:
		failed += 1
		failures.append("down should increment selection")

	input = MenuInputScript.new()
	input.up = true
	if MenuInputScript.step_index(0, 2, input) == 0:
		passed += 1
	else:
		failed += 1
		failures.append("up should clamp at zero")

	input = MenuInputScript.new()
	input.down = true
	if MenuInputScript.step_index(2, 2, input) == 2:
		passed += 1
	else:
		failed += 1
		failures.append("down should clamp at max")

	input = MenuInputScript.new()
	input.accept = true
	input.local_cancel = true
	input.number = 3
	input.mouse_pos = Vector2(12.0, 34.0)
	input.mouse_clicked = true
	if input.accept and input.local_cancel and input.number == 3 and input.mouse_pos == Vector2(12.0, 34.0) and input.mouse_clicked:
		passed += 1
	else:
		failed += 1
		failures.append("snapshot fields should be directly settable for controller tests")

	return {"passed": passed, "failed": failed, "failures": failures}
