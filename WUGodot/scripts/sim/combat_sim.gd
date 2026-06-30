class_name CombatSim
extends RefCounted

const DT: float = 1.0 / 60.0

func simulate(player: Fighter, node: MapNode, policy: PlayerPolicy, max_time: float = 60.0, forced_archetype: String = "", seed: int = -1, encounter: Dictionary = {}) -> CombatResult:
	if player == null:
		player = EnemyFactory.create_player()
	if policy == null:
		policy = HeuristicPlayer.new()
	var setup: Dictionary = CombatSetup.prepare(player, node, forced_archetype, encounter)
	var enemy: Fighter = setup["enemy"] as Fighter
	var combat_system: CombatSystem = setup["combat_system"] as CombatSystem

	var result: CombatResult = CombatResult.new()
	result.seed = seed
	result.enemy_archetype = enemy.archetype_id
	result.node_id = int(encounter.get("node_id", node.id if node != null else -1))
	result.normal_combat_ordinal = int(encounter.get("normal_combat_ordinal", -1))
	result.pool_class = str(encounter.get("pool_class", ""))
	result.ambush_wave = int(encounter.get("ambush_wave", 0))
	result.node_type = node.node_type if node != null else -1
	result.tier = node.tier if node != null else 0
	result.player_hp_before = player.health_current
	result.enemy_hp_before = enemy.health_current
	result.player_posture_min = player.posture_current
	result.enemy_posture_min = enemy.posture_current

	ProcRecorder.begin()
	var t: float = 0.0
	var enemy_kill_fired: bool = false
	while t < max_time:
		var input_state: Dictionary = policy.next_input(player, enemy, {"time": t, "frame": result.frames})
		CombatStep.advance(combat_system, player, enemy, input_state, DT)
		result.frames += 1
		t += DT
		result.player_posture_min = minf(result.player_posture_min, player.posture_current)
		result.enemy_posture_min = minf(result.enemy_posture_min, enemy.posture_current)
		var death_state: String = CombatStep.death_state(player, enemy)
		if death_state == "enemy":
			if not enemy_kill_fired:
				CombatStep.fire_player_kill(player)
				enemy_kill_fired = true
			result.winner = "player"
			break
		if death_state == "player":
			result.winner = "enemy"
			break

	if result.winner.is_empty():
		result.winner = "timeout"
		result.timed_out = true

	var recorder: Dictionary = ProcRecorder.end()
	result.boon_procs = recorder.get("boon_procs", {}) as Dictionary
	result.status_applications = recorder.get("status_applications", {}) as Dictionary
	result.duration = t
	result.player_hp_after = player.health_current
	result.enemy_hp_after = enemy.health_current
	result.damage_dealt = maxf(0.0, result.enemy_hp_before - result.enemy_hp_after)
	result.damage_taken = maxf(0.0, result.player_hp_before - result.player_hp_after)
	return result
