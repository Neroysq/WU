extends RefCounted

const CombatControllerScript = preload("res://scripts/sim/combat_controller.gd")
const RunConductorScript = preload("res://scripts/sim/run_conductor.gd")
const TriggerEngineScript = preload("res://scripts/sim/trigger_engine.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.reload_data()

	var hit_result: Dictionary = _scripted_light_exchange(70.0, 44)
	var hit_events: Array = hit_result.get("events", []) as Array
	if _has_event(hit_events, "attack_started") and _has_event(hit_events, "attack_active_started") and _has_hit(hit_events) and _count_event(hit_events, "whiff") == 0:
		passed += 1
	else:
		failed += 1
		failures.append("recorder should emit attack start/active/hit and no whiff on contact")

	var whiff_result: Dictionary = _scripted_light_exchange(700.0, 50)
	var whiff_events: Array = whiff_result.get("events", []) as Array
	if _count_event(whiff_events, "whiff") == 1 and not _has_hit(whiff_events):
		passed += 1
	else:
		failed += 1
		failures.append("recorder should emit exactly one whiff when the active window closes with zero contact")

	var controller: Variant = CombatControllerScript.new()
	controller.start(EnemyFactory.create_player(), MapNode.new(2, 1, MapNode.NodeType.BATTLE, []), "bandit_swordsman", 12, {})
	controller.enemy.is_ai = false
	controller.enemy.position = controller.player.position + Vector2(80.0, 0.0)
	var trigger_id: int = controller.add_trigger({"event": "player_attack_active"})
	var trigger_result: Dictionary = controller.advance(["light"], 30)
	if trigger_id > 0 and str(trigger_result.get("reason", "")) == "trigger" and int((trigger_result.get("trigger", {}) as Dictionary).get("id", 0)) == trigger_id:
		passed += 1
	else:
		failed += 1
		failures.append("trigger engine should pause the controller when player attack becomes active")

	var conductor: Variant = RunConductorScript.new()
	var run: RunState = RunState.new()
	var start: MapNode = MapNode.new(0, 0, MapNode.NodeType.EVENT, [1])
	var battle: MapNode = MapNode.new(1, 1, MapNode.NodeType.BATTLE, [])
	run.nodes = [start, battle]
	run.current_node_id = 0
	conductor.start(21, {"run_state_override": run, "forced_archetype": "bandit_swordsman"})
	var bad_step: Dictionary = conductor.step(1)
	var combat_pause: Dictionary = conductor.choose(0)
	var bad_choose: Dictionary = conductor.choose(0)
	if str(bad_step.get("status", "")) == "error" and str((combat_pause.get("pause", {}) as Dictionary).get("kind", "")) == "combat" and str(bad_choose.get("status", "")) == "error":
		passed += 1
	else:
		failed += 1
		failures.append("run conductor should enforce decision/combat command boundaries and route map choice into combat")

	var projection_before: Dictionary = conductor.transcript_state()
	var projection_snapshot: Dictionary = conductor.projection_snapshot()
	var projection_after: Dictionary = conductor.transcript_state()
	if projection_before == projection_after and str(projection_snapshot.get("pause_kind", "")) == "combat":
		passed += 1
	else:
		failed += 1
		failures.append("projection snapshot should be read-only over the conductor transcript state")

	return {"passed": passed, "failed": failed, "failures": failures}

func _scripted_light_exchange(distance: float, frames: int) -> Dictionary:
	var controller: Variant = CombatControllerScript.new()
	controller.start(EnemyFactory.create_player(), MapNode.new(1, 1, MapNode.NodeType.BATTLE, []), "bandit_swordsman", 11, {})
	controller.enemy.is_ai = false
	controller.enemy.position = controller.player.position + Vector2(distance, 0.0)
	return controller.advance(["light"], frames)

func _has_event(events: Array, type: String) -> bool:
	for event in events:
		if str((event as Dictionary).get("type", "")) == type:
			return true
	return false

func _count_event(events: Array, type: String) -> int:
	var count: int = 0
	for event in events:
		if str((event as Dictionary).get("type", "")) == type:
			count += 1
	return count

func _has_hit(events: Array) -> bool:
	for event in events:
		var data: Dictionary = event as Dictionary
		if str(data.get("type", "")) == "hit" and str(data.get("by", "")) == "player":
			return true
	return false
