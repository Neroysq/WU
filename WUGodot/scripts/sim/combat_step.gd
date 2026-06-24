class_name CombatStep
extends RefCounted

static func advance(combat_system: CombatSystem, player: Fighter, enemy: Fighter, input_state: Dictionary, dt: float, recorder: Variant = null) -> void:
	var active_recorder: Variant = recorder if recorder != null else combat_system.event_recorder
	if active_recorder != null:
		combat_system.event_recorder = active_recorder
	var player_before: Dictionary = _attack_snapshot(player)
	var enemy_before: Dictionary = _attack_snapshot(enemy)
	combat_system.update_facing(player, enemy)
	combat_system.update_player(player, input_state, dt, enemy)
	_record_transitions(active_recorder, player, "player", player_before)
	player_before = _attack_snapshot(player)
	combat_system.update_ai(enemy, player, dt)
	_record_transitions(active_recorder, enemy, "enemy", enemy_before)
	enemy_before = _attack_snapshot(enemy)
	combat_system.resolve_hits(player, enemy)
	combat_system.resolve_hits(enemy, player)
	combat_system.tick_effects(player, dt)
	combat_system.tick_effects(enemy, dt)
	combat_system.clamp_world_bounds(player)
	combat_system.clamp_world_bounds(enemy)
	_record_transitions(active_recorder, player, "player", player_before)
	_record_transitions(active_recorder, enemy, "enemy", enemy_before)

static func check_death(player: Fighter, enemy: Fighter) -> Variant:
	if player.health_current <= 0.0:
		return player
	if enemy.health_current <= 0.0:
		return enemy
	return null

static func death_state(player: Fighter, enemy: Fighter) -> String:
	var dead: Variant = check_death(player, enemy)
	if dead == player:
		return "player"
	if dead == enemy:
		return "enemy"
	return ""

static func fire_player_kill(player: Fighter) -> void:
	if player != null and player.technique_engine != null:
		player.technique_engine.on_kill(player)

static func _attack_snapshot(fighter: Fighter) -> Dictionary:
	return {
		"active": fighter._attack_state.is_active(),
		"hit_active": fighter._attack_state.is_hit_active(),
		"phase": fighter._attack_state.phase(),
	}

static func _record_transitions(recorder: Variant, fighter: Fighter, role: String, before: Dictionary) -> void:
	if recorder == null or fighter == null:
		return
	var now_active: bool = fighter._attack_state.is_active()
	var now_hit_active: bool = fighter._attack_state.is_hit_active()
	var now_phase: int = fighter._attack_state.phase()
	if not bool(before.get("active", false)) and now_active:
		recorder.begin_attack(role, fighter)
	if int(before.get("phase", AttackDefinition.Phase.FINISHED)) != now_phase and now_active:
		recorder.phase_changed(role, fighter, now_phase)
	if not bool(before.get("hit_active", false)) and now_hit_active:
		recorder.attack_active_started(role, fighter)
	if bool(before.get("hit_active", false)) and not now_hit_active:
		recorder.active_window_closed(role, fighter)
	if bool(before.get("active", false)) and not now_active:
		recorder.finish_attack(role, fighter)
