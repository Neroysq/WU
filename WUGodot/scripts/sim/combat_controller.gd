class_name CombatController
extends RefCounted

const DT: float = 1.0 / 60.0
const TriggerEngineScript = preload("res://scripts/sim/trigger_engine.gd")

var player: Fighter = null
var enemy: Fighter = null
var node: MapNode = null
var combat_system: CombatSystem = null
var recorder: Variant = null
var trigger_engine: Variant = TriggerEngineScript.new()
var frame: int = 0
var winner: String = ""
var encounter: Dictionary = {}

var _enemy_kill_fired: bool = false
var _proc_snapshot: Dictionary = {"boon_procs": {}, "status_applications": {}}

func start(player_fighter: Fighter, combat_node: MapNode, forced_archetype: String = "", seed: int = -1, encounter_data: Dictionary = {}) -> void:
	player = player_fighter if player_fighter != null else EnemyFactory.create_player()
	node = combat_node
	encounter = encounter_data.duplicate(true)
	var setup: Dictionary = CombatSetup.prepare(player, node, forced_archetype)
	enemy = setup["enemy"] as Fighter
	combat_system = setup["combat_system"] as CombatSystem
	recorder = load("res://scripts/sim/combat_event_recorder.gd").new()
	combat_system.event_recorder = recorder
	trigger_engine = TriggerEngineScript.new()
	frame = 0
	winner = ""
	_enemy_kill_fired = false
	ProcRecorder.begin()
	_proc_snapshot = ProcRecorder.snapshot()
	recorder.record("combat_start", {
		"seed": seed,
		"enemy_archetype": enemy.archetype_id,
		"node_id": node.id if node != null else -1,
		"pool_class": str(encounter.get("pool_class", "")),
	})

func add_trigger(spec: Dictionary) -> int:
	return trigger_engine.add_trigger(spec)

func clear_trigger(id: Variant) -> void:
	trigger_engine.clear(id)

func trigger_list() -> Array[Dictionary]:
	return trigger_engine.list()

func advance(actions: Array = [], frames: int = 1) -> Dictionary:
	if winner != "":
		return {"paused": true, "reason": "combat_end", "winner": winner, "events": recorder.drain()}
	var budget: int = maxi(1, frames)
	var stop: Dictionary = {"paused": false, "reason": "budget_spent", "winner": ""}
	for i in range(budget):
		var before_events: int = recorder.event_count()
		var input_state: Dictionary = _input_from_actions(actions, i == 0)
		CombatStep.advance(combat_system, player, enemy, input_state, DT, recorder)
		frame += 1
		_record_proc_deltas()
		_check_death()
		var new_events: Array[Dictionary] = recorder.events_from(before_events)
		var trigger_hit: Dictionary = trigger_engine.evaluate(new_events, state())
		if winner != "":
			stop = {"paused": true, "reason": "combat_end", "winner": winner}
			break
		if bool(trigger_hit.get("triggered", false)):
			stop = {
				"paused": true,
				"reason": "trigger",
				"trigger": trigger_hit,
				"winner": winner,
			}
			break
	if not bool(stop.get("paused", false)):
		stop["paused"] = true
	stop["events"] = recorder.drain()
	stop["state"] = state()
	return stop

func step(frames: int = 1) -> Dictionary:
	return advance([], frames)

func observe(drain_events: bool = true) -> Dictionary:
	return {
		"context": {"scene": "combat"},
		"state": state(),
		"events": recorder.drain() if drain_events else recorder.events(),
		"pause": {"kind": "combat", "reason": "observe" if winner == "" else "combat_end", "winner": winner},
	}

func state() -> Dictionary:
	var player_state: Dictionary = _fighter_state(player)
	var enemy_state: Dictionary = _fighter_state(enemy)
	return {
		"frame": frame,
		"winner": winner,
		"player": player_state,
		"enemy": enemy_state,
		"distance": absf(enemy.position.x - player.position.x) if player != null and enemy != null else 0.0,
	}

func _check_death() -> void:
	var death_state: String = CombatStep.death_state(player, enemy)
	if death_state == "enemy":
		if not _enemy_kill_fired:
			CombatStep.fire_player_kill(player)
			_enemy_kill_fired = true
		winner = "player"
		recorder.record_death(enemy)
		recorder.record("combat_end", {"winner": winner})
		ProcRecorder.end()
	elif death_state == "player":
		winner = "enemy"
		recorder.record_death(player)
		recorder.record("combat_end", {"winner": winner})
		ProcRecorder.end()

