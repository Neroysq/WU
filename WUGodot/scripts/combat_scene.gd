class_name CombatScene
extends Node2D

const CombatDebugOverlayScript = preload("res://scripts/combat_debug_overlay.gd")
const InputBufferScript = preload("res://scripts/input_buffer.gd")
const BackgroundRendererScript = preload("res://scripts/visual/background_renderer.gd")
const AnimationClockScript = preload("res://scripts/visual/animation_clock.gd")
const AnimationDebugOverlayScript = preload("res://scripts/visual/animation_debug_overlay.gd")
const FighterPresenterScript = preload("res://scripts/visual/fighter_presenter.gd")
const PresentationCollisionScript = preload("res://scripts/visual/presentation_collision.gd")

const ENABLE_AUTHORED_PLAYER_HITBOXES: bool = false

signal combat_end(victory: bool)

var _player: Fighter
var _enemy: Fighter
var _current_node: MapNode

var _combat_system: CombatSystem
var _particle_system: ParticleSystem
var _damage_number_system: DamageNumberSystem
var _camera: Camera2DHelper
var _asset_catalog: AssetCatalog
var _player_visual: FighterVisual
var _enemy_visual: FighterVisual
var _player_presenter: Variant = null
var _background: Variant = null
var _hit_geometry: Variant = null

var _is_paused_on_end: bool = false
var _end_message: String = ""
var _time_scale: float = 1.0
var _hitstop_timer: float = 0.0
var _slow_mo_timer: float = 0.0
var _slow_mo_factor: float = 1.0
var _feedback_message: String = ""
var _feedback_timer: float = 0.0
var _feedback_frame: int = -1
var _is_paused: bool = false
var _debug_enabled: bool = false
var _heavy_committed_attack: bool = false
var _boss_death_timer: float = 0.0
var _boss_death_triggered: bool = false
var _boss_beat_message: String = ""
var _boss_beat_timer: float = 0.0
var _controls_legend_timer: float = 0.0

var _input_tracker: InputTracker = InputTracker.new()
var _input_buffer: Variant = InputBufferScript.new()
var _debug_overlay: Variant = CombatDebugOverlayScript.new()

func _ready() -> void:
	_combat_system = CombatSystem.new()
	_hit_geometry = PresentationCollisionScript.new()
	_hit_geometry.register_from_manifest_file("hu", "res://assets/animation_manifests/hu.manifest.json")
	_combat_system.hit_geometry = _hit_geometry
	_particle_system = ParticleSystem.new(GameConstants.MAX_PARTICLES)
	_damage_number_system = DamageNumberSystem.new()
	_camera = Camera2DHelper.new()
	_asset_catalog = AssetCatalog.new()
	_player_visual = FighterVisual.new(_asset_catalog)
	_player_presenter = FighterPresenterScript.new(_asset_catalog)
	add_child(_player_presenter)
	_player_presenter.visible = false
	_enemy_visual = FighterVisual.new(_asset_catalog)
	_background = BackgroundRendererScript.new()

	_combat_system.spawn_particles.connect(_on_spawn_particles)
	_combat_system.camera_shake.connect(_on_camera_shake)
	_combat_system.slow_motion.connect(_trigger_slow_mo)
	_combat_system.show_feedback.connect(_show_feedback)
	_combat_system.damage_dealt.connect(_on_damage_dealt)
	_combat_system.hitstop.connect(_trigger_hitstop)

	set_process(false)
	visible = false

