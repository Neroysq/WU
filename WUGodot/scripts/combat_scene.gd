class_name CombatScene
extends Node2D

const CombatDebugOverlayScript = preload("res://scripts/combat_debug_overlay.gd")
const BoonTextScript = preload("res://scripts/boons/boon_text.gd")
const InputBufferScript = preload("res://scripts/input_buffer.gd")
const BackgroundRendererScript = preload("res://scripts/visual/background_renderer.gd")
const UiDraw = preload("res://scripts/ui/ui_draw.gd")
const DepthBandScript = preload("res://scripts/ui/depth_band.gd")
const AnimationClockScript = preload("res://scripts/visual/animation_clock.gd")
const AnimationDebugOverlayScript = preload("res://scripts/visual/animation_debug_overlay.gd")
const FighterPresenterScript = preload("res://scripts/visual/fighter_presenter.gd")
const PresentationCollisionScript = preload("res://scripts/visual/presentation_collision.gd")
const CombatSetupScript = preload("res://scripts/sim/combat_setup.gd")
const CombatStepScript = preload("res://scripts/sim/combat_step.gd")
const EncounterResolverScript = preload("res://scripts/encounter_resolver.gd")
const SettingsManagerScript = preload("res://scripts/settings_manager.gd")
const SettingsViewScript = preload("res://scripts/scenes/settings_view.gd")

const ENABLE_AUTHORED_PLAYER_HITBOXES: bool = true
const DEV_CAPTURE_STEP: float = 1.0 / 60.0
const ENTRY_DRAW_STATE: String = "COMBAT_ENTRY"
const ENTRY_DRAW_DURATION: float = 1.6
const LOADOUT_SLOT_ORDER: Array[String] = ["light", "heavy", "dash", "block", "stance", "jump"]

signal combat_end(victory: bool)

var _player: Fighter
var _enemy: Fighter
var _current_node: MapNode
var _boon_loadout: Variant = null

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
var _break_feedback_timer: float = 0.0
var _is_paused: bool = false
var _debug_enabled: bool = false
var _heavy_committed_attack: bool = false
var _boss_death_timer: float = 0.0
var _boss_death_triggered: bool = false
var _boss_beat_message: String = ""
var _boss_beat_caption: String = ""
var _boss_beat_timer: float = 0.0
var _boss_beat_duration: float = 1.1
var _controls_legend_timer: float = 0.0
var _pause_cursor_flash: float = 0.0
var _settings_open: bool = false
var _entry_timer: float = 0.0
var _entry_presenter_active: bool = false
var _dev_capture_mode: bool = false
var _dev_capture_playback: bool = false
var _dev_capture_physics: bool = false
var _dev_capture_show_hud: bool = true
var _dev_capture_show_enemy: bool = true
var _dev_capture_show_debug: bool = true

var _input_tracker: InputTracker = InputTracker.new()
var _input_buffer: Variant = InputBufferScript.new()
var _debug_overlay: Variant = CombatDebugOverlayScript.new()
var _settings_view: Variant = SettingsViewScript.new()

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

	_connect_combat_system_signals()

	set_process(false)
	visible = false

func setup_combat(player: Fighter, node: MapNode, show_controls_legend: bool = false, forced_archetype: String = "", boon_loadout: Variant = null, encounter_context: Dictionary = {}) -> void:
	_player = player
	_current_node = node
	_boon_loadout = boon_loadout
	var setup: Dictionary = CombatSetupScript.prepare(player, node, forced_archetype, encounter_context)
	_enemy = setup["enemy"] as Fighter
	_combat_system = setup["combat_system"] as CombatSystem
	_hit_geometry = setup["hit_geometry"]
	_connect_combat_system_signals()
	var arena_id: String = "chapter1_boss_clearing" if node.node_type == MapNode.NodeType.BOSS else "chapter1_bamboo_dusk"
	if _background != null:
		_background.set_arena(arena_id)
	_player_visual.configure(DataManager.get_visual_profile(_player.visual_profile_id), _player)
	_player_presenter.configure(
		"res://assets/animation_manifests/hu.manifest.json",
		"res://assets/animation_graphs/humanoid.graph.json",
		[
			"res://assets/animation_clips/hu_attack_light.timeline.json",
			"res://assets/animation_clips/hu_attack_heavy.timeline.json",
			"res://assets/animation_clips/idle.timeline.json",
			"res://assets/animation_clips/walk.timeline.json",
			"res://assets/animation_clips/held_block.timeline.json",
			"res://assets/animation_clips/held_hit.timeline.json",
			"res://assets/animation_clips/held_stunned.timeline.json",
			"res://assets/animation_clips/held_dash.timeline.json",
			"res://assets/animation_clips/held_jump.timeline.json",
			"res://assets/animation_clips/held_fall.timeline.json",
			"res://assets/animation_clips/held_land.timeline.json",
			"res://assets/animation_clips/entry_draw.timeline.json",
		],
		float(DataManager.get_visual_profile(_player.visual_profile_id).get("scale", 1.625))
	)
	if _boon_loadout != null:
		_player_presenter.set_move_skins(_boon_loadout.move_slot_schools())
	else:
		_player_presenter.set_move_skins({})
	var presenter_callback: Callable = Callable(self, "_on_player_timeline_event")
	if not _player_presenter.is_connected("timeline_event", presenter_callback):
		_player_presenter.connect("timeline_event", presenter_callback)
	_enemy_visual.configure(DataManager.get_visual_profile(_enemy.visual_profile_id), _enemy)
	_connect_attack_visual(_player, _player_visual)
	_connect_attack_visual(_enemy, _enemy_visual)

	_is_paused_on_end = false
	_end_message = ""
	_is_paused = false
	_feedback_message = ""
	_feedback_timer = 0.0
	_feedback_frame = -1
	_break_feedback_timer = 0.0
	_time_scale = 1.0
	_hitstop_timer = 0.0
	_slow_mo_timer = 0.0
	_slow_mo_factor = 1.0
	_heavy_committed_attack = false
	_boss_death_timer = 0.0
	_boss_death_triggered = false
	_boss_beat_message = ""
	_boss_beat_caption = ""
	_boss_beat_timer = 0.0
	_boss_beat_duration = 1.1
	_controls_legend_timer = 6.0 if show_controls_legend else 0.0
	_pause_cursor_flash = 0.0
	_settings_open = false
	_settings_view.enter()
	_entry_timer = 0.0
	_entry_presenter_active = false

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
	_entry_timer = ENTRY_DRAW_DURATION
	_entry_presenter_active = true
	if _current_node != null and _current_node.node_type == MapNode.NodeType.BOSS:
		_show_boss_beat("山門不開。", 1.4, "熊鐵 Xiong Tie — First of the Nine keeps the gate")

