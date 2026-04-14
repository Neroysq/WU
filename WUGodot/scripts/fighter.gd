class_name Fighter
extends RefCounted

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")
const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")
const AttackStateScript = preload("res://scripts/attack_state.gd")

enum AnimationState {
	IDLE,
	WALKING,
	ATTACKING_LIGHT,
	ATTACKING_HEAVY,
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
var _attack_state: Variant = AttackStateScript.new()
var technique_engine: Variant = null
var ai_brain: Variant = null
var boss_controller: Variant = null
var archetype_id: String = ""
var gold: int = 0

var dash_duration: float = GameConstants.DASH_DURATION
var dash_cooldown: float = GameConstants.DASH_COOLDOWN
var dash_iframe_end: float = GameConstants.DASH_IFRAME_END
var dash_speed: float = 1100.0
var air_dash_speed: float = 950.0

var parry_window: float = GameConstants.PARRY_WINDOW
var stun_duration: float = GameConstants.STUN_DURATION
var combo_window_duration: float = 0.5
var posture_recovery_rate: float = GameConstants.POSTURE_RECOVERY_RATE

var is_blocking: bool = false
var is_stunned: bool = false
var was_hit_this_swing: bool = false
var bleed_timer: float = 0.0
var bleed_dps: float = 0.0
var is_grabbed: bool = false
var _grab_timer: float = 0.0

var combo_window: float = 0.0
var combo_count: int = 0

var controls: Dictionary = {
	"left": KEY_A,
	"right": KEY_D,
	"attack": KEY_J,
	"block": KEY_K,
	"dash": KEY_SPACE,
	"jump": KEY_W,
	"stance": KEY_L,
}

var _attack_cooldown: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _parry_timer: float = 0.0
var _stun_timer: float = 0.0
var _jump_cooldown: float = 0.0
var _landing_recovery: float = 0.0
var _ai_decision_timer: float = 0.0
var _phoenix_invuln_timer: float = 0.0

func reset_for_combat() -> void:
	velocity = Vector2.ZERO
	animation_offset = Vector2.ZERO
	animation_timer = 0.0
	current_animation = AnimationState.IDLE
	is_grounded = true
	has_double_jump = false
	is_invulnerable = false
	is_blocking = false
	is_stunned = false
	was_hit_this_swing = false
	combo_window = 0.0
	combo_count = 0
	_attack_state.clear()
	_attack_cooldown = 0.0
	_dash_timer = 0.0
	_dash_cooldown = 0.0
	_parry_timer = 0.0
	_stun_timer = 0.0
	_jump_cooldown = 0.0
	_landing_recovery = 0.0
	_ai_decision_timer = 0.0
	bleed_timer = 0.0
	bleed_dps = 0.0
	_phoenix_invuln_timer = 0.0
	is_grabbed = false
	_grab_timer = 0.0
	if technique_engine != null:
		technique_engine.deactivate_stance(self)
		technique_engine.reset_combat_state(self)

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
	if _ai_decision_timer > 0.0:
		_ai_decision_timer -= dt
	if _phoenix_invuln_timer > 0.0:
		_phoenix_invuln_timer -= dt
	if _grab_timer > 0.0:
		_grab_timer -= dt
		if _grab_timer <= 0.0:
			is_grabbed = false
	if technique_engine != null:
		technique_engine.update(dt, self)

	if combo_window > 0.0:
		combo_window -= dt
		if combo_window <= 0.0:
			combo_count = 0

	if is_stunned:
		_stun_timer -= dt
		if _stun_timer <= 0.0:
			is_stunned = false
			current_animation = AnimationState.IDLE

	if _attack_state.is_active():
		var events: Dictionary = _attack_state.advance(dt)
		if bool(events.get("finished", false)):
			was_hit_this_swing = false
			# D2 Tiger Stance: auto-chain light attacks into a 3-hit combo.
			if technique_engine != null and technique_engine.active_stance() == "D2" \
					and _attack_state.def != null and _attack_state.def.id == "tiger_light" \
					and combo_count < 3:
				combo_window = combo_window_duration
				start_light_attack()
			elif current_animation == AnimationState.ATTACKING_LIGHT or current_animation == AnimationState.ATTACKING_HEAVY:
				current_animation = AnimationState.IDLE

	if _dash_timer > 0.0:
		_dash_timer -= dt
		if _dash_timer <= 0.0:
			_dash_timer = 0.0
			velocity.x *= 0.3
			if current_animation == AnimationState.DASHING:
				current_animation = AnimationState.IDLE

	is_invulnerable = _compute_is_invulnerable()

	_update_animation(dt)

func _update_animation(dt: float) -> void:
	animation_timer += dt

