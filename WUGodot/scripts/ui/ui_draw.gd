class_name UiDraw
extends RefCounted

const TextWrappingScript = preload("res://scripts/util/text_wrapping.gd")
const BODY_FONT_PATH: String = "res://assets/fonts/NotoSansSC-Regular.otf"

static var _fallback_body_font: Font = null
static var _school_icon_cache: Dictionary = {}

static func background(canvas: CanvasItem, band: String = "foothill") -> void:
	canvas.draw_rect(Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), GameConstants.COLOR_INK_BLACK, true)
	canvas.draw_rect(Rect2(0.0, float(GameConstants.VIEW_HEIGHT) * 0.58, GameConstants.VIEW_WIDTH, float(GameConstants.VIEW_HEIGHT) * 0.42), Color(GameConstants.COLOR_EARTH_DARK.r, GameConstants.COLOR_EARTH_DARK.g, GameConstants.COLOR_EARTH_DARK.b, 0.32), true)
	canvas.draw_rect(Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), GameConstants.COLOR_SCREEN_VIGNETTE, true)
	depth_wash(canvas, band)

static func depth_wash(canvas: CanvasItem, band: String, rect: Rect2 = Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT)) -> void:
	var tint: Color = GameConstants.BAND_TINTS.get(str(band).to_lower(), GameConstants.BAND_TINTS["foothill"]) as Color
	if tint.a <= 0.0 or canvas == null:
		return
	canvas.draw_rect(rect, tint, true)

static func modal_backdrop(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.44), true)

static func panel(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color(GameConstants.COLOR_PANEL_BG.r, GameConstants.COLOR_PANEL_BG.g, GameConstants.COLOR_PANEL_BG.b, 0.92), true)
	canvas.draw_rect(rect, GameConstants.COLOR_PANEL_BORDER, false, 2.0)
	canvas.draw_rect(Rect2(rect.position.x + 2.0, rect.position.y, rect.size.x - 4.0, 1.0), GameConstants.COLOR_PANEL_ACCENT)
	var cm: float = 6.0
	var cc: Color = GameConstants.COLOR_PANEL_BORDER
	canvas.draw_rect(Rect2(rect.position.x - 1.0, rect.position.y - 1.0, cm, 1.0), cc)
	canvas.draw_rect(Rect2(rect.position.x - 1.0, rect.position.y - 1.0, 1.0, cm), cc)
	canvas.draw_rect(Rect2(rect.end.x - cm + 1.0, rect.position.y - 1.0, cm, 1.0), cc)
	canvas.draw_rect(Rect2(rect.end.x, rect.position.y - 1.0, 1.0, cm), cc)
	canvas.draw_rect(Rect2(rect.position.x - 1.0, rect.end.y, cm, 1.0), cc)
	canvas.draw_rect(Rect2(rect.position.x - 1.0, rect.end.y - cm + 1.0, 1.0, cm), cc)
	canvas.draw_rect(Rect2(rect.end.x - cm + 1.0, rect.end.y, cm, 1.0), cc)
	canvas.draw_rect(Rect2(rect.end.x, rect.end.y - cm + 1.0, 1.0, cm), cc)

static func reward_option(canvas: CanvasItem, rect: Rect2, label: String, description: String, selected: bool, cursor_flash: float, accent: Color = GameConstants.COLOR_PANEL_ACCENT, rarity: int = 0) -> void:
	if selected:
		rect.position.y -= 10.0
	var has_rarity: bool = rarity > 0
	var option_accent: Color = rarity_color(rarity) if has_rarity else accent
	var border: Color = option_accent if selected or has_rarity else Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.3)
	if selected:
		canvas.draw_rect(rect.grow(8.0), Color(option_accent.r, option_accent.g, option_accent.b, 0.10), true)
	canvas.draw_rect(rect, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.88), true)
	canvas.draw_rect(rect, border, false, 2.0 if selected or has_rarity else 1.0)
	if has_rarity:
		var chip: Rect2 = Rect2(rect.end.x - 94.0, rect.position.y + 14.0, 76.0, 24.0)
		canvas.draw_rect(chip, Color(option_accent.r, option_accent.g, option_accent.b, 0.20), true)
		canvas.draw_rect(chip, Color(option_accent.r, option_accent.g, option_accent.b, 0.84), false, 1.0)
		text(canvas, rarity_label(rarity), chip.position.x + 9.0, chip.position.y + 17.0, GameConstants.COLOR_TEXT_HEADING, 12)
	text(canvas, label, rect.position.x + 18.0, rect.position.y + 36.0, GameConstants.COLOR_TEXT_HEADING, 20)
	if description != "":
		text_block(canvas, description, rect.position.x + 18.0, rect.position.y + 66.0, rect.size.x - 36.0, 18.0, GameConstants.COLOR_TEXT_BODY, 14)
	if selected:
		menu_cursor(canvas, Vector2(rect.position.x - 16.0, rect.position.y + 36.0), cursor_flash)