func on_exit() -> void:
	_particle_system.clear()
	_damage_number_system.clear()
	_entry_timer = 0.0
	_entry_presenter_active = false

func deactivate() -> void:
	set_process(false)
	visible = false

func blocks_global_hotkeys() -> bool:
	return _settings_open

func dev_set_capture_mode(enabled: bool) -> void:
	_dev_capture_mode = enabled
	_debug_enabled = enabled
	_dev_capture_show_hud = true
	_dev_capture_show_enemy = true
	_dev_capture_show_debug = true
	_controls_legend_timer = 0.0

func dev_set_capture_overlays(show_hud: bool = true, show_enemy: bool = true, show_debug: bool = true) -> void:
	_dev_capture_show_hud = show_hud
	_dev_capture_show_enemy = show_enemy
	_dev_capture_show_debug = show_debug
	_debug_enabled = show_debug

func dev_set_capture_playback(enabled: bool, physics: bool = false) -> void:
	_dev_capture_playback = enabled
	_dev_capture_physics = physics

func dev_prepare_capture_state(state_name: String) -> void:
	if _player == null or _enemy == null:
		return

	_player.reset_for_combat()
	_enemy.reset_for_combat()
	_player.position = Vector2(520.0, GameConstants.GROUND_Y)
	_enemy.position = Vector2(805.0, GameConstants.GROUND_Y)
	_player.facing = 1
	_enemy.facing = -1
	_player.velocity = Vector2.ZERO
	_enemy.velocity = Vector2.ZERO
	_player.animation_offset = Vector2.ZERO
	_enemy.animation_offset = Vector2.ZERO
	_player.current_animation = Fighter.AnimationState.IDLE
	_enemy.current_animation = Fighter.AnimationState.IDLE
	_player._attack_state.clear()
	_enemy._attack_state.clear()
	_camera.reset()
	_particle_system.clear()
	_damage_number_system.clear()
	_feedback_message = ""
	_feedback_timer = 0.0
	_is_paused = false
	_is_paused_on_end = false
	_boss_death_triggered = false
	_time_scale = 1.0
	_hitstop_timer = 0.0
	_slow_mo_timer = 0.0
	_slow_mo_factor = 1.0
	_controls_legend_timer = 0.0
	_entry_timer = 0.0
	_entry_presenter_active = false

	match state_name:
		"entry_draw":
			_entry_timer = ENTRY_DRAW_DURATION
			_entry_presenter_active = true
		"02_walk":
			_enemy.position = Vector2(1300.0, GameConstants.GROUND_Y)
			_player.current_animation = Fighter.AnimationState.WALKING
			_player.velocity.x = _player.move_speed * float(_player.facing)
			_player.animation_timer = 0.2
		"attack_light_full":
			_player.start_light_attack()
		"03_light_windup":
			_player.start_light_attack()
			if _player._attack_state.def != null:
				_player._attack_state.elapsed = maxf(0.01, _player._attack_state.def.windup_end * 0.55)
		"04_light_active":
			_player.start_light_attack()
			if _player._attack_state.def != null:
				_player._attack_state.elapsed = _player._attack_state.def.windup_end + 0.04
		"05_light_recover":
			_player.start_light_attack()
			if _player._attack_state.def != null:
				_player._attack_state.elapsed = _player._attack_state.def.active_end + 0.04
		"attack_heavy_full":
			_player.start_heavy_attack()
		"06_heavy_windup":
			_player.start_heavy_attack()
			if _player._attack_state.def != null:
				_player._attack_state.elapsed = maxf(0.01, _player._attack_state.def.windup_end * 0.55)
		"07_heavy_active":
			_player.start_heavy_attack()
			if _player._attack_state.def != null:
				_player._attack_state.elapsed = _player._attack_state.def.windup_end + 0.04
		"15_heavy_recover":
			_player.start_heavy_attack()
			if _player._attack_state.def != null:
				_player._attack_state.elapsed = _player._attack_state.def.active_end + 0.04
		"08_block":
			_player.current_animation = Fighter.AnimationState.BLOCKING
			_player.is_blocking = true
			_player.animation_timer = 0.1
		"09_hit_react":
			_player.current_animation = Fighter.AnimationState.HIT_REACTION
			_player.animation_timer = 0.1
		"10_stunned":
			_player.apply_stun(9999.0)
			_player.animation_timer = 0.15
		"11_dash":
			_player.start_dash(_player.facing)
			_player.animation_timer = 0.08
		"12_jump":
			_player.start_jump()
			_player.animation_timer = 0.12
		"13_fall":
			_player.current_animation = Fighter.AnimationState.FALLING
			_player.is_grounded = false
			_player.velocity.y = 450.0
			_player.animation_timer = 0.1
		"14_land":
			_player.current_animation = Fighter.AnimationState.LANDING
			_player.animation_timer = 0.08
		"05_enemy_windup", "15_enemy_windup", "16_enemy_windup":
			_dev_place_at_enemy_preferred_range()
			_dev_start_enemy_capture_attack(false)
		"06_enemy_active", "16_enemy_active", "17_enemy_active":
			_dev_place_at_enemy_preferred_range()
			_dev_start_enemy_capture_attack(true)
		"07_neutral_spacing", "17_neutral_spacing", "18_neutral_spacing":
			_dev_place_at_enemy_preferred_range()
		_:
			_player.current_animation = Fighter.AnimationState.IDLE

	_update_player_presenter(0.0, 0.0)
	if _dev_capture_mode and _player_presenter != null:
		var resolved_state: String = _resolve_player_state_name()
		print("CAPTURE CLIP: state=%s clip=%s tint=%s visible=%s handles=%s" % [resolved_state, _player_presenter.resolve_state_clip_id(resolved_state), _player_presenter.active_tint_school_for(resolved_state), str(_player_presenter.visible), str(_player_presenter.handles_state(resolved_state))])
	queue_redraw()

