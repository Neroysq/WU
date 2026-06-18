extends RefCounted

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const Registry = preload("res://scripts/techniques/technique_registry.gd")
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")

func _pair() -> Array:
	var attacker: Variant = FighterScript.new()
	var defender: Variant = FighterScript.new()
	attacker.position = Vector2(0.0, GameConstants.GROUND_Y)
	attacker.facing = 1
	defender.position = Vector2(60.0, GameConstants.GROUND_Y)
	defender.facing = -1
	attacker.technique_engine = TechniqueEngineScript.new()
	defender.technique_engine = TechniqueEngineScript.new()
	return [attacker, defender]

func _add_effect(fighter: Variant, effect_data: Dictionary, id: String) -> void:
	fighter.technique_engine.add_effect(Registry.create_effect_from_data(effect_data, id), fighter)

func _strike(cs: Variant, attacker: Variant, defender: Variant, attack: Variant) -> void:
	attacker._start_attack_with(attack)
	attacker._attack_state.advance(attack.windup_end + 0.01)
	cs.resolve_hits(attacker, defender)

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []
	var cs: Variant = CombatSystemScript.new()

	var p: Array = _pair()
	_add_effect(p[0], {"type": "deflect", "damage": 4.0}, "deflect#0")
	var handled: bool = p[0].technique_engine.dispatch_parry_success(p[0])
	var hp_before: float = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if handled and is_equal_approx(hp_before - p[1].health_current, 16.0) and not p[0].deflect_riposte_armed:
		passed += 1
	else:
		failed += 1
		failures.append("deflect should arm one riposte on parry and consume it on hit")

	p = _pair()
	_add_effect(p[0], {"type": "deflect", "damage": 4.0}, "deflect#0")
	_add_effect(p[0], {"type": "deflect_riposte_dmg", "damage": 5.0}, "deflect#1")
	p[0].technique_engine.dispatch_parry_success(p[0])
	hp_before = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp_before - p[1].health_current, 21.0):
		passed += 1
	else:
		failed += 1
		failures.append("deflect_riposte_dmg should add damage to an armed riposte")

	p = _pair()
	_add_effect(p[1], {"type": "deflect_reduce", "multiplier": 0.5}, "deflect#reduce")
	p[1].is_blocking = true
	hp_before = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp_before - p[1].health_current, 1.2):
		passed += 1
	else:
		failed += 1
		failures.append("deflect_reduce should reduce blocked chip damage")

	p = _pair()
	_add_effect(p[1], {"type": "deflect_redirect", "reflect": 0.2}, "deflect#redirect")
	p[1].is_blocking = true
	hp_before = p[0].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp_before - p[0].health_current, 2.4):
		passed += 1
	else:
		failed += 1
		failures.append("deflect_redirect should reflect part of a blocked light attack")

	return {"passed": passed, "failed": failed, "failures": failures}
