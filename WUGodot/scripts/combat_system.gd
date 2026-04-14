class_name CombatSystem
extends RefCounted

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")
const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")

signal spawn_particles(position: Vector2, count: int, color: Color)
signal camera_shake(amount: float)
signal slow_motion(factor: float, duration: float)
signal show_feedback(message: String, duration: float)
signal damage_dealt(position: Vector2, damage: float, is_critical: bool)
signal hitstop(duration: float)

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

	var can_move: bool = fighter.current_animation != Fighter.AnimationState.DASHING and fighter.current_animation != Fighter.AnimationState.ATTACKING_LIGHT and fighter.current_animation != Fighter.AnimationState.ATTACKING_HEAVY and fighter.current_animation != Fighter.AnimationState.STUNNED and not fighter.is_grabbed
	if can_move:
		fighter.velocity.x = lerp(fighter.velocity.x, target_speed, move_control)
	elif fighter.current_animation == Fighter.AnimationState.ATTACKING_LIGHT or fighter.current_animation == Fighter.AnimationState.ATTACKING_HEAVY:
		fighter.velocity.x = lerp(fighter.velocity.x, 0.0, move_control * attack_move_control_multiplier)

	if fighter.is_grounded and is_trying_to_move and fighter.current_animation == Fighter.AnimationState.IDLE and not fighter.is_grabbed:
		fighter.current_animation = Fighter.AnimationState.WALKING
		fighter.animation_timer = 0.0

	if bool(input_state.get("jump_pressed", false)) and fighter.can_jump():
		fighter.start_jump()
		emit_signal("spawn_particles", fighter.position + Vector2(0, 5), 12, GameConstants.COLOR_LIGHT_BLUE)

	if bool(input_state.get("dash_pressed", false)) and fighter.can_dash():
		var dash_direction: int = fighter.facing
		if is_trying_to_move:
			dash_direction = 1 if move > 0.0 else -1
		elif enemy != null:
			dash_direction = 1 if enemy.position.x > fighter.position.x else -1
		fighter.start_dash(dash_direction)
		emit_signal("spawn_particles", fighter.position, 8, GameConstants.COLOR_LIGHT_BLUE)
		emit_signal("camera_shake", 3.0)

	var attack_pos: Vector2 = Vector2(fighter.position.x + float(fighter.facing) * fighter.half_width, fighter.position.y - fighter.height * 0.4)
	if bool(input_state.get("heavy_pressed", false)) and fighter.can_attack():
		fighter.start_heavy_attack()
		emit_signal("spawn_particles", attack_pos, 16, GameConstants.COLOR_EARTH_LIGHT)
		emit_signal("camera_shake", 4.5)
		emit_signal("show_feedback", "HEAVY", 0.4)
	elif bool(input_state.get("light_pressed", false)) and fighter.can_attack():
		fighter.start_light_attack()
		var particle_count: int = 6 + fighter.combo_count * 2
		var attack_color: Color = GameConstants.COLOR_IMPERIAL_GOLD if fighter.combo_count > 2 else GameConstants.COLOR_GOLD_BRIGHT
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

	if bool(input_state.get("stance_pressed", false)):
		if fighter.on_stance_input():
			var stance_name: String = ""
			if fighter.technique_engine != null:
				match fighter.technique_engine.active_stance():
					"D1":
						stance_name = "醉拳 DRUNKEN FORM"
					"D2":
						stance_name = "虎形 TIGER STANCE"
				emit_signal("camera_shake", 10.0)
				emit_signal("slow_motion", 0.6, 0.3)
				emit_signal("show_feedback", stance_name, 0.8)
				emit_signal("spawn_particles", fighter.position, 20, GameConstants.COLOR_GOLD_BRIGHT)

	if not fighter.is_grounded:
		fighter.velocity.y += fighter.gravity * dt
		if fighter.velocity.y > 0.0 and fighter.current_animation == Fighter.AnimationState.JUMPING:
			fighter.current_animation = Fighter.AnimationState.FALLING
			fighter.animation_timer = 0.0

	var was_dashing: bool = fighter._dash_timer > 0.0
	fighter.update_timers(dt)
	var dash_just_ended: bool = was_dashing and fighter._dash_timer <= 0.0

	if dash_just_ended and fighter.technique_engine != null:
		fighter.technique_engine.on_dash_end()
		if fighter.technique_engine.has("A1") and enemy != null:
			var stab_range: float = 60.0
			var dist: float = absf(enemy.position.x - fighter.position.x)
			if dist <= stab_range + enemy.half_width:
				var facing_enemy: bool = (1 if enemy.position.x > fighter.position.x else -1) == fighter.facing
				if facing_enemy:
					enemy.health_current -= 8.0
					enemy.health_current = maxf(enemy.health_current, 0.0)
					emit_signal("damage_dealt", enemy.position + Vector2(0.0, -enemy.height - 20.0), 8.0, false)
					emit_signal("spawn_particles", enemy.position + Vector2(0.0, -enemy.height * 0.5), 6, GameConstants.COLOR_IMPERIAL_GOLD)
					emit_signal("show_feedback", "落葉!", 0.4)
	fighter.position += fighter.velocity * dt

	if fighter.is_invulnerable and enemy != null and enemy.is_hit_active():
		var dist: float = absf(enemy.position.x - fighter.position.x)
		var in_attack_zone: bool = dist <= enemy.current_attack_range() + fighter.half_width
		if in_attack_zone and fighter.technique_engine != null:
			fighter.technique_engine.on_dash_through()

	if fighter.position.y >= GameConstants.GROUND_Y:
		if (not fighter.is_grounded) and fighter.velocity.y > 100.0:
			fighter.land()
			emit_signal("spawn_particles", Vector2(fighter.position.x, GameConstants.GROUND_Y + 5.0), 8, GameConstants.COLOR_INK_MID)
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
	var direction: float = signf(distance)

	if ai.boss_controller != null:
		ai.boss_controller.update_cooldowns(dt)
		if ai.boss_controller.check_phase_transition(ai):
			emit_signal("camera_shake", 20.0)
			emit_signal("slow_motion", 0.4, 0.6)
			emit_signal("show_feedback", "「還在呼吸。好。我剛熱身。」", 1.2)
			emit_signal("spawn_particles", ai.position + Vector2(0.0, -ai.height * 0.5), 30, GameConstants.COLOR_IMPERIAL_GOLD)

	if ai.ai_brain != null:
		ai.ai_brain.update_cooldowns(dt)
		var action: Dictionary = ai.ai_brain.decide(ai, target)
		_execute_ai_action(ai, target, action, dt, direction)
	else:
		_execute_legacy_ai(ai, target, dt, direction, abs_distance)

	if ai.archetype_id == "masked_assassin" and not ai.is_stunned and not ai._attack_state.is_active():
		var tp_chance: float = ai.ai_brain.teleport_chance if ai.ai_brain != null else 0.08
		if abs_distance > 200.0 and ai.ai_brain != null and ai.ai_brain._rng.randf() < tp_chance:
			var behind_offset: float = -direction * 120.0
			var teleport_x: float = target.position.x + behind_offset
			teleport_x = clampf(teleport_x, GameConstants.WORLD_BOUNDS_LEFT + 40.0, GameConstants.WORLD_BOUNDS_RIGHT - 40.0)
			ai.position.x = teleport_x
			emit_signal("spawn_particles", ai.position + Vector2(0.0, -ai.height * 0.5), 12, GameConstants.COLOR_PURPLE_DARK)
			emit_signal("show_feedback", "!", 0.3)

	if ai._attack_state.is_active() and ai._attack_state.def != null:
		var lunge: float = ai._attack_state.def.forward_lunge
		if lunge > 0.0 and ai._attack_state.phase() == AttackDefinitionScript.Phase.WINDUP:
			var lunge_speed: float = lunge / maxf(ai._attack_state.def.windup_end, 0.01)
			ai.velocity.x = float(ai.facing) * lunge_speed

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

