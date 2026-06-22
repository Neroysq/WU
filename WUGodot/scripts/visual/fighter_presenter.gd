class_name FighterPresenter
extends Node2D

const AnimationManifestScript = preload("res://scripts/visual/animation_manifest.gd")
const AnimationGraphScript = preload("res://scripts/visual/animation_graph.gd")
const TimelineScript = preload("res://scripts/visual/animation_clip_timeline.gd")
const MoveSkinResolverScript = preload("res://scripts/visual/move_skin_resolver.gd")

const FLASH_DECAY: float = 0.08
const SKIN_TINT_WEIGHT: float = 0.35

var _catalog: AssetCatalog
var _manifest: Variant = null
var _graph: Variant = null
var _clips: Dictionary = {}
var _render_scale: float = 1.0

var _sprite_current: Sprite2D
var _sprite_previous: Sprite2D
var _mat_current: ShaderMaterial
var _mat_previous: ShaderMaterial

var _state: String = ""
var _clip: Variant = null
var _clip_time: float = 0.0
var _norm_t: float = 0.0
var _prev_norm_t: float = 0.0
var _dissolve_t: float = 1.0
var _dissolve_time: float = 0.08
var _flash: float = 0.0
var _slot_school_map: Dictionary = {}
var _variant_ids: Dictionary = {}
var _loaded_skin_schools: Dictionary = {}
var _active_stance_school: String = ""
var _recolor_school: String = ""

signal timeline_event(event_name: String)

func _init(catalog: AssetCatalog) -> void:
	_catalog = catalog

func configure(manifest_path: String, graph_path: String, clip_paths: Array, render_scale: float) -> void:
	_manifest = AnimationManifestScript.load_from_file(manifest_path)
	_graph = AnimationGraphScript.load_from_file(graph_path)
	_clips.clear()
	for p in clip_paths:
		var clip: Variant = TimelineScript.load_from_file(str(p))
		_clips[clip.id] = clip
	_render_scale = render_scale
	_state = ""
	_clip = null
	_clip_time = 0.0
	_norm_t = 0.0
	_prev_norm_t = 0.0
	_dissolve_t = 1.0
	_flash = 0.0
	_slot_school_map.clear()
	_variant_ids.clear()
	_loaded_skin_schools.clear()
	_active_stance_school = ""
	_recolor_school = ""

	_ensure_nodes()
	_sprite_current.texture = null
	_sprite_current.modulate = Color.WHITE
	_sprite_previous.texture = null
	_sprite_previous.modulate = Color.WHITE
	_sprite_previous.visible = false

func handles_state(state_name: String) -> bool:
	if _graph == null or not _graph.has_state(state_name):
		return false
	return _clips.has(_graph.clip_for(state_name))

func current_norm_t() -> float:
	return _norm_t

func set_move_skins(slot_school_map: Dictionary) -> void:
	_slot_school_map = slot_school_map.duplicate(true)
	for slot in _slot_school_map.keys():
		var school: String = str(_slot_school_map[slot])
		if school.is_empty():
			continue
		_load_skin_manifest(school)
		for state_name in MoveSkinResolverScript.STATE_SLOT.keys():
			if str(MoveSkinResolverScript.STATE_SLOT[state_name]) != str(slot):
				continue
			_load_variant_clip(school, str(state_name))

func set_active_stance_school(school: String) -> void:
	_active_stance_school = school

func resolve_state_clip_id(state_name: String) -> String:
	var base_clip_id: String = _graph.clip_for(state_name) if _graph != null else "idle"
	return str(MoveSkinResolverScript.resolve(state_name, base_clip_id, _slot_school_map, _variant_ids)["clip_id"])

func recolor_school_for(state_name: String) -> String:
	var base_clip_id: String = _graph.clip_for(state_name) if _graph != null else "idle"
	return str(MoveSkinResolverScript.resolve(state_name, base_clip_id, _slot_school_map, _variant_ids)["recolor_school"])

func active_tint_school_for(state_name: String) -> String:
	var recolor: String = recolor_school_for(state_name)
	return recolor if not recolor.is_empty() else _active_stance_school

