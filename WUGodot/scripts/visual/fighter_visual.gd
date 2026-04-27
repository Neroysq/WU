class_name FighterVisual
extends RefCounted

const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")

const ACTIVE_FLASH_DURATION: float = 0.08
const TIP_HISTORY_MAX: int = 6
const TIP_HISTORY_LIFETIME: float = 0.10

var _catalog: AssetCatalog
var _animation_set: AnimationSet

var _current_state: String = ""
var _frame_index: int = 0
var _frame_timer: float = 0.0
var _telegraph_pulse_t: float = 0.0
var _active_flash_t: float = 0.0
var _active_flash_hold_frame: bool = false
var _tip_history: Array[Vector2] = []
var _tip_history_age: Array[float] = []

var scale: float = 2.0
var y_offset: float = 0.0
var weapon_tip_offset: Vector2 = Vector2(60.0, -20.0)
var tint: Color = Color.WHITE
var shadow_tint: Color = Color(0.0, 0.0, 0.0, 0.35)
var enable_shadow: bool = true

func _init(catalog: AssetCatalog) -> void:
	_catalog = catalog
	_animation_set = AnimationSet.new()

func configure(profile: Dictionary, fighter: Fighter) -> void:
	var animation_set_path: String = str(profile.get("animationSet", ""))
	_animation_set = AnimationSet.load_from_file(animation_set_path, _catalog)
	scale = float(profile.get("scale", _animation_set.default_scale))
	y_offset = float(profile.get("yOffset", 0.0))
	weapon_tip_offset = _parse_vector2(profile.get("weaponTipOffset", [60.0, -20.0]), Vector2(60.0, -20.0))
	tint = fighter.color_body
	reset_runtime()

func reset_runtime() -> void:
	_current_state = ""
	_frame_index = 0
	_frame_timer = 0.0
	_telegraph_pulse_t = 0.0
	_active_flash_t = 0.0
	_active_flash_hold_frame = false
	_tip_history.clear()
	_tip_history_age.clear()

func update(fighter: Fighter, dt: float) -> void:
	tint = fighter.color_body
	_telegraph_pulse_t += dt
	# Preserve one full-white render after the signal; otherwise this update tick
	# immediately eats part of the 80 ms teaching flash before the player sees it.
	if _active_flash_hold_frame:
		_active_flash_hold_frame = false
	elif _active_flash_t > 0.0:
		_active_flash_t = maxf(0.0, _active_flash_t - dt)
	_update_tip_history(fighter, dt)

	var target_state: String = _resolve_state(fighter)
	if target_state != _current_state:
		_current_state = target_state
		_frame_index = 0
		_frame_timer = 0.0

	var clip: Dictionary = _animation_set.get_clip(_current_state)
	if clip.is_empty():
		return

	var frames: Array = clip.get("frames", []) as Array
	if frames.is_empty():
		return

	var phases: Array = clip.get("phases", []) as Array
	if _is_attack_state(_current_state) and not phases.is_empty():
		_frame_index = _frame_index_for_phase(clip, fighter)
		_frame_timer = 0.0
		return

	var frame_duration: float = 1.0 / maxf(float(clip.get("fps", 8.0)), 0.001)
	_frame_timer += dt
	while _frame_timer >= frame_duration:
		_frame_timer -= frame_duration
		_frame_index += 1
		if _frame_index >= frames.size():
			if bool(clip.get("loop", true)):
				_frame_index = 0
			else:
				_frame_index = frames.size() - 1

func draw(canvas: CanvasItem, fighter: Fighter, camera_offset: Vector2) -> void:
	var frame: Dictionary = _get_current_frame()
	if frame.is_empty():
		return

	var texture: Texture2D = frame.get("texture", null) as Texture2D
	if texture == null:
		return

	var frame_offset: Vector2 = frame.get("offset", Vector2.ZERO) as Vector2
	var anchor: Vector2 = fighter.position + fighter.animation_offset + camera_offset + Vector2(0.0, y_offset)
	anchor += frame_offset * scale

	var width: float = float(texture.get_width()) * scale
	var height: float = float(texture.get_height()) * scale
	var rect: Rect2 = Rect2(-width * 0.5, -height, width, height)

	canvas.draw_set_transform(anchor, 0.0, Vector2(float(fighter.facing), 1.0))
	if enable_shadow:
		var shadow_rect: Rect2 = rect
		shadow_rect.position += Vector2(2.0, 4.0)
		canvas.draw_texture_rect(texture, shadow_rect, false, shadow_tint)
	var draw_tint: Color = _compute_draw_tint(fighter)
	canvas.draw_texture_rect(texture, rect, false, draw_tint)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_weapon_arc(canvas, fighter, camera_offset)

