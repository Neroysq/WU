class_name EventScene
extends RefCounted

const EventRunnerScript = preload("res://scripts/event_runner.gd")
const SceneContext = preload("res://scripts/scene_context.gd")
const MenuInput = preload("res://scripts/ui/menu_input.gd")
const UiDraw = preload("res://scripts/ui/ui_draw.gd")

var runner: Variant = null
var event_data: Dictionary = {}
var choices: Array[Dictionary] = []
var choice_idx: int = 0
var result: Dictionary = {}
var showing_result: bool = false

func enter(ctx: Variant, payload: Dictionary = {}) -> void:
	event_data = (payload.get("event_data", {}) as Dictionary).duplicate(true)
	runner = EventRunnerScript.new()
	runner.load_event(event_data)
	choices = _typed_choices(runner.get_choices())
	choice_idx = 0
	result.clear()
	showing_result = false
	ctx.notice_message = ""
	ctx.notice_timer = 0.0

func update(ctx: Variant, input: Variant, _delta: float) -> void:
	if runner == null:
		ctx.run_state.mark_current_node_cleared()
		ctx.goto(SceneContext.SCENE_MAP)
		return

	if showing_result:
		if input.accept:
			_continue_from_result(ctx)
		return

	choice_idx = MenuInput.step_index(choice_idx, choices.size() - 1, input)
	if input.number >= 1 and input.number <= mini(3, choices.size()):
		choice_idx = input.number - 1
		_resolve_choice(ctx, choice_idx)
		return
	if input.accept:
		_resolve_choice(ctx, choice_idx)

func draw(ctx: Variant, canvas: CanvasItem) -> void:
	UiDraw.background(canvas)
	UiDraw.modal_backdrop(canvas)
	if runner == null:
		return

	var panel_width: float = float(GameConstants.VIEW_WIDTH) - 720.0
	var layout: Dictionary = _compute_event_panel_layout(panel_width - 64.0)
	var panel_height: float = clampf(float(layout.get("height", 360.0)), 240.0, float(GameConstants.VIEW_HEIGHT) - 160.0)
	var panel: Rect2 = Rect2(360.0, (float(GameConstants.VIEW_HEIGHT) - panel_height) * 0.5, panel_width, panel_height)
	UiDraw.panel(canvas, panel)

	var title: String = runner.get_title()
	var title_cn: String = runner.get_title_cn()
	if not title_cn.is_empty():
		title = "%s %s" % [title_cn, title]
	UiDraw.text(canvas, title, panel.position.x + 32.0, panel.position.y + 48.0, GameConstants.COLOR_TEXT_HEADING, 28, true)
	canvas.draw_rect(Rect2(panel.position.x + 32.0, panel.position.y + 64.0, panel.size.x - 64.0, 1.0), Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.55))
	var body_lines: Array = layout.get("body_lines", [])
	var result_lines: Array = layout.get("result_lines", [])
	var body_bottom: float = UiDraw.text_lines(canvas, body_lines, panel.position.x + 32.0, panel.position.y + 106.0, 28.0, GameConstants.COLOR_TEXT_BODY, 18)

	if showing_result:
		UiDraw.text_lines(canvas, result_lines, panel.position.x + 32.0, body_bottom + 34.0, 30.0, GameConstants.COLOR_TEXT_ACCENT, 19)
		UiDraw.text(canvas, "Press Enter to continue", panel.position.x + 32.0, panel.end.y - 34.0, GameConstants.COLOR_TEXT_HINT, 15)
	else:
		var y: float = body_bottom + 36.0
		for i in range(choices.size()):
			var choice: Dictionary = choices[i]
			var label: String = "%d. %s" % [i + 1, str(choice.get("label", "..."))]
			var row: Rect2 = Rect2(panel.position.x + 20.0, y - 24.0, panel.size.x - 40.0, 44.0)
			var selected: bool = i == choice_idx
			canvas.draw_rect(row, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.72), true)
			canvas.draw_rect(row, GameConstants.COLOR_PANEL_ACCENT if selected else Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.5), false, 1.0)
			if selected:
				UiDraw.menu_cursor(canvas, Vector2(panel.position.x + 12.0, y - 2.0), ctx.cursor_flash)
			UiDraw.text(canvas, label, panel.position.x + 48.0, y + 4.0, GameConstants.COLOR_TEXT_HEADING if selected else GameConstants.COLOR_TEXT_BODY, 18)
			y += 56.0
		if ctx.notice_timer > 0.0:
			UiDraw.text(canvas, ctx.notice_message, panel.position.x + 32.0, panel.end.y - 62.0, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.95), 16)
		UiDraw.text(canvas, "W/S or 1-3 to choose, Enter to confirm", panel.position.x + 32.0, panel.end.y - 34.0, GameConstants.COLOR_TEXT_HINT, 15)

func _compute_event_panel_layout(max_width: float) -> Dictionary:
	var body_lines: Array[String] = UiDraw.wrap_text(runner.get_text(), max_width, 18)
	var result_lines: Array[String] = []
	if showing_result:
		result_lines = UiDraw.wrap_text(str(result.get("message", "")), max_width, 19)
	var height: float = 96.0 + float(body_lines.size()) * 28.0
	if showing_result:
		height += 34.0 + float(result_lines.size()) * 30.0 + 16.0 + 28.0
	else:
		height += 24.0 + float(choices.size()) * 56.0 + 16.0 + 48.0
	return {"height": height, "body_lines": body_lines, "result_lines": result_lines}

func _resolve_choice(ctx: Variant, index: int) -> void:
	result = runner.choose(index, ctx.player)
	if bool(result.get("blocked", false)):
		ctx.notice_message = str(result.get("message", "Cannot do that."))
		ctx.notice_timer = 1.5
		result.clear()
		showing_result = false
		if not event_data.is_empty():
			runner.load_event(event_data)
			choices = _typed_choices(runner.get_choices())
		return
	if bool(result.get("timing_test", false)):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		result = runner.apply_timing_result(rng.randf() < 0.5, ctx.player)
	showing_result = true
	var granted: String = str(result.get("granted_technique", ""))
	if not granted.is_empty() and not ctx.run_techniques_acquired.has(granted):
		ctx.run_techniques_acquired.append(granted)

func _continue_from_result(ctx: Variant) -> void:
	var favor_school: String = str(result.get("favor_school", ""))
	if not favor_school.is_empty():
		ctx.run_state.favored_school = favor_school
	if bool(result.get("open_shop", false)):
		var owned_ids: Array[String] = []
		if ctx.player.technique_engine != null:
			owned_ids = ctx.player.technique_engine.technique_ids()
		ctx.run_state.mark_current_node_cleared()
		ctx.goto(SceneContext.SCENE_SHOP, {"items": ShopGenerator.generate_shop(owned_ids, bool(result.get("shop_rarity_boost", false)))})
	elif bool(result.get("trigger_combat", false)):
		ctx.combat_gold_multiplier = int(result.get("combat_gold_multiplier", 1))
		var node: MapNode = ctx.run_state.get_current_node()
		if node != null:
			ctx.request_combat(node)
		else:
			ctx.run_state.mark_current_node_cleared()
			ctx.goto(SceneContext.SCENE_MAP)
	else:
		ctx.run_state.mark_current_node_cleared()
		ctx.goto(SceneContext.SCENE_MAP)

func _typed_choices(source: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for choice in source:
		typed.append((choice as Dictionary).duplicate(true))
	return typed
