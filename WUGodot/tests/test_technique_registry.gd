extends RefCounted

const TechniqueEffectScript = preload("res://scripts/techniques/technique_effect.gd")
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")
const FighterScript = preload("res://scripts/fighter.gd")

class AddTwo extends "res://scripts/techniques/technique_effect.gd":
	func _init() -> void:
		id = "T_ADD"
		priority = 10
	func modify_outgoing_hit(ctx: Variant) -> void:
		ctx.hp_damage += 2.0

class DoubleIt extends "res://scripts/techniques/technique_effect.gd":
	func _init() -> void:
		id = "T_DBL"
		priority = 20
	func modify_outgoing_hit(ctx: Variant) -> void:
		ctx.hp_damage *= 2.0

class StanceA extends "res://scripts/techniques/technique_effect.gd":
	func _init() -> void:
		id = "T_STANCE_A"
		exclusive_group = "stance"

class StanceB extends "res://scripts/techniques/technique_effect.gd":
	func _init() -> void:
		id = "T_STANCE_B"
		exclusive_group = "stance"

class Counter extends "res://scripts/techniques/technique_effect.gd":
	var count: int = 0
	var combat_starts: int = 0
	func _init() -> void:
		id = "T_CTR"
		once_per_run = true
	func on_combat_start(_fighter: Variant) -> void:
		combat_starts += 1
	func state() -> Dictionary:
		return {"count": count}
	func restore(data: Dictionary) -> void:
		count = int(data.get("count", 0))

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	var engine: Variant = TechniqueEngineScript.new()
	var fighter: Variant = FighterScript.new()
	engine._install_effect(AddTwo.new(), fighter)
	engine._install_effect(DoubleIt.new(), fighter)

	var ctx: Variant = TechniqueEffectScript.HitContext.new()
	ctx.hp_damage = 10.0
	engine.dispatch_outgoing_hit(ctx)
	if is_equal_approx(ctx.hp_damage, 24.0):
		passed += 1
	else:
		failed += 1
		failures.append("dispatch must run in priority order (got %.1f)" % ctx.hp_damage)

	engine._install_effect(StanceA.new(), fighter)
	engine._install_effect(StanceB.new(), fighter)
	if not engine.has_effect("T_STANCE_A") and engine.has_effect("T_STANCE_B"):
		passed += 1
	else:
		failed += 1
		failures.append("exclusive_group install must replace the prior group member")

	var counter := Counter.new()
	counter.count = 3
	engine._install_effect(counter, fighter)
	engine.on_combat_start(fighter)
	if counter.count == 3 and counter.combat_starts == 1:
		passed += 1
	else:
		failed += 1
		failures.append("effect state must survive on_combat_start (count=%d)" % counter.count)

	var saved: Dictionary = engine.save_state()
	var engine2: Variant = TechniqueEngineScript.new()
	var counter2 := Counter.new()
	engine2._install_effect(counter2, fighter)
	engine2.load_state(saved, fighter)
	if counter2.count == 3:
		passed += 1
	else:
		failed += 1
		failures.append("load_state must restore concrete effect state fields (count=%d)" % counter2.count)

	var run_fighter: Variant = FighterScript.new()
	var run_engine: Variant = TechniqueEngineScript.new()
	run_fighter.technique_engine = run_engine
	run_engine.add("B4", run_fighter)
	run_engine.add("B6", run_fighter)
	run_engine.add("D1", run_fighter)
	run_engine.check_lethal_save(run_fighter)
	run_engine.on_kill(run_fighter)
	run_fighter.rage_current = run_fighter.rage_max
	run_engine.activate_stance(run_fighter)
	run_engine.on_stance_damage(15.0, run_fighter)
	var run_saved: Dictionary = run_engine.save_state()

	var restored_fighter: Variant = FighterScript.new()
	var restored_engine: Variant = TechniqueEngineScript.new()
	restored_fighter.technique_engine = restored_engine
	restored_fighter.rage_current = restored_fighter.rage_max
	var restored_rage: float = restored_fighter.rage_current
	restored_engine.load_state(run_saved, restored_fighter)
	if restored_engine.is_stance_active() and is_equal_approx(restored_fighter.rage_current, restored_rage) \
			and is_equal_approx(restored_fighter.dash_duration, 0.30) \
			and is_equal_approx(restored_fighter.dash_iframe_end, 0.26):
		passed += 1
	else:
		failed += 1
		failures.append("load_state should restore D1 active without spending rage and reapply dash params")

	restored_fighter.health_current = 0.0
	if not restored_engine.check_lethal_save(restored_fighter):
		passed += 1
	else:
		failed += 1
		failures.append("phoenix used-state should survive save/load")
	restored_fighter.health_current = restored_fighter.health_max

	var base_speed: float = restored_fighter.move_speed
	restored_engine.update(0.016, restored_fighter)
	if restored_fighter.move_speed > base_speed + 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("pending gaze should survive save/load and apply on next update")

	var active_gaze_fighter: Variant = FighterScript.new()
	var active_gaze_engine: Variant = TechniqueEngineScript.new()
	active_gaze_fighter.technique_engine = active_gaze_engine
	active_gaze_engine.add("B4", active_gaze_fighter)
	active_gaze_engine.on_kill(active_gaze_fighter)
	active_gaze_engine.update(0.016, active_gaze_fighter)
	var active_gaze_saved: Dictionary = active_gaze_engine.save_state()
	var restored_active_gaze_fighter: Variant = FighterScript.new()
	var restored_active_gaze_engine: Variant = TechniqueEngineScript.new()
	restored_active_gaze_fighter.technique_engine = restored_active_gaze_engine
	var active_gaze_base_speed: float = restored_active_gaze_fighter.move_speed
	restored_active_gaze_engine.load_state(active_gaze_saved, restored_active_gaze_fighter)
	restored_active_gaze_engine.update(3.0, restored_active_gaze_fighter)
	if restored_active_gaze_fighter.move_speed > active_gaze_base_speed + 0.01:
		failed += 1
		failures.append("active gaze restore should expire back to base speed")
	elif is_equal_approx(restored_active_gaze_fighter.move_speed, active_gaze_base_speed):
		passed += 1
	else:
		failed += 1
		failures.append("active gaze restored speed should return to base after expiry")

	if restored_engine.on_stance_damage(6.0, restored_fighter) and not restored_engine.is_stance_active():
		passed += 1
	else:
		failed += 1
		failures.append("D1 accumulated stance damage should survive save/load")

	var tiger_fighter: Variant = FighterScript.new()
	var tiger_engine: Variant = TechniqueEngineScript.new()
	tiger_fighter.technique_engine = tiger_engine
	tiger_engine.add("D2", tiger_fighter)
	tiger_fighter.rage_current = tiger_fighter.rage_max
	tiger_engine.activate_stance(tiger_fighter)
	tiger_engine.update(5.0, tiger_fighter)
	var tiger_saved: Dictionary = tiger_engine.save_state()
	var restored_tiger_fighter: Variant = FighterScript.new()
	var restored_tiger_engine: Variant = TechniqueEngineScript.new()
	restored_tiger_fighter.technique_engine = restored_tiger_engine
	restored_tiger_engine.load_state(tiger_saved, restored_tiger_fighter)
	restored_tiger_engine.update(10.1, restored_tiger_fighter)
	if not restored_tiger_engine.is_stance_active():
		passed += 1
	else:
		failed += 1
		failures.append("D2 remaining timer should restore, not restart at 15s")

	return {"passed": passed, "failed": failed, "failures": failures}
