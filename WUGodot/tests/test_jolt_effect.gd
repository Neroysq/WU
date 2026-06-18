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
	_add_effect(p[0], {"type": "jolt", "timer": 2.0}, "jolt#0")
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(p[1].jolt_timer, 2.0):
		passed += 1
	else:
		failed += 1
		failures.append("jolt hit should flag the defender as jolted")

	p = _pair()
	p[1].jolt_timer = 2.0
	var hp_before: float = p[1].health_current
	_add_effect(p[0], {"type": "jolt_amp", "multiplier": 1.25}, "jolt#1")
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp_before - p[1].health_current, 15.0):
		passed += 1
	else:
		failed += 1
		failures.append("jolt_amp should increase damage against already-jolted defenders")

	p = _pair()
	_add_effect(p[0], {"type": "jolt_nova", "timer": 2.5}, "jolt#nova")
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_heavy())
	if is_equal_approx(p[1].jolt_timer, 2.5):
		passed += 1
	else:
		failed += 1
		failures.append("jolt_nova should jolt the current defender in v1 single-enemy combat")

	p = _pair()
	p[1].jolt_timer = 3.0
	_add_effect(p[0], {"type": "jolt_dash_discharge", "damage": 6.0, "message": "雷!"}, "jolt#dash")
	var result: Dictionary = p[0].technique_engine.on_dash_end(p[0], p[1])
	if is_equal_approx(float(result.get("damage", 0.0)), 6.0) and is_equal_approx(p[1].jolt_timer, 0.0):
		passed += 1
	else:
		failed += 1
		failures.append("jolt_dash_discharge should consume jolt for burst damage")

	return {"passed": passed, "failed": failed, "failures": failures}
