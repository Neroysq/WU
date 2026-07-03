class_name LoadoutView
extends RefCounted

const UiDraw = preload("res://scripts/ui/ui_draw.gd")
const BoonTextScript = preload("res://scripts/boons/boon_text.gd")
const SLOTS: Array[String] = ["light", "heavy", "dash", "block", "stance", "jump"]

static func draw(canvas: CanvasItem, ctx: Variant, rect: Rect2, _cursor_flash: float = 0.0) -> void:
	UiDraw.panel(canvas, rect)
	UiDraw.text(canvas, "Loadout", rect.position.x + 18.0, rect.position.y + 30.0, GameConstants.COLOR_TEXT_HEADING, 20)
	if ctx == null or ctx.run_state == null:
		return

	var data: Dictionary = ctx.run_state.boon_loadout.serialize()
	var slots: Dictionary = data.get("slots", {}) as Dictionary
	var y: float = rect.position.y + 62.0
	for slot in SLOTS:
		y = _draw_record_row(canvas, rect, y, slot.capitalize(), slots.get(slot, {}) as Dictionary)

	y += 8.0
	y = _draw_record_list(canvas, rect, y, "Passives", data.get("passives", []) as Array)
	y = _draw_record_list(canvas, rect, y, "Duos", data.get("duos", []) as Array)
	_draw_record_list(canvas, rect, y, "Masteries", data.get("masteries", []) as Array)

static func _draw_record_list(canvas: CanvasItem, rect: Rect2, y: float, title: String, records: Array) -> float:
	if records.is_empty():
		return y
	UiDraw.text(canvas, title, rect.position.x + 18.0, y + 18.0, GameConstants.COLOR_TEXT_HINT, 13)
	y += 26.0
	for record in records:
		if typeof(record) == TYPE_DICTIONARY:
			y = _draw_record_row(canvas, rect, y, "", record as Dictionary)
	return y + 4.0

static func _draw_record_row(canvas: CanvasItem, rect: Rect2, y: float, label: String, identity: Dictionary) -> float:
	var row: Rect2 = Rect2(rect.position.x + 12.0, y - 16.0, rect.size.x - 24.0, 42.0)
	canvas.draw_rect(row, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.62), true)
	canvas.draw_rect(row, Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.32), false, 1.0)

	var boon_id: String = str(identity.get("boon_id", ""))
	var tier: String = str(identity.get("tier", "common"))
	var label_text: String = label
	var body: String = "Empty"
	var hint: String = ""
	var school_data: Dictionary = {}
	if not boon_id.is_empty():
		var boon: Dictionary = DataManager.get_boon(boon_id)
		body = BoonTextScript.name(boon)
		hint = "%s · %s" % [tier.capitalize(), BoonTextScript.summary(boon, tier)]
		school_data = DataManager.get_school(str(boon.get("school", "")))

	if not label_text.is_empty():
		UiDraw.text(canvas, label_text, row.position.x + 10.0, y + 2.0, GameConstants.COLOR_TEXT_HINT, 12)
		if not school_data.is_empty():
			UiDraw.school_mark(canvas, school_data, Vector2(row.position.x + 52.0, row.position.y + 9.0), 22.0)
		UiDraw.text(canvas, body, row.position.x + 82.0, y + 2.0, GameConstants.COLOR_TEXT_HEADING, 14)
		UiDraw.text(canvas, hint, row.position.x + 82.0, y + 20.0, GameConstants.COLOR_TEXT_HINT, 11)
	else:
		var body_x: float = row.position.x + 10.0
		if not school_data.is_empty():
			UiDraw.school_mark(canvas, school_data, Vector2(row.position.x + 10.0, row.position.y + 9.0), 22.0)
			body_x = row.position.x + 40.0
		UiDraw.text(canvas, body, body_x, y + 2.0, GameConstants.COLOR_TEXT_HEADING, 14)
		UiDraw.text(canvas, hint, body_x, y + 20.0, GameConstants.COLOR_TEXT_HINT, 11)
	return y + 48.0