func _execute_ai_action(ai: Fighter, target: Fighter, action: Dictionary, dt: float, direction: float) -> void:
	ai.is_blocking = false

	var action_type: String = str(action.get("type", "idle"))
	match action_type:
		"attack":
			if ai.can_attack():
				var attack_id: String = str(action.get("attack_id", ""))
				if ai.boss_controller != null:
					var phase_table: Array[String] = ai.boss_controller.get_phase_attack_table()
					if not phase_table.is_empty() and ai.ai_brain != null:
						var boss_distance: float = absf(target.position.x - ai.position.x)
						attack_id = ai.ai_brain.pick_attack_from_table(phase_table, boss_distance)
					if attack_id == "bear_crush_grab" and not ai.boss_controller.can_use_bear_crush():
						attack_id = "bear_swipe"
					elif attack_id == "bear_crush_grab":
						ai.boss_controller.consume_bear_crush()
					if ai.boss_controller.can_use_mountain_breaker() and ai.ai_brain != null and ai.ai_brain._rng.randf() < 0.15:
						attack_id = "mountain_breaker"
						ai.boss_controller.consume_mountain_breaker()
				var atk_def: Variant = ai.ai_brain.get_attack_def(attack_id) if ai.ai_brain != null else null
				if atk_def != null:
					if ai.boss_controller != null and ai.boss_controller.current_phase == 2:
						var recovery: float = atk_def.duration - atk_def.active_end
						atk_def.duration = atk_def.active_end + recovery * 0.8
					ai._start_attack_with(atk_def)
					ai._ai_decision_timer = 0.2
					var attack_pos: Vector2 = ai.position + Vector2(float(ai.facing) * ai.half_width, -ai.height * 0.4)
					emit_signal("spawn_particles", attack_pos, 6, GameConstants.COLOR_EARTH_LIGHT)
		"block":
			ai.is_blocking = true
			ai.trigger_parry_window()
		"move":
			var move_dir: float = float(action.get("direction", direction))
			ai.velocity.x = lerp(ai.velocity.x, move_dir * ai.move_speed, 0.3)
		"dash":
			if ai.can_dash():
				var dash_dir: int = int(signf(float(action.get("direction", direction))))
				ai.start_dash(dash_dir)
				emit_signal("spawn_particles", ai.position, 8, GameConstants.COLOR_VERMILLION_RED)
		_:
			ai.velocity.x = lerp(ai.velocity.x, 0.0, 0.2)

