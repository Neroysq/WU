class_name BoonOfferScene
extends RefCounted

const SceneContext = preload("res://scripts/scene_context.gd")
const UiDraw = preload("res://scripts/ui/ui_draw.gd")

var offers: Array = []
var school: String = ""
var selection_idx: int = 0

func enter(ctx: Variant, payload: Dictionary = {}) -> void:
	selection_idx = 0
	school = str(payload.get("school", ""))
	offers = payload.get("offers", []) as Array
	if offers.is_empty() and ctx.run_state != null:
		var current_node: MapNode = ctx.run_state.get_current_node()
		var generated: Dictionary = RunFlow.generate_boon_offer_payload(ctx.run_state, current_node, school)
		school = str(generated.get("school", school))
		offers = generated.get("offers", []) as Array

func update(ctx: Variant, input: Variant, _delta: float) -> void:
	if offers.is_empty():
		ctx.run_state.mark_current_node_cleared()
		ctx.goto(SceneContext.SCENE_MAP)
		return

	var max_idx: int = offers.size() - 1
	if input.left:
		selection_idx = maxi(0, selection_idx - 1)
	if input.right:
		selection_idx = mini(max_idx, selection_idx + 1)
	if input.number >= 1 and input.number <= offers.size():
		_apply_offer_by_index(ctx, input.number - 1)
		return

	var hovered_idx: int = _get_hovered_offer_index(input.mouse_pos)
	if hovered_idx >= 0:
		selection_idx = hovered_idx

	if input.accept:
		_apply_offer_by_index(ctx, selection_idx)
	elif hovered_idx >= 0 and input.mouse_clicked:
		_apply_offer_by_index(ctx, hovered_idx)

func draw(ctx: Variant, canvas: CanvasItem) -> void:
	UiDraw.background(canvas)
	UiDraw.modal_backdrop(canvas)

	var school_data: Dictionary = DataManager.get_school(school)
	var accent: Color = _school_color(school_data)
	var header_cn: String = str(school_data.get("hanzi", school))
	var header_en: String = str(school_data.get("name", school.capitalize()))
	var panel: Rect2 = _get_offer_panel_rect()
	UiDraw.panel(canvas, panel)
	var header_bar: Rect2 = Rect2(panel.position.x + 18.0, panel.position.y + 18.0, panel.size.x - 36.0, 54.0)
	canvas.draw_rect(header_bar, Color(accent.r, accent.g, accent.b, 0.18), true)
	canvas.draw_rect(header_bar, Color(accent.r, accent.g, accent.b, 0.8), false, 1.0)
	UiDraw.text(canvas, header_cn, header_bar.position.x + 18.0, header_bar.position.y + 28.0, GameConstants.COLOR_TEXT_HEADING, 24, true)
	UiDraw.text(canvas, header_en, header_bar.position.x + 18.0, header_bar.position.y + 48.0, GameConstants.COLOR_TEXT_BODY, 17)
	UiDraw.text(canvas, "Arrows, 1/2/3, Enter or click", panel.position.x + 26.0, panel.position.y + 92.0, GameConstants.COLOR_TEXT_HINT, 15)

	for i in range(offers.size()):
		var box: Rect2 = _get_offer_box_rect(i)
		var offer: Dictionary = offers[i] as Dictionary
		UiDraw.reward_option(canvas, box, _offer_label(offer), _offer_description(offer), selection_idx == i, ctx.cursor_flash, accent)

func _apply_offer_by_index(ctx: Variant, index: int) -> void:
	if index < 0 or index >= offers.size():
		return
	if not RunFlow.apply_boon_offer_selection(ctx.run_state, offers[index] as Dictionary):
		return
	ctx.run_state.mark_current_node_cleared()
	offers.clear()
	selection_idx = 0
	ctx.goto(SceneContext.SCENE_MAP)

func _offer_label(offer: Dictionary) -> String:
	var boon: Dictionary = offer.get("boon", {}) as Dictionary
	var tier: String = str(offer.get("tier", "common")).capitalize()
	var source_id: String = str(boon.get("sourceTechnique", ""))
	if not source_id.is_empty():
		var technique: Dictionary = DataManager.get_technique(source_id)
		return "%s %s" % [tier, str(technique.get("name_en", boon.get("id", "")))]
	return "%s %s" % [tier, str(boon.get("id", ""))]

func _offer_description(offer: Dictionary) -> String:
	var boon: Dictionary = offer.get("boon", {}) as Dictionary
	var kind: String = str(boon.get("kind", ""))
	var slot: String = str(boon.get("slot", ""))
	var source_id: String = str(boon.get("sourceTechnique", ""))
	var body: String = ""
	if not source_id.is_empty():
		body = str(DataManager.get_technique(source_id).get("description", ""))
	if body.is_empty():
		body = "Adds %s effects." % kind
	return "%s%s · %s" % [kind, " / %s" % slot if not slot.is_empty() else "", body]

func _get_offer_panel_rect() -> Rect2:
	var width: float = minf(1200.0, float(GameConstants.VIEW_WIDTH) - 200.0)
	var height: float = 300.0
	return Rect2((float(GameConstants.VIEW_WIDTH) - width) * 0.5, (float(GameConstants.VIEW_HEIGHT) - height) * 0.5 - 20.0, width, height)

func _get_offer_box_rect(index: int) -> Rect2:
	var panel: Rect2 = _get_offer_panel_rect()
	var count: int = maxi(offers.size(), 1)
	var gap: float = 20.0
	var box_width: float = (panel.size.x - gap * float(count + 1)) / float(count)
	var box_height: float = 150.0
	var x: float = panel.position.x + gap + float(index) * (box_width + gap)
	var y: float = panel.position.y + 118.0
	return Rect2(x, y, box_width, box_height)

func _get_hovered_offer_index(mouse_pos: Vector2) -> int:
	if mouse_pos == Vector2.INF:
		return -1
	for i in range(offers.size()):
		if _get_offer_box_rect(i).has_point(mouse_pos):
			return i
	return -1

func _school_color(school_data: Dictionary) -> Color:
	var text: String = str(school_data.get("themeColor", ""))
	if text.length() == 7 and text.begins_with("#"):
		return Color.html(text)
	return GameConstants.COLOR_PANEL_ACCENT