func _on_attack_active_started() -> void:
	_active_flash_t = ACTIVE_FLASH_DURATION
	_active_flash_hold_frame = true

func get_body_rect(fighter: Fighter, camera_offset: Vector2) -> Rect2:
	var frame: Dictionary = _get_current_frame()
	if frame.is_empty():
		return Rect2(
			fighter.position.x - fighter.half_width + camera_offset.x,
			fighter.position.y - fighter.height + camera_offset.y,
			fighter.half_width * 2.0,
			fighter.height
		)

	var texture: Texture2D = frame.get("texture", null) as Texture2D
	if texture == null:
		return Rect2(
			fighter.position.x - fighter.half_width + camera_offset.x,
			fighter.position.y - fighter.height + camera_offset.y,
			fighter.half_width * 2.0,
			fighter.height
		)

	var frame_offset: Vector2 = frame.get("offset", Vector2.ZERO) as Vector2
	var anchor: Vector2 = fighter.position + fighter.animation_offset + camera_offset + Vector2(0.0, y_offset)
	anchor += frame_offset * scale

	var width: float = float(texture.get_width()) * scale
	var height: float = float(texture.get_height()) * scale
	return Rect2(anchor.x - width * 0.5, anchor.y - height, width, height)

func _resolve_state(fighter: Fighter) -> String:
	var state_index: int = fighter.current_animation
	var raw_state: String = ""
	match state_index:
		Fighter.AnimationState.ATTACKING_LIGHT:
			raw_state = "ATTACKING_LIGHT"
		Fighter.AnimationState.ATTACKING_HEAVY:
			raw_state = "ATTACKING_HEAVY"
		_:
			raw_state = str(Fighter.AnimationState.keys()[state_index]).to_upper()

	if _animation_set.has_clip(raw_state):
		return raw_state

	match raw_state:
		"ATTACKING_LIGHT", "ATTACKING_HEAVY":
			if _animation_set.has_clip("ATTACKING"):
				return "ATTACKING"
		"FALLING":
			if _animation_set.has_clip("JUMPING"):
				return "JUMPING"
		"HIT_REACTION":
			if _animation_set.has_clip("STUNNED"):
				return "STUNNED"
		"LANDING":
			if _animation_set.has_clip("IDLE"):
				return "IDLE"

	return "IDLE"

func _get_current_frame() -> Dictionary:
	var clip: Dictionary = _animation_set.get_clip(_current_state)
	if clip.is_empty():
		clip = _animation_set.get_clip("IDLE")
		if clip.is_empty():
			return {}

	var frames: Array = clip.get("frames", []) as Array
	if frames.is_empty():
		return {}

	var idx: int = clampi(_frame_index, 0, frames.size() - 1)
	if typeof(frames[idx]) != TYPE_DICTIONARY:
		return {}
	return frames[idx] as Dictionary

func _is_attack_state(state_name: String) -> bool:
	return state_name == "ATTACKING_LIGHT" or state_name == "ATTACKING_HEAVY" or state_name == "ATTACKING"

func _frame_index_for_phase(clip: Dictionary, fighter: Fighter) -> int:
	var frames: Array = clip.get("frames", []) as Array
	if frames.is_empty():
		return 0

	var phases: Array = clip.get("phases", []) as Array
	if phases.is_empty() or fighter._attack_state == null:
		return clampi(_frame_index, 0, frames.size() - 1)

	var attack_phase: int = fighter._attack_state.phase()
	if attack_phase == AttackDefinitionScript.Phase.FINISHED:
		return _last_phase_frame_index(phases, frames.size() - 1)

	for phase_entry_variant in phases:
		if typeof(phase_entry_variant) != TYPE_DICTIONARY:
			continue
		var phase_entry: Dictionary = phase_entry_variant as Dictionary
		if int(phase_entry.get("phase", -1)) != attack_phase:
			continue

		var phase_frames: Array = phase_entry.get("frames", []) as Array
		if phase_frames.is_empty():
			return clampi(_frame_index, 0, frames.size() - 1)

		var progress: float = fighter._attack_state.progress_in_phase()
		var local_idx: int = clampi(int(floor(progress * float(phase_frames.size()))), 0, phase_frames.size() - 1)
		return clampi(int(phase_frames[local_idx]), 0, frames.size() - 1)

	return _last_phase_frame_index(phases, frames.size() - 1)