func _execute_legacy_ai(ai: Fighter, target: Fighter, dt: float, direction: float, abs_distance: float) -> void:
	var aggression_multiplier: float = 1.2 + (1.0 - ai.health_current / maxf(ai.health_max, 0.001)) * 0.5
	if ai.is_in_recovery() or ai.is_stunned:
		var retreat_speed: float = 0.0 if ai.is_stunned else -direction * ai.move_speed * 0.4
		ai.velocity.x = lerp(ai.velocity.x, retreat_speed, 0.2)
	else:
		if abs_distance > ai.attack_range * 0.9:
			ai.velocity.x = lerp(ai.velocity.x, direction * ai.move_speed * aggression_multiplier, 0.3)
		else:
			ai.velocity.x = lerp(ai.velocity.x, 0.0, 0.3)
			if ai.can_attack() and ai._ai_decision_timer <= 0.0 and _rng.randf() < 0.25 * aggression_multiplier:
				var next_attack: Variant = AttackCatalogScript.bandit_thrust_perilous() if _rng.randf() < 0.30 else AttackCatalogScript.bandit_slash()
				ai._start_attack_with(next_attack)
				ai._ai_decision_timer = 0.25
			if target.is_hit_active() and _rng.randf() < 0.4:
				ai.is_blocking = true
				ai.trigger_parry_window()
			else:
				ai.is_blocking = false