func setup_combat(player: Fighter, node: MapNode, show_controls_legend: bool = false) -> void:
	_player = player
	_current_node = node
	_enemy = EnemyFactory.create_enemy_for_node(node)
	var arena_id: String = "chapter1_boss_clearing" if node.node_type == MapNode.NodeType.BOSS else "chapter1_bamboo_dusk"
	if _background != null:
		_background.set_arena(arena_id)
	_player_visual.configure(DataManager.get_visual_profile(_player.visual_profile_id), _player)
	_player_presenter.configure(
		"res://assets/animation_manifests/hu.manifest.json",
		"res://assets/animation_graphs/humanoid.graph.json",
		[
			"res://assets/animation_clips/hu_attack_light.timeline.json",
			"res://assets/animation_clips/idle.timeline.json",
			"res://assets/animation_clips/walk.timeline.json",
		],
		float(DataManager.get_visual_profile(_player.visual_profile_id).get("scale", 1.625))
	)
	var presenter_callback: Callable = Callable(self, "_on_player_timeline_event")
	if not _player_presenter.is_connected("timeline_event", presenter_callback):
		_player_presenter.connect("timeline_event", presenter_callback)
	_enemy_visual.configure(DataManager.get_visual_profile(_enemy.visual_profile_id), _enemy)
	_connect_attack_visual(_player, _player_visual)
	_connect_attack_visual(_enemy, _enemy_visual)

	_player.reset_for_combat()
	_enemy.reset_for_combat()
	# Placeholder anchors currently extend Hu's live reach roughly 2x. Keep the
	# tested geometry path dormant until measured per-pose anchors replace them.
	if _hit_geometry != null and ENABLE_AUTHORED_PLAYER_HITBOXES:
		_hit_geometry.register_fighter(_player, "hu")
	_player.position = Vector2(360.0, GameConstants.GROUND_Y)
	_enemy.position = Vector2(1560.0, GameConstants.GROUND_Y)
	_player.facing = 1
	_enemy.facing = -1

	_is_paused_on_end = false
	_end_message = ""
	_is_paused = false
	_feedback_message = ""
	_feedback_timer = 0.0
	_feedback_frame = -1
	_time_scale = 1.0
	_hitstop_timer = 0.0
	_slow_mo_timer = 0.0
	_slow_mo_factor = 1.0
	_heavy_committed_attack = false
	_boss_death_timer = 0.0
	_boss_death_triggered = false
	_boss_beat_message = ""
	_boss_beat_timer = 0.0
	_controls_legend_timer = 6.0 if show_controls_legend else 0.0

	_particle_system.clear()
	_damage_number_system.clear()
	_camera.reset()

	_input_tracker.clear()
	_input_buffer.clear()
	_sync_input_tracker()

	visible = true
	set_process(true)
	queue_redraw()

func on_enter() -> void:
	_time_scale = 1.0
	_hitstop_timer = 0.0
	_slow_mo_timer = 0.0
	_slow_mo_factor = 1.0

func on_exit() -> void:
	_particle_system.clear()
	_damage_number_system.clear()

func deactivate() -> void:
	set_process(false)
	visible = false

func _process(delta: float) -> void:
	if _player == null or _enemy == null:
		return

	if _input_tracker.pressed_key(KEY_QUOTELEFT):
		_debug_enabled = not _debug_enabled

	if _input_tracker.pressed_key(KEY_P):
		_is_paused = not _is_paused

	if _feedback_timer > 0.0:
		_feedback_timer -= delta
	if _boss_beat_timer > 0.0:
		_boss_beat_timer -= delta
	if _controls_legend_timer > 0.0:
		_controls_legend_timer = maxf(0.0, _controls_legend_timer - delta)

	if _is_paused and not _is_paused_on_end:
		_sync_input_tracker()
		queue_redraw()
		return

	if _hitstop_timer > 0.0:
		_hitstop_timer -= delta
		_time_scale = 0.0
	elif _slow_mo_timer > 0.0:
		_slow_mo_timer -= delta
		_time_scale = _slow_mo_factor
	else:
		if _time_scale < 1.0:
			_time_scale = lerp(_time_scale, 1.0, GameConstants.TIME_SCALE_RECOVERY)
			if _time_scale > 0.99:
				_time_scale = 1.0
		_slow_mo_factor = 1.0

	var dt: float = delta * _time_scale
	var clocks: Dictionary = AnimationClockScript.resolve(delta, _time_scale)
	var input_active: bool = bool(clocks["input_active"])

	if _is_paused_on_end:
		if _input_tracker.pressed_key(KEY_ENTER) or _input_tracker.pressed_key(KEY_J):
			emit_signal("combat_end", _player.health_current > 0.0)
		_sync_input_tracker()
		queue_redraw()
		return

	if _boss_death_triggered:
		_boss_death_timer -= delta
		if _boss_death_timer <= 0.0:
			_boss_death_triggered = false
			_is_paused_on_end = true
			_end_message = "Boss Defeated (Enter)"
			_sync_input_tracker()
			queue_redraw()
			return
		if not _is_paused:
			_camera.update(delta)
			_particle_system.update(dt)
			_damage_number_system.update(dt)
		_sync_input_tracker()
		queue_redraw()
		return

	_combat_system.update_facing(_player, _enemy)

	var attack_key: int = int(_player.controls.get("attack", KEY_J))
	if input_active:
		_input_tracker.update_hold_timers([attack_key], delta)
		_input_buffer.advance(delta)

	if not input_active:
		if not _is_paused:
			_camera.update(delta)
			_particle_system.update(dt)
			_damage_number_system.update(dt)
			_player_visual.update(_player, dt)
			_enemy_visual.update(_enemy, dt)
			_update_player_presenter(float(clocks["combat"]), float(clocks["presentation"]))
		_sync_input_tracker()
		queue_redraw()
		return

	var input_state: Dictionary = _build_player_input(input_active)
	_combat_system.update_player(_player, input_state, dt, _enemy)
	_combat_system.update_ai(_enemy, _player, dt)

	_combat_system.resolve_hits(_player, _enemy)
	_combat_system.resolve_hits(_enemy, _player)
	_combat_system.tick_effects(_player, dt)
	_combat_system.tick_effects(_enemy, dt)

	_combat_system.clamp_world_bounds(_player)
	_combat_system.clamp_world_bounds(_enemy)

	if _player.health_current <= 0.0:
		_is_paused_on_end = true
		_end_message = "Defeat (Enter: continue)"
	elif _enemy.health_current <= 0.0:
		if _player.technique_engine != null:
			_player.technique_engine.on_kill(_player)
			if _current_node.node_type == MapNode.NodeType.BOSS:
				_boss_death_triggered = true
				_boss_death_timer = 1.0
				_trigger_slow_mo(0.2, 1.0)
				_on_camera_shake(20.0)
				_show_boss_beat("破山!", 1.1)
				_particle_system.spawn_hit_sparks(_enemy.position + Vector2(0.0, -_enemy.height * 0.5), 40, GameConstants.COLOR_GOLD_BRIGHT)
				_particle_system.spawn_hit_sparks(_enemy.position + Vector2(0.0, -_enemy.height * 0.3), 20, GameConstants.COLOR_CRIMSON)
		else:
			_is_paused_on_end = true
			_end_message = "Victory (Enter)"

	if not _is_paused:
		_camera.update(delta)
		_particle_system.update(dt)
		_damage_number_system.update(dt)
		_player_visual.update(_player, dt)
		_enemy_visual.update(_enemy, dt)
		_update_player_presenter(float(clocks["combat"]), float(clocks["presentation"]))

	_sync_input_tracker()
	queue_redraw()

