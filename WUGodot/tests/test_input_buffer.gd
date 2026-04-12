extends RefCounted

const InputBufferScript = preload("res://scripts/input_buffer.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var buf: Variant = InputBufferScript.new()
	if buf.pending_actions().is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("new buffer should start empty")

	buf.record("light")
	if buf.has("light") and buf.pending_actions() == ["light"]:
		passed += 1
	else:
		failed += 1
		failures.append("record(light) did not populate buffer")

	buf.advance(0.05)
	if buf.has("light"):
		passed += 1
	else:
		failed += 1
		failures.append("buffer entry expired too early")

	if buf.consume("light") and not buf.has("light"):
		passed += 1
	else:
		failed += 1
		failures.append("consume(light) failed")

	var short_buf: Variant = InputBufferScript.new(0.05)
	short_buf.record("dash")
	short_buf.advance(0.06)
	if not short_buf.has("dash"):
		passed += 1
	else:
		failed += 1
		failures.append("expired entry should be removed")

	buf.record("jump")
	buf.advance(0.10)
	buf.record("jump")
	buf.advance(0.10)
	if buf.has("jump"):
		passed += 1
	else:
		failed += 1
		failures.append("recording same action should refresh its age")

	return {"passed": passed, "failed": failed, "failures": failures}