func resolve_hits(attacker: Fighter, defender: Fighter) -> void:
	var settings: Dictionary = DataManager.get_game_settings()
	if not attacker.is_hit_active():
		return
	if defender.is_invulnerable:
		return

	var attack_def: Variant = attacker._attack_state.def
	var attack_is_perilous: bool = attack_def != null and not attack_def.is_parryable
	var attack_ignores_block: bool = attack_def != null and attack_def.ignores_block
	var attack_range: float = attack_def.range_units if attack_def != null else attacker.attack_range

	var in_range: bool = absf(defender.position.x - attacker.position.x) <= attack_range + defender.half_width
	var vertical_range: bool = absf(defender.position.y - attacker.position.y) <= defender.height + 20.0
	var facing_correct: bool = (-1 if defender.position.x - attacker.position.x < 0.0 else 1) == attacker.facing

	if in_range and vertical_range and facing_correct and not attacker.was_hit_this_swing:
		attacker.was_hit_this_swing = true

		var attack_is_grab: bool = attack_def != null and attack_def.is_grab
		if attack_is_grab:
			var grab_damage: float = defender.health_max * 0.25
			defender.health_current -= grab_damage
			defender.health_current = maxf(defender.health_current, 0.0)
			defender.is_grabbed = true
			defender._grab_timer = 0.6
			defender.velocity = Vector2.ZERO
			emit_signal("damage_dealt", defender.position + Vector2(0.0, -defender.height - 20.0), grab_damage, true)
			emit_signal("camera_shake", 14.0)
			emit_signal("hitstop", 0.15)
			emit_signal("show_feedback", "CRUSH!", 0.7)
			emit_signal("spawn_particles", defender.position + Vector2(0.0, -defender.height * 0.5), 16, GameConstants.COLOR_CRIMSON)
			if defender.health_current <= 0.0 and defender.technique_engine != null:
				if defender.technique_engine.check_lethal_save(defender):
					emit_signal("camera_shake", 16.0)
					emit_signal("slow_motion", 0.4, 0.5)
					emit_signal("show_feedback", "鳳凰起!", 0.8)
					emit_signal("spawn_particles", defender.position + Vector2(0.0, -defender.height * 0.5), 24, GameConstants.COLOR_IMPERIAL_GOLD)
			return

		if defender.consume_parry_if_active() and not attack_is_perilous:
			attacker.apply_posture_damage(float(settings.get("parryPostureDamage", 55.0)))
			attacker.apply_stun(float(settings.get("parryStunDuration", 0.6)))
			defender.gain_rage(15.0)
			var armed_echo: bool = defender.technique_engine != null and defender.technique_engine.has("B1")
			if armed_echo:
				defender.technique_engine.set_echo()
			emit_signal("camera_shake", 12.0)

			var parry_pos: Vector2 = defender.position + Vector2(float(defender.facing) * -6.0, -defender.height + 24.0)
			for i in range(24):
				var angle: float = (float(i) / 24.0) * TAU
				var spark_pos: Vector2 = parry_pos + Vector2(cos(angle), sin(angle)) * 30.0
				emit_signal("spawn_particles", spark_pos, 2, GameConstants.COLOR_GOLD_BRIGHT)

			emit_signal("slow_motion", 0.55, 0.30)
			emit_signal("hitstop", 0.15)
			emit_signal("show_feedback", "PARRY!", 0.8)
			if armed_echo:
				emit_signal("show_feedback", "ECHO!", 0.5)
			return

		var combo_damage_bonus: float = 1.0 + float(attacker.combo_count - 1) * 0.15
		var hp_damage: float = (attack_def.damage if attack_def != null else attacker.attack_damage) * combo_damage_bonus
		var posture_damage: float = (attack_def.posture_damage if attack_def != null else attacker.attack_posture_damage) * combo_damage_bonus
		if attacker.technique_engine != null and attacker.technique_engine.has("B5"):
			if attacker.health_current <= attacker.health_max * 0.3:
				hp_damage *= 1.25
				posture_damage *= 1.25
		if attacker.technique_engine != null and attacker.technique_engine.has("A4"):
			if attack_def != null and not attack_def.is_heavy and attacker.technique_engine.has_sparrow_bonus():
				hp_damage *= 1.30
				attacker.technique_engine.consume_sparrow()
				emit_signal("show_feedback", "雀翼!", 0.4)
		if attacker.technique_engine != null and attacker.technique_engine.consume_echo():
			posture_damage = defender.posture_current + 1.0
			emit_signal("show_feedback", "山谷回響!", 0.6)
		if attacker.technique_engine != null and attacker.technique_engine.consume_flowing_water():
			attacker.health_current = minf(attacker.health_current + 5.0, attacker.health_max)
			emit_signal("show_feedback", "流水!", 0.5)

		if defender.is_blocking and not attack_is_perilous and not attack_ignores_block:
			hp_damage *= float(settings.get("blockHealthMultiplier", 0.2))
			if defender.technique_engine != null and defender.technique_engine.has("A5"):
				hp_damage *= 0.5
			posture_damage *= float(settings.get("blockPostureMultiplier", 1.6))
			if defender.technique_engine != null and defender.technique_engine.is_stance_active() and defender.technique_engine.active_stance() == "D2":
				var base_damage: float = (attack_def.damage if attack_def != null else attacker.attack_damage) * combo_damage_bonus
				var reflect_damage: float = base_damage * 0.10
				attacker.health_current -= reflect_damage
				attacker.health_current = maxf(attacker.health_current, 0.0)
				emit_signal("damage_dealt", attacker.position + Vector2(0.0, -attacker.height - 20.0), reflect_damage, false)
			defender.gain_rage(6.0)
			emit_signal("show_feedback", "BLOCKED", 0.5)
		elif defender.is_blocking and attack_is_perilous:
			emit_signal("show_feedback", "UNBLOCKABLE!", 0.6)
		elif defender.is_blocking and attack_ignores_block:
			emit_signal("show_feedback", "SLIPPED!", 0.5)
		else:
			emit_signal("show_feedback", "HIT", 0.3)

		defender.health_current -= hp_damage
		if attacker.technique_engine != null and attacker.technique_engine.has("A3"):
			if attack_def != null and attack_def.is_heavy:
				defender.bleed_timer = 3.0
				defender.bleed_dps = 1.5
		if defender.health_current <= 0.0 and defender.technique_engine != null:
			if defender.technique_engine.check_lethal_save(defender):
				emit_signal("camera_shake", 16.0)
				emit_signal("slow_motion", 0.4, 0.5)
				emit_signal("show_feedback", "鳳凰起!", 0.8)
				emit_signal("spawn_particles", defender.position + Vector2(0.0, -defender.height * 0.5), 24, GameConstants.COLOR_IMPERIAL_GOLD)

		var will_posture_break: bool = (defender.posture_current - posture_damage) <= 0.0 and not defender.is_stunned
		defender.apply_posture_damage(posture_damage)

		if will_posture_break:
			emit_signal("hitstop", 0.18)
			emit_signal("camera_shake", 18.0)
			emit_signal("spawn_particles", defender.position + Vector2(0.0, -defender.height), 24, GameConstants.COLOR_GOLD_BRIGHT)
			emit_signal("show_feedback", "破", 0.9)
			if attacker.technique_engine != null:
				attacker.technique_engine.on_posture_break(attacker)
				if attacker.technique_engine.has("B2"):
					emit_signal("show_feedback", "回春!", 0.6)

		var damage_pos: Vector2 = defender.position + Vector2(0.0, -defender.height - 20.0)
		var is_critical: bool = attacker.combo_count > 2 or (attack_def != null and attack_def.is_heavy)
		emit_signal("damage_dealt", damage_pos, hp_damage, is_critical)

		var base_knockback: float = attack_def.knockback_units if attack_def != null else 300.0
		if defender.is_blocking and not attack_is_perilous:
			base_knockback *= 0.5
		if not defender.is_grounded:
			base_knockback *= 1.3
		defender.velocity = Vector2(float(attacker.facing) * base_knockback, -100.0 if defender.is_grounded else defender.velocity.y - 200.0)

		var attacker_rage_gain: float = 10.0
		if attack_def != null and attack_def.is_heavy:
			attacker_rage_gain += 8.0
		attacker.gain_rage(attacker_rage_gain)
		defender.gain_rage(4.0)

		if not defender.is_stunned:
			defender.current_animation = Fighter.AnimationState.HIT_REACTION
			defender.animation_timer = 0.0
		if attacker.technique_engine != null and attacker.technique_engine.roll_stagger():
			if attack_def != null and not attack_def.is_heavy and defender._attack_state.is_active():
				defender._attack_state.clear()
				defender._attack_cooldown = 0.3
				emit_signal("show_feedback", "STAGGER!", 0.4)

		defender.health_current = maxf(defender.health_current, 0.0)

		var shake_amount: float = 12.0 if (attack_def != null and attack_def.is_heavy) else 4.0
		emit_signal("camera_shake", shake_amount)
		emit_signal("hitstop", 0.10 if (attack_def != null and attack_def.is_heavy) else 0.05)
		emit_signal("spawn_particles", defender.position + Vector2(float(defender.facing) * -4.0, -defender.height + 28.0), 10, GameConstants.COLOR_IMPERIAL_GOLD)
		if attacker.technique_engine != null and attacker.technique_engine.has("A10"):
			if attack_def != null and attack_def.is_heavy:
				var twin_damage: float = hp_damage * 0.5
				defender.health_current -= twin_damage
				defender.health_current = maxf(defender.health_current, 0.0)
				var twin_pos: Vector2 = defender.position + Vector2(float(defender.facing) * -8.0, -defender.height - 30.0)
				emit_signal("damage_dealt", twin_pos, twin_damage, true)
				emit_signal("spawn_particles", twin_pos, 8, GameConstants.COLOR_GOLD_BRIGHT)
		if defender.technique_engine != null and defender.technique_engine.is_stance_active():
			if defender.technique_engine.on_stance_damage(hp_damage, defender):
				emit_signal("show_feedback", "STANCE BROKEN!", 0.6)
				emit_signal("camera_shake", 8.0)

func update_facing(player: Fighter, enemy: Fighter) -> void:
	player.facing = 1 if player.position.x <= enemy.position.x else -1
	enemy.facing = -player.facing

func clamp_world_bounds(fighter: Fighter) -> void:
	fighter.position.x = clampf(fighter.position.x, GameConstants.WORLD_BOUNDS_LEFT, GameConstants.WORLD_BOUNDS_RIGHT)

func tick_effects(fighter: Fighter, dt: float) -> void:
	if fighter.bleed_timer > 0.0:
		var bleed_damage: float = fighter.bleed_dps * dt
		fighter.health_current -= bleed_damage
		fighter.health_current = maxf(fighter.health_current, 0.0)
		fighter.bleed_timer -= dt
		if fighter.bleed_timer <= 0.0:
			fighter.bleed_timer = 0.0
			fighter.bleed_dps = 0.0
		if bleed_damage > 0.1:
			emit_signal("damage_dealt", fighter.position + Vector2(0.0, -fighter.height - 20.0), bleed_damage, false)