func _dev_place_at_enemy_preferred_range() -> void:
	var preferred: float = _enemy.attack_range
	if _enemy.ai_brain != null:
		preferred = _enemy.ai_brain.preferred_range
	var gap: float = preferred + _enemy.half_width + _player.half_width
	_player.position = Vector2(520.0, GameConstants.GROUND_Y)
	_enemy.position = Vector2(_player.position.x + gap, GameConstants.GROUND_Y)
	_player.facing = 1
	_enemy.facing = -1
	_player.velocity = Vector2.ZERO
	_enemy.velocity = Vector2.ZERO

func _dev_start_enemy_capture_attack(active: bool) -> void:
	var attack_def: Variant = _dev_pick_enemy_capture_attack()
	if attack_def == null:
		return
	_enemy._start_attack_with(attack_def)
	if active:
		var active_span: float = maxf(attack_def.active_end - attack_def.windup_end, 0.001)
		_enemy._attack_state.elapsed = attack_def.windup_end + active_span * 0.4
	else:
		_enemy._attack_state.elapsed = maxf(0.01, attack_def.windup_end * 0.55)

func _dev_pick_enemy_capture_attack() -> Variant:
	if _enemy == null or _enemy.ai_brain == null:
		return null
	var best_def: Variant = null
	for attack_id in _enemy.ai_brain.pattern_table:
		var attack_def: Variant = _enemy.ai_brain.get_attack_def(str(attack_id))
		if attack_def == null:
			continue
		if best_def == null or float(attack_def.range_units) < float(best_def.range_units):
			best_def = attack_def
	return best_def

func _process(delta: float) -> void:
	if _player == null or _enemy == null:
		return
	_pause_cursor_flash += delta

	if _dev_capture_mode:
		var presenter_dt: float = 0.0
		if _dev_capture_playback:
			var capture_dt: float = DEV_CAPTURE_STEP
			presenter_dt = capture_dt
			_advance_entry_timer(capture_dt, false)
			if _dev_capture_physics:
				_combat_system.update_player(_player, _dev_capture_input(), capture_dt, _enemy)
			else:
				_player.update_timers(capture_dt)
			_particle_system.update(capture_dt)
		_player_visual.update(_player, 0.0)
		_enemy_visual.update(_enemy, 0.0)
		_update_player_presenter(presenter_dt, presenter_dt)
		_sync_input_tracker()
		queue_redraw()
		return

	if not _settings_open and _input_tracker.pressed_key(KEY_QUOTELEFT):
		_debug_enabled = not _debug_enabled

	if not _settings_open and _input_tracker.pressed_key(KEY_P):
		_is_paused = not _is_paused
		if not _is_paused:
			_settings_open = false

	if _feedback_timer > 0.0:
		_feedback_timer -= delta
	if _break_feedback_timer > 0.0:
		_break_feedback_timer -= delta
	if _boss_beat_timer > 0.0:
		_boss_beat_timer -= delta
	if _controls_legend_timer > 0.0:
		_controls_legend_timer = maxf(0.0, _controls_legend_timer - delta)

	if _is_paused and not _is_paused_on_end:
		var pause_input: MenuInput = MenuInput.from_tracker(_input_tracker, get_viewport())
		if _settings_open:
			var settings_result: Dictionary = _settings_view.update(pause_input, delta)
			if _settings_view.consume_changed():
				_apply_settings_to_player()
			if bool(settings_result.get("exit", false)):
				_settings_open = false
			_sync_input_tracker()
			queue_redraw()
			return
		if _input_tracker.pressed_key(KEY_O):
			_settings_open = true
			_settings_view.enter()
			_sync_input_tracker()
			queue_redraw()
			return
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
	if _advance_entry_timer(float(clocks["combat"]), true):
		input_active = false

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

	var attack_key: int = int(_player.controls.get("attack", KEY_J))
	if input_active:
		_input_tracker.update_physical_hold_timers([attack_key], delta)
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
	CombatStepScript.advance(_combat_system, _player, _enemy, input_state, dt)

	var death_state: String = CombatStepScript.death_state(_player, _enemy)
	if death_state == "player":
		_is_paused_on_end = true
		_end_message = "Defeat (Enter: continue)"
	elif death_state == "enemy":
		CombatStepScript.fire_player_kill(_player)
		if _current_node.node_type == MapNode.NodeType.BOSS:
			_boss_death_triggered = true
			_boss_death_timer = 1.0
			_trigger_slow_mo(0.2, 1.0)
			_on_camera_shake(20.0)
			_show_boss_beat("破山!", 1.1, "the gate stands open — something above is listening")
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

	if _input_tracker.pressed_physical_key(jump_key):
		_input_buffer.record("jump")
	if _input_tracker.pressed_physical_key(dash_key):
		_input_buffer.record("dash")
	if _input_tracker.pressed_physical_key(block_key):
		_input_buffer.record("parry")
	if stance_key != KEY_NONE and _input_tracker.pressed_physical_key(stance_key):
		_input_buffer.record("stance")

	var attack_press_edge: bool = _input_tracker.pressed_physical_key(attack_key)
	var attack_release_edge: bool = _input_tracker.released_physical_key(attack_key)
	var attack_held: bool = _input_tracker.is_physical_held(attack_key)
	var attack_hold: float = _input_tracker.physical_hold_duration(attack_key)

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

	var left_down: bool = _input_tracker.is_physical_held(left_key)
	var right_down: bool = _input_tracker.is_physical_held(right_key)
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
		"block_down": _input_tracker.is_physical_held(block_key),
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