func _build_player_input(input_active: bool = true) -> Dictionary:
	if not input_active:
		return _neutral_input()

	var left_key: int = int(_player.controls.get("left", KEY_A))
	var right_key: int = int(_player.controls.get("right", KEY_D))
	var jump_key: int = int(_player.controls.get("jump", KEY_W))
	var dash_key: int = int(_player.controls.get("dash", KEY_SPACE))
	var attack_key: int = int(_player.controls.get("attack", KEY_J))
	var block_key: int = int(_player.controls.get("block", KEY_K))
	var stance_key: int = int(_player.controls.get("stance", KEY_NONE))

	if _input_tracker.pressed_key(jump_key):
		_input_buffer.record("jump")
	if _input_tracker.pressed_key(dash_key):
		_input_buffer.record("dash")
	if _input_tracker.pressed_key(block_key):
		_input_buffer.record("parry")
	if stance_key != KEY_NONE and _input_tracker.pressed_key(stance_key):
		_input_buffer.record("stance")

	var attack_press_edge: bool = _input_tracker.pressed_key(attack_key)
	var attack_release_edge: bool = _input_tracker.released_key(attack_key)
	var attack_held: bool = Input.is_key_pressed(attack_key)
	var attack_hold: float = _input_tracker.hold_duration(attack_key)

	if attack_press_edge:
		_heavy_committed_attack = false

	if attack_held and attack_hold >= 0.25 and not _heavy_committed_attack:
		_input_buffer.record("heavy")
		_heavy_committed_attack = true

	if attack_release_edge and not _heavy_committed_attack:
		_input_buffer.record("light")
	if attack_release_edge:
		_heavy_committed_attack = false

	var can_act_now: bool = _player.can_attack()
	var jump_pressed: bool = _input_buffer.consume("jump") if _player.can_jump() else false
	var dash_pressed: bool = _input_buffer.consume("dash") if _player.can_dash() else false
	var parry_pressed: bool = _input_buffer.consume("parry")
	var light_pressed: bool = _input_buffer.consume("light") if can_act_now else false
	var heavy_pressed: bool = _input_buffer.consume("heavy") if can_act_now else false
	var stance_pressed: bool = _input_buffer.consume("stance")

	var left_down: bool = Input.is_key_pressed(left_key)
	var right_down: bool = Input.is_key_pressed(right_key)
	var move: float = 0.0
	if left_down:
		move -= 1.0
	if right_down:
		move += 1.0

	return {
		"move": move,
		"jump_pressed": jump_pressed,
		"dash_pressed": dash_pressed,
		"light_pressed": light_pressed,
		"heavy_pressed": heavy_pressed,
		"block_pressed": parry_pressed,
		"block_down": Input.is_key_pressed(block_key),
		"stance_pressed": stance_pressed,
		"attack_holding": attack_held,
		"attack_hold_duration": attack_hold,
	}

