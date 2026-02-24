class_name CombatScene
extends Node2D

signal combat_end(victory: bool)

var _player: Fighter
var _enemy: Fighter
var _current_node: MapNode

var _combat_system: CombatSystem
var _particle_system: ParticleSystem
var _damage_number_system: DamageNumberSystem
var _camera: Camera2DHelper

var _is_paused_on_end: bool = false
var _end_message: String = ""
var _time_scale: float = 1.0
var _time_scale_recover_timer: float = 0.0
var _feedback_message: String = ""
var _feedback_timer: float = 0.0
var _is_paused: bool = false
var _debug_enabled: bool = false

var _prev_keys: Dictionary = {}

func _ready() -> void:
	_combat_system = CombatSystem.new()
	_particle_system = ParticleSystem.new(GameConstants.MAX_PARTICLES)
	_damage_number_system = DamageNumberSystem.new()
	_camera = Camera2DHelper.new()

	_combat_system.spawn_particles.connect(_on_spawn_particles)
	_combat_system.camera_shake.connect(_on_camera_shake)
	_combat_system.slow_motion.connect(_trigger_slow_mo)
	_combat_system.show_feedback.connect(_show_feedback)
	_combat_system.damage_dealt.connect(_on_damage_dealt)

	set_process(false)
	visible = false

func setup_combat(player: Fighter, node: MapNode) -> void:
	_player = player
	_current_node = node
	_enemy = EnemyFactory.create_enemy_for_node(node)

	_player.position = Vector2(360.0, GameConstants.GROUND_Y)
	_player.velocity = Vector2.ZERO
	_player.is_stunned = false
	_player.is_blocking = false
	_player.was_hit_this_swing = false
	_player.combo_window = 0.0
	_player.combo_count = 0

	_is_paused_on_end = false
	_end_message = ""
	_is_paused = false
	_feedback_message = ""
	_feedback_timer = 0.0
	_time_scale = 1.0
	_time_scale_recover_timer = 0.0

	_particle_system.clear()
	_damage_number_system.clear()
	_camera.reset()

	_prev_keys.clear()
	_sync_prev_keys()

	visible = true
	set_process(true)
	queue_redraw()

func on_enter() -> void:
	_time_scale = 1.0
	_time_scale_recover_timer = 0.0

func on_exit() -> void:
	_particle_system.clear()
	_damage_number_system.clear()

func deactivate() -> void:
	set_process(false)
	visible = false

func _process(delta: float) -> void:
	if _player == null or _enemy == null:
		return

	if _pressed(KEY_QUOTELEFT):
		_debug_enabled = not _debug_enabled

	if _pressed(KEY_P):
		_is_paused = not _is_paused

	if _feedback_timer > 0.0:
		_feedback_timer -= delta

	if _is_paused and not _is_paused_on_end:
		_sync_prev_keys()
		queue_redraw()
		return

	if _time_scale_recover_timer > 0.0:
		_time_scale_recover_timer -= delta
		_time_scale = lerp(_time_scale, 1.0, GameConstants.TIME_SCALE_RECOVERY)

	var dt: float = delta * _time_scale

	if _is_paused_on_end:
		if _pressed(KEY_ENTER) or _pressed(KEY_J):
			emit_signal("combat_end", _player.health_current > 0.0)
		_sync_prev_keys()
		queue_redraw()
		return

	_combat_system.update_facing(_player, _enemy)

	var input_state: Dictionary = _build_player_input()
	_combat_system.update_player(_player, input_state, dt, _enemy)
	_combat_system.update_ai(_enemy, _player, dt)

	_combat_system.resolve_hits(_player, _enemy)
	_combat_system.resolve_hits(_enemy, _player)

	_combat_system.clamp_world_bounds(_player)
	_combat_system.clamp_world_bounds(_enemy)

	if _player.health_current <= 0.0:
		_is_paused_on_end = true
		_end_message = "Defeat (Enter: continue)"
	elif _enemy.health_current <= 0.0:
		_is_paused_on_end = true
		_end_message = "Boss Defeated (Enter)" if _current_node.node_type == MapNode.NodeType.BOSS else "Victory (Enter)"

	if not _is_paused:
		_camera.update(delta)
		_particle_system.update(dt)
		_damage_number_system.update(dt)

	_sync_prev_keys()
	queue_redraw()

