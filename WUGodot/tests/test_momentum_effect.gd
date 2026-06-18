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
	_add_effect(p[0], {"type": "momentum", "dash_gain": 30.0, "decay": 10.0, "max": 100.0}, "momentum#0")
	p[0].technique_engine.on_dash_end(p[0], p[1])
	p[0].technique_engine.update(1.0, p[0])
	if is_equal_approx(p[0].momentum, 20.0):
		passed += 1
	else:
		failed += 1
		failures.append("momentum should build on dash end and decay over time")

	p = _pair()
	p[0].momentum = 80.0
	_add_effect(p[0], {"type": "momentum_flurry", "threshold": 50.0, "damage": 3.0, "cost": 20.0}, "momentum#flurry")
	var hp_before: float = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp_before - p[1].health_current, 15.0) and is_equal_approx(p[0].momentum, 60.0):
		passed += 1
	else:
		failed += 1
		failures.append("momentum_flurry should add an extra light hit at high momentum and spend meter")

	p = _pair()
	_add_effect(p[0], {"type": "momentum_aerial", "multiplier": 1.5, "landing_gain": 12.0}, "momentum#aerial")
	p[0].is_grounded = false
	hp_before = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	p[0].technique_engine.dispatch_land(p[0])
	if is_equal_approx(hp_before - p[1].health_current, 18.0) and is_equal_approx(p[0].momentum, 12.0) and not p[0].momentum_landing_burst_ready:
		passed += 1
	else:
		failed += 1
		failures.append("momentum_aerial should boost aerial hits and cash out on land")

	p = _pair()
	var speed_before: float = p[0].move_speed
	var effect: Variant = Registry.create_effect_from_data({"type": "momentum_speed", "move_speed": 25.0}, "momentum#speed")
	p[0].technique_engine.add_effect(effect, p[0])
	var speed_after_add: float = p[0].move_speed
	p[0].technique_engine.remove_effect(effect, p[0])
	if is_equal_approx(speed_after_add, speed_before + 25.0) and is_equal_approx(p[0].move_speed, speed_before):
		passed += 1
	else:
		failed += 1
		failures.append("momentum_speed should add and restore move speed like a stat delta")

	return {"passed": passed, "failed": failed, "failures": failures}
