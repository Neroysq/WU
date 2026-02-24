class_name Camera2DHelper
extends RefCounted

var position: Vector2 = Vector2.ZERO
var offset: Vector2 = Vector2.ZERO
var shake: float = 0.0
var zoom: float = 1.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func update(dt: float) -> void:
	if shake > 0.0:
		shake = maxf(0.0, shake - GameConstants.CAMERA_SHAKE_DECAY * dt)
		var dx: float = (_rng.randf() * 2.0 - 1.0) * shake
		var dy: float = (_rng.randf() * 2.0 - 1.0) * shake * 0.6
		offset = Vector2(dx, dy)
	else:
		offset = offset.lerp(Vector2.ZERO, 0.15)

func add_shake(amount: float) -> void:
	shake += amount

func reset() -> void:
	position = Vector2.ZERO
	offset = Vector2.ZERO
	shake = 0.0
	zoom = 1.0
