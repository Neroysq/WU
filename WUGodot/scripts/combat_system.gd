class_name CombatSystem
extends RefCounted

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")
const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")
const TechniqueEffectScript = preload("res://scripts/techniques/technique_effect.gd")
const RngServiceScript = preload("res://scripts/sim/rng_service.gd")
const ProcRecorderScript = preload("res://scripts/sim/proc_recorder.gd")

signal spawn_particles(position: Vector2, count: int, color: Color)
signal camera_shake(amount: float)
signal slow_motion(factor: float, duration: float)
signal show_feedback(message: String, duration: float)
signal damage_dealt(position: Vector2, damage: float, is_critical: bool)
signal hitstop(duration: float)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var hit_geometry: Variant = null
var event_recorder: Variant = null

func _init() -> void:
	_rng = RngServiceScript.stream("combat")

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
		if fighter.technique_engine != null:
			fighter.technique_engine.dispatch_jump(fighter)
		emit_signal("spawn_particles", fighter.position + Vector2(0, 5), 12, GameConstants.COLOR_LIGHT_BLUE)

	if bool(input_state.get("dash_pressed", false)) and fighter.can_dash():
		var dash_direction: int = fighter.facing
		if is_trying_to_move:
			dash_direction = 1 if move > 0.0 else -1
		elif enemy != null:
			dash_direction = 1 if enemy.position.x > fighter.position.x else -1
		fighter.start_dash(dash_direction)
		if event_recorder != null:
			event_recorder.record_dash(fighter)
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
				stance_name = fighter.technique_engine.active_stance_display_name()
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
		var dash_result: Dictionary = fighter.technique_engine.on_dash_end(fighter, enemy)
		if enemy != null and not dash_result.is_empty():
			var dash_damage: float = float(dash_result.get("damage", 0.0))
			enemy.health_current -= dash_damage
			enemy.health_current = maxf(enemy.health_current, 0.0)
			emit_signal("damage_dealt", enemy.position + Vector2(0.0, -enemy.height - 20.0), dash_damage, false)
			emit_signal("spawn_particles", enemy.position + Vector2(0.0, -enemy.height * 0.5), 6, GameConstants.COLOR_IMPERIAL_GOLD)
			emit_signal("show_feedback", str(dash_result.get("message", "")), 0.4)
	fighter.position += fighter.velocity * dt

	var in_dash_through_zone: bool = enemy != null and absf(enemy.position.x - fighter.position.x) <= enemy.current_attack_range() + fighter.half_width
	var dash_through_contact: bool = fighter.is_invulnerable and enemy != null and enemy.is_hit_active() and in_dash_through_zone
	if dash_through_contact and not fighter._dash_through_fired and fighter.technique_engine != null:
		fighter._dash_through_fired = true
		var dash_through_result: Dictionary = fighter.technique_engine.on_dash_through(fighter, enemy)
		var dash_through_posture: float = float(dash_through_result.get("posture_damage", 0.0))
		if dash_through_posture > 0.0:
			apply_posture_break_aware(fighter, enemy, dash_through_posture)
			if event_recorder != null:
				event_recorder.record_dash_through(fighter, enemy, dash_through_posture)
		fighter.momentum = minf(fighter.momentum + float(dash_through_result.get("momentum_gain", 0.0)), 100.0)
		for message in dash_through_result.get("messages", []) as Array:
			emit_signal("show_feedback", str(message), 0.4)
	elif not dash_through_contact:
		fighter._dash_through_fired = false

	if fighter.position.y >= GameConstants.GROUND_Y:
		if (not fighter.is_grounded) and fighter.velocity.y > 100.0:
			fighter.land()
			if fighter.technique_engine != null:
				fighter.technique_engine.dispatch_land(fighter)
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
	var chosen_attack_id: String = str(action.get("attack_id", ""))
	if event_recorder != null and action_type != "idle":
		event_recorder.record_enemy_decision(action_type, chosen_attack_id)
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
		"move":
			var move_dir: float = float(action.get("direction", direction))
			ai.velocity.x = lerp(ai.velocity.x, move_dir * ai.move_speed, 0.3)
		"dash":
			if ai.can_dash():
				var dash_dir: int = int(signf(float(action.get("direction", direction))))
				ai.start_dash(dash_dir)
				if event_recorder != null:
					event_recorder.record_dash(ai)
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
			else:
				ai.is_blocking = false

func apply_posture_break_aware(attacker: Fighter, defender: Fighter, posture_amount: float) -> bool:
	var will_posture_break: bool = (defender.posture_current - posture_amount) <= 0.0 and not defender.is_stunned
	defender.apply_posture_damage(posture_amount)
	if will_posture_break:
		emit_signal("hitstop", 0.18)
		emit_signal("camera_shake", 18.0)
		emit_signal("spawn_particles", defender.position + Vector2(0.0, -defender.height), 24, GameConstants.COLOR_GOLD_BRIGHT)
		emit_signal("show_feedback", "破", 0.9)
		if event_recorder != null:
			event_recorder.record_stun(defender, defender.stun_duration)
		if attacker != null and attacker.technique_engine != null:
			if attacker.technique_engine.on_posture_break(attacker):
				emit_signal("show_feedback", "回春!", 0.6)
	return will_posture_break

