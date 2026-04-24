extends Node

const BODY_FONT_PATH := "res://assets/fonts/NotoSansSC-Regular.otf"

var _body_font: Font = null
var _warned_missing_font: bool = false
var _warned_fallback_font: bool = false

func _ready() -> void:
	_body_font = _load_font(BODY_FONT_PATH)

func body_font() -> Font:
	if _body_font == null:
		_body_font = _load_font(BODY_FONT_PATH)
	if _body_font != null:
		return _body_font
	if not _warned_fallback_font:
		push_warning("Fonts.body_font() fell back to ThemeDB.fallback_font; CJK glyph coverage may be incomplete.")
		_warned_fallback_font = true
	return ThemeDB.fallback_font

func display_font() -> Font:
	return body_font()

func _load_font(path: String) -> Font:
	if path.is_empty() or not ResourceLoader.exists(path):
		if not _warned_missing_font:
			push_warning("Missing font resource: %s" % path)
			_warned_missing_font = true
		return null
	return load(path) as Font
