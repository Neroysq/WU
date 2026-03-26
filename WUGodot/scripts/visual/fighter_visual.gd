class_name FighterVisual
extends RefCounted

var _catalog: AssetCatalog
var _animation_set: AnimationSet

var _current_state: String = ""
var _frame_index: int = 0
var _frame_timer: float = 0.0

var scale: float = 2.0
var y_offset: float = 0.0
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
	tint = fighter.color_body
	reset_runtime()

func reset_runtime() -> void:
	_current_state = ""
	_frame_index = 0
	_frame_timer = 0.0

func update(fighter: Fighter, dt: float) -> void:
	tint = fighter.color_body
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
	canvas.draw_texture_rect(texture, rect, false, tint)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
	var raw_state: String = str(Fighter.AnimationState.keys()[fighter.current_animation]).to_upper()
	if _animation_set.has_clip(raw_state):
		return raw_state

	match raw_state:
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