func _build_player_input() -> Dictionary:
	var left_key: int = int(_player.controls.get("left", KEY_A))
	var right_key: int = int(_player.controls.get("right", KEY_D))
	var jump_key: int = int(_player.controls.get("jump", KEY_W))
	var dash_key: int = int(_player.controls.get("dash", KEY_SPACE))
	var attack_key: int = int(_player.controls.get("attack", KEY_J))
	var block_key: int = int(_player.controls.get("block", KEY_K))

	var left_down: bool = Input.is_key_pressed(left_key)
	var right_down: bool = Input.is_key_pressed(right_key)
	var move: float = 0.0
	if left_down:
		move -= 1.0
	if right_down:
		move += 1.0

	return {
		"move": move,
		"jump_pressed": _pressed(jump_key),
		"dash_pressed": _pressed(dash_key),
		"attack_pressed": _pressed(attack_key),
		"block_pressed": _pressed(block_key),
		"block_down": Input.is_key_pressed(block_key),
	}

func _draw() -> void:
	if _player == null or _enemy == null or not visible:
		return

	var camera_offset: Vector2 = _camera.offset
	_draw_arena(camera_offset)
	_draw_fighter(_player, camera_offset)
	_draw_fighter(_enemy, camera_offset)
	_particle_system.draw(self, camera_offset)
	_damage_number_system.draw(self, camera_offset)

	_draw_hud()
	_draw_feedback()
	if _is_paused_on_end:
		_draw_end_message()
	_draw_effects()

	if _is_paused:
		_draw_pause_indicator()

	if _debug_enabled:
		_draw_debug_overlay()

func _draw_arena(offset: Vector2) -> void:
	draw_rect(Rect2(offset.x, offset.y, GameConstants.VIEW_WIDTH, GameConstants.GROUND_Y + 200.0), Color8(18, 14, 28))
	_draw_mountain_layer(40, 0.010, int(GameConstants.GROUND_Y - 140.0), Color8(24, 22, 44), offset)
	_draw_mountain_layer(28, 0.014, int(GameConstants.GROUND_Y - 100.0), Color8(32, 28, 54), offset)
	_draw_mountain_layer(16, 0.020, int(GameConstants.GROUND_Y - 70.0), Color8(44, 38, 70), offset)
	_draw_window_frame(offset)
	_draw_platform(offset)

func _draw_mountain_layer(amplitude: int, frequency: float, base_y: int, color: Color, offset: Vector2) -> void:
	for x in range(0, GameConstants.VIEW_WIDTH, 6):
		var y: float = float(base_y) + sin(float(x) * frequency) * float(amplitude)
		draw_rect(Rect2(offset.x + float(x), offset.y + y, 6.0, GameConstants.GROUND_Y + 60.0 - y), color)