func _neutral_input() -> Dictionary:
	return {
		"move": 0.0,
		"jump_pressed": false,
		"dash_pressed": false,
		"light_pressed": false,
		"heavy_pressed": false,
		"block_pressed": false,
		"block_down": false,
		"stance_pressed": false,
		"attack_holding": false,
		"attack_hold_duration": 0.0,
	}

func _update_player_presenter(combat_dt: float, presentation_dt: float) -> void:
	if _player_presenter == null or _player == null:
		return

	var state_name: String = _resolve_player_state_name()
	if _player_presenter.handles_state(state_name):
		_player_presenter.visible = true
		_player_presenter.update(_player, state_name, combat_dt, presentation_dt, _camera.offset)
	else:
		_player_presenter.visible = false

func _resolve_player_state_name() -> String:
	match _player.current_animation:
		Fighter.AnimationState.ATTACKING_LIGHT:
			return "ATTACKING_LIGHT"
		Fighter.AnimationState.WALKING:
			return "WALKING"
		Fighter.AnimationState.IDLE:
			return "IDLE"
		_:
			return "FALLBACK"

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
	_draw_boss_beat()
	if _is_paused_on_end:
		_draw_end_message()
	_draw_effects()

	if _is_paused:
		_draw_pause_indicator()
		_draw_controls_legend(1.0)

	if _debug_enabled:
		_draw_debug_overlay()

func _draw_arena(offset: Vector2) -> void:
	if _background != null:
		_background.draw(self, offset, {})
	else:
		draw_rect(Rect2(offset.x, offset.y, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), GameConstants.COLOR_INK_BLACK)
	_draw_platform(offset)