func get_body_rect(fighter: Fighter, camera_offset: Vector2) -> Rect2:
	# Bounds reflect the most recent update(); combat_scene updates the
	# presenter before _draw, so callers see same-frame state.
	var fallback := Rect2(
		fighter.position.x - fighter.half_width + camera_offset.x,
		fighter.position.y - fighter.height + camera_offset.y,
		fighter.half_width * 2.0,
		fighter.height
	)
	if _clip == null or _manifest == null or _sprite_current == null or _sprite_current.texture == null:
		return fallback

	var attack_def: Variant = fighter._attack_state.def if fighter._attack_state != null else null
	var pose: Dictionary = _manifest.get_pose(_clip.pose_at(_norm_t, attack_def))
	if pose.is_empty():
		return fallback
	var hb: Rect2 = pose.get("hurtbox", Rect2()) as Rect2
	if hb.size.x <= 0.0 or hb.size.y <= 0.0:
		return fallback

	var corners: Array[Vector2] = [
		hb.position,
		hb.position + Vector2(hb.size.x, 0.0),
		hb.position + Vector2(0.0, hb.size.y),
		hb.end,
	]
	var rect := Rect2()
	for i in range(corners.size()):
		var p: Vector2 = position + _sprite_current.position + (corners[i] * _sprite_current.scale).rotated(_sprite_current.rotation)
		if i == 0:
			rect = Rect2(p, Vector2.ZERO)
		else:
			rect = rect.expand(p)
	return rect

func set_flash(amount: float) -> void:
	_flash = clampf(amount, 0.0, 1.0)

func update(fighter: Fighter, state_name: String, combat_dt: float, presentation_dt: float, camera_offset: Vector2) -> void:
	_ensure_nodes()
	_maybe_change_state(state_name)
	if _clip == null or _manifest == null:
		return
	_recolor_school = recolor_school_for(state_name) if _graph != null else ""

	_prev_norm_t = _norm_t
	var attack_def: Variant = fighter._attack_state.def if fighter._attack_state != null else null
	if _clip.duration_from_attack_def and attack_def != null and attack_def.duration > 0.0:
		_norm_t = clampf(fighter._attack_state.elapsed / attack_def.duration, 0.0, 1.0)
	else:
		var dur: float = maxf(_clip.fixed_duration, 0.0001)
		_clip_time += combat_dt * _clip_rate_multiplier(fighter)
		if _clip.loop:
			_norm_t = fposmod(_clip_time, dur) / dur
		else:
			_clip_time = minf(_clip_time, dur)
			_norm_t = clampf(_clip_time / dur, 0.0, 1.0)

	if _norm_t >= _prev_norm_t:
		for e in _clip.events_in_window(_prev_norm_t, _norm_t, attack_def):
			emit_signal("timeline_event", e)

	position = fighter.position + camera_offset
	if _clip.use_fighter_offset:
		position += fighter.animation_offset

	var pose: Dictionary = _manifest.get_pose(_clip.pose_at(_norm_t, attack_def))
	_sprite_current.texture = _catalog.get_texture(str(pose.get("path", "")))
	var foot: Vector2 = pose.get("footAnchor", Vector2.ZERO) as Vector2
	var facing: int = fighter.facing
	var off_x: float = _clip.sample_track("offsetX", _norm_t, 0.0)
	var off_y: float = _clip.sample_track("offsetY", _norm_t, 0.0)
	var scale_y: float = _clip.sample_track("scaleY", _norm_t, 1.0)
	var scale_x: float = _clip.sample_track("scaleX", _norm_t, 1.0)
	if not _clip.has_track("scaleX") and _clip.has_track("scaleY"):
		scale_x = clampf(1.0 / maxf(scale_y, 0.001), 0.75, 1.25)
	var rotation_rad: float = deg_to_rad(_clip.sample_track("rotation", _norm_t, 0.0) * float(facing))
	var smear_v: float = _clip.sample_track("smear", _norm_t, 0.0)

	var sx: float = _render_scale * float(facing) * scale_x
	var sy: float = _render_scale * scale_y
	_sprite_current.scale = Vector2(sx, sy)
	_sprite_current.rotation = rotation_rad
	_sprite_current.position = Vector2(off_x * float(facing), off_y) - Vector2(foot.x * sx, foot.y * sy).rotated(rotation_rad)

	if _dissolve_t < 1.0:
		_dissolve_t = minf(1.0, _dissolve_t + presentation_dt / _dissolve_time)
		if _dissolve_t >= 1.0:
			_sprite_previous.visible = false
	_flash = maxf(0.0, _flash - presentation_dt / FLASH_DECAY)

	_mat_current.set_shader_parameter("smear", smear_v)
	_mat_current.set_shader_parameter("smear_dir", Vector2(float(facing), 0.0))
	_mat_current.set_shader_parameter("flash", _flash)
	_mat_current.set_shader_parameter("dissolve", _dissolve_t)
	_mat_current.set_shader_parameter("skin_tint_weight", 0.0)
	_mat_previous.set_shader_parameter("skin_tint_weight", 0.0)
	var tint_school: String = _recolor_school if not _recolor_school.is_empty() else _active_stance_school
	if tint_school.is_empty():
		_sprite_current.modulate = Color.WHITE
		_sprite_previous.modulate = Color.WHITE
	else:
		var skin_color: Color = Color.html(str(DataManager.get_school(tint_school).get("themeColor", "#ffffff")))
		var modulated_tint: Color = Color.WHITE.lerp(skin_color, SKIN_TINT_WEIGHT)
		var flashed: Color = modulated_tint.lerp(Color.WHITE, _flash)
		_sprite_current.modulate = flashed
		_sprite_previous.modulate = flashed
	_mat_previous.set_shader_parameter("smear", 0.0)
	_mat_previous.set_shader_parameter("flash", 0.0)
	_mat_previous.set_shader_parameter("dissolve", 1.0 - _dissolve_t)

