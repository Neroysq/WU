class_name ForgetScene
extends RefCounted

const SceneContext = preload("res://scripts/scene_context.gd")
const MenuInput = preload("res://scripts/ui/menu_input.gd")
const UiDraw = preload("res://scripts/ui/ui_draw.gd")

var selection_idx: int = 0

func enter(_ctx: Variant, _payload: Dictionary = {}) -> void:
	selection_idx = 0

func update(ctx: Variant, input: Variant, _delta: float) -> void:
	if ctx.player.technique_engine == null:
		ctx.run_state.mark_current_node_cleared()
		ctx.goto(SceneContext.SCENE_MAP)
		return

	var technique_ids: Array[String] = ctx.player.technique_engine.technique_ids()
	if technique_ids.is_empty():
		ctx.run_state.mark_current_node_cleared()
		ctx.goto(SceneContext.SCENE_MAP)
		return

	selection_idx = MenuInput.step_index(selection_idx, technique_ids.size() - 1, input)
	if input.local_cancel:
		ctx.run_state.mark_current_node_cleared()
		ctx.goto(SceneContext.SCENE_MAP)
		return

	if input.accept and selection_idx >= 0 and selection_idx < technique_ids.size():
		ForgetService.apply(technique_ids[selection_idx], ctx.player, ctx.run_state)
		ctx.goto(SceneContext.SCENE_MAP)

func draw(ctx: Variant, canvas: CanvasItem) -> void:
	UiDraw.background(canvas)
	UiDraw.modal_backdrop(canvas)
	var technique_count: int = 0
	if ctx.player.technique_engine != null:
		technique_count = ctx.player.technique_engine.technique_ids().size()
	var panel_height: float = clampf(210.0 + float(technique_count) * 72.0, 320.0, 560.0)
	var panel: Rect2 = Rect2(420.0, (float(GameConstants.VIEW_HEIGHT) - panel_height) * 0.5, float(GameConstants.VIEW_WIDTH) - 840.0, panel_height)
	UiDraw.panel(canvas, panel)
	UiDraw.text(canvas, "忘招 Forget Technique", panel.position.x + 32.0, panel.position.y + 48.0, GameConstants.COLOR_TEXT_HEADING, 28, true)

	if ctx.player.technique_engine == null:
		return
	var technique_ids: Array[String] = ctx.player.technique_engine.technique_ids()
	var y: float = panel.position.y + 100.0
	for i in range(technique_ids.size()):
		var tech_data: Dictionary = DataManager.get_technique(technique_ids[i])
		var display: String = "%s %s" % [str(tech_data.get("name_cn", technique_ids[i])), str(tech_data.get("name_en", ""))]
		var desc: String = str(tech_data.get("description", ""))
		var selected: bool = i == selection_idx
		var row: Rect2 = Rect2(panel.position.x + 20.0, y - 28.0, panel.size.x - 40.0, 62.0)
		var color: Color = GameConstants.COLOR_VERMILLION_RED if selected else GameConstants.COLOR_TEXT_BODY
		canvas.draw_rect(row, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.76), true)
		canvas.draw_rect(row, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.9) if selected else Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.42), false, 1.0)
		if selected:
			UiDraw.menu_cursor(canvas, Vector2(panel.position.x + 12.0, y), ctx.cursor_flash)
		UiDraw.text(canvas, display, panel.position.x + 48.0, y + 2.0, color, 18)
		UiDraw.text(canvas, desc, panel.position.x + 48.0, y + 26.0, GameConstants.COLOR_TEXT_HINT, 14)
		y += 72.0
	UiDraw.text(canvas, "W/S to browse, Enter to forget, Q or Esc to cancel", panel.position.x + 32.0, panel.end.y - 28.0, GameConstants.COLOR_TEXT_HINT, 15)