func _draw_fighter(fighter: Fighter, camera_offset: Vector2) -> void:
	var animated_pos: Vector2 = fighter.position + fighter.animation_offset + camera_offset
	var body_rect: Rect2 = Rect2(animated_pos.x - fighter.half_width, animated_pos.y - fighter.height, fighter.half_width * 2.0, fighter.height)

	if fighter.is_telegraphing:
		var intensity: float = 0.5 + 0.5 * absf(sin(fighter.telegraph_timer * 15.0))
		for size in range(1, 5):
			var outline: Rect2 = Rect2(
				body_rect.position.x - size * 2.0,
				body_rect.position.y - size * 2.0,
				body_rect.size.x + size * 4.0,
				body_rect.size.y + size * 4.0
			)
			var alpha: int = int(80.0 * intensity / float(size))
			draw_rect(outline, Color8(255, 50, 50, alpha), false)

	if fighter.is_invulnerable:
		var pulse: float = sin(fighter.animation_timer * 20.0) * 0.5 + 0.5
		for i in range(1, 4):
			var glow: Rect2 = Rect2(
				body_rect.position.x - i * 3.0,
				body_rect.position.y - i * 3.0,
				body_rect.size.x + i * 6.0,
				body_rect.size.y + i * 6.0
			)
			var alpha: int = int(80.0 * pulse / float(i))
			draw_rect(glow, Color8(100, 200, 255, alpha), false)

	if fighter.is_parrying():
		var parry_intensity: float = sin(fighter.animation_timer * 25.0) * 0.3 + 0.7
		for i in range(1, 5):
			var parry_rect: Rect2 = Rect2(
				body_rect.position.x - i * 2.0,
				body_rect.position.y - i * 2.0,
				body_rect.size.x + i * 4.0,
				body_rect.size.y + i * 4.0
			)
			var alpha: int = int(120.0 * parry_intensity / float(i))
			draw_rect(parry_rect, Color8(255, 255, 100, alpha), false)

	draw_rect(body_rect, fighter.color_body, true)

	if fighter.is_hit_active():
		var weapon_start: Vector2 = Vector2(fighter.position.x + float(fighter.facing) * fighter.half_width, fighter.position.y - fighter.height * 0.4) + camera_offset
		var weapon_end: Vector2 = weapon_start + Vector2(float(fighter.facing) * fighter.attack_range, 0.0)
		var slash_color: Color = Color8(255, 198, 120, 180) if fighter.combo_count > 2 else Color8(200, 220, 255, 140)
		draw_line(weapon_start, weapon_end, slash_color, 3.0)
		if fighter.combo_count > 1:
			for trail in range(1, fighter.combo_count + 1):
				var trail_start: Vector2 = weapon_start - Vector2(float(fighter.facing) * trail * 15.0, float(trail) * 3.0)
				var trail_end: Vector2 = weapon_end - Vector2(float(fighter.facing) * trail * 20.0, float(trail) * 3.0)
				draw_line(trail_start, trail_end, Color8(255, 200, 100, int(40.0 / float(trail))), 1.0)

	if fighter.is_stunned:
		var stun_pulse: float = sin(fighter.animation_timer * 12.0) * 0.5 + 0.5
		var stun_rect: Rect2 = Rect2(body_rect.position.x, body_rect.position.y - 18.0, body_rect.size.x, 12.0)
		draw_rect(stun_rect, Color8(255, 220, 0, int(120.0 * stun_pulse)), true)

	if fighter.combo_count > 1 and fighter.combo_window > 0.0:
		_draw_text("x%d" % fighter.combo_count, body_rect.position.x + body_rect.size.x * 0.5 - 12.0, body_rect.position.y - 40.0, Color8(255, 200, 100), 16)

func _draw_hud() -> void:
	var left_panel: Rect2 = Rect2(20, 18, GameConstants.VIEW_WIDTH / 2 - 40, 98)
	var right_panel: Rect2 = Rect2(GameConstants.VIEW_WIDTH / 2 + 20, 18, GameConstants.VIEW_WIDTH / 2 - 40, 98)
	_draw_panel(left_panel)
	_draw_panel(right_panel)

	_draw_bars(_player, 34, 36, false)
	_draw_bars(_enemy, GameConstants.VIEW_WIDTH / 2 + 34, 36, true)

	_draw_text("A/D move  W jump  J attack  K block/parry  Space dash  P pause  R restart", 36, 128, Color8(170, 170, 186), 14)

func _draw_bars(fighter: Fighter, x: int, y: int, mirror: bool) -> void:
	var width: int = GameConstants.VIEW_WIDTH / 2 - 76
	var bar_h: int = 16
	var gap: int = 8

	_draw_single_bar(fighter.health_current, fighter.health_max, x, y, width, bar_h, GameConstants.COLOR_VERMILLION_RED, mirror)
	_draw_single_bar(fighter.posture_current, fighter.posture_max, x, y + (bar_h + gap), width, bar_h, GameConstants.COLOR_IMPERIAL_GOLD, mirror)
	_draw_single_bar(fighter.rage_current, fighter.rage_max, x, y + (bar_h + gap) * 2, width, bar_h, GameConstants.COLOR_JADE_GREEN, mirror)

func _draw_single_bar(current: float, max_value: float, x: int, y: int, width: int, bar_h: int, color: Color, mirror: bool) -> void:
	var pct: float = clampf(current / maxf(max_value, 0.001), 0.0, 1.0)
	var back: Rect2 = Rect2(x, y, width, bar_h)
	_draw_bar_frame(back)
	var fill: Rect2 = Rect2(x, y, width * pct, bar_h)
	draw_rect(fill, color, true)

	var value_text: String = "%d/%d" % [int(round(current)), int(round(max_value))]
	var text_x: int = x + 4
	if mirror:
		var text_width: int = _measure_text(value_text, 14)
		text_x = x + width - text_width - 4
	_draw_text(value_text, text_x + 1, y + 13, Color(0, 0, 0, 0.7), 14)
	_draw_text(value_text, text_x, y + 12, GameConstants.COLOR_SCROLL_WHITE, 14)