static func rarity_color(rarity: int) -> Color:
	match rarity:
		2:
			return GameConstants.COLOR_SKY_BLUE
		3:
			return GameConstants.COLOR_PURPLE_LIGHT
		_:
			return GameConstants.COLOR_LIGHT_BLUE

static func rarity_label(rarity: int) -> String:
	match rarity:
		2:
			return "Rare"
		3:
			return "Epic"
		_:
			return "Common"

static func school_mark(canvas: CanvasItem, school_data: Dictionary, pos: Vector2, size: float, tint: Color = GameConstants.COLOR_TEXT_HEADING) -> bool:
	var icon_path: String = str(school_data.get("icon", ""))
	if not icon_path.is_empty():
		var texture: Texture2D = _school_icon(icon_path)
		if texture != null:
			if canvas != null:
				canvas.draw_texture_rect(texture, Rect2(pos, Vector2(size, size)), false, tint)
			return true
	var hanzi: String = str(school_data.get("hanzi", ""))
	if hanzi.is_empty():
		hanzi = str(school_data.get("id", "?")).substr(0, 1).to_upper()
	if canvas != null:
		var font_size: int = maxi(10, int(round(size * 0.72)))
		var width: float = float(measure_text(hanzi, font_size, true))
		text(canvas, hanzi, pos.x + (size - width) * 0.5, pos.y + size * 0.76, tint, font_size, true)
	return false

static func menu_cursor(canvas: CanvasItem, position: Vector2, cursor_flash: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(cursor_flash * 8.0)
	var cursor_color: Color = Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, 0.55 + 0.35 * pulse)
	canvas.draw_circle(position, 2.5 + pulse, cursor_color)
	canvas.draw_line(position + Vector2(-10.0, -4.0), position + Vector2(-2.0, 0.0), cursor_color, 2.0)
	canvas.draw_line(position + Vector2(-10.0, 4.0), position + Vector2(-2.0, 0.0), cursor_color, 2.0)

static func text(canvas: CanvasItem, value: String, x: float, y: float, color: Color, size: int = 16, display: bool = false) -> void:
	var font: Font = font_for_size(size, display)
	if font != null:
		canvas.draw_string(font, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

static func centered_text(canvas: CanvasItem, value: String, center_x: float, y: float, color: Color, size: int = 16, display: bool = false) -> void:
	var width: float = measure_text(value, size, display)
	text(canvas, value, center_x - width * 0.5, y, color, size, display)

static func text_lines(canvas: CanvasItem, lines: Array, x: float, y: float, line_height: float, color: Color, size: int = 16, display: bool = false) -> float:
	var cursor_y: float = y
	for line in lines:
		text(canvas, str(line), x, cursor_y, color, size, display)
		cursor_y += line_height
	return cursor_y

static func text_block(canvas: CanvasItem, value: String, x: float, y: float, max_width: float, line_height: float, color: Color, size: int = 16, display: bool = false) -> float:
	return text_lines(canvas, wrap_text(value, max_width, size, display), x, y, line_height, color, size, display)

static func font_for_size(size: int, display: bool = false) -> Font:
	var fonts: Variant = _fonts_autoload()
	if display or size >= 32:
		var display_font: Font = fonts.display_font() if fonts != null else _body_font()
		if display_font != null:
			return display_font
	var body_font: Font = fonts.body_font() if fonts != null else _body_font()
	if body_font != null:
		return body_font
	return ThemeDB.fallback_font

static func _fonts_autoload() -> Variant:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Fonts")
	return null

static func _body_font() -> Font:
	if _fallback_body_font == null and ResourceLoader.exists(BODY_FONT_PATH):
		_fallback_body_font = load(BODY_FONT_PATH) as Font
	return _fallback_body_font

static func measure_text(value: String, size: int = 16, display: bool = false) -> int:
	var font: Font = font_for_size(size, display)
	if font == null:
		return value.length() * size / 2
	return int(round(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x))

static func wrap_text(value: String, max_width: float, size: int = 16, display: bool = false) -> Array[String]:
	return TextWrappingScript.wrap_lines(font_for_size(size, display), value, max_width, size)

static func _school_icon(path: String) -> Texture2D:
	if _school_icon_cache.has(path):
		return _school_icon_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path) as Texture2D
	if texture != null:
		_school_icon_cache[path] = texture
	return texture
