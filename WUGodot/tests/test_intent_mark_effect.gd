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
	_add_effect(p[0], {"type": "intent_mark", "marks": 1, "max": 3, "burst_per_mark": 6.0}, "intent#0")
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if p[1].intent_marks == 1:
		passed += 1
	else:
		failed += 1
		failures.append("intent_mark should apply a mark on light hit")

	p = _pair()
	p[1].intent_marks = 2
	_add_effect(p[0], {"type": "intent_mark", "marks": 1, "max": 3, "burst_per_mark": 6.0}, "intent#0")
	var hp_before: float = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_heavy())
	var expected_heavy: float = AttackCatalogScript.hu_heavy().damage + 12.0
	if is_equal_approx(hp_before - p[1].health_current, expected_heavy) and p[1].intent_marks == 0:
		passed += 1
	else:
		failed += 1
		failures.append("intent_mark heavy should consume marks for burst damage")

	p = _pair()
	p[1].intent_marks = 1
	_add_effect(p[0], {"type": "intent_crit_vs_marked", "multiplier": 1.5}, "intent#crit")
	hp_before = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp_before - p[1].health_current, 18.0):
		passed += 1
	else:
		failed += 1
		failures.append("intent_crit_vs_marked should amplify damage against marked defenders")

	p = _pair()
	var effect: Variant = Registry.create_effect_from_data({"type": "intent_reach", "range": 18.0}, "intent#reach")
	p[0].technique_engine.add_effect(effect, p[0])
	p[0]._start_attack_with(AttackCatalogScript.hu_light())
	var range_after_add: float = p[0].current_attack_range()
	p[0].technique_engine.remove_effect(effect, p[0])
	if is_equal_approx(range_after_add, AttackCatalogScript.hu_light().range_units + 18.0) and is_equal_approx(p[0].attack_range_bonus, 0.0):
		passed += 1
	else:
		failed += 1
		failures.append("intent_reach should extend authored attack reach and restore on remove")

	p = _pair()
	_add_effect(p[0], {"type": "intent_dash_flash", "marks": 1, "max": 3, "range": 120.0}, "intent#dash")
	p[0].technique_engine.on_dash_end(p[0], p[1])
	if p[1].intent_marks == 1:
		passed += 1
	else:
		failed += 1
		failures.append("intent_dash_flash should mark the current defender after a dash")

	return {"passed": passed, "failed": failed, "failures": failures}
