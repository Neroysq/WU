class_name MenuInput
extends RefCounted

var up: bool = false
var down: bool = false
var left: bool = false
var right: bool = false
var accept: bool = false
var local_cancel: bool = false
var restart: bool = false
var reload_data: bool = false
var number: int = -1
var mouse_pos: Vector2 = Vector2.INF
var mouse_clicked: bool = false

static func from_tracker(t: InputTracker, viewport: Viewport) -> Variant:
	var m: Variant = new()
	m.up = t.pressed_key(KEY_W) or t.pressed_key(KEY_UP)
	m.down = t.pressed_key(KEY_S) or t.pressed_key(KEY_DOWN)
	m.left = t.pressed_key(KEY_A) or t.pressed_key(KEY_LEFT)
	m.right = t.pressed_key(KEY_D) or t.pressed_key(KEY_RIGHT)
	m.accept = t.pressed_key(KEY_J) or t.pressed_key(KEY_ENTER) or t.pressed_key(KEY_KP_ENTER) or t.pressed_key(KEY_SPACE)
	m.local_cancel = t.pressed_key(KEY_Q) or t.pressed_key(KEY_ESCAPE)
	m.restart = t.pressed_key(KEY_R)
	m.reload_data = t.pressed_key(KEY_F5)
	var number_keys: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
	var keypad_keys: Array[int] = [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9]
	for i in range(number_keys.size()):
		if t.pressed_key(number_keys[i]) or t.pressed_key(keypad_keys[i]):
			m.number = i + 1
			break
	m.mouse_pos = viewport.get_mouse_position()
	m.mouse_clicked = t.pressed_mouse(MOUSE_BUTTON_LEFT)
	return m

static func step_index(idx: int, max_idx: int, input: Variant) -> int:
	if input.up:
		idx = maxi(0, idx - 1)
	if input.down:
		idx = mini(max_idx, idx + 1)
	return idx
