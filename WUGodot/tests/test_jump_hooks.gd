extends RefCounted

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")

class HookRecorder extends "res://scripts/techniques/technique_effect.gd":
	var jumps: int = 0
	var lands: int = 0
	var aerial_hits: int = 0

	func _init() -> void:
		id = "hook_recorder#0"

	func on_jump(_fighter: Variant) -> void:
		jumps += 1

	func on_land(_fighter: Variant) -> void:
		lands += 1

	func modify_aerial_hit(ctx: Variant) -> void:
		aerial_hits += 1
		ctx.hp_damage += 1.0

func _make_fighter() -> Variant:
	var fighter: Variant = FighterScript.new()
	fighter.position = Vector2(0.0, GameConstants.GROUND_Y)
	fighter.facing = 1
	fighter.technique_engine = TechniqueEngineScript.new()
	return fighter

func _strike(cs: Variant, attacker: Variant, defender: Variant) -> void:
	attacker._start_attack_with(AttackCatalogScript.hu_light())
	attacker._attack_state.advance(AttackCatalogScript.hu_light().windup_end + 0.01)
	cs.resolve_hits(attacker, defender)

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []
	var cs: Variant = CombatSystemScript.new()

	var fighter: Variant = _make_fighter()
	var recorder := HookRecorder.new()
	fighter.technique_engine.add_effect(recorder, fighter)
	cs.update_player(fighter, {"jump_pressed": true}, 0.016, null)
	if recorder.jumps == 1:
		passed += 1
	else:
		failed += 1
		failures.append("jump input should dispatch on_jump exactly once")

	fighter.position.y = GameConstants.GROUND_Y - 5.0
	fighter.velocity.y = 200.0
	fighter.is_grounded = false
	cs.update_player(fighter, {}, 0.1, null)
	if recorder.lands == 1:
		passed += 1
	else:
		failed += 1
		failures.append("ground contact should dispatch on_land exactly once")

	var attacker: Variant = _make_fighter()
	var defender: Variant = _make_fighter()
	defender.position = Vector2(60.0, GameConstants.GROUND_Y)
	defender.facing = -1
	attacker.is_grounded = false
	var aerial_recorder := HookRecorder.new()
	attacker.technique_engine.add_effect(aerial_recorder, attacker)
	var hp_before: float = defender.health_current
	_strike(cs, attacker, defender)
	if aerial_recorder.aerial_hits == 1 and is_equal_approx(hp_before - defender.health_current, 13.0):
		passed += 1
	else:
		failed += 1
		failures.append("aerial hit should dispatch modify_aerial_hit and affect damage")

	return {"passed": passed, "failed": failed, "failures": failures}