func _draw_fighter(fighter: Fighter, camera_offset: Vector2) -> void:
	var visual: FighterVisual = _get_visual_for(fighter)
	var body_rect: Rect2 = visual.get_body_rect(fighter, camera_offset)

	var telegraph_color: Color = fighter.current_telegraph_color()
	if telegraph_color.a > 0.0:
		var def: Variant = fighter._attack_state.def
		var windup_progress: float = clampf(fighter._attack_state.elapsed / maxf(def.windup_end, 0.001), 0.0, 1.0)
		var intensity: float = 0.4 + 0.6 * windup_progress
		for size in range(1, 5):
			var outline: Rect2 = Rect2(
				body_rect.position.x - size * 2.0,
				body_rect.position.y - size * 2.0,
				body_rect.size.x + size * 4.0,
				body_rect.size.y + size * 4.0
			)
			var flash_color: Color = Color(telegraph_color.r, telegraph_color.g, telegraph_color.b, telegraph_color.a * intensity / float(size))
			draw_rect(outline, flash_color, false)

	if fighter.is_invulnerable:
		var pulse: float = sin(fighter.animation_timer * 20.0) * 0.5 + 0.5
		var center: Vector2 = body_rect.get_center()
		var base_radius: float = maxf(body_rect.size.x, body_rect.size.y) * 0.45
		for i in range(1, 4):
			var alpha: float = 0.22 * pulse / float(i)
			draw_arc(center, base_radius + float(i) * 10.0 + pulse * 3.0, 0.0, TAU, 32, Color(GameConstants.COLOR_LIGHT_BLUE.r, GameConstants.COLOR_LIGHT_BLUE.g, GameConstants.COLOR_LIGHT_BLUE.b, alpha), 2.0, true)

	if fighter.is_parrying():
		var parry_intensity: float = sin(fighter.animation_timer * 25.0) * 0.3 + 0.7
		var center: Vector2 = body_rect.get_center()
		var parry_radius: float = maxf(body_rect.size.x, body_rect.size.y) * 0.42
		for i in range(1, 5):
			var alpha: float = 0.34 * parry_intensity / float(i)
			draw_arc(center, parry_radius + float(i) * 6.0, 0.0, TAU, 32, Color(GameConstants.COLOR_GOLD_BRIGHT.r, GameConstants.COLOR_GOLD_BRIGHT.g, GameConstants.COLOR_GOLD_BRIGHT.b, alpha), 2.0, true)

	if fighter == _player and _player_presenter != null and _player_presenter.visible:
		if _debug_enabled:
			AnimationDebugOverlayScript.draw(self, fighter, camera_offset, _resolve_player_state_name(), _player_presenter.current_norm_t())
	else:
		visual.draw(self, fighter, camera_offset)

	if fighter == _player and _debug_enabled and _hit_geometry != null:
		var cap: Dictionary = _hit_geometry.debug_capsule_world(_player)
		if not cap.is_empty():
			AnimationDebugOverlayScript.draw_shapes(
				self,
				_hit_geometry.debug_hurtbox_world(_enemy),
				cap["a"] as Vector2,
				cap["b"] as Vector2,
				float(cap["r"]),
				camera_offset,
				_player.is_hit_active()
			)

	if fighter.is_stunned:
		var stun_pulse: float = sin(fighter.animation_timer * 12.0) * 0.5 + 0.5
		var stun_rect: Rect2 = Rect2(body_rect.position.x, body_rect.position.y - 18.0, body_rect.size.x, 12.0)
		draw_rect(stun_rect, Color(GameConstants.COLOR_IMPERIAL_GOLD.r, GameConstants.COLOR_IMPERIAL_GOLD.g, GameConstants.COLOR_IMPERIAL_GOLD.b, 120.0 * stun_pulse / 255.0), true)

	if fighter.combo_count > 1 and fighter.combo_window > 0.0:
		_draw_text("x%d" % fighter.combo_count, body_rect.position.x + body_rect.size.x * 0.5 - 12.0, body_rect.position.y - 40.0, GameConstants.COLOR_IMPERIAL_GOLD, 16)

	if fighter.bleed_timer > 0.0:
		var bleed_pulse: float = sin(fighter.animation_timer * 8.0) * 0.4 + 0.6
		var bleed_rect: Rect2 = Rect2(body_rect.position.x, body_rect.end.y + 4.0, body_rect.size.x, 4.0)
		draw_rect(bleed_rect, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 160.0 * bleed_pulse / 255.0), true)

	if fighter.is_grabbed:
		var grab_pulse: float = sin(fighter.animation_timer * 15.0) * 0.5 + 0.5
		var grab_rect: Rect2 = Rect2(
			body_rect.position.x - 4.0,
			body_rect.position.y - 4.0,
			body_rect.size.x + 8.0,
			body_rect.size.y + 8.0
		)
		draw_rect(grab_rect, Color(GameConstants.COLOR_CRIMSON.r, GameConstants.COLOR_CRIMSON.g, GameConstants.COLOR_CRIMSON.b, 120.0 * grab_pulse / 255.0), false, 3.0)

