class_name CombatSystem
extends RefCounted

signal spawn_particles(position: Vector2, count: int, color: Color)
signal camera_shake(amount: float)
signal slow_motion(factor: float, duration: float)
signal show_feedback(message: String, duration: float)
signal damage_dealt(position: Vector2, damage: float, is_critical: bool)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func update_player(fighter: Fighter, input_state: Dictionary, dt: float, enemy: Fighter = null) -> void:
	var settings: Dictionary = DataManager.get_game_settings()
	var move: float = float(input_state.get("move", 0.0))
	var is_trying_to_move: bool = absf(move) > 0.01

	var ground_move_control: float = float(settings.get("groundMoveControl", 0.25))
	var air_move_control: float = float(settings.get("airMoveControl", 0.12))
	var attack_move_control_multiplier: float = float(settings.get("attackMoveControlMultiplier", 2.0))
	var move_control: float = ground_move_control if fighter.is_grounded else air_move_control
	var target_speed: float = move * fighter.move_speed if is_trying_to_move else 0.0

	var can_move: bool = fighter.current_animation != Fighter.AnimationState.DASHING and fighter.current_animation != Fighter.AnimationState.ATTACKING and fighter.current_animation != Fighter.AnimationState.STUNNED
	if can_move:
		fighter.velocity.x = lerp(fighter.velocity.x, target_speed, move_control)
	elif fighter.current_animation == Fighter.AnimationState.ATTACKING:
		fighter.velocity.x = lerp(fighter.velocity.x, 0.0, move_control * attack_move_control_multiplier)

	if fighter.is_grounded and is_trying_to_move and fighter.current_animation == Fighter.AnimationState.IDLE:
		fighter.current_animation = Fighter.AnimationState.WALKING
		fighter.animation_timer = 0.0

	if bool(input_state.get("jump_pressed", false)) and fighter.can_jump():
		fighter.start_jump()
		emit_signal("spawn_particles", fighter.position + Vector2(0, 5), 12, Color8(180, 200, 255))

	if bool(input_state.get("dash_pressed", false)) and fighter.can_dash():
		var dash_direction: int = fighter.facing
		if is_trying_to_move:
			dash_direction = 1 if move > 0.0 else -1
		elif enemy != null:
			dash_direction = 1 if enemy.position.x > fighter.position.x else -1
		fighter.start_dash(dash_direction)
		emit_signal("spawn_particles", fighter.position, 8, Color8(200, 200, 255))
		emit_signal("camera_shake", 3.0)

	if bool(input_state.get("attack_pressed", false)) and fighter.can_attack():
		fighter.start_attack()
		var attack_pos: Vector2 = Vector2(fighter.position.x + float(fighter.facing) * fighter.half_width, fighter.position.y - fighter.height * 0.4)
		var particle_count: int = 6 + fighter.combo_count * 2
		var attack_color: Color = Color8(255, 180, 100) if fighter.combo_count > 2 else Color8(255, 255, 200)
		emit_signal("spawn_particles", attack_pos, particle_count, attack_color)
		emit_signal("camera_shake", 2.0 + fighter.combo_count * 0.5)
		if fighter.combo_count > 2:
			emit_signal("show_feedback", "COMBO x%d!" % fighter.combo_count, 0.5)

	var was_blocking: bool = fighter.is_blocking
	fighter.is_blocking = bool(input_state.get("block_down", false))
	if bool(input_state.get("block_pressed", false)):
		fighter.trigger_parry_window()
		fighter.current_animation = Fighter.AnimationState.BLOCKING
		fighter.animation_timer = 0.0

	if fighter.is_blocking and fighter.current_animation == Fighter.AnimationState.IDLE:
		fighter.current_animation = Fighter.AnimationState.BLOCKING
		fighter.animation_timer = 0.0
	elif (not fighter.is_blocking) and was_blocking and fighter.current_animation == Fighter.AnimationState.BLOCKING:
		fighter.current_animation = Fighter.AnimationState.IDLE
		fighter.animation_timer = 0.0

	if not fighter.is_grounded:
		fighter.velocity.y += fighter.gravity * dt
		if fighter.velocity.y > 0.0 and fighter.current_animation == Fighter.AnimationState.JUMPING:
			fighter.current_animation = Fighter.AnimationState.FALLING
			fighter.animation_timer = 0.0

	fighter.update_timers(dt)
	fighter.position += fighter.velocity * dt

	if fighter.position.y >= GameConstants.GROUND_Y:
		if (not fighter.is_grounded) and fighter.velocity.y > 100.0:
			fighter.land()
			emit_signal("spawn_particles", Vector2(fighter.position.x, GameConstants.GROUND_Y + 5.0), 8, Color8(140, 120, 100))
		fighter.position.y = GameConstants.GROUND_Y
		fighter.velocity.y = 0.0
		fighter.is_grounded = true
	else:
		fighter.is_grounded = false

