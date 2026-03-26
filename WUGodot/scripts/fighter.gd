class_name Fighter
extends RefCounted

enum AnimationState {
	IDLE,
	WALKING,
	ATTACKING,
	HIT_REACTION,
	BLOCKING,
	STUNNED,
	DASHING,
	JUMPING,
	FALLING,
	LANDING,
}

var name: String = "Fighter"
var is_ai: bool = false
var visual_profile_id: String = ""

var color_body: Color = Color8(130, 160, 220)
var color_accent: Color = Color8(90, 120, 190)

var current_animation: int = AnimationState.IDLE
var animation_timer: float = 0.0
var animation_offset: Vector2 = Vector2.ZERO

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var facing: int = 1

var half_width: float = 22.0
var height: float = 88.0

var move_speed: float = GameConstants.DEFAULT_MOVE_SPEED
var jump_force: float = 750.0
var gravity: float = 2800.0
var is_grounded: bool = true
var has_double_jump: bool = false
var is_invulnerable: bool = false

var _health_max: float = GameConstants.DEFAULT_HEALTH_MAX
var _health_current: float = GameConstants.DEFAULT_HEALTH_MAX
var _posture_max: float = GameConstants.DEFAULT_POSTURE_MAX
var _posture_current: float = GameConstants.DEFAULT_POSTURE_MAX
var _rage_max: float = GameConstants.DEFAULT_RAGE_MAX
var _rage_current: float = 0.0

var health_max: float:
	get:
		return _health_max
	set(value):
		_health_max = maxf(value, 1.0)
		_health_current = clampf(_health_current, 0.0, _health_max)

var health_current: float:
	get:
		return _health_current
	set(value):
		_health_current = clampf(value, 0.0, health_max)

var posture_max: float:
	get:
		return _posture_max
	set(value):
		_posture_max = maxf(value, 1.0)
		_posture_current = clampf(_posture_current, 0.0, _posture_max)

var posture_current: float:
	get:
		return _posture_current
	set(value):
		_posture_current = clampf(value, 0.0, posture_max)

var rage_max: float:
	get:
		return _rage_max
	set(value):
		_rage_max = maxf(value, 1.0)
		_rage_current = clampf(_rage_current, 0.0, _rage_max)

var rage_current: float:
	get:
		return _rage_current
	set(value):
		_rage_current = clampf(value, 0.0, rage_max)

var attack_range: float = GameConstants.DEFAULT_ATTACK_RANGE
var attack_damage: float = GameConstants.DEFAULT_ATTACK_DAMAGE
var attack_posture_damage: float = GameConstants.DEFAULT_POSTURE_DAMAGE
var attack_duration: float = GameConstants.ATTACK_DURATION
var attack_active_start: float = GameConstants.ATTACK_ACTIVE_START
var attack_active_end: float = GameConstants.ATTACK_ACTIVE_END

var dash_duration: float = GameConstants.DASH_DURATION
var dash_cooldown: float = GameConstants.DASH_COOLDOWN
var dash_speed: float = 1100.0
var air_dash_speed: float = 950.0

var parry_window: float = GameConstants.PARRY_WINDOW
var stun_duration: float = GameConstants.STUN_DURATION
var combo_window_duration: float = 0.5
var posture_recovery_rate: float = GameConstants.POSTURE_RECOVERY_RATE

var is_blocking: bool = false
var is_stunned: bool = false
var is_telegraphing: bool = false
var was_hit_this_swing: bool = false

var telegraph_timer: float = 0.0
var telegraph_duration: float = 0.35
var combo_window: float = 0.0
var combo_count: int = 0

var controls: Dictionary = {
	"left": KEY_A,
	"right": KEY_D,
	"attack": KEY_J,
	"block": KEY_K,
	"dash": KEY_SPACE,
	"jump": KEY_W,
}

var _attack_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _parry_timer: float = 0.0
var _stun_timer: float = 0.0
var _jump_cooldown: float = 0.0
var _landing_recovery: float = 0.0
var _iframe_timer: float = 0.0

func update_timers(dt: float) -> void:
	if not is_stunned:
		posture_current += posture_recovery_rate * dt

	if _attack_cooldown > 0.0:
		_attack_cooldown -= dt
	if _dash_cooldown > 0.0:
		_dash_cooldown -= dt
	if _parry_timer > 0.0:
		_parry_timer -= dt
	if _jump_cooldown > 0.0:
		_jump_cooldown -= dt
	if _landing_recovery > 0.0:
		_landing_recovery -= dt
	if _iframe_timer > 0.0:
		_iframe_timer -= dt

	if combo_window > 0.0:
		combo_window -= dt
		if combo_window <= 0.0:
			combo_count = 0

	is_invulnerable = _iframe_timer > 0.0 or (_dash_timer > 0.0 and _dash_timer > dash_duration * 0.2)

	if is_stunned:
		_stun_timer -= dt
		if _stun_timer <= 0.0:
			is_stunned = false
			current_animation = AnimationState.IDLE

	if _attack_timer > 0.0:
		_attack_timer -= dt
		if _attack_timer <= 0.0:
			_attack_timer = 0.0
			was_hit_this_swing = false
			current_animation = AnimationState.IDLE

	if _dash_timer > 0.0:
		_dash_timer -= dt
		if _dash_timer <= 0.0:
			_dash_timer = 0.0
			velocity.x *= 0.3
			current_animation = AnimationState.IDLE

	if is_telegraphing:
		telegraph_timer -= dt
		if telegraph_timer < -1.0:
			is_telegraphing = false

	_update_animation(dt)

