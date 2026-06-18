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
	_add_effect(p[0], {"type": "venom", "stacks": 2, "timer": 3.0, "dps": 1.0}, "venom#0")
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if p[1].venom_stacks == 2 and is_equal_approx(p[1].venom_timer, 3.0) and is_equal_approx(p[1].venom_dps, 1.0):
		passed += 1
	else:
		failed += 1
		failures.append("venom hit should apply stacks, timer, and dps")

	var hp_before: float = p[1].health_current
	cs.tick_effects(p[1], 1.0)
	if is_equal_approx(hp_before - p[1].health_current, 2.0):
		passed += 1
	else:
		failed += 1
		failures.append("venom should tick dps times stacks")

	p = _pair()
	var base_speed: float = p[1].move_speed
	_add_effect(p[0], {"type": "venom", "stacks": 1, "timer": 1.0, "dps": 1.0}, "venom#0")
	_add_effect(p[0], {"type": "venom_slow", "multiplier": 0.75}, "venom#1")
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(p[1].move_speed, base_speed * 0.75):
		passed += 1
	else:
		failed += 1
		failures.append("venom_slow should reduce move speed while venomed")
	cs.tick_effects(p[1], 1.1)
	if p[1].venom_stacks == 0 and is_equal_approx(p[1].move_speed, base_speed):
		passed += 1
	else:
		failed += 1
		failures.append("venom expiry should clear stacks and restore slow")

	var spread: Variant = Registry.create_effect_from_data({"type": "venom_spread"}, "venom#spread")
	if spread != null:
		passed += 1
	else:
		failed += 1
		failures.append("venom_spread rider should be registered even though v1 single-enemy spread is a no-op")

	p = _pair()
	p[1].venom_stacks = 3
	p[1].venom_timer = 3.0
	p[1].venom_dps = 1.0
	_add_effect(p[0], {"type": "venom_heavy_detonate", "damage_per_stack": 2.0}, "venom#detonate")
	hp_before = p[1].health_current
	var heavy: Variant = AttackCatalogScript.hu_heavy()
	_strike(cs, p[0], p[1], heavy)
	if is_equal_approx(hp_before - p[1].health_current, heavy.damage + 6.0) and p[1].venom_stacks == 0:
		passed += 1
	else:
		failed += 1
		failures.append("venom_heavy_detonate should add burst damage and consume stacks")

	return {"passed": passed, "failed": failed, "failures": failures}
