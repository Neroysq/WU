class_name InputTracker
extends RefCounted

var _prev_keys: Dictionary = {}
var _prev_mouse_buttons: Dictionary = {}

func clear() -> void:
	_prev_keys.clear()
	_prev_mouse_buttons.clear()

func pressed_key(keycode: int) -> bool:
	var current: bool = Input.is_key_pressed(keycode)
	var previous: bool = bool(_prev_keys.get(keycode, false))
	return current and not previous

func pressed_mouse(button_index: int) -> bool:
	var current: bool = Input.is_mouse_button_pressed(button_index)
	var previous: bool = bool(_prev_mouse_buttons.get(button_index, false))
	return current and not previous

func sync_keys(keys: Array[int]) -> void:
	for key in keys:
		_prev_keys[key] = Input.is_key_pressed(key)

func sync_mouse_buttons(buttons: Array[int]) -> void:
	for button in buttons:
		_prev_mouse_buttons[button] = Input.is_mouse_button_pressed(button)
