extends RefCounted
class_name TextWrapping

static func wrap_lines(font: Font, text: String, max_width: float, size: int) -> Array[String]:
	if text.is_empty():
		return [""]
	if font == null:
		return [text]

	var lines: Array[String] = []
	# Preserve blank paragraphs so event/result copy can intentionally carry visual breaks.
	for paragraph in text.split("\n", true):
		if paragraph.is_empty():
			lines.append("")
			continue

		var words := paragraph.split(" ", false)
		if words.is_empty():
			lines.append(paragraph)
			continue

		var current: String = words[0]
		for i in range(1, words.size()):
			var candidate: String = "%s %s" % [current, words[i]]
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x <= max_width:
				current = candidate
			else:
				lines.append(current)
				current = words[i]
		lines.append(current)

	return lines
