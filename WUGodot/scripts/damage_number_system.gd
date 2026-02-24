class_name DamageNumberSystem
extends RefCounted

var _damage_numbers: Array[Dictionary] = []
var _max_numbers: int = 50
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(max_numbers: int = 50) -> void:
	_max_numbers = max_numbers
	_rng.randomize()

func spawn_damage_number(position: Vector2, damage: float, is_healing: bool = false, is_critical: bool = false) -> void:
	if _damage_numbers.size() >= _max_numbers:
		_damage_numbers.remove_at(0)

	var color: Color = Color8(255, 100, 100)
	if is_healing:
		color = Color8(100, 255, 100)
	elif is_critical:
		color = Color8(255, 200, 50)

	var x_offset: float = _rng.randf_range(-10.0, 10.0)
	var y_offset: float = _rng.randf_range(-5.0, 5.0)

	_damage_numbers.append({
		"position": position + Vector2(x_offset, y_offset),
		"value": damage,
		"color": color,
		"timer": 0.0,
		"max_time": 1.2,
		"critical": is_critical,
	})

func update(dt: float) -> void:
	for i in range(_damage_numbers.size() - 1, -1, -1):
		var number: Dictionary = _damage_numbers[i]
		number["timer"] = float(number["timer"]) + dt

		var timer: float = number["timer"]
		var max_time: float = float(number["max_time"])
		var x_drift: float = sin(timer * 3.0) * 20.0 * dt
		var y_drift: float = -60.0 * dt * (1.0 - timer / maxf(max_time, 0.001))
		number["position"] = (number["position"] as Vector2) + Vector2(x_drift, y_drift)

		if timer >= max_time:
			_damage_numbers.remove_at(i)
		else:
			_damage_numbers[i] = number

func draw(canvas: CanvasItem, offset: Vector2 = Vector2.ZERO) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	for number in _damage_numbers:
		var value_text: String = str(int(round(float(number["value"]))))
		if bool(number["critical"]):
			value_text += "!"

		var timer: float = float(number["timer"])
		var max_time: float = float(number["max_time"])
		var alpha: float = 1.0
		if timer > max_time * 0.7:
			alpha = 1.0 - (timer - max_time * 0.7) / (max_time * 0.3)

		var scale: float = 1.0
		if timer < 0.1:
			scale = 1.5 - (timer / 0.1) * 0.5

		var color: Color = number["color"]
		color.a *= clampf(alpha, 0.0, 1.0)

		var font_size: int = maxi(10, int(round(18.0 * scale)))
		var pos: Vector2 = (number["position"] as Vector2) + offset

		var shadow: Color = Color(0, 0, 0, color.a * 0.5)
		canvas.draw_string(font, pos + Vector2(1, 1), value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, shadow)
		canvas.draw_string(font, pos, value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func clear() -> void:
	_damage_numbers.clear()