func _dev_capture_input() -> Dictionary:
	var input: Dictionary = _neutral_input()
	if _player != null and _player.current_animation == Fighter.AnimationState.WALKING:
		input["move"] = float(_player.facing)
	return input

func _advance_entry_timer(dt: float, allow_cancel: bool) -> bool:
	_entry_presenter_active = false
	if _entry_timer <= 0.0:
		return false
	if allow_cancel and _entry_cancel_requested():
		_entry_timer = 0.0
		return false

	_entry_presenter_active = true
	_entry_timer = maxf(0.0, _entry_timer - dt)
	return true

func _entry_cancel_requested() -> bool:
	if _player == null:
		return false
	for action_name in ["left", "right", "jump", "dash", "attack", "block", "stance"]:
		var key: int = int(_player.controls.get(str(action_name), KEY_NONE))
		if key != KEY_NONE and Input.is_physical_key_pressed(key):
			return true
	return false

func _update_player_presenter(combat_dt: float, presentation_dt: float) -> void:
	if _player_presenter == null or _player == null:
		return

	var state_name: String = _resolve_player_state_name()
	if _entry_presenter_active:
		state_name = ENTRY_DRAW_STATE
	var stance_school: String = ""
	if _boon_loadout != null and _player.technique_engine != null and _player.technique_engine.is_stance_active():
		stance_school = _boon_loadout.school_for_effect_id(_player.technique_engine.active_stance())
	_player_presenter.set_active_stance_school(stance_school)
	if _player_presenter.handles_state(state_name):
		_player_presenter.visible = true
		_player_presenter.update(_player, state_name, combat_dt, presentation_dt, _camera.offset)
	else:
		_player_presenter.visible = false

func _resolve_player_state_name() -> String:
	match _player.current_animation:
		Fighter.AnimationState.ATTACKING_LIGHT:
			return "ATTACKING_LIGHT"
		Fighter.AnimationState.ATTACKING_HEAVY:
			return "ATTACKING_HEAVY"
		Fighter.AnimationState.WALKING:
			return "WALKING"
		Fighter.AnimationState.IDLE:
			return "IDLE"
		Fighter.AnimationState.BLOCKING:
			return "BLOCKING"
		Fighter.AnimationState.HIT_REACTION:
			return "HIT_REACTION"
		Fighter.AnimationState.STUNNED:
			return "STUNNED"
		Fighter.AnimationState.DASHING:
			return "DASHING"
		Fighter.AnimationState.JUMPING:
			return "JUMPING"
		Fighter.AnimationState.FALLING:
			return "FALLING"
		Fighter.AnimationState.LANDING:
			return "LANDING"
		_:
			return "FALLBACK"

func _body_rect_for(fighter: Fighter, visual: FighterVisual, camera_offset: Vector2) -> Rect2:
	if fighter == _player and _player_presenter != null and _player_presenter.visible and _player_presenter.handles_state(_resolve_player_state_name()):
		return _player_presenter.get_body_rect(fighter, camera_offset)
	return visual.get_body_rect(fighter, camera_offset)

func _draw() -> void:
	if _player == null or _enemy == null or not visible:
		return

	var camera_offset: Vector2 = _camera.offset
	_draw_arena(camera_offset)
	_draw_fighter(_player, camera_offset)
	if not _dev_capture_mode or _dev_capture_show_enemy:
		_draw_fighter(_enemy, camera_offset)
	_particle_system.draw(self, camera_offset)
	_damage_number_system.draw(self, camera_offset)

	if not _dev_capture_mode or _dev_capture_show_hud:
		_draw_hud()
	_draw_feedback()
	_draw_break_feedback()
	_draw_boss_beat()
	if _is_paused_on_end:
		_draw_end_message()
	_draw_effects()

	if _is_paused:
		_draw_pause_indicator()
		if _settings_open:
			_settings_view.draw(self, SettingsViewScript.default_rect(), _pause_cursor_flash)
		else:
			_draw_controls_legend(1.0)

	if _debug_enabled and not _settings_open and (not _dev_capture_mode or _dev_capture_show_debug):
		_draw_debug_overlay()