func _input_from_actions(actions: Array, pressed_frame: bool) -> Dictionary:
	var input: Dictionary = PlayerPolicy.neutral_input()
	for action in actions:
		match str(action):
			"light":
				input["light_pressed"] = pressed_frame
				input["attack_holding"] = true
			"heavy":
				input["heavy_pressed"] = pressed_frame
				input["attack_holding"] = true
			"dash":
				input["dash_pressed"] = pressed_frame
			"block":
				input["block_down"] = true
				input["block_pressed"] = pressed_frame
			"move_left":
				input["move"] = -1.0
			"move_right":
				input["move"] = 1.0
			"stance":
				input["stance_pressed"] = pressed_frame
			"jump":
				input["jump_pressed"] = pressed_frame
	return input

func _fighter_state(fighter: Fighter) -> Dictionary:
	if fighter == null:
		return {}
	return {
		"hp": fighter.health_current,
		"hp_max": fighter.health_max,
		"posture": fighter.posture_current,
		"posture_max": fighter.posture_max,
		"position": {"x": fighter.position.x, "y": fighter.position.y},
		"facing": fighter.facing,
		"animation": _animation_name(fighter.current_animation),
		"attack": _attack_state(fighter),
		"iframe": fighter.dash_iframe_end if fighter.is_invulnerable else 0.0,
		"stun": fighter._stun_timer if fighter.is_stunned else 0.0,
		"cooldown": fighter._attack_cooldown,
		"is_blocking": fighter.is_blocking,
		"is_invulnerable": fighter.is_invulnerable,
		"is_hit_active": fighter.is_hit_active(),
		"archetype": fighter.archetype_id,
	}

func _attack_state(fighter: Fighter) -> Dictionary:
	if fighter._attack_state == null or not fighter._attack_state.is_active():
		return {"id": "", "phase": "none", "elapsed": 0.0}
	return {
		"id": str(fighter._attack_state.def.id) if fighter._attack_state.def != null else "",
		"phase": _phase_name(fighter._attack_state.phase()),
		"elapsed": fighter._attack_state.elapsed,
	}

func _record_proc_deltas() -> void:
	var current: Dictionary = ProcRecorder.snapshot()
	_emit_proc_delta("boon_procs", current)
	_emit_proc_delta("status_applications", current)
	_proc_snapshot = current

func _emit_proc_delta(key: String, current: Dictionary) -> void:
	var previous_values: Dictionary = _proc_snapshot.get(key, {}) as Dictionary
	var current_values: Dictionary = current.get(key, {}) as Dictionary
	for id in current_values.keys():
		var delta: int = int(current_values[id]) - int(previous_values.get(id, 0))
		if delta <= 0:
			continue
		if key == "boon_procs":
			recorder.record_boon_proc(str(id), delta)

func _phase_name(phase: int) -> String:
	match phase:
		AttackDefinition.Phase.WINDUP:
			return "windup"
		AttackDefinition.Phase.ACTIVE:
			return "active"
		AttackDefinition.Phase.RECOVERY:
			return "recovery"
		_:
			return "finished"

func _animation_name(value: int) -> String:
	match value:
		Fighter.AnimationState.IDLE:
			return "IDLE"
		Fighter.AnimationState.WALKING:
			return "WALKING"
		Fighter.AnimationState.ATTACKING_LIGHT:
			return "ATTACKING_LIGHT"
		Fighter.AnimationState.ATTACKING_HEAVY:
			return "ATTACKING_HEAVY"
		Fighter.AnimationState.HIT_REACTION:
			return "HIT_REACTION"
		Fighter.AnimationState.BLOCKING:
			return "BLOCKING"
		Fighter.AnimationState.STUNNED:
			return "STUNNED"
		Fighter.AnimationState.DASHING:
			return "DASHING"
		Fighter.AnimationState.JUMPING:
			return "JUMPING"
		Fighter.AnimationState.FALLING:
			return "FALLING"
		Fighter.AnimationState.LANDING:
			return "LANDING"
		_:
			return "UNKNOWN"
