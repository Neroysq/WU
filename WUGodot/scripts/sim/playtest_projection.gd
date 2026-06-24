extends Node2D

var snapshot: Dictionary = {}

func configure(data: Dictionary) -> void:
	snapshot = data.duplicate(true)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), Color8(18, 20, 24), true)
	draw_line(Vector2(0, GameConstants.GROUND_Y), Vector2(1920, GameConstants.GROUND_Y), Color8(180, 166, 118), 3.0)
	var pause: String = str(snapshot.get("pause_kind", ""))
	if pause == "combat":
		_draw_combat(snapshot.get("combat", {}) as Dictionary)
	else:
		_draw_decision(snapshot)

func _draw_combat(combat_state: Dictionary) -> void:
	var player: Dictionary = combat_state.get("player", {}) as Dictionary
	var enemy: Dictionary = combat_state.get("enemy", {}) as Dictionary
	_draw_fighter(player, Color8(78, 132, 210))
	_draw_fighter(enemy, Color8(190, 78, 74))
	draw_string(ThemeDB.fallback_font, Vector2(48, 64), "combat frame %d" % int(combat_state.get("frame", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color8(232, 226, 204))

func _draw_fighter(fighter: Dictionary, color: Color) -> void:
	if fighter.is_empty():
		return
	var pos: Dictionary = fighter.get("position", {}) as Dictionary
	var x: float = float(pos.get("x", 0.0))
	var y: float = float(pos.get("y", GameConstants.GROUND_Y))
	var hp: float = float(fighter.get("hp", 0.0))
	var hp_max: float = maxf(1.0, float(fighter.get("hp_max", 1.0)))
	draw_rect(Rect2(Vector2(x - 22.0, y - 88.0), Vector2(44.0, 88.0)), color, true)
	draw_line(Vector2(x, y - 78.0), Vector2(x + float(fighter.get("facing", 1)) * 62.0, y - 58.0), Color8(222, 222, 212), 5.0)
	draw_rect(Rect2(Vector2(x - 45.0, y - 120.0), Vector2(90.0, 8.0)), Color8(48, 44, 42), true)
	draw_rect(Rect2(Vector2(x - 45.0, y - 120.0), Vector2(90.0 * clampf(hp / hp_max, 0.0, 1.0), 8.0)), Color8(98, 190, 104), true)

func _draw_decision(data: Dictionary) -> void:
	var decision: String = str(data.get("decision", ""))
	draw_string(ThemeDB.fallback_font, Vector2(64, 86), "decision: %s" % decision, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color8(232, 226, 204))
	var options: Array = data.get("options", []) as Array
	for i in range(options.size()):
		var y: float = 150.0 + float(i) * 82.0
		draw_rect(Rect2(Vector2(64, y), Vector2(760, 58)), Color8(44, 52, 60), true)
		draw_string(ThemeDB.fallback_font, Vector2(86, y + 38.0), "%d  %s" % [i, _option_label(options[i])], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color8(232, 226, 204))

func _option_label(option: Variant) -> String:
	if typeof(option) == TYPE_DICTIONARY:
		var data: Dictionary = option as Dictionary
		if data.has("label"):
			return str(data.get("label", ""))
		if data.has("boon_id"):
			return "%s %s" % [str(data.get("boon_id", "")), str(data.get("tier", ""))]
		if data.has("id"):
			return "node %s tier %s type %s" % [str(data.get("id", "")), str(data.get("tier", "")), str(data.get("type", ""))]
	return str(option)