func _ensure_nodes() -> void:
	if _sprite_current != null and _sprite_previous != null:
		return

	var shader: Shader = load("res://scripts/visual/shaders/fighter_presenter.gdshader") as Shader
	_mat_previous = ShaderMaterial.new()
	_mat_previous.shader = shader
	_mat_current = ShaderMaterial.new()
	_mat_current.shader = shader

	_sprite_previous = Sprite2D.new()
	_sprite_previous.material = _mat_previous
	_sprite_previous.centered = false
	_sprite_previous.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite_previous)

	_sprite_current = Sprite2D.new()
	_sprite_current.material = _mat_current
	_sprite_current.centered = false
	_sprite_current.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite_current)

	_sprite_previous.visible = false

func _load_variant_clip(school: String, state_name: String) -> void:
	if _graph == null:
		return
	var base_clip_id: String = _graph.clip_for(state_name)
	var path: String = "res://assets/animation_clips/skins/%s/%s_%s.timeline.json" % [school, school, base_clip_id]
	if not FileAccess.file_exists(path):
		return
	var clip: Variant = TimelineScript.load_from_file(path)
	_clips[clip.id] = clip
	_variant_ids[MoveSkinResolverScript.variant_key(school, state_name)] = clip.id

func _load_skin_manifest(school: String) -> void:
	if _loaded_skin_schools.has(school) or _manifest == null:
		return
	_loaded_skin_schools[school] = true
	var path: String = "res://assets/animation_manifests/skins/%s.manifest.json" % school
	if not FileAccess.file_exists(path):
		return
	var overlay: Variant = AnimationManifestScript.load_from_file(path)
	for pose_name in overlay.poses.keys():
		_manifest.poses[str(pose_name)] = overlay.poses[pose_name]

func _maybe_change_state(state_name: String) -> void:
	if state_name == _state:
		return

	var enter: Dictionary = _graph.enter_for(state_name) if _graph != null else {"mode": "dither", "time": 0.08}
	if str(enter.get("mode", "dither")) == "dither" and _sprite_current.texture != null:
		_sprite_previous.texture = _sprite_current.texture
		_sprite_previous.position = _sprite_current.position
		_sprite_previous.scale = _sprite_current.scale
		_sprite_previous.rotation = _sprite_current.rotation
		_sprite_previous.visible = true
		_dissolve_t = 0.0
		_dissolve_time = maxf(float(enter.get("time", 0.08)), 0.001)
	else:
		_dissolve_t = 1.0
		_sprite_previous.visible = false

	_state = state_name
	_clip = _clips.get(resolve_state_clip_id(state_name), null) if _graph != null else null
	_recolor_school = recolor_school_for(state_name) if _graph != null else ""
	_clip_time = 0.0
	_norm_t = 0.0
	_prev_norm_t = 0.0

func _clip_rate_multiplier(fighter: Fighter) -> float:
	if _clip == null or str(_clip.rate_mode) != "velocity":
		return 1.0
	var denom: float = maxf(absf(fighter.move_speed), 1.0)
	return clampf(absf(fighter.velocity.x) / denom, 0.3, 1.6)
