class_name FighterPresenter
extends Node2D

const AnimationManifestScript = preload("res://scripts/visual/animation_manifest.gd")
const AnimationGraphScript = preload("res://scripts/visual/animation_graph.gd")
const TimelineScript = preload("res://scripts/visual/animation_clip_timeline.gd")

const FLASH_DECAY: float = 0.08

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

	_ensure_nodes()
	_sprite_current.texture = null
	_sprite_previous.texture = null
	_sprite_previous.visible = false

func handles_state(state_name: String) -> bool:
	if _graph == null or not _graph.has_state(state_name):
		return false
	return _clips.has(_graph.clip_for(state_name))

func current_norm_t() -> float:
	return _norm_t

func set_flash(amount: float) -> void:
	_flash = clampf(amount, 0.0, 1.0)

func update(fighter: Fighter, state_name: String, combat_dt: float, presentation_dt: float, camera_offset: Vector2) -> void:
	_ensure_nodes()
	_maybe_change_state(state_name)
	if _clip == null or _manifest == null:
		return

	_prev_norm_t = _norm_t
	var attack_def: Variant = fighter._attack_state.def if fighter._attack_state != null else null
	if _clip.duration_from_attack_def and attack_def != null and attack_def.duration > 0.0:
		_norm_t = clampf(fighter._attack_state.elapsed / attack_def.duration, 0.0, 1.0)
	else:
		var dur: float = maxf(_clip.fixed_duration, 0.0001)
		_clip_time += combat_dt
		_norm_t = fposmod(_clip_time, dur) / dur

	if _norm_t >= _prev_norm_t:
		for e in _clip.events_in_window(_prev_norm_t, _norm_t, attack_def):
			emit_signal("timeline_event", e)

	position = fighter.position + camera_offset

	var pose: Dictionary = _manifest.get_pose(_clip.pose_at(_norm_t))
	_sprite_current.texture = _catalog.get_texture(str(pose.get("path", "")))
	var foot: Vector2 = pose.get("footAnchor", Vector2.ZERO) as Vector2
	var facing: int = fighter.facing
	var off_x: float = _clip.sample_track("offsetX", _norm_t, 0.0)
	var scale_y: float = _clip.sample_track("scaleY", _norm_t, 1.0)
	var smear_v: float = _clip.sample_track("smear", _norm_t, 0.0)

	var sx: float = _render_scale * float(facing)
	var sy: float = _render_scale * scale_y
	_sprite_current.scale = Vector2(sx, sy)
	_sprite_current.position = Vector2(-foot.x * sx, -foot.y * sy) + Vector2(off_x * float(facing), 0.0)

	if _dissolve_t < 1.0:
		_dissolve_t = minf(1.0, _dissolve_t + presentation_dt / _dissolve_time)
		if _dissolve_t >= 1.0:
			_sprite_previous.visible = false
	_flash = maxf(0.0, _flash - presentation_dt / FLASH_DECAY)

	_mat_current.set_shader_parameter("smear", smear_v)
	_mat_current.set_shader_parameter("smear_dir", Vector2(float(facing), 0.0))
	_mat_current.set_shader_parameter("flash", _flash)
	_mat_current.set_shader_parameter("dissolve", _dissolve_t)
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

func _maybe_change_state(state_name: String) -> void:
	if state_name == _state:
		return

	var enter: Dictionary = _graph.enter_for(state_name) if _graph != null else {"mode": "dither", "time": 0.08}
	if str(enter.get("mode", "dither")) == "dither" and _sprite_current.texture != null:
		_sprite_previous.texture = _sprite_current.texture
		_sprite_previous.position = _sprite_current.position
		_sprite_previous.scale = _sprite_current.scale
		_sprite_previous.visible = true
		_dissolve_t = 0.0
		_dissolve_time = maxf(float(enter.get("time", 0.08)), 0.001)
	else:
		_dissolve_t = 1.0
		_sprite_previous.visible = false

	_state = state_name
	_clip = _clips.get(_graph.clip_for(state_name), null) if _graph != null else null
	_clip_time = 0.0
	_norm_t = 0.0
	_prev_norm_t = 0.0