func resolve_hits(attacker: Fighter, defender: Fighter) -> void:
	var settings: Dictionary = DataManager.get_game_settings()
	if not attacker.is_hit_active():
		return
	if defender.is_invulnerable:
		return

	var attack_def: Variant = attacker._attack_state.def
	var attack_is_perilous: bool = attack_def != null and not attack_def.is_parryable
	var attack_ignores_block: bool = attack_def != null and attack_def.ignores_block
	var attack_range: float = (attack_def.range_units if attack_def != null else attacker.attack_range) + attacker.attack_range_bonus

	var in_range: bool = absf(defender.position.x - attacker.position.x) <= attack_range + defender.half_width
	var vertical_range: bool = absf(defender.position.y - attacker.position.y) <= defender.height + 20.0
	var facing_correct: bool = (-1 if defender.position.x - attacker.position.x < 0.0 else 1) == attacker.facing

	var connects: bool = false
	if hit_geometry != null and hit_geometry.has_authored_hitbox(attacker):
		connects = hit_geometry.query_hit(attacker, defender)
	else:
		connects = in_range and vertical_range and facing_correct

	if connects and not attacker.was_hit_this_swing:
		attacker.was_hit_this_swing = true

		var attack_is_grab: bool = attack_def != null and attack_def.is_grab
		if attack_is_grab:
			var grab_damage: float = defender.health_max * 0.25
			defender.health_current -= grab_damage
			defender.health_current = maxf(defender.health_current, 0.0)
			if event_recorder != null:
				event_recorder.record_hit(attacker, defender, grab_damage, 0.0, false, false, true)
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
			var parry_posture_damage: float = float(settings.get("parryPostureDamage", 55.0))
			var parry_stun_duration: float = float(settings.get("parryStunDuration", 0.6))
			if event_recorder != null:
				event_recorder.record_hit(attacker, defender, 0.0, parry_posture_damage, false, true, false)
			attacker.apply_posture_damage(parry_posture_damage)
			attacker.apply_stun(parry_stun_duration)
			if event_recorder != null:
				event_recorder.record_stun(attacker, parry_stun_duration)
			defender.gain_rage(15.0)
			var armed_echo: bool = false
			if defender.technique_engine != null:
				armed_echo = defender.technique_engine.dispatch_parry_success(defender)
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
		var ctx: Variant = TechniqueEffectScript.HitContext.new()
		ctx.attacker = attacker
		ctx.defender = defender
		ctx.attack_def = attack_def
		ctx.base_hp_damage = (attack_def.damage if attack_def != null else attacker.attack_damage) * combo_damage_bonus
		ctx.hp_damage = ctx.base_hp_damage
		ctx.posture_damage = (attack_def.posture_damage if attack_def != null else attacker.attack_posture_damage) * combo_damage_bonus
		if attacker.technique_engine != null:
			attacker.technique_engine.dispatch_outgoing_hit(ctx)
			if not attacker.is_grounded:
				attacker.technique_engine.dispatch_aerial_hit(ctx)
		for message in ctx.messages:
			emit_signal("show_feedback", message, 0.5)

		if defender.is_blocking and not attack_is_perilous and not attack_ignores_block:
			ctx.hp_damage *= float(settings.get("blockHealthMultiplier", 0.2))
			if defender.technique_engine != null:
				defender.technique_engine.dispatch_block(ctx)
			ctx.posture_damage *= float(settings.get("blockPostureMultiplier", 1.6))
			if ctx.reflect_to_attacker > 0.0:
				attacker.health_current -= ctx.reflect_to_attacker
				attacker.health_current = maxf(attacker.health_current, 0.0)
				emit_signal("damage_dealt", attacker.position + Vector2(0.0, -attacker.height - 20.0), ctx.reflect_to_attacker, false)
			defender.gain_rage(6.0)
			emit_signal("show_feedback", "BLOCKED", 0.5)
		elif defender.is_blocking and attack_is_perilous:
			emit_signal("show_feedback", "UNBLOCKABLE!", 0.6)
		elif defender.is_blocking and attack_ignores_block:
			emit_signal("show_feedback", "SLIPPED!", 0.5)
		else:
			emit_signal("show_feedback", "HIT", 0.3)
		var is_critical: bool = attacker.combo_count > 2 or (attack_def != null and attack_def.is_heavy)
		if event_recorder != null:
			var blocked_contact: bool = defender.is_blocking and not attack_is_perilous and not attack_ignores_block
			event_recorder.record_hit(attacker, defender, ctx.hp_damage, ctx.posture_damage, blocked_contact, false, is_critical)

		if ctx.heal_attacker > 0.0:
			attacker.health_current = minf(attacker.health_current + ctx.heal_attacker, attacker.health_max)
		defender.health_current -= ctx.hp_damage
		if ctx.bleed_timer > 0.0:
			defender.bleed_timer = ctx.bleed_timer
			defender.bleed_dps = ctx.bleed_dps
			ProcRecorderScript.record_status("bleed")
			if event_recorder != null:
				event_recorder.record_status_applied(defender, "bleed")
		if ctx.venom_stacks > 0:
			defender.venom_stacks += ctx.venom_stacks
			defender.venom_timer = maxf(defender.venom_timer, ctx.venom_timer)
			defender.venom_dps = maxf(defender.venom_dps, ctx.venom_dps)
			_apply_venom_slow(defender, ctx.venom_slow_multiplier)
			ProcRecorderScript.record_status("venom", ctx.venom_stacks)
			if event_recorder != null:
				event_recorder.record_status_applied(defender, "venom", ctx.venom_stacks)
		if ctx.consume_venom:
			_clear_venom(defender)
		if ctx.jolt_timer > 0.0:
			defender.jolt_timer = maxf(defender.jolt_timer, ctx.jolt_timer)
			ProcRecorderScript.record_status("jolt")
			if event_recorder != null:
				event_recorder.record_status_applied(defender, "jolt")
		if ctx.consume_intent_marks:
			defender.intent_marks = 0
		if ctx.intent_marks > 0:
			defender.intent_marks = mini(defender.intent_marks + ctx.intent_marks, ctx.intent_mark_cap)
			ProcRecorderScript.record_status("intent_mark", ctx.intent_marks)
			if event_recorder != null:
				event_recorder.record_status_applied(defender, "intent_mark", ctx.intent_marks)
		if defender.health_current <= 0.0 and defender.technique_engine != null:
			if defender.technique_engine.check_lethal_save(defender):
				emit_signal("camera_shake", 16.0)
				emit_signal("slow_motion", 0.4, 0.5)
				emit_signal("show_feedback", "鳳凰起!", 0.8)
				emit_signal("spawn_particles", defender.position + Vector2(0.0, -defender.height * 0.5), 24, GameConstants.COLOR_IMPERIAL_GOLD)

		apply_posture_break_aware(attacker, defender, ctx.posture_damage)

		var damage_pos: Vector2 = defender.position + Vector2(0.0, -defender.height - 20.0)
		emit_signal("damage_dealt", damage_pos, ctx.hp_damage, is_critical)

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
		if attacker.technique_engine != null:
			attacker.technique_engine.dispatch_post_hit(ctx)
			for extra_hit in ctx.extra_hits:
				var extra_damage: float = float(extra_hit.get("damage", 0.0))
				defender.health_current -= extra_damage
				defender.health_current = maxf(defender.health_current, 0.0)
				var twin_pos: Vector2 = defender.position + (extra_hit.get("offset", Vector2.ZERO) as Vector2)
				emit_signal("damage_dealt", twin_pos, extra_damage, bool(extra_hit.get("critical", true)))
				emit_signal("spawn_particles", twin_pos, 8, GameConstants.COLOR_GOLD_BRIGHT)
		if defender.technique_engine != null and defender.technique_engine.is_stance_active():
			if defender.technique_engine.on_stance_damage(ctx.hp_damage, defender):
				emit_signal("show_feedback", "STANCE BROKEN!", 0.6)
				emit_signal("camera_shake", 8.0)

