class_name SettingsView
extends RefCounted

const MenuInput = preload("res://scripts/ui/menu_input.gd")
const SettingsManagerScript = preload("res://scripts/settings_manager.gd")
const UiDraw = preload("res://scripts/ui/ui_draw.gd")

const _ACTION_ROWS: Array[String] = ["left", "right", "attack", "block", "dash", "jump", "stance"]
const _ROW_FULLSCREEN: String = "fullscreen"
const _ROW_DIFFICULTY: String = "difficulty"
const _ROW_RESET: String = "reset"

var selection_idx: int = 0
var _capture_action: String = ""
var _message: String = ""
var _message_timer: float = 0.0
var _changed: bool = false

func enter() -> void:
	selection_idx = 0
	_capture_action = ""
	_message = ""
	_message_timer = 0.0
	_changed = false

func update(input: Variant, delta: float) -> Dictionary:
	if _message_timer > 0.0:
		_message_timer = maxf(0.0, _message_timer - delta)
		if _message_timer <= 0.0:
			_message = ""

	if is_capturing():
		return {"exit": false}

	var rows: Array[Dictionary] = _rows()
	selection_idx = MenuInput.step_index(selection_idx, rows.size() - 1, input)

	var hovered_idx: int = _hovered_index(input.mouse_pos)
	if hovered_idx >= 0:
		selection_idx = hovered_idx

	if input.local_cancel:
		MenuInput.play_ui_confirm()
		return {"exit": true}

	if input.accept or (input.mouse_clicked and hovered_idx >= 0):
		MenuInput.play_ui_confirm()
		_activate_row(rows[selection_idx])

	return {"exit": false}

func is_capturing() -> bool:
	return not _capture_action.is_empty()

func feed_key_event(event: InputEventKey) -> void:
	if not is_capturing() or event == null or not event.pressed or event.echo:
		return
	var physical_keycode: int = int(event.physical_keycode)
	if physical_keycode == KEY_NONE:
		physical_keycode = int(event.keycode)
	if physical_keycode == KEY_ESCAPE:
		_capture_action = ""
		_flash("Cancelled")
		return
	var result: Dictionary = SettingsManagerScript.try_bind(_capture_action, physical_keycode)
	if bool(result.get("ok", false)):
		var action: String = _capture_action
		_capture_action = ""
		_changed = true
		_flash("%s bound to %s" % [SettingsManagerScript.action_label(action), SettingsManagerScript.key_label(physical_keycode)])
	else:
		_flash(str(result.get("reason", "Could not bind")))

func consume_changed() -> bool:
	var value: bool = _changed
	_changed = false
	return value

func draw(canvas: CanvasItem, rect: Rect2, cursor_flash: float) -> void:
	UiDraw.panel(canvas, rect)
	UiDraw.text(canvas, "Settings", rect.position.x + 34.0, rect.position.y + 48.0, GameConstants.COLOR_TEXT_HEADING, 30, true)
	UiDraw.text(canvas, "Keybindings", rect.position.x + 36.0, rect.position.y + 92.0, GameConstants.COLOR_TEXT_SUBHEADING, 17)

	var rows: Array[Dictionary] = _rows()
	for i in range(rows.size()):
		_draw_row(canvas, rect, rows[i], i, cursor_flash)

	var footer_y: float = rect.end.y - 34.0
	canvas.draw_rect(Rect2(rect.position.x + 34.0, footer_y - 24.0, rect.size.x - 68.0, 1.0), Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.45), true)
	var footer: String = "W/S or arrows to browse · Enter to select · Esc to leave"
	if is_capturing():
		footer = "Press a key to bind · Esc cancels"
	UiDraw.text(canvas, footer, rect.position.x + 36.0, footer_y, GameConstants.COLOR_TEXT_HINT, 15)
	if not _message.is_empty():
		UiDraw.text(canvas, _message, rect.end.x - 360.0, footer_y, GameConstants.COLOR_TEXT_ACCENT, 15)

