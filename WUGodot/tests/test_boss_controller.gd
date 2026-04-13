extends RefCounted

const BossControllerScript = preload("res://scripts/boss_controller.gd")
const FighterScript = preload("res://scripts/fighter.gd")

func _make_boss() -> Variant:
	var fighter: Variant = FighterScript.new()
	fighter.health_max = 300.0
	fighter.health_current = 300.0
	fighter.posture_max = 160.0
	fighter.posture_current = 160.0
	fighter.move_speed = 280.0
	fighter.is_ai = true
	return fighter

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var boss: Variant = _make_boss()
	var ctrl: Variant = BossControllerScript.new()

	# Test 1: starts in phase 1
	if ctrl.current_phase == 1:
		passed += 1
	else:
		failed += 1
		failures.append("should start in phase 1 (got %d)" % ctrl.current_phase)

	# Test 2: no transition above 50% HP
	boss.health_current = 200.0
	var transitioned: bool = ctrl.check_phase_transition(boss)
	if not transitioned and ctrl.current_phase == 1:
		passed += 1
	else:
		failed += 1
		failures.append("should not transition above 50%% HP")

	# Test 3: transition at 50% HP
	boss.health_current = 150.0
	transitioned = ctrl.check_phase_transition(boss)
	if transitioned and ctrl.current_phase == 2:
		passed += 1
	else:
		failed += 1
		failures.append("should transition at 50%% HP (phase=%d)" % ctrl.current_phase)

	# Test 4: transition only fires once
	boss.health_current = 100.0
	transitioned = ctrl.check_phase_transition(boss)
	if not transitioned:
		passed += 1
	else:
		failed += 1
		failures.append("phase transition should not fire twice")

	# Test 5: phase 1 attack table
	ctrl = BossControllerScript.new()
	var p1_table: Array[String] = ctrl.get_phase_attack_table()
	if p1_table.has("bear_swipe") and p1_table.has("bear_overhead") and p1_table.has("bear_crush_grab") and not p1_table.has("bear_roar_aoe"):
		passed += 1
	else:
		failed += 1
		failures.append("phase 1 table should have swipe/overhead/crush but not roar_aoe")

	# Test 6: phase 2 attack table keeps crush and adds roar_aoe
	boss = _make_boss()
	boss.health_current = 140.0
	ctrl.check_phase_transition(boss)
	var p2_table: Array[String] = ctrl.get_phase_attack_table()
	if p2_table.has("bear_roar_aoe") and p2_table.has("bear_swipe") and p2_table.has("bear_crush_grab"):
		passed += 1
	else:
		failed += 1
		failures.append("phase 2 table should have roar_aoe, swipe, and crush")

	# Test 7: Mountain-Breaker once per phase
	ctrl = BossControllerScript.new()
	if ctrl.can_use_mountain_breaker():
		passed += 1
	else:
		failed += 1
		failures.append("should allow mountain_breaker in phase 1")
	ctrl.consume_mountain_breaker()
	if not ctrl.can_use_mountain_breaker():
		passed += 1
	else:
		failed += 1
		failures.append("should not allow mountain_breaker twice in phase 1")

	# Test 8: phase transition resets Mountain-Breaker
	boss = _make_boss()
	boss.health_current = 140.0
	ctrl.check_phase_transition(boss)
	if ctrl.can_use_mountain_breaker():
		passed += 1
	else:
		failed += 1
		failures.append("phase transition should reset mountain_breaker availability")

	# Test 9: Bear Crush cooldown
	ctrl = BossControllerScript.new()
	if ctrl.can_use_bear_crush():
		passed += 1
	else:
		failed += 1
		failures.append("should allow bear_crush initially")
	ctrl.consume_bear_crush()
	if not ctrl.can_use_bear_crush():
		passed += 1
	else:
		failed += 1
		failures.append("should not allow bear_crush on cooldown")
	ctrl.update_cooldowns(10.0)
	if ctrl.can_use_bear_crush():
		passed += 1
	else:
		failed += 1
		failures.append("bear_crush should be available after cooldown expires")

	return {"passed": passed, "failed": failed, "failures": failures}
