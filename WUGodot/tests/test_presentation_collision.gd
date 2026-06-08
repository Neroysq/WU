extends RefCounted

const PresentationCollisionScript = preload("res://scripts/visual/presentation_collision.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var pc: Variant = PresentationCollisionScript.new()
	pc.register_from_manifest_file("hu", "res://assets/animation_manifests/hu.manifest.json")

	var attacker: Variant = _active_attacker(AttackCatalogScript.hu_light())
	pc.register_fighter(attacker, "hu")

	if pc.has_authored_hitbox(attacker):
		passed += 1
	else:
		failed += 1
		failures.append("registered attacker mid-active should have an authored hitbox")

	var near: Variant = FighterScript.new()
	near.position = Vector2(470.0, 900.0)
	near.facing = -1
	if pc.query_hit(attacker, near):
		passed += 1
	else:
		failed += 1
		failures.append("defender within capsule reach should be hit")

	var far: Variant = FighterScript.new()
	far.position = Vector2(900.0, 900.0)
	far.facing = -1
	if not pc.query_hit(attacker, far):
		passed += 1
	else:
		failed += 1
		failures.append("defender out of reach should not be hit")

	var behind: Variant = FighterScript.new()
	behind.position = Vector2(330.0, 900.0)
	behind.facing = 1
	if not pc.query_hit(attacker, behind):
		passed += 1
	else:
		failed += 1
		failures.append("defender behind the attacker should not be hit")

	var stranger: Variant = FighterScript.new()
	if not pc.has_authored_hitbox(stranger):
		passed += 1
	else:
		failed += 1
		failures.append("unregistered fighter must not report an authored hitbox")

	var tech: Variant = _active_attacker(AttackCatalogScript.tiger_light())
	pc.register_fighter(tech, "hu")
	if not pc.has_authored_hitbox(tech):
		passed += 1
	else:
		failed += 1
		failures.append("technique-override attack must fall back to scalar")

	var cap_dbg: Dictionary = pc.attack_capsule_world(attacker)
	var expected_reach: float = maxf((cap_dbg["a"] as Vector2).x, (cap_dbg["b"] as Vector2).x) + float(cap_dbg["r"]) - attacker.position.x
	var reach_right: float = pc.derived_reach(attacker)
	if absf(reach_right - expected_reach) <= 0.5:
		passed += 1
	else:
		failed += 1
		failures.append("derived_reach should equal the world capsule forward extent (facing right)")

	var atk_l: Variant = FighterScript.new()
	atk_l.position = Vector2(400.0, 900.0)
	atk_l.facing = -1
	atk_l._attack_state.start(AttackCatalogScript.hu_light())
	atk_l._attack_state.advance(AttackCatalogScript.hu_light().windup_end + 0.01)
	pc.register_fighter(atk_l, "hu")
	if absf(pc.derived_reach(atk_l) - reach_right) <= 0.5:
		passed += 1
	else:
		failed += 1
		failures.append("derived_reach should be facing-agnostic (left == right magnitude)")

	var cs: Variant = CombatSystemScript.new()
	cs.hit_geometry = pc

	var atk2: Variant = _active_attacker(AttackCatalogScript.hu_light())
	pc.register_fighter(atk2, "hu")
	var def2: Variant = FighterScript.new()
	def2.position = Vector2(470.0, 900.0)
	def2.facing = -1
	var hp_before: float = def2.health_current
	cs.resolve_hits(atk2, def2)
	if def2.health_current < hp_before:
		passed += 1
	else:
		failed += 1
		failures.append("authored hitbox should deal damage to an in-reach defender")

	var atk3: Variant = _active_attacker(AttackCatalogScript.bandit_slash())
	var def3: Variant = FighterScript.new()
	def3.position = Vector2(460.0, 900.0)
	def3.facing = -1
	var hp3_before: float = def3.health_current
	cs.resolve_hits(atk3, def3)
	if def3.health_current < hp3_before:
		passed += 1
	else:
		failed += 1
		failures.append("unregistered attacker should still hit via scalar fallback")

	var atk4: Variant = _active_attacker(AttackCatalogScript.hu_light())
	var def4: Variant = FighterScript.new()
	def4.position = Vector2(atk4.position.x + AttackCatalogScript.hu_light().range_units + def4.half_width + 40.0, 900.0)
	def4.facing = -1
	var hp4_before: float = def4.health_current
	cs.resolve_hits(atk4, def4)
	if is_equal_approx(def4.health_current, hp4_before):
		passed += 1
	else:
		failed += 1
		failures.append("unregistered Hu should not hit beyond scalar range while authored geometry is dormant")

	for atk_name in ["hu_light", "hu_heavy"]:
		var atk: Variant = AttackCatalogScript.hu_light() if atk_name == "hu_light" else AttackCatalogScript.hu_heavy()
		var ra: Variant = FighterScript.new()
		ra.position = Vector2(0.0, 900.0)
		ra.facing = 1
		ra._attack_state.start(atk)
		ra._attack_state.advance(atk.windup_end + 0.01)
		pc.register_fighter(ra, "hu")
		var reach: float = pc.derived_reach(ra)
		if absf(reach - (atk.range_units + 22.0)) <= maxf(20.0, atk.range_units * 0.25):
			passed += 1
		else:
			failed += 1
			failures.append("%s reach %.0f should equal range_units+22 (%.0f)" % [atk_name, reach, atk.range_units + 22.0])

	return {"passed": passed, "failed": failed, "failures": failures}

func _active_attacker(attack_def: Variant) -> Variant:
	var fighter: Variant = FighterScript.new()
	fighter.position = Vector2(400.0, 900.0)
	fighter.facing = 1
	fighter._attack_state.start(attack_def)
	fighter._attack_state.advance(attack_def.windup_end + 0.01)
	return fighter
