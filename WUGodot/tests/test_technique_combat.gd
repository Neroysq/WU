extends RefCounted

const CombatSystemScript = preload("res://scripts/combat_system.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")
const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

func _pair(attacker_tech: Array, defender_tech: Array) -> Array:
	var attacker: Variant = FighterScript.new()
	var defender: Variant = FighterScript.new()
	attacker.position = Vector2(0.0, 900.0)
	attacker.facing = 1
	defender.position = Vector2(60.0, 900.0)
	defender.facing = -1
	attacker.technique_engine = TechniqueEngineScript.new()
	defender.technique_engine = TechniqueEngineScript.new()
	for id in attacker_tech:
		attacker.technique_engine.add(str(id), attacker)
	for id in defender_tech:
		defender.technique_engine.add(str(id), defender)
	return [attacker, defender]

func _strike(cs: Variant, attacker: Variant, defender: Variant, attack: Variant) -> void:
	attacker._start_attack_with(attack)
	attacker._attack_state.advance(attack.windup_end + 0.01)
	cs.resolve_hits(attacker, defender)

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []
	var cs: Variant = CombatSystemScript.new()

	var p := _pair(["B5"], [])
	p[0].health_current = p[0].health_max * 0.25
	var hp0: float = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp0 - p[1].health_current, 15.0):
		passed += 1
	else:
		failed += 1
		failures.append("B5 low-HP light should deal 15 (got %.1f)" % (hp0 - p[1].health_current))

	p = _pair(["A4"], [])
	p[0].technique_engine.on_dash_end()
	hp0 = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp0 - p[1].health_current, 15.6) and not p[0].technique_engine.has_sparrow_bonus():
		passed += 1
	else:
		failed += 1
		failures.append("A4 sparrow light should deal 15.6 and consume")

	p = _pair(["A4"], [])
	p[0].technique_engine.on_dash_end()
	var feedback_log: Array[String] = []
	cs.show_feedback.connect(func(msg: String, _duration: float) -> void: feedback_log.append(msg))
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	var sparrow_idx: int = feedback_log.find("雀翼!")
	var hit_idx: int = feedback_log.find("HIT")
	if sparrow_idx != -1 and hit_idx != -1 and sparrow_idx < hit_idx:
		passed += 1
	else:
		failed += 1
		failures.append("technique feedback must precede generic HIT (got %s)" % str(feedback_log))

	p = _pair(["B1"], [])
	p[0].technique_engine.set_echo()
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if p[1].is_stunned:
		passed += 1
	else:
		failed += 1
		failures.append("armed echo should guarantee a posture break")

	p = _pair(["B3"], [])
	p[0].health_current = 50.0
	p[0].technique_engine.on_dash_through()
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(p[0].health_current, 55.0):
		passed += 1
	else:
		failed += 1
		failures.append("B3 should heal attacker 5 (got %.1f)" % p[0].health_current)

	p = _pair(["A3"], [])
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_heavy())
	if is_equal_approx(p[1].bleed_timer, 3.0) and is_equal_approx(p[1].bleed_dps, 1.5):
		passed += 1
	else:
		failed += 1
		failures.append("A3 heavy should bleed 3.0s @ 1.5dps")

	p = _pair(["A10"], [])
	hp0 = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_heavy())
	if is_equal_approx(hp0 - p[1].health_current, 33.0):
		passed += 1
	else:
		failed += 1
		failures.append("A10 heavy total should be 33 (got %.1f)" % (hp0 - p[1].health_current))

	p = _pair([], ["A5"])
	p[1].is_blocking = true
	hp0 = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp0 - p[1].health_current, 1.2):
		passed += 1
	else:
		failed += 1
		failures.append("A5 blocked light chip should be 1.2 (got %.2f)" % (hp0 - p[1].health_current))

	p = _pair([], ["D2"])
	p[1].rage_current = p[1].rage_max
	p[1].technique_engine.activate_stance(p[1])
	p[1].is_blocking = true
	hp0 = p[0].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp0 - p[0].health_current, 1.2):
		passed += 1
	else:
		failed += 1
		failures.append("D2 block should reflect 1.2 (got %.2f)" % (hp0 - p[0].health_current))

	p = _pair(["B2"], [])
	p[0].health_current = 50.0
	p[1].posture_current = 1.0
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(p[0].health_current, 65.0):
		passed += 1
	else:
		failed += 1
		failures.append("B2 should heal 15 on posture break (got %.1f)" % p[0].health_current)

	p = _pair(["A2"], [])
	p[0].technique_engine._rng.seed = 1
	var rolled_any := false
	for _i in range(50):
		if p[0].technique_engine.roll_stagger():
			rolled_any = true
	if rolled_any:
		passed += 1
	else:
		failed += 1
		failures.append("A2 seeded stagger should fire within 50 rolls")

	p = _pair([], ["B6"])
	p[1].health_current = 1.0
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_heavy())
	if is_equal_approx(p[1].health_current, p[1].health_max * 0.2):
		passed += 1
	else:
		failed += 1
		failures.append("B6 lethal save should leave 20%% HP (got %.1f)" % p[1].health_current)

	p = _pair(["A1"], [])
	p[0]._dash_timer = 0.01
	hp0 = p[1].health_current
	cs.update_player(p[0], {"move": 0.0}, 0.02, p[1])
	if is_equal_approx(hp0 - p[1].health_current, 8.0):
		passed += 1
	else:
		failed += 1
		failures.append("A1 dash-end stab should deal 8 (got %.1f)" % (hp0 - p[1].health_current))

	p = _pair([], [])
	p[0].is_ai = true
	p[0].incoming_pressure_mult = 0.5
	hp0 = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp0 - p[1].health_current, 6.0):
		passed += 1
	else:
		failed += 1
		failures.append("enemy pressure multiplier should scale outgoing damage (got %.1f)" % (hp0 - p[1].health_current))

	p = _pair([], [])
	p[0].incoming_pressure_mult = 0.5
	hp0 = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp0 - p[1].health_current, 12.0):
		passed += 1
	else:
		failed += 1
		failures.append("player damage should ignore incoming_pressure_mult (got %.1f)" % (hp0 - p[1].health_current))

	return {"passed": passed, "failed": failed, "failures": failures}