func update_ai(ai: Fighter, target: Fighter, dt: float) -> void:
	if not ai.is_ai:
		return

	ai.update_timers(dt)

	var distance: float = target.position.x - ai.position.x
	var abs_distance: float = absf(distance)
	var direction: float = -1.0 if distance < 0.0 else 1.0
	var vertical_diff: float = target.position.y - ai.position.y

	var aggression_multiplier: float = 1.2 + (1.0 - ai.health_current / maxf(ai.health_max, 0.001)) * 0.5

	if ai.is_in_recovery() or ai.is_stunned:
		var retreat_speed: float = 0.0 if ai.is_stunned else -direction * ai.move_speed * 0.4
		ai.velocity.x = lerp(ai.velocity.x, retreat_speed, 0.2)
	else:
		if abs_distance > ai.attack_range * 0.9:
			ai.velocity.x = lerp(ai.velocity.x, direction * ai.move_speed * aggression_multiplier, 0.3)
			if vertical_diff < -50.0 and ai.can_jump() and _rng.randf() < 0.1:
				ai.start_jump()
			if abs_distance > 200.0 and ai.can_dash() and _rng.randf() < 0.05 * aggression_multiplier:
				ai.start_dash()
				emit_signal("spawn_particles", ai.position, 8, Color8(255, 100, 100))
		else:
			if _rng.randf() < 0.02 * aggression_multiplier:
				ai.velocity.x = lerp(ai.velocity.x, -direction * ai.move_speed * 0.8, 0.3)
			else:
				ai.velocity.x = lerp(ai.velocity.x, 0.0, 0.3)

			var attack_chance: float = 0.25 * aggression_multiplier
			if ai.can_attack() and _rng.randf() < attack_chance:
				ai.start_telegraph()

			if target.is_hit_active() and _rng.randf() < 0.4:
				ai.is_blocking = true
				ai.trigger_parry_window()
			else:
				ai.is_blocking = false

	if ai.is_telegraphing and ai.telegraph_timer <= 0.0:
		ai.start_attack()
		if ai.combo_count > 0 and _rng.randf() < 0.3 * aggression_multiplier:
			ai.combo_window = 0.4

	if not ai.is_grounded:
		ai.velocity.y += ai.gravity * dt

	ai.position += ai.velocity * dt

	if ai.position.y >= GameConstants.GROUND_Y:
		if (not ai.is_grounded) and ai.velocity.y > 100.0:
			ai.land()
		ai.position.y = GameConstants.GROUND_Y
		ai.velocity.y = 0.0
		ai.is_grounded = true
	else:
		ai.is_grounded = false

func resolve_hits(attacker: Fighter, defender: Fighter) -> void:
	var settings: Dictionary = DataManager.get_game_settings()
	if not attacker.is_hit_active():
		return
	if defender.is_invulnerable:
		return

	var in_range: bool = absf(defender.position.x - attacker.position.x) <= attacker.attack_range + defender.half_width
	var vertical_range: bool = absf(defender.position.y - attacker.position.y) <= defender.height + 20.0
	var facing_correct: bool = (-1 if defender.position.x - attacker.position.x < 0.0 else 1) == attacker.facing

	if in_range and vertical_range and facing_correct and not attacker.was_hit_this_swing:
		attacker.was_hit_this_swing = true

		if defender.consume_parry_if_active():
			attacker.apply_posture_damage(float(settings.get("parryPostureDamage", 55.0)))
			attacker.apply_stun(float(settings.get("parryStunDuration", 0.6)))
			defender.gain_rage(12.0)
			emit_signal("camera_shake", 12.0)

			var parry_pos: Vector2 = defender.position + Vector2(float(defender.facing) * -6.0, -defender.height + 24.0)
			for i in range(24):
				var angle: float = (float(i) / 24.0) * TAU
				var spark_pos: Vector2 = parry_pos + Vector2(cos(angle), sin(angle)) * 30.0
				emit_signal("spawn_particles", spark_pos, 2, Color8(255, 230, 90))

			emit_signal("slow_motion", 0.55, 0.30)
			emit_signal("show_feedback", "PARRY!", 0.8)
			return

		var combo_damage_bonus: float = 1.0 + float(attacker.combo_count - 1) * 0.15
		var hp_damage: float = attacker.attack_damage * combo_damage_bonus
		var posture_damage: float = attacker.attack_posture_damage * combo_damage_bonus

		if defender.is_blocking:
			hp_damage *= float(settings.get("blockHealthMultiplier", 0.2))
			posture_damage *= float(settings.get("blockPostureMultiplier", 1.6))
			defender.gain_rage(6.0)
			emit_signal("show_feedback", "BLOCKED", 0.5)
		else:
			emit_signal("show_feedback", "HIT", 0.3)

		defender.health_current -= hp_damage
		defender.apply_posture_damage(posture_damage)

		var damage_pos: Vector2 = defender.position + Vector2(0.0, -defender.height - 20.0)
		var is_critical: bool = attacker.combo_count > 2
		emit_signal("damage_dealt", damage_pos, hp_damage, is_critical)

		var knockback: float = 150.0 if defender.is_blocking else 300.0
		if not defender.is_grounded:
			knockback *= 1.3
		defender.velocity = Vector2(float(attacker.facing) * knockback, -100.0 if defender.is_grounded else defender.velocity.y - 200.0)

		attacker.gain_rage(10.0 + attacker.combo_count * 2.0)
		defender.gain_rage(4.0)

		if not defender.is_stunned:
			defender.current_animation = Fighter.AnimationState.HIT_REACTION
			defender.animation_timer = 0.0

		defender.health_current = maxf(defender.health_current, 0.0)

		emit_signal("camera_shake", 6.0)
		emit_signal("spawn_particles", defender.position + Vector2(float(defender.facing) * -4.0, -defender.height + 28.0), 10, Color8(255, 190, 160))

func update_facing(player: Fighter, enemy: Fighter) -> void:
	player.facing = 1 if player.position.x <= enemy.position.x else -1
	enemy.facing = -player.facing

func clamp_world_bounds(fighter: Fighter) -> void:
	fighter.position.x = clampf(fighter.position.x, GameConstants.WORLD_BOUNDS_LEFT, GameConstants.WORLD_BOUNDS_RIGHT)