func update_facing(player: Fighter, enemy: Fighter) -> void:
	player.facing = 1 if player.position.x <= enemy.position.x else -1
	enemy.facing = -player.facing

func clamp_world_bounds(fighter: Fighter) -> void:
	fighter.position.x = clampf(fighter.position.x, GameConstants.WORLD_BOUNDS_LEFT, GameConstants.WORLD_BOUNDS_RIGHT)

func tick_effects(fighter: Fighter, dt: float) -> void:
	if fighter.jolt_timer > 0.0:
		fighter.jolt_timer = maxf(fighter.jolt_timer - dt, 0.0)

	if fighter.venom_timer > 0.0 and fighter.venom_stacks > 0:
		var venom_damage: float = fighter.venom_dps * float(fighter.venom_stacks) * dt
		fighter.health_current -= venom_damage
		fighter.health_current = maxf(fighter.health_current, 0.0)
		fighter.venom_timer -= dt
		if fighter.venom_timer <= 0.0:
			_clear_venom(fighter)
		if venom_damage > 0.1:
			emit_signal("damage_dealt", fighter.position + Vector2(0.0, -fighter.height - 34.0), venom_damage, false)

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

func _apply_venom_slow(fighter: Fighter, multiplier: float) -> void:
	if multiplier >= 1.0:
		return
	if not is_equal_approx(fighter._venom_slow_delta, 0.0):
		fighter.move_speed -= fighter._venom_slow_delta
	var clamped: float = clampf(multiplier, 0.1, 1.0)
	fighter.venom_slow_multiplier = clamped
	fighter._venom_slow_delta = fighter.move_speed * (clamped - 1.0)
	fighter.move_speed += fighter._venom_slow_delta

func _clear_venom(fighter: Fighter) -> void:
	fighter.venom_stacks = 0
	fighter.venom_timer = 0.0
	fighter.venom_dps = 0.0
	fighter.venom_slow_multiplier = 1.0
	if not is_equal_approx(fighter._venom_slow_delta, 0.0):
		fighter.move_speed -= fighter._venom_slow_delta
	fighter._venom_slow_delta = 0.0
