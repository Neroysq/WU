class_name AnimationDebugOverlay
extends RefCounted

static func draw(canvas: CanvasItem, fighter: Fighter, camera_offset: Vector2, state_name: String, norm_t: float) -> void:
	var ground: Vector2 = fighter.position + camera_offset
	canvas.draw_circle(ground, 4.0, Color(0.2, 1.0, 0.4, 0.9))
	canvas.draw_line(ground + Vector2(-40.0, 0.0), ground + Vector2(40.0, 0.0), Color(0.2, 1.0, 0.4, 0.6), 1.0)
	var label: String = "%s  t=%.2f" % [state_name, norm_t]
	var font: Font = ThemeDB.fallback_font
	if font != null:
		canvas.draw_string(font, ground + Vector2(-40.0, -8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.2, 1.0, 0.4, 0.9))

static func draw_shapes(
	canvas: CanvasItem,
	hurtbox_world: Rect2,
	capsule_a_world: Vector2,
	capsule_b_world: Vector2,
	capsule_radius: float,
	camera_offset: Vector2,
	active: bool
) -> void:
	var hurt: Rect2 = Rect2(hurtbox_world.position + camera_offset, hurtbox_world.size)
	var shape_color: Color = Color(1.0, 0.22, 0.18, 0.9) if active else Color(0.9, 0.8, 0.25, 0.55)
	var hurt_color: Color = Color(0.18, 0.7, 1.0, 0.38)
	canvas.draw_rect(hurt, hurt_color, false, 2.0)
	var a: Vector2 = capsule_a_world + camera_offset
	var b: Vector2 = capsule_b_world + camera_offset
	canvas.draw_line(a, b, shape_color, maxf(2.0, capsule_radius * 0.18), true)
	canvas.draw_arc(a, capsule_radius, 0.0, TAU, 32, shape_color, 2.0, true)
	canvas.draw_arc(b, capsule_radius, 0.0, TAU, 32, shape_color, 2.0, true)
