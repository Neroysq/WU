class_name MenuScene
extends RefCounted

const SceneContext = preload("res://scripts/scene_context.gd")
const MenuInput = preload("res://scripts/ui/menu_input.gd")
const UiDraw = preload("res://scripts/ui/ui_draw.gd")

var selection_idx: int = 0

func enter(_ctx: Variant, _payload: Dictionary = {}) -> void:
	selection_idx = 0

func update(ctx: Variant, input: Variant, _delta: float) -> void:
	selection_idx = MenuInput.step_index(selection_idx, 1, input)
	var hovered_idx: int = _hovered_option(input.mouse_pos)
	if hovered_idx >= 0:
		selection_idx = hovered_idx
	if input.accept or input.mouse_clicked:
		MenuInput.play_ui_confirm()
		if selection_idx == 1:
			ctx.goto(SceneContext.SCENE_SETTINGS)
			return
		ctx.request_new_run()

func draw(ctx: Variant, canvas: CanvasItem) -> void:
	UiDraw.background(canvas)
	_draw_bamboo_silhouettes(canvas, float(GameConstants.VIEW_HEIGHT) - 32.0, 0.55, ctx.cursor_flash)
	_draw_scene_frame(canvas, 48.0)

	var center_x: float = float(GameConstants.VIEW_WIDTH) * 0.5
	var title_y: float = float(GameConstants.VIEW_HEIGHT) * 0.42
	var title_panel: Rect2 = Rect2(center_x - 360.0, title_y - 150.0, 720.0, 340.0)
	UiDraw.panel(canvas, title_panel)
	UiDraw.centered_text(canvas, "武", center_x, title_y, GameConstants.COLOR_TEXT_HEADING, 200, true)
	UiDraw.centered_text(canvas, "WU", center_x, title_y + 94.0, GameConstants.COLOR_TEXT_SUBHEADING, 42, true)
	UiDraw.centered_text(canvas, "The Wanderer Emerges", center_x, title_y + 150.0, GameConstants.COLOR_TEXT_BODY, 22)
	UiDraw.centered_text(canvas, "A Sekiro-paced wuxia duel roguelike", center_x, title_y + 184.0, GameConstants.COLOR_TEXT_HINT, 17)

	var prompt_pulse: float = 0.775 + 0.225 * sin(ctx.cursor_flash * 4.0)
	_draw_menu_option(canvas, "Begin", 0, center_x, float(GameConstants.VIEW_HEIGHT) * 0.78, ctx.cursor_flash, prompt_pulse)
	_draw_menu_option(canvas, "Settings", 1, center_x, float(GameConstants.VIEW_HEIGHT) * 0.84, ctx.cursor_flash, prompt_pulse)
	UiDraw.centered_text(canvas, "第一章 江湖", center_x, float(GameConstants.VIEW_HEIGHT) - 78.0, GameConstants.COLOR_TEXT_BODY, 18, true)
	UiDraw.centered_text(canvas, "Bamboo roads, wandering blades, and a debt still unpaid", center_x, float(GameConstants.VIEW_HEIGHT) - 48.0, GameConstants.COLOR_TEXT_HINT, 15)

func _draw_menu_option(canvas: CanvasItem, label: String, idx: int, center_x: float, y: float, cursor_flash: float, prompt_pulse: float) -> void:
	var selected: bool = idx == selection_idx
	var color: Color = Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, prompt_pulse) if selected else GameConstants.COLOR_TEXT_BODY
	UiDraw.centered_text(canvas, label, center_x, y, color, 24)
	if selected:
		UiDraw.menu_cursor(canvas, Vector2(center_x - 88.0, y - 8.0), cursor_flash)

func _hovered_option(mouse_pos: Vector2) -> int:
	if mouse_pos == Vector2.INF:
		return -1
	var center_x: float = float(GameConstants.VIEW_WIDTH) * 0.5
	var begin_rect: Rect2 = Rect2(center_x - 120.0, float(GameConstants.VIEW_HEIGHT) * 0.78 - 28.0, 240.0, 42.0)
	var settings_rect: Rect2 = Rect2(center_x - 120.0, float(GameConstants.VIEW_HEIGHT) * 0.84 - 28.0, 240.0, 42.0)
	if begin_rect.has_point(mouse_pos):
		return 0
	if settings_rect.has_point(mouse_pos):
		return 1
	return -1

func _draw_scene_frame(canvas: CanvasItem, margin: float) -> void:
	var cm: float = 12.0
	var cc: Color = Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.7)
	var w: float = float(GameConstants.VIEW_WIDTH)
	var h: float = float(GameConstants.VIEW_HEIGHT)
	canvas.draw_rect(Rect2(margin, margin, cm, 1.0), cc)
	canvas.draw_rect(Rect2(margin, margin, 1.0, cm), cc)
	canvas.draw_rect(Rect2(w - margin - cm, margin, cm, 1.0), cc)
	canvas.draw_rect(Rect2(w - margin - 1.0, margin, 1.0, cm), cc)
	canvas.draw_rect(Rect2(margin, h - margin - 1.0, cm, 1.0), cc)
	canvas.draw_rect(Rect2(margin, h - margin - cm, 1.0, cm), cc)
	canvas.draw_rect(Rect2(w - margin - cm, h - margin - 1.0, cm, 1.0), cc)
	canvas.draw_rect(Rect2(w - margin - 1.0, h - margin - cm, 1.0, cm), cc)

func _draw_bamboo_silhouettes(canvas: CanvasItem, base_y: float, opacity: float, cursor_flash: float) -> void:
	var pan_offset: float = fmod(cursor_flash * 8.0, 82.0)
	for i in range(26):
		var x: float = -54.0 - pan_offset + float(i) * 82.0 + float((i * 37) % 19)
		var height: float = 170.0 + float((i * 29) % 150)
		var width: float = 8.0 + float(i % 3) * 2.0
		var stalk_color: Color = Color(GameConstants.COLOR_MOUNTAIN_BLUE.r, GameConstants.COLOR_MOUNTAIN_BLUE.g, GameConstants.COLOR_MOUNTAIN_BLUE.b, opacity)
		canvas.draw_rect(Rect2(x, base_y - height, width, height), stalk_color, true)
		for node in range(1, 6):
			var node_y: float = base_y - height + float(node) * (height / 6.0)
			canvas.draw_rect(Rect2(x - 1.0, node_y, width + 2.0, 2.0), Color(GameConstants.COLOR_LIGHT_BLUE.r, GameConstants.COLOR_LIGHT_BLUE.g, GameConstants.COLOR_LIGHT_BLUE.b, opacity * 0.18), true)
		for leaf in range(3):
			var leaf_y: float = base_y - height * (0.34 + float(leaf) * 0.18)
			var dir: float = -1.0 if ((i + leaf) % 2 == 0) else 1.0
			var leaf_color: Color = Color(GameConstants.COLOR_JADE_DARK.r, GameConstants.COLOR_JADE_DARK.g, GameConstants.COLOR_JADE_DARK.b, opacity * 0.78)
			canvas.draw_line(Vector2(x + width * 0.5, leaf_y), Vector2(x + width * 0.5 + dir * 34.0, leaf_y - 16.0), leaf_color, 2.0)
			canvas.draw_line(Vector2(x + width * 0.5, leaf_y + 6.0), Vector2(x + width * 0.5 + dir * 24.0, leaf_y + 18.0), leaf_color, 2.0)
