class_name RestScene
extends RefCounted

const SceneContext = preload("res://scripts/scene_context.gd")
const MenuInput = preload("res://scripts/ui/menu_input.gd")
const UiDraw = preload("res://scripts/ui/ui_draw.gd")

var choice_idx: int = 0

func enter(_ctx: Variant, _payload: Dictionary = {}) -> void:
	choice_idx = 0

func update(ctx: Variant, input: Variant, _delta: float) -> void:
	choice_idx = MenuInput.step_index(choice_idx, 2, input)
	if not input.accept:
		return
	if choice_idx == 0:
		ctx.player.health_current = minf(ctx.player.health_current + ctx.player.health_max * 0.4, ctx.player.health_max)
		ctx.run_state.mark_current_node_cleared()
		ctx.goto(SceneContext.SCENE_MAP)
	elif choice_idx == 1 and ctx.player.technique_engine != null and not ctx.player.technique_engine.technique_ids().is_empty():
		ctx.goto(SceneContext.SCENE_FORGET_TECHNIQUE)
	elif choice_idx == 2 and ctx.run_state.upgrade_first_boon_with_insight():
		ctx.run_state.mark_current_node_cleared()
		ctx.goto(SceneContext.SCENE_MAP)
	else:
		ctx.run_state.mark_current_node_cleared()
		ctx.goto(SceneContext.SCENE_MAP)

func draw(ctx: Variant, canvas: CanvasItem) -> void:
	UiDraw.background(canvas)
	UiDraw.modal_backdrop(canvas)
	var panel: Rect2 = Rect2(520.0, (float(GameConstants.VIEW_HEIGHT) - 350.0) * 0.5, float(GameConstants.VIEW_WIDTH) - 1040.0, 350.0)
	UiDraw.panel(canvas, panel)
	UiDraw.text(canvas, "歇息 Rest Site", panel.position.x + 32.0, panel.position.y + 48.0, GameConstants.COLOR_TEXT_HEADING, 28, true)
	UiDraw.text(canvas, "HP: %d/%d" % [int(round(ctx.player.health_current)), int(round(ctx.player.health_max))], panel.position.x + 32.0, panel.position.y + 78.0, GameConstants.COLOR_TEXT_BODY, 18)
	UiDraw.text(canvas, "Insight: %d" % ctx.run_state.insight, panel.end.x - 160.0, panel.position.y + 78.0, GameConstants.COLOR_TEXT_BODY, 18)

	var can_remove: bool = ctx.player.technique_engine != null and not ctx.player.technique_engine.technique_ids().is_empty()
	var can_upgrade: bool = ctx.run_state.insight > 0 and not ctx.run_state.first_upgradeable_boon_id().is_empty()
	var choices: Array[String] = ["Heal (40% max HP)", "Remove a technique", "Upgrade a boon"]
	var choice_hints: Array[String] = ["Recover and steady yourself before the next road.", "Forget one technique and lighten the loadout.", "Spend 1 Insight on the first eligible boon."]
	var y: float = panel.position.y + 126.0
	for i in range(choices.size()):
		var row: Rect2 = Rect2(panel.position.x + 20.0, y - 28.0, panel.size.x - 40.0, 64.0)
		var selected: bool = i == choice_idx
		var enabled: bool = i == 0 or (i == 1 and can_remove) or (i == 2 and can_upgrade)
		var border_color: Color = GameConstants.COLOR_PANEL_ACCENT if selected and enabled else Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.5)
		var label_color: Color = GameConstants.COLOR_TEXT_HEADING if enabled else GameConstants.COLOR_TEXT_DISABLED
		var hint_color: Color = GameConstants.COLOR_TEXT_HINT if enabled else GameConstants.COLOR_TEXT_DISABLED
		canvas.draw_rect(row, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.76), true)
		canvas.draw_rect(row, border_color, false, 1.0)
		if selected:
			UiDraw.menu_cursor(canvas, Vector2(panel.position.x + 12.0, y), ctx.cursor_flash)
		UiDraw.text(canvas, choices[i], panel.position.x + 48.0, y + 2.0, label_color, 19)
		UiDraw.text(canvas, choice_hints[i], panel.position.x + 48.0, y + 26.0, hint_color, 14)
		if not enabled:
			var chip_rect: Rect2 = Rect2(row.end.x - 84.0, y - 18.0, 64.0, 24.0)
			canvas.draw_rect(chip_rect, Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.18), true)
			canvas.draw_rect(chip_rect, Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.65), false, 1.0)
			UiDraw.text(canvas, "Locked", chip_rect.position.x + 10.0, chip_rect.position.y + 17.0, GameConstants.COLOR_TEXT_HINT, 13)
			canvas.draw_line(Vector2(panel.position.x + 48.0, y - 6.0), Vector2(panel.position.x + 232.0, y - 6.0), Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.75), 1.0)
		y += 74.0
	UiDraw.text(canvas, "W/S to choose, Enter to confirm", panel.position.x + 32.0, panel.end.y - 28.0, GameConstants.COLOR_TEXT_HINT, 15)