func _unhandled_input(event: InputEvent) -> void:
	if not _settings_open or not _settings_view.is_capturing():
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			_settings_view.feed_key_event(key_event)
			if _settings_view.consume_changed():
				_apply_settings_to_player()
			get_viewport().set_input_as_handled()
			_sync_input_tracker()
			queue_redraw()

func _draw_arena(offset: Vector2) -> void:
	if _background != null:
		_background.draw(self, offset, {}, {"band": _combat_depth_band()})
	else:
		draw_rect(Rect2(offset.x, offset.y, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), GameConstants.COLOR_INK_BLACK)
	_draw_platform(offset)

func _draw_fighter(fighter: Fighter, camera_offset: Vector2) -> void:
	var visual: FighterVisual = _get_visual_for(fighter)
	var body_rect: Rect2 = _body_rect_for(fighter, visual, camera_offset)

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

	if fighter == _enemy and _debug_enabled and fighter._attack_state.is_active():
		_draw_enemy_scalar_reach_debug(fighter, camera_offset)

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

func _draw_enemy_scalar_reach_debug(attacker: Fighter, camera_offset: Vector2) -> void:
	var attack_def: Variant = attacker._attack_state.def
	if attack_def == null or _player == null:
		return

	var y_offset: float = -attacker.height * 0.72
	var facing: float = float(attacker.facing)
	var start: Vector2 = attacker.position + camera_offset + Vector2(facing * attacker.half_width, y_offset)
	var end: Vector2 = attacker.position + camera_offset + Vector2(facing * (float(attack_def.range_units) + _player.half_width), y_offset)
	var active: bool = attacker.is_hit_active()
	var line_color: Color = Color(1.0, 0.18, 0.12, 0.92) if active else Color(1.0, 0.78, 0.15, 0.55)
	draw_line(start, end, line_color, 4.0, true)
	draw_circle(end, 8.0, line_color)

func _draw_hud() -> void:
	var left_panel: Rect2 = Rect2(20, 18, GameConstants.VIEW_WIDTH / 2 - 40, 98)
	var right_panel: Rect2 = Rect2(GameConstants.VIEW_WIDTH / 2 + 20, 18, GameConstants.VIEW_WIDTH / 2 - 40, 98)
	_draw_panel(left_panel)
	_draw_panel(right_panel)

	_draw_bars(_player, 34, 36, false, true)
	_draw_bars(_enemy, GameConstants.VIEW_WIDTH / 2 + 34, 36, true, false)
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
	elif _current_node != null and _current_node.node_type == MapNode.NodeType.AMBUSH:
		_draw_ambush_progress(GameConstants.VIEW_WIDTH - 190.0, 30.0)

	var show_controls_legend: bool = _controls_legend_timer > 0.0 or (_is_paused and not _settings_open) or _is_paused_on_end
	if show_controls_legend:
		var legend_alpha: float = 1.0 if _is_paused or _is_paused_on_end else clampf(_controls_legend_timer, 0.0, 1.0)
		_draw_controls_legend(legend_alpha)
	var active_schools: Array[String] = _active_boon_schools()
	if _player != null and _player.technique_engine != null:
		var tech_ids: Array[String] = _player.technique_engine.technique_ids()
		var slot_entries: Array[Dictionary] = _equipped_slot_boon_entries()
		if not tech_ids.is_empty() or not active_schools.is_empty():
			var show_full_loadout: bool = _is_paused or _is_paused_on_end or (_debug_enabled and not _dev_capture_mode)
			if show_full_loadout:
				var tech_panel_height: float = 72.0 + float(tech_ids.size()) * 18.0 + (30.0 if not active_schools.is_empty() else 0.0)
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
				if not active_schools.is_empty():
					_draw_school_chips(active_schools, tech_panel.position.x + 18.0, tech_panel.end.y - 24.0)
			else:
				_draw_compact_loadout_panel(tech_ids.size(), slot_entries, active_schools)

			if _player.technique_engine.is_stance_active():
				var stance_label: String = _player.technique_engine.active_stance_display_name()
				var pulse: float = sin(_player.animation_timer * 6.0) * 0.3 + 0.7
				_draw_text("STANCE: %s" % stance_label, 36.0, 104.0, Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, pulse), 16)

func _draw_controls_legend(alpha: float) -> void:
	var controls_panel: Rect2 = Rect2(410.0, float(GameConstants.VIEW_HEIGHT) - 70.0, 1100.0, 44.0)
	var panel_bg: Color = Color(GameConstants.COLOR_PANEL_BG.r, GameConstants.COLOR_PANEL_BG.g, GameConstants.COLOR_PANEL_BG.b, 0.88 * alpha)
	var panel_border: Color = Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, alpha)
	var accent: Color = Color(GameConstants.COLOR_PANEL_ACCENT.r, GameConstants.COLOR_PANEL_ACCENT.g, GameConstants.COLOR_PANEL_ACCENT.b, 0.75 * alpha)
	var text_color: Color = Color(GameConstants.COLOR_TEXT_BODY.r, GameConstants.COLOR_TEXT_BODY.g, GameConstants.COLOR_TEXT_BODY.b, alpha)
	draw_rect(controls_panel, panel_bg, true)
	draw_rect(controls_panel, panel_border, false, 2.0)
	draw_rect(Rect2(controls_panel.position.x + 2.0, controls_panel.position.y, controls_panel.size.x - 4.0, 1.0), accent, true)
	_draw_text(_controls_legend_text(), controls_panel.position.x + 18.0, controls_panel.position.y + 28.0, text_color, 15)

