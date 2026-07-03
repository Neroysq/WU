class_name EndingScene
extends RefCounted

const SceneContext = preload("res://scripts/scene_context.gd")
const MenuInput = preload("res://scripts/ui/menu_input.gd")
const UiDraw = preload("res://scripts/ui/ui_draw.gd")

func enter(_ctx: Variant, _payload: Dictionary = {}) -> void:
	pass

func update(ctx: Variant, input: Variant, _delta: float) -> void:
	if input.accept or input.mouse_clicked:
		MenuInput.play_ui_confirm()
		ctx.goto(SceneContext.SCENE_MAIN_MENU)

func draw(ctx: Variant, canvas: CanvasItem) -> void:
	if ctx.current_scene == SceneContext.SCENE_VICTORY:
		_draw_victory(ctx, canvas)
	else:
		_draw_game_over(ctx, canvas)

func _draw_victory(ctx: Variant, canvas: CanvasItem) -> void:
	UiDraw.background(canvas)
	UiDraw.modal_backdrop(canvas)
	var center_x: float = float(GameConstants.VIEW_WIDTH) * 0.5
	var technique_count: int = maxi(ctx.run_techniques_acquired.size(), 1)
	var scroll_height: float = clampf(476.0 + float(technique_count) * 22.0, 500.0, 760.0)
	var scroll: Rect2 = Rect2(center_x - 340.0, (float(GameConstants.VIEW_HEIGHT) - scroll_height) * 0.5, 680.0, scroll_height)
	canvas.draw_rect(scroll, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 240.0 / 255.0), true)
	var gold: Color = GameConstants.COLOR_IMPERIAL_GOLD
	canvas.draw_rect(Rect2(scroll.position.x, scroll.position.y, scroll.size.x, 3.0), gold)
	canvas.draw_rect(Rect2(scroll.position.x, scroll.end.y - 3.0, scroll.size.x, 3.0), gold)
	canvas.draw_rect(Rect2(scroll.position.x, scroll.position.y, 3.0, scroll.size.y), gold)
	canvas.draw_rect(Rect2(scroll.end.x - 3.0, scroll.position.y, 3.0, scroll.size.y), gold)

	var y: float = scroll.position.y + 50.0
	var left: float = scroll.position.x + 40.0
	UiDraw.centered_text(canvas, "山門開了", center_x, y, GameConstants.COLOR_TEXT_HEADING, 40, true)
	y += 40.0
	UiDraw.centered_text(canvas, "The Gate Stands Open", center_x, y, GameConstants.COLOR_TEXT_SUBHEADING, 19)
	y += 60.0
	canvas.draw_rect(Rect2(left, y, scroll.size.x - 80.0, 1.0), Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.4))
	y += 30.0

	var run_duration: float = ctx.run_end_time - ctx.run_start_time
	var minutes: int = int(run_duration) / 60
	var seconds: int = int(run_duration) % 60
	UiDraw.text(canvas, "Run Duration", left, y, GameConstants.COLOR_TEXT_CAPTION, 14)
	UiDraw.text(canvas, "%d:%02d" % [minutes, seconds], left + 200.0, y, GameConstants.COLOR_TEXT_HEADING, 16)
	y += 30.0

	var hp_pct: int = 0
	if ctx.player != null:
		hp_pct = int(round(ctx.player.health_current / maxf(ctx.player.health_max, 1.0) * 100.0))
	UiDraw.text(canvas, "Final HP", left, y, GameConstants.COLOR_TEXT_CAPTION, 14)
	UiDraw.text(canvas, "%d%%" % hp_pct, left + 200.0, y, GameConstants.COLOR_TEXT_HEADING, 16)
	y += 30.0
	UiDraw.text(canvas, "Gold Earned", left, y, GameConstants.COLOR_TEXT_CAPTION, 14)
	UiDraw.text(canvas, "%d" % ctx.run_gold_earned, left + 200.0, y, GameConstants.COLOR_TEXT_ACCENT, 16)
	y += 40.0
	canvas.draw_rect(Rect2(left, y, scroll.size.x - 80.0, 1.0), Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.4))
	y += 20.0
	UiDraw.text(canvas, "Techniques Acquired", left, y, GameConstants.COLOR_TEXT_CAPTION, 14)
	y += 24.0

	if ctx.run_techniques_acquired.is_empty():
		UiDraw.text(canvas, "(none)", left + 20.0, y, GameConstants.COLOR_TEXT_CAPTION, 14)
		y += 20.0
	else:
		for tech_id in ctx.run_techniques_acquired:
			var tech_data: Dictionary = DataManager.get_technique(tech_id)
			UiDraw.text(canvas, "%s %s" % [str(tech_data.get("name_cn", "")), str(tech_data.get("name_en", tech_id))], left + 20.0, y, GameConstants.COLOR_TEXT_BODY, 15)
			y += 22.0

	y += 24.0
	canvas.draw_rect(Rect2(left, y, scroll.size.x - 80.0, 1.0), Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.4))
	y += 20.0
	UiDraw.text_block(canvas, "The gatekeeper kneels. The summit is silent. Somewhere above, a door you cannot see has noticed you.", left, y, scroll.size.x - 80.0, 22.0, GameConstants.COLOR_TEXT_BODY, 15, true)
	var pulse: float = 0.775 + 0.225 * sin(ctx.cursor_flash * 4.0)
	UiDraw.centered_text(canvas, "Press Enter to return", center_x, scroll.end.y - 28.0, Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, pulse), 18)

func _draw_game_over(ctx: Variant, canvas: CanvasItem) -> void:
	UiDraw.background(canvas)
	UiDraw.modal_backdrop(canvas)
	var center_x: float = float(GameConstants.VIEW_WIDTH) * 0.5
	var center_y: float = float(GameConstants.VIEW_HEIGHT) * 0.5
	var glyph_center: Vector2 = Vector2(center_x, center_y - 90.0)
	for ring in range(8, 0, -1):
		var radius: float = 58.0 + float(ring) * 34.0
		var alpha: float = 0.015 + float(9 - ring) * 0.009
		canvas.draw_circle(glyph_center, radius, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, alpha))
	UiDraw.centered_text(canvas, "敗", center_x, center_y - 18.0, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.88), 300, true)
	UiDraw.centered_text(canvas, "The mountain keeps what it kills.", center_x, center_y + 132.0, Color(GameConstants.COLOR_TEXT_SUBHEADING.r, GameConstants.COLOR_TEXT_SUBHEADING.g, GameConstants.COLOR_TEXT_SUBHEADING.b, 0.92), 30)
	var run_duration: float = ctx.run_end_time - ctx.run_start_time
	var minutes: int = int(run_duration) / 60
	var seconds: int = int(run_duration) % 60
	UiDraw.centered_text(canvas, "Time: %d:%02d" % [minutes, seconds], center_x, center_y + 176.0, GameConstants.COLOR_TEXT_BODY, 18)
	var pulse: float = 0.775 + 0.225 * sin(ctx.cursor_flash * 4.0)
	UiDraw.centered_text(canvas, "Press Enter to return", center_x, center_y + 216.0, Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, pulse), 20)