func _update_animation(dt: float) -> void:
	animation_timer += dt

	match current_animation:
		AnimationState.ATTACKING:
			var attack_progress: float = 1.0 - (_attack_timer / maxf(attack_duration, 0.001))
			animation_offset.x = sin(attack_progress * PI) * 15.0 * float(facing)
		AnimationState.HIT_REACTION:
			animation_offset.x = cos(animation_timer * 20.0) * 8.0 * float(-facing)
			if animation_timer > 0.3:
				current_animation = AnimationState.IDLE
				animation_timer = 0.0
		AnimationState.BLOCKING:
			animation_offset.y = sin(animation_timer * 8.0) * 3.0
			if not is_blocking:
				current_animation = AnimationState.IDLE
				animation_timer = 0.0
		AnimationState.STUNNED:
			animation_offset.x = sin(animation_timer * 12.0) * 5.0
			animation_offset.y = cos(animation_timer * 15.0) * 2.0
		AnimationState.DASHING:
			var dash_progress: float = 1.0 - (_dash_timer / maxf(dash_duration, 0.001))
			animation_offset.x = sin(dash_progress * PI) * 20.0 * float(facing)
			animation_offset.y = sin(dash_progress * PI * 2.0) * -8.0
		AnimationState.JUMPING:
			animation_offset.y = sin(animation_timer * 10.0) * 3.0 - 5.0
		AnimationState.LANDING:
			animation_offset.y = cos(animation_timer * 15.0) * 4.0 + 3.0
			if animation_timer > 0.2:
				current_animation = AnimationState.IDLE
				animation_timer = 0.0
		AnimationState.WALKING:
			animation_offset.y = sin(animation_timer * 12.0) * 2.0
			if absf(velocity.x) < 10.0:
				current_animation = AnimationState.IDLE
				animation_timer = 0.0
		_:
			animation_offset = animation_offset.lerp(Vector2.ZERO, 0.15)

func can_attack() -> bool:
	return _attack_timer <= 0.0 and _attack_cooldown <= 0.0 and not is_stunned and not is_telegraphing and _landing_recovery <= 0.0

func can_jump() -> bool:
	return (is_grounded or has_double_jump) and _jump_cooldown <= 0.0 and not is_stunned

func start_jump() -> void:
	if not is_grounded and has_double_jump:
		has_double_jump = false
		velocity.y = -jump_force * 0.85
	elif is_grounded:
		velocity.y = -jump_force
		is_grounded = false
		has_double_jump = true

	_jump_cooldown = 0.1
	current_animation = AnimationState.JUMPING
	animation_timer = 0.0

func land() -> void:
	is_grounded = true
	has_double_jump = false
	_landing_recovery = 0.1
	if current_animation == AnimationState.JUMPING or current_animation == AnimationState.FALLING:
		current_animation = AnimationState.LANDING
		animation_timer = 0.0

func start_telegraph() -> void:
	if can_attack():
		is_telegraphing = true
		telegraph_timer = telegraph_duration

func start_attack() -> void:
	if _attack_timer > 0.0 or _attack_cooldown > 0.0 or is_stunned or _landing_recovery > 0.0:
		return

	combo_count = combo_count + 1 if combo_window > 0.0 else 1
	combo_window = combo_window_duration

	_attack_timer = attack_duration
	_attack_cooldown = attack_duration * (0.8 if combo_count > 2 else 1.0)
	was_hit_this_swing = false
	is_telegraphing = false
	current_animation = AnimationState.ATTACKING
	animation_timer = 0.0

	if not is_grounded:
		velocity.y *= 0.5

func is_hit_active() -> bool:
	return _attack_timer > 0.0 and _attack_timer <= (attack_duration - attack_active_start) and _attack_timer >= (attack_duration - attack_active_end)

func can_dash() -> bool:
	return _dash_timer <= 0.0 and _dash_cooldown <= 0.0 and not is_stunned

func start_dash(direction: int = 999) -> void:
	_dash_timer = dash_duration
	_dash_cooldown = dash_cooldown
	var speed: float = dash_speed if is_grounded else air_dash_speed
	var dash_direction: int = direction if direction != 999 else facing
	velocity = Vector2(float(dash_direction) * speed, 0.0 if is_grounded else velocity.y * 0.3)
	current_animation = AnimationState.DASHING
	animation_timer = 0.0
	_iframe_timer = dash_duration * 0.7

func trigger_parry_window() -> void:
	_parry_timer = parry_window

func is_parrying() -> bool:
	return _parry_timer > 0.0

func consume_parry_if_active() -> bool:
	if _parry_timer > 0.0:
		_parry_timer = 0.0
		return true
	return false

func apply_posture_damage(amount: float) -> void:
	posture_current -= amount
	if posture_current <= 0.0:
		posture_current = 0.0
		apply_stun(stun_duration)
		posture_current = minf(posture_max * 0.4, posture_max)

func apply_stun(duration: float) -> void:
	is_stunned = true
	_stun_timer = duration
	_attack_timer = 0.0
	_attack_cooldown = 0.25
	is_telegraphing = false
	velocity.x *= 0.3
	current_animation = AnimationState.STUNNED
	animation_timer = 0.0

func gain_rage(amount: float) -> void:
	rage_current = clampf(rage_current + amount, 0.0, rage_max)

func is_in_recovery() -> bool:
	return _attack_timer <= 0.0 and _attack_cooldown > 0.0

static func player_controls() -> Dictionary:
	return {
		"left": KEY_A,
		"right": KEY_D,
		"attack": KEY_J,
		"block": KEY_K,
		"dash": KEY_SPACE,
		"jump": KEY_W,
	}

static func none_controls() -> Dictionary:
	return {
		"left": KEY_NONE,
		"right": KEY_NONE,
		"attack": KEY_NONE,
		"block": KEY_NONE,
		"dash": KEY_NONE,
		"jump": KEY_NONE,
	}
