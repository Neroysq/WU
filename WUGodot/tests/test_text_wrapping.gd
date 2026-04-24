extends RefCounted

const BODY_FONT_PATH := "res://assets/fonts/NotoSansSC-Regular.otf"
const TextWrappingScript = preload("res://scripts/util/text_wrapping.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var font: Font = load(BODY_FONT_PATH) as Font
	if font == null:
		return {
			"passed": passed,
			"failed": failed + 1,
			"failures": ["could not load %s" % BODY_FONT_PATH]
		}

	var empty_lines: Array[String] = TextWrappingScript.wrap_lines(font, "", 240.0, 16)
	if empty_lines.size() == 1 and empty_lines[0] == "":
		passed += 1
	else:
		failed += 1
		failures.append("empty input should return [''] (got %s)" % str(empty_lines))

	var single_line: Array[String] = TextWrappingScript.wrap_lines(font, "a b c", 400.0, 16)
	if single_line.size() == 1 and single_line[0] == "a b c":
		passed += 1
	else:
		failed += 1
		failures.append("wide width should keep 'a b c' on one line (got %s)" % str(single_line))

	var wrapped: Array[String] = TextWrappingScript.wrap_lines(font, "a bb ccc dddd eeeee ffffff", 70.0, 16)
	if wrapped.size() >= 2:
		passed += 1
	else:
		failed += 1
		failures.append("narrow width should force multiple lines (got %s)" % str(wrapped))

	var paragraphs: Array[String] = TextWrappingScript.wrap_lines(font, "alpha beta\n\ngamma delta", 400.0, 16)
	if paragraphs.size() == 3 and paragraphs[0] == "alpha beta" and paragraphs[1] == "" and paragraphs[2] == "gamma delta":
		passed += 1
	else:
		failed += 1
		failures.append("newline-delimited paragraphs should preserve blank lines (got %s)" % str(paragraphs))

	var no_throw: Array[String] = TextWrappingScript.wrap_lines(font, "reward card body copy should not crash", 96.0, 16)
	if no_throw.size() >= 2 and not no_throw[0].is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("PackedStringArray regression should return multiple non-empty wrapped lines (got %s)" % str(no_throw))

	return {"passed": passed, "failed": failed, "failures": failures}
