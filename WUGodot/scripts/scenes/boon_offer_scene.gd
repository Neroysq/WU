class_name BoonOfferScene
extends RefCounted

const SceneContext = preload("res://scripts/scene_context.gd")
const MenuInput = preload("res://scripts/ui/menu_input.gd")
const UiDraw = preload("res://scripts/ui/ui_draw.gd")
const BoonTextScript = preload("res://scripts/boons/boon_text.gd")

var offers: Array = []
var school_choices: Array = []
var school: String = ""
var selection_idx: int = 0

func enter(ctx: Variant, payload: Dictionary = {}) -> void:
	selection_idx = 0
	school = str(payload.get("school", ""))
	offers = payload.get("offers", []) as Array
	school_choices = payload.get("school_choices", []) as Array
	if offers.is_empty() and school_choices.is_empty() and ctx.run_state != null:
		var current_node: MapNode = ctx.run_state.get_current_node()
		var generated: Dictionary = RunFlow.generate_boon_offer_payload(ctx.run_state, current_node, school)
		school = str(generated.get("school", school))
		offers = generated.get("offers", []) as Array

func update(ctx: Variant, input: Variant, _delta: float) -> void:
	if not school_choices.is_empty():
		_update_school_choice(ctx, input)
		return
	if offers.is_empty():
		ctx.run_state.mark_current_node_cleared()
		ctx.goto(SceneContext.SCENE_MAP)
		return

	var max_idx: int = offers.size() - 1
	var before_idx: int = selection_idx
	if input.left:
		selection_idx = maxi(0, selection_idx - 1)
	if input.right:
		selection_idx = mini(max_idx, selection_idx + 1)
	if selection_idx != before_idx:
		MenuInput.play_ui_move()
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
	var choosing_school: bool = not school_choices.is_empty()
	var header_cn: String = "流" if choosing_school else str(school_data.get("hanzi", school))
	var header_en: String = "Choose School" if choosing_school else str(school_data.get("name", school.capitalize()))
	var panel: Rect2 = _get_offer_panel_rect()
	UiDraw.panel(canvas, panel)
	var header_bar: Rect2 = Rect2(panel.position.x + 18.0, panel.position.y + 18.0, panel.size.x - 36.0, 54.0)
	canvas.draw_rect(header_bar, Color(accent.r, accent.g, accent.b, 0.18), true)
	canvas.draw_rect(header_bar, Color(accent.r, accent.g, accent.b, 0.8), false, 1.0)
	UiDraw.text(canvas, header_cn, header_bar.position.x + 18.0, header_bar.position.y + 28.0, GameConstants.COLOR_TEXT_HEADING, 24, true)
	UiDraw.text(canvas, header_en, header_bar.position.x + 18.0, header_bar.position.y + 48.0, GameConstants.COLOR_TEXT_BODY, 17)
	UiDraw.text(canvas, "Arrows, 1/2/3, Enter or click", panel.position.x + 26.0, panel.position.y + 92.0, GameConstants.COLOR_TEXT_HINT, 15)

	if choosing_school:
		for i in range(school_choices.size()):
			var choice_box: Rect2 = _get_offer_box_rect(i)
			var choice: Dictionary = school_choices[i] as Dictionary
			UiDraw.reward_option(canvas, choice_box, _school_choice_label(choice), _school_choice_description(choice), selection_idx == i, ctx.cursor_flash, accent)
		return

	for i in range(offers.size()):
		var box: Rect2 = _get_offer_box_rect(i)
		var offer: Dictionary = offers[i] as Dictionary
		_draw_offer_card(canvas, box, offer, selection_idx == i, ctx.cursor_flash, accent)

func _update_school_choice(ctx: Variant, input: Variant) -> void:
	var max_idx: int = school_choices.size() - 1
	var before_idx: int = selection_idx
	if input.left:
		selection_idx = maxi(0, selection_idx - 1)
	if input.right:
		selection_idx = mini(max_idx, selection_idx + 1)
	if selection_idx != before_idx:
		MenuInput.play_ui_move()
	if input.number >= 1 and input.number <= school_choices.size():
		_select_school(ctx, input.number - 1)
		return

	var hovered_idx: int = _get_hovered_offer_index(input.mouse_pos)
	if hovered_idx >= 0:
		selection_idx = hovered_idx

	if input.accept:
		_select_school(ctx, selection_idx)
	elif hovered_idx >= 0 and input.mouse_clicked:
		_select_school(ctx, hovered_idx)

func _select_school(ctx: Variant, index: int) -> void:
	if index < 0 or index >= school_choices.size():
		return
	MenuInput.play_ui_confirm()
	var choice: Dictionary = school_choices[index] as Dictionary
	school = str(choice.get("school", ""))
	var current_node: MapNode = ctx.run_state.get_current_node() if ctx.run_state != null else null
	var generated: Dictionary = RunFlow.generate_boon_offer_payload(ctx.run_state, current_node, school)
	offers = generated.get("offers", []) as Array
	school_choices.clear()
	selection_idx = 0

func _apply_offer_by_index(ctx: Variant, index: int) -> void:
	if index < 0 or index >= offers.size():
		return
	if not RunFlow.apply_boon_offer_selection(ctx.run_state, offers[index] as Dictionary):
		return
	MenuInput.play_ui_confirm()
	ctx.run_state.mark_current_node_cleared()
	offers.clear()
	selection_idx = 0
	ctx.goto(SceneContext.SCENE_MAP)

func _offer_label(offer: Dictionary) -> String:
	var boon: Dictionary = offer.get("boon", {}) as Dictionary
	return BoonTextScript.label(boon, str(offer.get("tier", "common")))