func _draw_hud() -> void:
	var left_panel: Rect2 = Rect2(20, 18, GameConstants.VIEW_WIDTH / 2 - 40, 98)
	var right_panel: Rect2 = Rect2(GameConstants.VIEW_WIDTH / 2 + 20, 18, GameConstants.VIEW_WIDTH / 2 - 40, 98)
	_draw_panel(left_panel)
	_draw_panel(right_panel)

	_draw_bars(_player, 34, 36, false)
	_draw_bars(_enemy, GameConstants.VIEW_WIDTH / 2 + 34, 36, true)
	var enemy_name: String = _enemy.name
	if not _enemy.archetype_id.is_empty():
		var enemy_data: Dictionary = DataManager.get_enemy(_enemy.archetype_id)
		var cn: String = str(enemy_data.get("name_cn", ""))
		if not cn.is_empty():
			enemy_name = "%s %s" % [cn, _enemy.name]
	_draw_text(enemy_name, GameConstants.VIEW_WIDTH / 2 + 34, 30, GameConstants.COLOR_TEXT_HEADING, 14)

	if _enemy.boss_controller != null:
		var phase_text: String = "Phase %d" % _enemy.boss_controller.current_phase
		var phase_color: Color = GameConstants.COLOR_TEXT_ACCENT if _enemy.boss_controller.current_phase == 2 else GameConstants.COLOR_TEXT_SUBHEADING
		_draw_text(phase_text, GameConstants.VIEW_WIDTH - 120, 30, phase_color, 14)

	var show_controls_legend: bool = _controls_legend_timer > 0.0 or _is_paused or _is_paused_on_end
	if show_controls_legend:
		var legend_alpha: float = 1.0 if _is_paused or _is_paused_on_end else clampf(_controls_legend_timer, 0.0, 1.0)
		_draw_controls_legend(legend_alpha)
	if _player != null and _player.technique_engine != null:
		var tech_ids: Array[String] = _player.technique_engine.technique_ids()
		if not tech_ids.is_empty():
			var show_full_loadout: bool = _is_paused or _is_paused_on_end or _debug_enabled
			if show_full_loadout:
				var tech_panel_height: float = 56.0 + float(tech_ids.size()) * 18.0
				var tech_panel: Rect2 = Rect2(24.0, float(GameConstants.VIEW_HEIGHT) - tech_panel_height - 28.0, 360.0, tech_panel_height)
				_draw_panel(tech_panel)
				var tech_y: float = tech_panel.position.y + 28.0
				_draw_text("技藝 Techniques", tech_panel.position.x + 18.0, tech_y, GameConstants.COLOR_TEXT_SUBHEADING, 15, true)
				tech_y += 18.0
				for tech_id in tech_ids:
					var tech_data: Dictionary = DataManager.get_technique(tech_id)
					var display: String = "%s %s" % [str(tech_data.get("name_cn", tech_id)), str(tech_data.get("name_en", ""))]
					var tech_color: Color = GameConstants.COLOR_LIGHT_BLUE
					if tech_id.begins_with("D"):
						tech_color = GameConstants.COLOR_GOLD_BRIGHT
					elif tech_id.begins_with("B"):
						tech_color = GameConstants.COLOR_SKY_BLUE
					_draw_text(display, tech_panel.position.x + 18.0, tech_y, tech_color, 13)
					tech_y += 16.0
			else:
				var compact_panel: Rect2 = Rect2(24.0, float(GameConstants.VIEW_HEIGHT) - 84.0, 280.0, 56.0)
				_draw_panel(compact_panel)
				_draw_text("技藝 %d" % tech_ids.size(), compact_panel.position.x + 16.0, compact_panel.position.y + 24.0, GameConstants.COLOR_TEXT_SUBHEADING, 15, true)
				_draw_text("Pause to inspect full loadout", compact_panel.position.x + 16.0, compact_panel.position.y + 44.0, GameConstants.COLOR_TEXT_HINT, 13)

		if _player.technique_engine.is_stance_active():
			var stance_id: String = _player.technique_engine.active_stance()
			var stance_label: String = "醉拳" if stance_id == "D1" else "虎形"
			var pulse: float = sin(_player.animation_timer * 6.0) * 0.3 + 0.7
			_draw_text("STANCE: %s" % stance_label, 36.0, 104.0, Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, pulse), 16)

func _draw_controls_legend(alpha: float) -> void:
	var controls_panel: Rect2 = Rect2(520.0, float(GameConstants.VIEW_HEIGHT) - 70.0, 880.0, 44.0)
	var panel_bg: Color = Color(GameConstants.COLOR_PANEL_BG.r, GameConstants.COLOR_PANEL_BG.g, GameConstants.COLOR_PANEL_BG.b, 0.88 * alpha)
	var panel_border: Color = Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, alpha)
	var accent: Color = Color(GameConstants.COLOR_PANEL_ACCENT.r, GameConstants.COLOR_PANEL_ACCENT.g, GameConstants.COLOR_PANEL_ACCENT.b, 0.75 * alpha)
	var text_color: Color = Color(GameConstants.COLOR_TEXT_BODY.r, GameConstants.COLOR_TEXT_BODY.g, GameConstants.COLOR_TEXT_BODY.b, alpha)
	draw_rect(controls_panel, panel_bg, true)
	draw_rect(controls_panel, panel_border, false, 2.0)
	draw_rect(Rect2(controls_panel.position.x + 2.0, controls_panel.position.y, controls_panel.size.x - 4.0, 1.0), accent, true)
	_draw_text("A/D move  W jump  J tap/hold  K block/parry  Space dash  L stance  P pause  R restart", controls_panel.position.x + 18.0, controls_panel.position.y + 28.0, text_color, 15)

func _draw_bars(fighter: Fighter, x: int, y: int, mirror: bool) -> void:
	var width: int = GameConstants.VIEW_WIDTH / 2 - 76
	var bar_h: int = 16
	var gap: int = 8

	_draw_single_bar(fighter.health_current, fighter.health_max, x, y, width, bar_h, GameConstants.COLOR_HEALTH, mirror)
	_draw_single_bar(fighter.posture_current, fighter.posture_max, x, y + (bar_h + gap), width, bar_h, GameConstants.COLOR_POSTURE, mirror)
	_draw_single_bar(fighter.rage_current, fighter.rage_max, x, y + (bar_h + gap) * 2, width, bar_h, GameConstants.COLOR_RAGE, mirror)

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
	_draw_text(value_text, text_x, y + 12, GameConstants.COLOR_TEXT_HEADING, 14)

