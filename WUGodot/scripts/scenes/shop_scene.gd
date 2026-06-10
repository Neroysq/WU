class_name ShopScene
extends RefCounted

const SceneContext = preload("res://scripts/scene_context.gd")
const MenuInput = preload("res://scripts/ui/menu_input.gd")
const UiDraw = preload("res://scripts/ui/ui_draw.gd")

var items: Array[Dictionary] = []
var selection_idx: int = 0

func enter(ctx: Variant, payload: Dictionary = {}) -> void:
	items = _typed_items(payload.get("items", []))
	selection_idx = 0
	ctx.notice_message = ""
	ctx.notice_timer = 0.0

func update(ctx: Variant, input: Variant, _delta: float) -> void:
	var max_idx: int = maxi(items.size() - 1, 0)
	selection_idx = MenuInput.step_index(selection_idx, max_idx, input)

	if input.local_cancel:
		ctx.run_state.mark_current_node_cleared()
		ctx.goto(SceneContext.SCENE_MAP)
		return

	if input.accept and selection_idx >= 0 and selection_idx < items.size():
		var item: Dictionary = items[selection_idx]
		var result: Dictionary = ShopGenerator.buy_item(item, ctx.player)
		ctx.notice_message = str(result.get("message", ""))
		ctx.notice_timer = 2.0
		if bool(result.get("success", false)):
			if str(item.get("type", "")) == "technique":
				var bought_id: String = str(item.get("technique_id", ""))
				if not bought_id.is_empty() and not ctx.run_techniques_acquired.has(bought_id):
					ctx.run_techniques_acquired.append(bought_id)
			items.remove_at(selection_idx)
			selection_idx = mini(selection_idx, maxi(items.size() - 1, 0))
			if bool(result.get("open_forget", false)):
				ctx.goto(SceneContext.SCENE_FORGET_TECHNIQUE)

func draw(ctx: Variant, canvas: CanvasItem) -> void:
	UiDraw.background(canvas)
	UiDraw.modal_backdrop(canvas)
	var panel: Rect2 = Rect2(300.0, 110.0, float(GameConstants.VIEW_WIDTH) - 600.0, 740.0)
	UiDraw.panel(canvas, panel)
	UiDraw.text(canvas, "商鋪 Shop", panel.position.x + 32.0, panel.position.y + 48.0, GameConstants.COLOR_TEXT_HEADING, 28, true)
	UiDraw.text(canvas, "Gold: %d" % ctx.player.gold, panel.end.x - 180.0, panel.position.y + 48.0, GameConstants.COLOR_TEXT_ACCENT, 24)
	canvas.draw_rect(Rect2(panel.position.x + 32.0, panel.position.y + 64.0, panel.size.x - 64.0, 1.0), Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.55))

	var y: float = panel.position.y + 114.0
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var label: String = str(item.get("label", "???"))
		var price: int = int(item.get("price", 0))
		var desc: String = str(item.get("description", ""))
		var can_afford: bool = ctx.player.gold >= price
		var selected: bool = i == selection_idx
		var row: Rect2 = Rect2(panel.position.x + 24.0, y - 28.0, panel.size.x - 48.0, 70.0)
		var text_color: Color = GameConstants.COLOR_TEXT_HEADING if selected else GameConstants.COLOR_TEXT_BODY
		var price_color: Color = GameConstants.COLOR_TEXT_ACCENT if can_afford else Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.8)
		canvas.draw_rect(row, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.76), true)
		canvas.draw_rect(row, GameConstants.COLOR_PANEL_ACCENT if selected else Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.42), false, 1.0)
		if not can_afford:
			text_color = GameConstants.COLOR_TEXT_DISABLED
		if selected:
			UiDraw.menu_cursor(canvas, Vector2(panel.position.x + 16.0, y - 2.0), ctx.cursor_flash)
		UiDraw.text(canvas, label, panel.position.x + 52.0, y + 2.0, text_color, 19)
		if not can_afford:
			var chip_rect: Rect2 = Rect2(row.end.x - 214.0, y - 18.0, 92.0, 24.0)
			canvas.draw_rect(chip_rect, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.16), true)
			canvas.draw_rect(chip_rect, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.75), false, 1.0)
			UiDraw.text(canvas, "Need Gold", chip_rect.position.x + 10.0, chip_rect.position.y + 17.0, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.95), 13)
		UiDraw.text(canvas, "%dg" % price, row.end.x - 88.0, y + 2.0, price_color, 20)
		UiDraw.text(canvas, desc, panel.position.x + 52.0, y + 28.0, GameConstants.COLOR_TEXT_HINT if can_afford else GameConstants.COLOR_TEXT_DISABLED, 14)
		y += 82.0

	if ctx.notice_timer > 0.0:
		UiDraw.text(canvas, ctx.notice_message, panel.position.x + 32.0, panel.end.y - 58.0, GameConstants.COLOR_TEXT_ACCENT, 17)
	UiDraw.text(canvas, "W/S to browse, Enter to buy, Q or Esc to leave", panel.position.x + 32.0, panel.end.y - 28.0, GameConstants.COLOR_TEXT_HINT, 15)

func _typed_items(source: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for item in source:
		typed.append((item as Dictionary).duplicate(true))
	return typed