	match current_animation:
		AnimationState.ATTACKING_LIGHT, AnimationState.ATTACKING_HEAVY:
			var attack_progress: float = _attack_state.progress()
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

func _compute_is_invulnerable() -> bool:
	if _phoenix_invuln_timer > 0.0:
		return true
	if _dash_timer <= 0.0:
		return false
	var dash_elapsed: float = dash_duration - _dash_timer
	return dash_elapsed >= GameConstants.DASH_STARTUP_END and dash_elapsed < dash_iframe_end

func dash_phase_label() -> String:
	if _dash_timer <= 0.0:
		return "idle"
	var dash_elapsed: float = dash_duration - _dash_timer
	if dash_elapsed < GameConstants.DASH_STARTUP_END:
		return "startup"
	if dash_elapsed < dash_iframe_end:
		return "iframes"
	return "recovery"

func current_attack_range() -> float:
	if _attack_state.is_active() and _attack_state.def != null:
		return _attack_state.def.range_units
	return attack_range

func current_telegraph_color() -> Color:
	if not _attack_state.is_active():
		return Color(0.0, 0.0, 0.0, 0.0)
	if _attack_state.phase() != AttackDefinitionScript.Phase.WINDUP:
		return Color(0.0, 0.0, 0.0, 0.0)
	if _attack_state.def != null and _attack_state.def.is_perilous:
		return Color(GameConstants.COLOR_CRIMSON.r, GameConstants.COLOR_CRIMSON.g, GameConstants.COLOR_CRIMSON.b, 0.86)
	return Color(GameConstants.COLOR_PAPER.r, GameConstants.COLOR_PAPER.g, GameConstants.COLOR_PAPER.b, 0.78)

func can_attack() -> bool:
	return not _attack_state.is_active() and _attack_cooldown <= 0.0 and _dash_timer <= 0.0 and not is_stunned and _landing_recovery <= 0.0 and not is_grabbed

func can_jump() -> bool:
	return (is_grounded or has_double_jump) and _jump_cooldown <= 0.0 and not is_stunned and not is_grabbed

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

func start_light_attack() -> void:
	var override: Variant = null
	if technique_engine != null:
		override = technique_engine.get_light_override()
	_start_attack_with(override if override != null else AttackCatalogScript.hu_light())

func start_heavy_attack() -> void:
	var override: Variant = null
	if technique_engine != null:
		override = technique_engine.get_heavy_override()
	_start_attack_with(override if override != null else AttackCatalogScript.hu_heavy())

func _start_attack_with(definition: Variant) -> void:
	if not can_attack():
		return

	combo_count = combo_count + 1 if combo_window > 0.0 else 1
	combo_window = combo_window_duration

	_attack_state.start(definition)
	_attack_cooldown = definition.duration * (0.8 if combo_count > 2 else 1.0)
	was_hit_this_swing = false
	current_animation = AnimationState.ATTACKING_HEAVY if definition.is_heavy else AnimationState.ATTACKING_LIGHT
	animation_timer = 0.0

	if not is_grounded:
		velocity.y *= 0.5

func is_hit_active() -> bool:
	return _attack_state.is_hit_active()

func can_dash() -> bool:
	return _dash_timer <= 0.0 and _dash_cooldown <= 0.0 and not _attack_state.is_active() and not is_stunned and not is_grabbed

func start_dash(direction: int = 999) -> void:
	_dash_timer = dash_duration
	_dash_cooldown = dash_cooldown
	var speed: float = dash_speed if is_grounded else air_dash_speed
	var dash_direction: int = direction if direction != 999 else facing
	velocity = Vector2(float(dash_direction) * speed, 0.0 if is_grounded else velocity.y * 0.3)
	current_animation = AnimationState.DASHING
	animation_timer = 0.0

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
	_attack_state.clear()
	_attack_cooldown = 0.25
	velocity.x *= 0.3
	current_animation = AnimationState.STUNNED
	animation_timer = 0.0

func gain_rage(amount: float) -> void:
	rage_current = clampf(rage_current + amount, 0.0, rage_max)

func is_in_recovery() -> bool:
	return not _attack_state.is_active() and _attack_cooldown > 0.0

func on_stance_input() -> bool:
	if technique_engine == null:
		return false
	return technique_engine.activate_stance(self)

static func player_controls() -> Dictionary:
	return {
		"left": KEY_A,
		"right": KEY_D,
		"attack": KEY_J,
		"block": KEY_K,
		"dash": KEY_SPACE,
		"jump": KEY_W,
		"stance": KEY_L,
	}

static func none_controls() -> Dictionary:
	return {
		"left": KEY_NONE,
		"right": KEY_NONE,
		"attack": KEY_NONE,
		"block": KEY_NONE,
		"dash": KEY_NONE,
		"jump": KEY_NONE,
		"stance": KEY_NONE,
	}
