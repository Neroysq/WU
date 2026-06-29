class_name InputTracker
extends RefCounted

var _prev_keys: Dictionary = {}
var _prev_physical_keys: Dictionary = {}
var _prev_mouse_buttons: Dictionary = {}
var _key_hold_ms: Dictionary = {}
var _physical_key_hold_ms: Dictionary = {}

func clear() -> void:
	_prev_keys.clear()
	_prev_physical_keys.clear()
	_prev_mouse_buttons.clear()
	_key_hold_ms.clear()
	_physical_key_hold_ms.clear()

func pressed_key(keycode: int) -> bool:
	var current: bool = Input.is_key_pressed(keycode)
	var previous: bool = bool(_prev_keys.get(keycode, false))
	return current and not previous

func released_key(keycode: int) -> bool:
	var current: bool = Input.is_key_pressed(keycode)
	var previous: bool = bool(_prev_keys.get(keycode, false))
	return (not current) and previous

func pressed_mouse(button_index: int) -> bool:
	var current: bool = Input.is_mouse_button_pressed(button_index)
	var previous: bool = bool(_prev_mouse_buttons.get(button_index, false))
	return current and not previous

func is_held(keycode: int) -> bool:
	return Input.is_key_pressed(keycode)

func pressed_physical_key(keycode: int) -> bool:
	var current: bool = Input.is_physical_key_pressed(keycode)
	var previous: bool = bool(_prev_physical_keys.get(keycode, false))
	return current and not previous

func released_physical_key(keycode: int) -> bool:
	var current: bool = Input.is_physical_key_pressed(keycode)
	var previous: bool = bool(_prev_physical_keys.get(keycode, false))
	return (not current) and previous

func is_physical_held(keycode: int) -> bool:
	return Input.is_physical_key_pressed(keycode)

func hold_duration(keycode: int) -> float:
	return float(_key_hold_ms.get(keycode, 0.0))

func physical_hold_duration(keycode: int) -> float:
	return float(_physical_key_hold_ms.get(keycode, 0.0))

func is_held_ms(keycode: int) -> float:
	return hold_duration(keycode) * 1000.0

func update_hold_timers(keys: Array[int], dt: float) -> void:
	for key in keys:
		var current: bool = Input.is_key_pressed(key)
		var previous: bool = bool(_prev_keys.get(key, false))
		if current and not previous:
			_key_hold_ms[key] = dt
		elif current and previous:
			_key_hold_ms[key] = float(_key_hold_ms.get(key, 0.0)) + dt
		elif (not current) and previous:
			pass
		else:
			_key_hold_ms[key] = 0.0

func update_physical_hold_timers(keys: Array[int], dt: float) -> void:
	for key in keys:
		var current: bool = Input.is_physical_key_pressed(key)
		var previous: bool = bool(_prev_physical_keys.get(key, false))
		if current and not previous:
			_physical_key_hold_ms[key] = dt
		elif current and previous:
			_physical_key_hold_ms[key] = float(_physical_key_hold_ms.get(key, 0.0)) + dt
		elif (not current) and previous:
			pass
		else:
			_physical_key_hold_ms[key] = 0.0

func sync_keys(keys: Array[int]) -> void:
	for key in keys:
		_prev_keys[key] = Input.is_key_pressed(key)

func sync_physical_keys(keys: Array[int]) -> void:
	for key in keys:
		_prev_physical_keys[key] = Input.is_physical_key_pressed(key)

func sync_mouse_buttons(buttons: Array[int]) -> void:
	for button in buttons:
		_prev_mouse_buttons[button] = Input.is_mouse_button_pressed(button)
