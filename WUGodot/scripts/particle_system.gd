class_name ParticleSystem
extends RefCounted

var _particles: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _max_particles: int = 100

func _init(max_particles: int = 100) -> void:
	_max_particles = max_particles
	_rng.randomize()

func spawn_hit_sparks(center: Vector2, count: int, color: Color) -> void:
	if _particles.size() + count > _max_particles:
		count = _max_particles - _particles.size()
	if count <= 0:
		return

	for i in range(count):
		var angle: float = _rng.randf_range(0.0, TAU)
		var speed: float = _rng.randf_range(280.0, 460.0)
		var velocity: Vector2 = Vector2(cos(angle), sin(angle)) * speed
		var life: float = _rng.randf_range(0.18, 0.40)
		_particles.append({
			"position": center,
			"velocity": velocity,
			"life": life,
			"max_life": life,
			"color": color,
			"size": _rng.randi_range(2, 4),
		})

func update(dt: float) -> void:
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["life"] = float(p["life"]) - dt
		if float(p["life"]) <= 0.0:
			_particles.remove_at(i)
			continue
		var velocity: Vector2 = p["velocity"]
		velocity *= 0.92
		velocity.y += 120.0 * dt
		p["velocity"] = velocity
		p["position"] = (p["position"] as Vector2) + velocity * dt
		_particles[i] = p

func draw(canvas: CanvasItem, offset: Vector2 = Vector2.ZERO) -> void:
	for p in _particles:
		var life_ratio: float = float(p["life"]) / maxf(float(p["max_life"]), 0.001)
		var color: Color = p["color"]
		color.a *= life_ratio
		var radius: float = float(int(p["size"])) * (0.6 + life_ratio * 0.7)
		canvas.draw_circle((p["position"] as Vector2) + offset, radius, color)

func clear() -> void:
	_particles.clear()