func _draw_feedback() -> void:
	if _feedback_timer <= 0.0:
		return
	var alpha: float = clampf(_feedback_timer, 0.0, 1.0)
	var text_width: float = _measure_text(_feedback_message, 22)
	_draw_text(_feedback_message, GameConstants.VIEW_WIDTH * 0.5 - text_width * 0.5, 200.0, Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, alpha), 22)

func _draw_boss_beat() -> void:
	if _boss_beat_timer <= 0.0 or _boss_beat_message.is_empty():
		return
	var alpha: float = clampf(_boss_beat_timer / 1.1, 0.0, 1.0)
	var pulse: float = 0.7 + 0.3 * sin((1.1 - _boss_beat_timer) * 12.0)
	var rect: Rect2 = Rect2(GameConstants.VIEW_WIDTH * 0.5 - 250.0, 118.0, 500.0, 120.0)
	draw_rect(rect, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.58 * alpha), true)
	draw_rect(rect, Color(GameConstants.COLOR_PANEL_ACCENT.r, GameConstants.COLOR_PANEL_ACCENT.g, GameConstants.COLOR_PANEL_ACCENT.b, 0.75 * alpha), false, 2.0)
	_draw_text(_boss_beat_message, rect.position.x + rect.size.x * 0.5 - _measure_text(_boss_beat_message, 52, true) * 0.5, rect.position.y + 60.0, Color(GameConstants.COLOR_TEXT_HEADING.r, GameConstants.COLOR_TEXT_HEADING.g, GameConstants.COLOR_TEXT_HEADING.b, alpha), 52, true)
	_draw_text("Iron Bear falls", rect.position.x + rect.size.x * 0.5 - _measure_text("Iron Bear falls", 18) * 0.5, rect.position.y + 92.0, Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, alpha * pulse), 18)

func _draw_end_message() -> void:
	var rect: Rect2 = Rect2((GameConstants.VIEW_WIDTH - 420) / 2, (GameConstants.VIEW_HEIGHT - 120) / 2 - 24, 420, 120)
	_draw_panel(rect)
	_draw_text(_end_message, rect.position.x + 28.0, rect.position.y + 42.0, GameConstants.COLOR_TEXT_HEADING, 20)

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
	draw_rect(Rect2(offset.x, offset.y + top, GameConstants.VIEW_WIDTH, 6), GameConstants.COLOR_PANEL_BORDER)
	draw_rect(Rect2(offset.x, offset.y + top + 6, GameConstants.VIEW_WIDTH, 10), GameConstants.COLOR_MOUNTAIN_BLUE)
	draw_rect(Rect2(offset.x, offset.y + platform_y, GameConstants.VIEW_WIDTH, 220), GameConstants.COLOR_INK_BLACK)
	for x in range(0, GameConstants.VIEW_WIDTH, 18):
		var jitter: int = (x * 13) % 6
		draw_rect(Rect2(offset.x + x, offset.y + top + 4 + jitter, 10, 2), GameConstants.COLOR_INK_MID)

func _draw_panel(rect: Rect2) -> void:
	draw_rect(rect, Color(GameConstants.COLOR_PANEL_BG.r, GameConstants.COLOR_PANEL_BG.g, GameConstants.COLOR_PANEL_BG.b, 0.92), true)
	draw_rect(rect, GameConstants.COLOR_PANEL_BORDER, false, 2.0)
	draw_rect(Rect2(rect.position.x + 2.0, rect.position.y, rect.size.x - 4.0, 1.0), GameConstants.COLOR_PANEL_ACCENT)
	var cm: float = 6.0
	var cc: Color = GameConstants.COLOR_PANEL_BORDER
	draw_rect(Rect2(rect.position.x - 1.0, rect.position.y - 1.0, cm, 1.0), cc)
	draw_rect(Rect2(rect.position.x - 1.0, rect.position.y - 1.0, 1.0, cm), cc)
	draw_rect(Rect2(rect.end.x - cm + 1.0, rect.position.y - 1.0, cm, 1.0), cc)
	draw_rect(Rect2(rect.end.x, rect.position.y - 1.0, 1.0, cm), cc)
	draw_rect(Rect2(rect.position.x - 1.0, rect.end.y, cm, 1.0), cc)
	draw_rect(Rect2(rect.position.x - 1.0, rect.end.y - cm + 1.0, 1.0, cm), cc)
	draw_rect(Rect2(rect.end.x - cm + 1.0, rect.end.y, cm, 1.0), cc)
	draw_rect(Rect2(rect.end.x, rect.end.y - cm + 1.0, 1.0, cm), cc)

