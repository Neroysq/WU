class_name CombatDebugOverlay
extends RefCounted

const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")

func draw(canvas: CanvasItem, player: Fighter, enemy: Fighter, buffer: Variant) -> void:
	var rect: Rect2 = Rect2(14, 14, 620, 232)
	canvas.draw_rect(rect, Color(0, 0, 0, 0.60), true)

	_text(canvas, "DEBUG", 24, 34, Color.LIME_GREEN, 18)

	var y: int = 58
	_text(canvas, "Player  HP %s  PST %s  Rage %s" % [_fmt(player.health_current), _fmt(player.posture_current), _fmt(player.rage_current)], 24, y, Color.WHITE, 14)
	y += 20
	_text(canvas, "  state=%s  atk=%s  dash=%s  inv=%s" % [
		Fighter.AnimationState.keys()[player.current_animation],
		_attack_label(player),
		player.dash_phase_label(),
		"yes" if player.is_invulnerable else "no",
	], 24, y, Color.LIGHT_BLUE, 13)
	y += 20

	_text(canvas, "Enemy   HP %s  PST %s  Rage %s" % [_fmt(enemy.health_current), _fmt(enemy.posture_current), _fmt(enemy.rage_current)], 24, y, Color.WHITE, 14)
	y += 20
	_text(canvas, "  state=%s  atk=%s  dash=%s  inv=%s" % [
		Fighter.AnimationState.keys()[enemy.current_animation],
		_attack_label(enemy),
		enemy.dash_phase_label(),
		"yes" if enemy.is_invulnerable else "no",
	], 24, y, Color.LIGHT_CORAL, 13)
	y += 24

	var buffered: String = ", ".join(buffer.pending_actions())
	if buffered.is_empty():
		buffered = "(empty)"
	_text(canvas, "InputBuffer: %s" % buffered, 24, y, Color.YELLOW, 14)
	y += 20

	_text(canvas, "Rage ready for stance: %s" % ("YES" if player.rage_current >= player.rage_max else "no"), 24, y, Color.YELLOW, 13)

func _attack_label(fighter: Fighter) -> String:
	if not fighter._attack_state.is_active():
		return "idle"
	var def: Variant = fighter._attack_state.def
	if def == null:
		return "?"
	var phase_name: String = AttackDefinitionScript.Phase.keys()[fighter._attack_state.phase()]
	return "%s %s %.0f%%" % [def.id, phase_name, fighter._attack_state.progress() * 100.0]

func _fmt(value: float) -> String:
	return "%d" % int(round(value))

func _text(canvas: CanvasItem, text: String, x: float, y: float, color: Color, size: int) -> void:
	var font: Font = Fonts.body_font()
	if font == null:
		font = ThemeDB.fallback_font
	if font == null:
		return
	canvas.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