func _draw_feedback() -> void:
	if _feedback_timer <= 0.0:
		return
	var alpha: float = clampf(_feedback_timer, 0.0, 1.0)
	_draw_text(_feedback_message, GameConstants.VIEW_WIDTH * 0.5 - 50.0, 200.0, Color(1.0, 0.95, 0.55, alpha), 20)

func _draw_end_message() -> void:
	var rect: Rect2 = Rect2((GameConstants.VIEW_WIDTH - 420) / 2, (GameConstants.VIEW_HEIGHT - 120) / 2 - 24, 420, 120)
	_draw_panel(rect)
	_draw_text(_end_message, rect.position.x + 28.0, rect.position.y + 42.0, GameConstants.COLOR_SCROLL_WHITE, 20)

func _draw_effects() -> void:
	var border: int = 30
	var col: Color = Color(0, 0, 0, 0.45)
	draw_rect(Rect2(0, 0, GameConstants.VIEW_WIDTH, border), col)
	draw_rect(Rect2(0, GameConstants.VIEW_HEIGHT - border, GameConstants.VIEW_WIDTH, border), col)
	draw_rect(Rect2(0, 0, border, GameConstants.VIEW_HEIGHT), col)
	draw_rect(Rect2(GameConstants.VIEW_WIDTH - border, 0, border, GameConstants.VIEW_HEIGHT), col)

func _draw_platform(offset: Vector2) -> void:
	var platform_y: int = int(GameConstants.GROUND_Y) + 20
	var top: int = platform_y - 16
	draw_rect(Rect2(offset.x, offset.y + top, GameConstants.VIEW_WIDTH, 6), Color8(76, 62, 48))
	draw_rect(Rect2(offset.x, offset.y + top + 6, GameConstants.VIEW_WIDTH, 10), Color8(58, 46, 36))
	draw_rect(Rect2(offset.x, offset.y + platform_y, GameConstants.VIEW_WIDTH, 220), Color8(16, 12, 18))
	for x in range(0, GameConstants.VIEW_WIDTH, 18):
		var jitter: int = (x * 13) % 6
		draw_rect(Rect2(offset.x + x, offset.y + top + 4 + jitter, 10, 2), Color8(96, 78, 62))

func _draw_window_frame(offset: Vector2) -> void:
	var margin: int = 26
	var thickness: int = 12
	var frame_color: Color = Color8(22, 18, 24, 220)
	var trim: Color = GameConstants.COLOR_GOLD_DARK

	draw_rect(Rect2(offset.x + margin, offset.y + margin, GameConstants.VIEW_WIDTH - margin * 2, thickness), frame_color)
	draw_rect(Rect2(offset.x + margin, offset.y + GameConstants.VIEW_HEIGHT - margin - thickness, GameConstants.VIEW_WIDTH - margin * 2, thickness), frame_color)
	draw_rect(Rect2(offset.x + margin, offset.y + margin, thickness, GameConstants.VIEW_HEIGHT - margin * 2), frame_color)
	draw_rect(Rect2(offset.x + GameConstants.VIEW_WIDTH - margin - thickness, offset.y + margin, thickness, GameConstants.VIEW_HEIGHT - margin * 2), frame_color)

	draw_rect(Rect2(offset.x + margin, offset.y + margin, GameConstants.VIEW_WIDTH - margin * 2, 2), trim)
	draw_rect(Rect2(offset.x + margin, offset.y + GameConstants.VIEW_HEIGHT - margin - 2, GameConstants.VIEW_WIDTH - margin * 2, 2), trim)
	draw_rect(Rect2(offset.x + margin, offset.y + margin, 2, GameConstants.VIEW_HEIGHT - margin * 2), trim)
	draw_rect(Rect2(offset.x + GameConstants.VIEW_WIDTH - margin - 2, offset.y + margin, 2, GameConstants.VIEW_HEIGHT - margin * 2), trim)