func _draw_bar_frame(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position.x - 1, rect.position.y - 1, rect.size.x + 2, rect.size.y + 2), GameConstants.COLOR_PANEL_BORDER)
	draw_rect(rect, GameConstants.COLOR_INK_BLACK, true)
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 1), GameConstants.COLOR_PANEL_ACCENT)

func _draw_pause_indicator() -> void:
	draw_rect(Rect2(0, 0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), Color(0, 0, 0, 0.4), true)
	_draw_text("PAUSED", GameConstants.VIEW_WIDTH * 0.5 - 55.0, GameConstants.VIEW_HEIGHT * 0.5 - 30.0, GameConstants.COLOR_TEXT_HEADING, 28)
	_draw_text("Press P to resume | ` for debug | R to restart", GameConstants.VIEW_WIDTH * 0.5 - 185.0, GameConstants.VIEW_HEIGHT * 0.5 + 10.0, GameConstants.COLOR_TEXT_BODY, 14)

func _draw_debug_overlay() -> void:
	_debug_overlay.draw(self, _player, _enemy, _input_buffer)

func _draw_text(text: String, x: float, y: float, color: Color, size: int = 16, display: bool = false) -> void:
	var font: Font = _font_for_size(size, display)
	if font == null:
		return
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _measure_text(text: String, size: int = 16, display: bool = false) -> int:
	var font: Font = _font_for_size(size, display)
	if font == null:
		return text.length() * size / 2
	return int(round(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x))

func _font_for_size(size: int, display: bool = false) -> Font:
	if display or size >= 32:
		var display_font: Font = Fonts.display_font()
		if display_font != null:
			return display_font
	var body_font: Font = Fonts.body_font()
	if body_font != null:
		return body_font
	return ThemeDB.fallback_font

func _sync_input_tracker() -> void:
	var keys: Array[int] = [KEY_QUOTELEFT, KEY_P, KEY_ENTER, KEY_J]
	if _player != null:
		for control_name in _player.controls.keys():
			var key: int = int(_player.controls[control_name])
			if key != KEY_NONE and not keys.has(key):
				keys.append(key)
	_input_tracker.sync_keys(keys)

func _on_spawn_particles(position: Vector2, count: int, color: Color) -> void:
	_particle_system.spawn_hit_sparks(position, count, color)

func _on_camera_shake(amount: float) -> void:
	_camera.add_shake(amount)

func _on_damage_dealt(position: Vector2, damage: float, is_critical: bool) -> void:
	_damage_number_system.spawn_damage_number(position, damage, false, is_critical)

func _on_player_timeline_event(event_name: String) -> void:
	match event_name:
		"attack_active_start":
			if _player_presenter != null:
				_player_presenter.set_flash(1.0)

func _trigger_slow_mo(factor: float, duration: float) -> void:
	_slow_mo_factor = clampf(factor, 0.0, 1.0)
	_slow_mo_timer = maxf(_slow_mo_timer, duration)

func _trigger_hitstop(duration: float) -> void:
	_hitstop_timer = maxf(_hitstop_timer, duration)

func _show_feedback(message: String, duration: float) -> void:
	var frame: int = Engine.get_process_frames()
	if _feedback_frame == frame and not _feedback_message.is_empty():
		if _feedback_message.find(message) == -1:
			_feedback_message = "%s | %s" % [_feedback_message, message]
		_feedback_timer = maxf(_feedback_timer, duration)
		return
	_feedback_frame = frame
	_feedback_message = message
	_feedback_timer = duration

func _show_boss_beat(message: String, duration: float) -> void:
	_boss_beat_message = message
	_boss_beat_timer = duration

func _connect_attack_visual(fighter: Fighter, visual: FighterVisual) -> void:
	var callback: Callable = Callable(visual, "_on_attack_active_started")
	if not fighter.is_connected("attack_active_started", callback):
		fighter.connect("attack_active_started", callback)

func _get_visual_for(fighter: Fighter) -> FighterVisual:
	if fighter.is_ai:
		return _enemy_visual
	return _player_visual