func _last_phase_frame_index(phases: Array, fallback: int) -> int:
	for i in range(phases.size() - 1, -1, -1):
		var phase_entry_variant: Variant = phases[i]
		if typeof(phase_entry_variant) != TYPE_DICTIONARY:
			continue
		var phase_entry: Dictionary = phase_entry_variant as Dictionary
		var phase_frames: Array = phase_entry.get("frames", []) as Array
		if phase_frames.is_empty():
			continue
		return int(phase_frames[phase_frames.size() - 1])
	return fallback

func _compute_draw_tint(fighter: Fighter) -> Color:
	var draw_tint: Color = tint
	var telegraph_color: Color = fighter.current_telegraph_color()
	if telegraph_color.a > 0.001:
		var pulse: float = 0.5 + 0.5 * sin(_telegraph_pulse_t * 12.0)
		draw_tint = draw_tint.lerp(telegraph_color, 0.35 + 0.25 * pulse)

	if _active_flash_t > 0.0:
		var flash_weight: float = clampf(_active_flash_t / ACTIVE_FLASH_DURATION, 0.0, 1.0)
		draw_tint = draw_tint.lerp(Color.WHITE, flash_weight)

	return draw_tint

func _update_tip_history(fighter: Fighter, dt: float) -> void:
	for i in range(_tip_history_age.size() - 1, -1, -1):
		_tip_history_age[i] += dt
		if _tip_history_age[i] > TIP_HISTORY_LIFETIME:
			_tip_history.remove_at(i)
			_tip_history_age.remove_at(i)

	if not fighter.is_hit_active():
		return

	var tip: Vector2 = _weapon_tip_world_position(fighter)
	# Avoid stacking duplicate samples when hitstop or tiny dt advances leave the tip still.
	if _tip_history.is_empty() or tip.distance_to(_tip_history[_tip_history.size() - 1]) >= 1.0:
		_tip_history.append(tip)
		_tip_history_age.append(0.0)

	while _tip_history.size() > TIP_HISTORY_MAX:
		_tip_history.pop_front()
		_tip_history_age.pop_front()

func _weapon_tip_world_position(fighter: Fighter) -> Vector2:
	# Attack definitions are the gameplay source of truth; profile offsets can extend
	# long weapons beyond the hit range, but cannot make the readable trail shorter.
	var tip_distance: float = maxf(absf(weapon_tip_offset.x), fighter.current_attack_range())
	return fighter.position + fighter.animation_offset + Vector2(float(fighter.facing) * tip_distance, weapon_tip_offset.y)

func _draw_weapon_arc(canvas: CanvasItem, fighter: Fighter, camera_offset: Vector2) -> void:
	if _tip_history.is_empty():
		return

	var attack_def: Variant = fighter._attack_state.def
	var base_color: Color = GameConstants.COLOR_SKIN_WARM if attack_def != null and attack_def.is_heavy else GameConstants.COLOR_LIGHT_BLUE

	if _tip_history.size() == 1:
		var freshness: float = 1.0 - clampf(_tip_history_age[0] / TIP_HISTORY_LIFETIME, 0.0, 1.0)
		canvas.draw_circle(_tip_history[0] + camera_offset, 3.0, Color(base_color.r, base_color.g, base_color.b, 0.55 * freshness))
		return

	for i in range(1, _tip_history.size()):
		var age: float = maxf(_tip_history_age[i - 1], _tip_history_age[i])
		var freshness: float = 1.0 - clampf(age / TIP_HISTORY_LIFETIME, 0.0, 1.0)
		var sequence_t: float = float(i) / float(maxi(_tip_history.size() - 1, 1))
		var alpha: float = 0.70 * freshness * sequence_t
		var width: float = lerpf(1.0, 4.0, sequence_t)
		var from_pos: Vector2 = _tip_history[i - 1] + camera_offset
		var to_pos: Vector2 = _tip_history[i] + camera_offset
		canvas.draw_line(from_pos, to_pos, Color(base_color.r, base_color.g, base_color.b, alpha), width)

func _parse_vector2(raw: Variant, fallback: Vector2) -> Vector2:
	if typeof(raw) == TYPE_VECTOR2:
		return raw as Vector2
	if typeof(raw) == TYPE_ARRAY:
		var list: Array = raw as Array
		if list.size() >= 2:
			return Vector2(float(list[0]), float(list[1]))
	if typeof(raw) == TYPE_DICTIONARY:
		var map: Dictionary = raw as Dictionary
		return Vector2(float(map.get("x", fallback.x)), float(map.get("y", fallback.y)))
	return fallback