func _offer_description(offer: Dictionary) -> String:
	var boon: Dictionary = offer.get("boon", {}) as Dictionary
	var kind: String = str(boon.get("kind", ""))
	var slot: String = str(boon.get("slot", ""))
	var body: String = BoonTextScript.describe(boon, str(offer.get("tier", "common")))
	return "%s%s · %s" % [kind, " / %s" % slot if not slot.is_empty() else "", body]

func _school_choice_label(choice: Dictionary) -> String:
	var school_id: String = str(choice.get("school", ""))
	var data: Dictionary = choice.get("school_data", {}) as Dictionary
	var name: String = str(data.get("name", school_id.capitalize()))
	var hanzi: String = str(data.get("hanzi", school_id))
	return "%s %s" % [hanzi, name]

func _school_choice_description(choice: Dictionary) -> String:
	var data: Dictionary = choice.get("school_data", {}) as Dictionary
	var blurb: String = str(data.get("blurb", ""))
	return blurb if not blurb.is_empty() else "Choose this school for the next boon offer."

func _get_offer_panel_rect() -> Rect2:
	var width: float = minf(1320.0, float(GameConstants.VIEW_WIDTH) - 180.0)
	if offers.size() > 0:
		var offer_height: float = 530.0
		return Rect2((float(GameConstants.VIEW_WIDTH) - width) * 0.5, (float(GameConstants.VIEW_HEIGHT) - offer_height) * 0.5, width, offer_height)
	var school_height: float = 430.0
	return Rect2((float(GameConstants.VIEW_WIDTH) - width) * 0.5, (float(GameConstants.VIEW_HEIGHT) - school_height) * 0.5 - 38.0, width, school_height)

func _get_offer_box_rect(index: int) -> Rect2:
	var panel: Rect2 = _get_offer_panel_rect()
	var count: int = maxi(maxi(offers.size(), school_choices.size()), 1)
	var gap: float = 20.0
	var has_offers: bool = offers.size() > 0
	var box_width: float = (panel.size.x - gap * float(count + 1)) / float(count)
	var box_height: float = 310.0 if has_offers else 150.0
	var x: float = panel.position.x + gap + float(index) * (box_width + gap)
	var y: float = panel.position.y + (150.0 if has_offers else 138.0)
	return Rect2(x, y, box_width, box_height)

func _get_hovered_offer_index(mouse_pos: Vector2) -> int:
	if mouse_pos == Vector2.INF:
		return -1
	var count: int = maxi(offers.size(), school_choices.size())
	for i in range(count):
		if _get_offer_box_rect(i).has_point(mouse_pos):
			return i
	return -1

func _school_color(school_data: Dictionary) -> Color:
	var text: String = str(school_data.get("themeColor", ""))
	if text.length() == 7 and text.begins_with("#"):
		return Color.html(text)
	return GameConstants.COLOR_PANEL_ACCENT

func _draw_offer_card(canvas: CanvasItem, rect: Rect2, offer: Dictionary, selected: bool, cursor_flash: float, school_accent: Color) -> void:
	var boon: Dictionary = offer.get("boon", {}) as Dictionary
	var tier: String = str(offer.get("tier", "common")).to_lower()
	var rarity_color: Color = _rarity_color(tier)
	var card: Rect2 = rect
	if selected:
		card.position.y -= 8.0
		canvas.draw_rect(card.grow(10.0), Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.13), true)
	var border_width: float = 3.0 if tier == "epic" or tier == "legendary" or selected else 1.5
	canvas.draw_rect(card, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.91), true)
	canvas.draw_rect(Rect2(card.position.x, card.position.y, card.size.x, 6.0), Color(school_accent.r, school_accent.g, school_accent.b, 0.72), true)
	canvas.draw_rect(card, Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.90 if selected else 0.62), false, border_width)
	var chip: Rect2 = Rect2(card.position.x + 18.0, card.position.y + 18.0, 118.0, 28.0)
	canvas.draw_rect(chip, Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.20), true)
	canvas.draw_rect(chip, Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.84), false, 1.0)
	UiDraw.text(canvas, tier.capitalize(), chip.position.x + 12.0, chip.position.y + 20.0, GameConstants.COLOR_TEXT_HEADING, 14)
	var kind_slot: String = _offer_kind_slot(boon)
	if not kind_slot.is_empty():
		UiDraw.text(canvas, kind_slot, card.end.x - UiDraw.measure_text(kind_slot, 13) - 18.0, card.position.y + 38.0, Color(school_accent.r, school_accent.g, school_accent.b, 0.95), 13)
	UiDraw.text_block(canvas, BoonTextScript.name(boon), card.position.x + 18.0, card.position.y + 100.0, card.size.x - 36.0, 28.0, GameConstants.COLOR_TEXT_HEADING, 24, true)
	var body_y: float = card.position.y + 150.0
	UiDraw.text_block(canvas, BoonTextScript.describe(boon, tier), card.position.x + 18.0, body_y, card.size.x - 36.0, 22.0, GameConstants.COLOR_TEXT_BODY, 14)
	if selected:
		UiDraw.menu_cursor(canvas, Vector2(card.position.x - 16.0, card.position.y + 42.0), cursor_flash)

func _offer_kind_slot(boon: Dictionary) -> String:
	var kind: String = str(boon.get("kind", ""))
	var slot: String = str(boon.get("slot", ""))
	if kind.is_empty():
		return ""
	return "%s%s" % [kind, " / %s" % slot if not slot.is_empty() else ""]

func _rarity_color(tier: String) -> Color:
	match tier:
		"rare":
			return GameConstants.COLOR_SKY_BLUE
		"epic":
			return GameConstants.COLOR_PURPLE_LIGHT
		"legendary":
			return GameConstants.COLOR_GOLD_BRIGHT
		_:
			return GameConstants.COLOR_LIGHT_BLUE