func _draw_row(canvas: CanvasItem, rect: Rect2, row: Dictionary, idx: int, cursor_flash: float) -> void:
	var row_rect: Rect2 = _row_rect(rect, idx)
	var selected: bool = idx == selection_idx
	var enabled: bool = bool(row.get("enabled", true))
	var border: Color = GameConstants.COLOR_PANEL_ACCENT if selected and enabled else Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.42)
	var bg_alpha: float = 0.82 if selected else 0.68
	canvas.draw_rect(row_rect, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, bg_alpha), true)
	canvas.draw_rect(row_rect, border, false, 1.0)
	if selected:
		UiDraw.menu_cursor(canvas, Vector2(row_rect.position.x - 10.0, row_rect.position.y + 29.0), cursor_flash)

	var label_color: Color = GameConstants.COLOR_TEXT_HEADING if enabled else GameConstants.COLOR_TEXT_DISABLED
	var value_color: Color = GameConstants.COLOR_TEXT_ACCENT if enabled else GameConstants.COLOR_TEXT_DISABLED
	UiDraw.text(canvas, str(row.get("label", "")), row_rect.position.x + 22.0, row_rect.position.y + 35.0, label_color, 18)
	UiDraw.text(canvas, str(row.get("value", "")), row_rect.end.x - 260.0, row_rect.position.y + 35.0, value_color, 17)
	var hint: String = str(row.get("hint", ""))
	if not hint.is_empty():
		UiDraw.text(canvas, hint, row_rect.position.x + 22.0, row_rect.position.y + 56.0, GameConstants.COLOR_TEXT_HINT if enabled else GameConstants.COLOR_TEXT_DISABLED, 13)

func _activate_row(row: Dictionary) -> void:
	if not bool(row.get("enabled", true)):
		_flash("Coming soon")
		return
	var kind: String = str(row.get("kind", ""))
	match kind:
		"action":
			_capture_action = str(row.get("action", ""))
			_message = ""
			_message_timer = 0.0
		_ROW_FULLSCREEN:
			SettingsManagerScript.set_fullscreen(not SettingsManagerScript.fullscreen())
			_changed = true
			_flash("Fullscreen %s" % ("On" if SettingsManagerScript.fullscreen() else "Off"))
		_ROW_RESET:
			SettingsManagerScript.reset_defaults()
			_changed = true
			_flash("Defaults restored")

func _rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var bindings: Dictionary = SettingsManagerScript.keybinds()
	for action in _ACTION_ROWS:
		var value: String = "Press a key..." if _capture_action == action else SettingsManagerScript.key_label(int(bindings.get(action, KEY_NONE)))
		rows.append({
			"kind": "action",
			"action": action,
			"label": SettingsManagerScript.action_label(action),
			"value": value,
			"hint": "Rebind combat control",
			"enabled": true,
		})
	rows.append({
		"kind": _ROW_FULLSCREEN,
		"label": "Fullscreen",
		"value": "On" if SettingsManagerScript.fullscreen() else "Off",
		"hint": "Apply immediately",
		"enabled": true,
	})
	rows.append({
		"kind": _ROW_DIFFICULTY,
		"label": "Difficulty",
		"value": "Normal",
		"hint": "Coming soon",
		"enabled": false,
	})
	rows.append({
		"kind": _ROW_RESET,
		"label": "Reset to Defaults",
		"value": "",
		"hint": "Restore the original combat keys",
		"enabled": true,
	})
	return rows

func _row_rect(rect: Rect2, idx: int) -> Rect2:
	return Rect2(rect.position.x + 34.0, rect.position.y + 118.0 + float(idx) * 68.0, rect.size.x - 68.0, 58.0)

func _hovered_index(mouse_pos: Vector2) -> int:
	if mouse_pos == Vector2.INF:
		return -1
	var panel: Rect2 = default_rect()
	for i in range(_rows().size()):
		if _row_rect(panel, i).has_point(mouse_pos):
			return i
	return -1

func _flash(message: String, duration: float = 1.5) -> void:
	_message = message
	_message_timer = duration

static func default_rect() -> Rect2:
	return Rect2(510.0, 92.0, 900.0, 900.0)