func _controls_legend_text() -> String:
	var controls: Dictionary = _player.controls if _player != null else SettingsManagerScript.keybinds()
	return "%s/%s move  %s jump  %s tap/hold  %s block/parry  %s dash  %s stance  P pause  R restart" % [
		SettingsManagerScript.key_label(int(controls.get("left", KEY_A))),
		SettingsManagerScript.key_label(int(controls.get("right", KEY_D))),
		SettingsManagerScript.key_label(int(controls.get("jump", KEY_W))),
		SettingsManagerScript.key_label(int(controls.get("attack", KEY_J))),
		SettingsManagerScript.key_label(int(controls.get("block", KEY_K))),
		SettingsManagerScript.key_label(int(controls.get("dash", KEY_SPACE))),
		SettingsManagerScript.key_label(int(controls.get("stance", KEY_L))),
	]

func _draw_bars(fighter: Fighter, x: int, y: int, mirror: bool, show_rage: bool) -> void:
	var width: int = GameConstants.VIEW_WIDTH / 2 - 76
	var gap: int = 7

	_draw_single_bar(fighter.health_current, fighter.health_max, x, y, width, 15, GameConstants.COLOR_HEALTH, mirror, "命 HP", false)
	_draw_single_bar(fighter.posture_current, fighter.posture_max, x, y + 15 + gap, width, 20, GameConstants.COLOR_POSTURE, mirror, "構 PST", true)
	if show_rage:
		_draw_single_bar(fighter.rage_current, fighter.rage_max, x, y + 15 + gap + 20 + gap, width, 14, GameConstants.COLOR_RAGE, mirror, "氣 RAGE", false)

func _draw_single_bar(current: float, max_value: float, x: int, y: int, width: int, bar_h: int, color: Color, mirror: bool, label: String, emphasized: bool) -> void:
	var pct: float = clampf(current / maxf(max_value, 0.001), 0.0, 1.0)
	var back: Rect2 = Rect2(x, y, width, bar_h)
	_draw_bar_frame(back)
	if emphasized:
		draw_rect(back.grow(2.0), Color(color.r, color.g, color.b, 0.10), true)
	var fill: Rect2 = Rect2(x, y, width * pct, bar_h)
	draw_rect(fill, color, true)
	if emphasized:
		var ticks: int = 10
		for i in range(1, ticks):
			var tick_x: float = float(x) + float(width) * float(i) / float(ticks)
			draw_line(Vector2(tick_x, float(y) + 2.0), Vector2(tick_x, float(y + bar_h) - 2.0), Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.42), 1.0)

	var value_text: String = "%d/%d" % [int(round(current)), int(round(max_value))]
	var label_x: float = float(x + 6)
	var value_x: float = float(x + width - _measure_text(value_text, 14) - 6)
	if mirror:
		label_x = float(x + width - _measure_text(label, 13, true) - 6)
		value_x = float(x + 6)
	_draw_text(label, label_x + 1.0, float(y) + float(bar_h) - 3.0, Color(0, 0, 0, 0.72), 13, true)
	_draw_text(label, label_x, float(y) + float(bar_h) - 4.0, GameConstants.COLOR_TEXT_HEADING if emphasized else GameConstants.COLOR_TEXT_BODY, 13, true)
	_draw_text(value_text, value_x + 1.0, float(y) + float(bar_h) - 3.0, Color(0, 0, 0, 0.72), 14)
	_draw_text(value_text, value_x, float(y) + float(bar_h) - 4.0, GameConstants.COLOR_TEXT_HEADING, 14)

func _draw_feedback() -> void:
	if _feedback_timer <= 0.0:
		return
	var alpha: float = clampf(_feedback_timer, 0.0, 1.0)
	var text_width: float = _measure_text(_feedback_message, 22)
	_draw_text(_feedback_message, GameConstants.VIEW_WIDTH * 0.5 - text_width * 0.5, 200.0, Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, alpha), 22)

func _draw_break_feedback() -> void:
	if _break_feedback_timer <= 0.0:
		return
	var alpha: float = clampf(_break_feedback_timer / 0.85, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin((0.85 - _break_feedback_timer) * 18.0)
	var rect: Rect2 = Rect2(GameConstants.VIEW_WIDTH * 0.5 - 170.0, 132.0, 340.0, 84.0)
	draw_rect(rect, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.58 * alpha), true)
	draw_rect(rect, Color(GameConstants.COLOR_POSTURE.r, GameConstants.COLOR_POSTURE.g, GameConstants.COLOR_POSTURE.b, 0.85 * alpha), false, 2.0 + pulse)
	var kanji_size: int = int(48.0 + pulse * 8.0)
	_draw_text("破", rect.position.x + rect.size.x * 0.5 - _measure_text("破", kanji_size, true) * 0.5, rect.position.y + 50.0, Color(GameConstants.COLOR_TEXT_HEADING.r, GameConstants.COLOR_TEXT_HEADING.g, GameConstants.COLOR_TEXT_HEADING.b, alpha), kanji_size, true)
	_draw_text("Posture Broken", rect.position.x + rect.size.x * 0.5 - _measure_text("Posture Broken", 16) * 0.5, rect.position.y + 72.0, Color(GameConstants.COLOR_POSTURE.r, GameConstants.COLOR_POSTURE.g, GameConstants.COLOR_POSTURE.b, alpha), 16)