func _draw_panel(rect: Rect2) -> void:
	draw_rect(rect, Color8(16, 14, 18, 200), true)
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 2), GameConstants.COLOR_GOLD_DARK)
	draw_rect(Rect2(rect.position.x, rect.end.y - 2, rect.size.x, 2), GameConstants.COLOR_GOLD_DARK)
	draw_rect(Rect2(rect.position.x, rect.position.y, 2, rect.size.y), GameConstants.COLOR_GOLD_DARK)
	draw_rect(Rect2(rect.end.x - 2, rect.position.y, 2, rect.size.y), GameConstants.COLOR_GOLD_DARK)
	draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, rect.size.x - 4, 1), Color8(70, 60, 80, 120))

func _draw_bar_frame(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position.x - 1, rect.position.y - 1, rect.size.x + 2, rect.size.y + 2), GameConstants.COLOR_GOLD_DARK)
	draw_rect(rect, Color8(14, 12, 16), true)
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 2), Color8(60, 52, 66))

func _draw_pause_indicator() -> void:
	draw_rect(Rect2(0, 0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), Color(0, 0, 0, 0.4), true)
	_draw_text("PAUSED", GameConstants.VIEW_WIDTH * 0.5 - 55.0, GameConstants.VIEW_HEIGHT * 0.5 - 30.0, Color.WHITE, 28)
	_draw_text("Press P to resume | ` for debug | R to restart", GameConstants.VIEW_WIDTH * 0.5 - 185.0, GameConstants.VIEW_HEIGHT * 0.5 + 10.0, Color.LIGHT_GRAY, 14)

func _draw_debug_overlay() -> void:
	draw_rect(Rect2(14, 14, 460, 138), Color(0, 0, 0, 0.55), true)
	_draw_text("DEBUG", 24, 34, Color.LIME_GREEN, 18)
	_draw_text("Player: HP %.1f  PST %.1f  Rage %.1f  State %s" % [_player.health_current, _player.posture_current, _player.rage_current, Fighter.AnimationState.keys()[_player.current_animation]], 24, 58, Color.WHITE, 14)
	_draw_text("Enemy:  HP %.1f  PST %.1f  Rage %.1f  State %s" % [_enemy.health_current, _enemy.posture_current, _enemy.rage_current, Fighter.AnimationState.keys()[_enemy.current_animation]], 24, 80, Color.WHITE, 14)
	_draw_text("Player Pos %.0f,%.0f  Vel %.0f,%.0f" % [_player.position.x, _player.position.y, _player.velocity.x, _player.velocity.y], 24, 102, Color.LIGHT_BLUE, 13)
	_draw_text("Enemy Pos %.0f,%.0f  Vel %.0f,%.0f" % [_enemy.position.x, _enemy.position.y, _enemy.velocity.x, _enemy.velocity.y], 24, 122, Color.LIGHT_CORAL, 13)

func _draw_text(text: String, x: float, y: float, color: Color, size: int = 16) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _measure_text(text: String, size: int = 16) -> int:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return text.length() * size / 2
	return int(round(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x))

func _pressed(keycode: int) -> bool:
	var current: bool = Input.is_key_pressed(keycode)
	var previous: bool = bool(_prev_keys.get(keycode, false))
	return current and not previous

func _sync_prev_keys() -> void:
	var keys: Array[int] = [KEY_QUOTELEFT, KEY_P, KEY_ENTER, KEY_J]
	if _player != null:
		var control_keys: Array[String] = ["left", "right", "attack", "block", "dash", "jump"]
		for control in control_keys:
			var key: int = int(_player.controls.get(control, KEY_NONE))
			if key != KEY_NONE and not keys.has(key):
				keys.append(key)
	for key in keys:
		_prev_keys[key] = Input.is_key_pressed(key)

func _on_spawn_particles(position: Vector2, count: int, color: Color) -> void:
	_particle_system.spawn_hit_sparks(position, count, color)

func _on_camera_shake(amount: float) -> void:
	_camera.add_shake(amount)

func _on_damage_dealt(position: Vector2, damage: float, is_critical: bool) -> void:
	_damage_number_system.spawn_damage_number(position, damage, false, is_critical)

func _trigger_slow_mo(factor: float, duration: float) -> void:
	_time_scale = clampf(factor, 0.3, 1.0)
	_time_scale_recover_timer = maxf(_time_scale_recover_timer, duration)

func _show_feedback(message: String, duration: float) -> void:
	_feedback_message = message
	_feedback_timer = duration