func _draw_boss_beat() -> void:
	if _boss_beat_timer <= 0.0 or _boss_beat_message.is_empty():
		return
	var alpha: float = clampf(_boss_beat_timer / maxf(_boss_beat_duration, 0.001), 0.0, 1.0)
	var pulse: float = 0.7 + 0.3 * sin((maxf(_boss_beat_duration, 0.001) - _boss_beat_timer) * 12.0)
	var rect: Rect2 = Rect2(GameConstants.VIEW_WIDTH * 0.5 - 250.0, 118.0, 500.0, 120.0)
	draw_rect(rect, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.58 * alpha), true)
	draw_rect(rect, Color(GameConstants.COLOR_PANEL_ACCENT.r, GameConstants.COLOR_PANEL_ACCENT.g, GameConstants.COLOR_PANEL_ACCENT.b, 0.75 * alpha), false, 2.0)
	_draw_text(_boss_beat_message, rect.position.x + rect.size.x * 0.5 - _measure_text(_boss_beat_message, 52, true) * 0.5, rect.position.y + 60.0, Color(GameConstants.COLOR_TEXT_HEADING.r, GameConstants.COLOR_TEXT_HEADING.g, GameConstants.COLOR_TEXT_HEADING.b, alpha), 52, true)
	if not _boss_beat_caption.is_empty():
		_draw_text(_boss_beat_caption, rect.position.x + rect.size.x * 0.5 - _measure_text(_boss_beat_caption, 18) * 0.5, rect.position.y + 92.0, Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, alpha * pulse), 18)

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
	_draw_text("Press P to resume | O settings | ` for debug | R to restart", GameConstants.VIEW_WIDTH * 0.5 - 245.0, GameConstants.VIEW_HEIGHT * 0.5 + 10.0, GameConstants.COLOR_TEXT_BODY, 14)

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
	var keys: Array[int] = [
		KEY_QUOTELEFT, KEY_P, KEY_O, KEY_ESCAPE, KEY_Q, KEY_F5, KEY_R,
		KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
		KEY_ENTER, KEY_KP_ENTER, KEY_J, KEY_SPACE,
	]
	var physical_keys: Array[int] = []
	if _player != null:
		for control_name in _player.controls.keys():
			var key: int = int(_player.controls[control_name])
			if key != KEY_NONE and not physical_keys.has(key):
				physical_keys.append(key)
	_input_tracker.sync_keys(keys)
	_input_tracker.sync_physical_keys(physical_keys)

func _apply_settings_to_player() -> void:
	if _player == null:
		return
	_player.controls = SettingsManagerScript.keybinds()
	_sync_input_tracker()

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
	if message == "破":
		_break_feedback_timer = maxf(_break_feedback_timer, maxf(duration, 0.85))
	var frame: int = Engine.get_process_frames()
	if _feedback_frame == frame and not _feedback_message.is_empty():
		if _feedback_message.find(message) == -1:
			_feedback_message = "%s | %s" % [_feedback_message, message]
		_feedback_timer = maxf(_feedback_timer, duration)
		return
	_feedback_frame = frame
	_feedback_message = message
	_feedback_timer = duration

func _show_boss_beat(message: String, duration: float = 1.1, caption: String = "") -> void:
	_boss_beat_message = message
	_boss_beat_caption = caption
	_boss_beat_timer = duration
	_boss_beat_duration = duration

func _draw_ambush_progress(x: float, y: float) -> void:
	if _current_node == null:
		return
	var length: int = EncounterResolverScript.ambush_length(DataManager.get_difficulty_curve(1), _current_node.tier)
	var current_wave: int = clampi(length - _current_node.ambush_remaining + 1, 1, length)
	_draw_text("Ambush %d/%d" % [current_wave, length], x, y, GameConstants.COLOR_VERMILLION_RED, 14)

func _active_boon_schools() -> Array[String]:
	if _boon_loadout == null or not _boon_loadout.has_method("active_schools"):
		return []
	return _boon_loadout.active_schools()

func _equipped_slot_boon_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _boon_loadout == null or not _boon_loadout.has_method("serialize"):
		return entries
	var data: Dictionary = _boon_loadout.serialize()
	var slots: Dictionary = data.get("slots", {}) as Dictionary
	for slot in LOADOUT_SLOT_ORDER:
		if not slots.has(slot) or typeof(slots[slot]) != TYPE_DICTIONARY:
			continue
		var identity: Dictionary = slots[slot] as Dictionary
		var boon_id: String = str(identity.get("boon_id", ""))
		if boon_id.is_empty():
			continue
		var boon: Dictionary = DataManager.get_boon(boon_id)
		if boon.is_empty():
			continue
		var school_id: String = str(boon.get("school", ""))
		var school_data: Dictionary = DataManager.get_school(school_id)
		entries.append({
			"slot": slot,
			"name": BoonTextScript.name(boon),
			"tier": str(identity.get("tier", "common")),
			"school": school_id,
			"school_data": school_data,
			"color": _school_color_from_data(school_data),
		})
	return entries

func _draw_compact_loadout_panel(tech_count: int, slot_entries: Array[Dictionary], active_schools: Array[String]) -> void:
	var has_slot_entries: bool = not slot_entries.is_empty()
	var panel_height: float = 102.0 if has_slot_entries else 64.0
	var panel_width: float = 390.0 if has_slot_entries else 320.0
	var compact_panel: Rect2 = Rect2(24.0, float(GameConstants.VIEW_HEIGHT) - panel_height - 28.0, panel_width, panel_height)
	_draw_panel(compact_panel)
	var visible_count: int = slot_entries.size() if has_slot_entries else tech_count
	_draw_text("技藝 %d" % visible_count, compact_panel.position.x + 16.0, compact_panel.position.y + 24.0, GameConstants.COLOR_TEXT_SUBHEADING, 15, true)
	if has_slot_entries:
		var item_width: float = 172.0
		var start_y: float = compact_panel.position.y + 48.0
		for i in range(slot_entries.size()):
			var entry: Dictionary = slot_entries[i] as Dictionary
			var col: int = i % 2
			var row: int = int(i / 2)
			var x: float = compact_panel.position.x + 16.0 + float(col) * 178.0
			var y: float = start_y + float(row) * 18.0
			var color_value: Variant = entry.get("color", GameConstants.COLOR_PANEL_ACCENT)
			var color: Color = color_value if typeof(color_value) == TYPE_COLOR else GameConstants.COLOR_PANEL_ACCENT
			var school_data: Dictionary = entry.get("school_data", {}) as Dictionary
			UiDraw.school_mark(self, school_data, Vector2(x, y - 15.0), 16.0, Color(color.r, color.g, color.b, 0.95))
			var label: String = "%s %s" % [_slot_label(str(entry.get("slot", ""))), str(entry.get("name", ""))]
			_draw_text(_fit_text(label, item_width - 40.0, 12), x + 34.0, y, GameConstants.COLOR_TEXT_BODY, 12)
		return
	if active_schools.is_empty():
		_draw_text("Pause to inspect full loadout", compact_panel.position.x + 16.0, compact_panel.position.y + 46.0, GameConstants.COLOR_TEXT_HINT, 13)
	else:
		_draw_school_chips(active_schools, compact_panel.position.x + 16.0, compact_panel.position.y + 44.0)

func _slot_label(slot: String) -> String:
	match slot:
		"light":
			return "L"
		"heavy":
			return "H"
		"dash":
			return "D"
		"block":
			return "B"
		"stance":
			return "S"
		"jump":
			return "J"
		_:
			return slot.substr(0, 1).to_upper()

func _fit_text(text: String, max_width: float, size: int, display: bool = false) -> String:
	if float(_measure_text(text, size, display)) <= max_width:
		return text
	var suffix: String = "..."
	var available: float = max_width - float(_measure_text(suffix, size, display))
	if available <= 0.0:
		return suffix
	var trimmed: String = text
	while trimmed.length() > 1 and float(_measure_text(trimmed, size, display)) > available:
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	return "%s%s" % [trimmed.strip_edges(), suffix]

func _draw_school_chips(schools: Array[String], x: float, y: float) -> void:
	var chip_x: float = x
	for school_id in schools.slice(0, mini(schools.size(), 5)):
		var school_data: Dictionary = DataManager.get_school(school_id)
		var color: Color = _school_color_from_data(school_data)
		var rect: Rect2 = Rect2(chip_x, y - 17.0, 30.0, 22.0)
		draw_rect(rect, Color(color.r, color.g, color.b, 0.22), true)
		draw_rect(rect, Color(color.r, color.g, color.b, 0.82), false, 1.0)
		UiDraw.school_mark(self, school_data, Vector2(rect.position.x + 6.0, rect.position.y + 2.0), 18.0)
		chip_x += 36.0

func _combat_depth_band() -> String:
	return DepthBandScript.band_for_node(_current_node)

func _school_color_from_data(school_data: Dictionary) -> Color:
	var text: String = str(school_data.get("themeColor", ""))
	if text.length() == 7 and text.begins_with("#"):
		return Color.html(text)
	return GameConstants.COLOR_PANEL_ACCENT

func _connect_attack_visual(fighter: Fighter, visual: FighterVisual) -> void:
	var callback: Callable = Callable(visual, "_on_attack_active_started")
	if not fighter.is_connected("attack_active_started", callback):
		fighter.connect("attack_active_started", callback)

func _connect_combat_system_signals() -> void:
	if _combat_system == null:
		return
	var signal_map: Array[Array] = [
		["spawn_particles", Callable(self, "_on_spawn_particles")],
		["camera_shake", Callable(self, "_on_camera_shake")],
		["slow_motion", Callable(self, "_trigger_slow_mo")],
		["show_feedback", Callable(self, "_show_feedback")],
		["damage_dealt", Callable(self, "_on_damage_dealt")],
		["hitstop", Callable(self, "_trigger_hitstop")],
		["sfx", Callable(self, "_on_sfx")],
	]
	for pair in signal_map:
		var signal_name: String = str(pair[0])
		var callback: Callable = pair[1] as Callable
		if not _combat_system.is_connected(signal_name, callback):
			_combat_system.connect(signal_name, callback)

func _on_sfx(id: String) -> void:
	var manager: Node = get_tree().root.get_node_or_null("AudioManager")
	if manager != null and manager.has_method("play"):
		manager.play(id)

func _get_visual_for(fighter: Fighter) -> FighterVisual:
	if fighter.is_ai:
		return _enemy_visual
	return _player_visual
