extends RefCounted

const AiBrainScript = preload("res://scripts/ai_brain.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

func _make_fighter() -> Variant:
	var fighter: Variant = FighterScript.new()
	fighter.health_max = 100.0
	fighter.health_current = 100.0
	fighter.posture_max = 100.0
	fighter.posture_current = 100.0
	fighter.move_speed = 300.0
	fighter.attack_range = 68.0
	fighter.position = Vector2(800.0, 940.0)
	fighter.facing = -1
	fighter.is_ai = true
	return fighter

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var brain: Variant = AiBrainScript.new()
	var ai: Variant = _make_fighter()
	var target: Variant = _make_fighter()
	target.is_ai = false
	target.position = Vector2(400.0, 940.0)
	ai.position = Vector2(470.0, 940.0)

	# Test 1: empty brain returns idle
	var action: Dictionary = brain.decide(ai, target)
	if str(action.get("type", "")) == "idle":
		passed += 1
	else:
		failed += 1
		failures.append("empty brain should return idle (got %s)" % str(action.get("type", "")))

	# Test 2: brain with pattern table returns attack when in range
	brain = AiBrainScript.new()
	brain.pattern_table.append("bandit_slash")
	brain.pattern_table.append("bandit_thrust_perilous")
	brain.aggression = 1.0
	brain.preferred_range = 70.0
	brain.retreat_chance = 0.0
	brain.block_chance = 0.0
	ai.position = Vector2(470.0, 940.0)
	target.position = Vector2(400.0, 940.0)
	ai._attack_cooldown = 0.0
	ai._ai_decision_timer = 0.0
	var got_attack: bool = false
	for i in range(20):
		action = brain.decide(ai, target)
		if str(action.get("type", "")) == "attack":
			got_attack = true
			break
		brain._decision_cooldown = 0.0
	if got_attack:
		passed += 1
	else:
		failed += 1
		failures.append("brain with pattern table should return attack when in range")

	# Test 3: attack_id from decision is in pattern table
	if got_attack:
		var attack_id: String = str(action.get("attack_id", ""))
		if brain.pattern_table.has(attack_id):
			passed += 1
		else:
			failed += 1
			failures.append("attack_id '%s' not in pattern table" % attack_id)
	else:
		passed += 1

	# Test 4: brain respects decision cooldown
	brain._decision_cooldown = 5.0
	action = brain.decide(ai, target)
	if str(action.get("type", "")) != "attack":
		passed += 1
	else:
		failed += 1
		failures.append("brain should not attack during decision cooldown")
	brain._decision_cooldown = 0.0

	# Test 5: out of range -> move toward target
	brain.dash_chance = 0.0
	brain._decision_cooldown = 0.0
	ai.position = Vector2(900.0, 940.0)
	target.position = Vector2(400.0, 940.0)
	action = brain.decide(ai, target)
	if str(action.get("type", "")) == "move":
		passed += 1
	else:
		failed += 1
		failures.append("should move toward target when out of range (got %s)" % str(action.get("type", "")))

	# Test 6: block decision when target has started an attack.
	# AttackState.is_active() is true immediately on start() during windup.
	ai.position = Vector2(470.0, 940.0)
	target.position = Vector2(400.0, 940.0)
	brain.block_chance = 1.0
	brain._decision_cooldown = 0.0
	target.start_light_attack()
	action = brain.decide(ai, target)
	if str(action.get("type", "")) == "block":
		passed += 1
	else:
		failed += 1
		failures.append("should block when target attacking and block_chance=1.0 (got %s)" % str(action.get("type", "")))
	brain.block_chance = 0.0
	target._attack_state.clear()
	brain._decision_cooldown = 0.0

	# Test 6b: block reaction scales with the attacker's current reach, not only
	# preferred_range. Keep this beyond preferred_range*1.5 but inside Hu's art-derived reach.
	ai.position = Vector2(550.0, 940.0)
	target.position = Vector2(400.0, 940.0)
	brain.preferred_range = 70.0
	brain.block_chance = 1.0
	target._attack_state.start(AttackCatalogScript.hu_light())
	action = brain.decide(ai, target)
	if str(action.get("type", "")) == "block":
		passed += 1
	else:
		failed += 1
		failures.append("should block player windup inside target attack range (got %s)" % str(action.get("type", "")))
	brain.block_chance = 0.0
	target._attack_state.clear()
	brain._decision_cooldown = 0.0

	# Test 7: update_cooldowns decrements timer
	brain._decision_cooldown = 1.0
	brain.update_cooldowns(0.5)
	if absf(brain._decision_cooldown - 0.5) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("update_cooldowns should decrement (got %.2f)" % brain._decision_cooldown)

	# Test 8: get_attack_def returns valid definition
	var attack_def: Variant = brain.get_attack_def("bandit_slash")
	if attack_def != null and attack_def.id == "bandit_slash":
		passed += 1
	else:
		failed += 1
		failures.append("get_attack_def should return valid attack definition")

	# Test 9: range filter favors attacks that can actually reach.
	brain.pattern_table.clear()
	brain.pattern_table.append("bandit_slash")
	brain.pattern_table.append("spear_wide_swing")
	brain._decision_cooldown = 0.0
	var ranged_only: bool = true
	for i in range(20):
		var picked: String = brain.pick_attack_from_table(brain.pattern_table, 180.0)
		if picked != "spear_wide_swing":
			ranged_only = false
			break
	if ranged_only:
		passed += 1
	else:
		failed += 1
		failures.append("range filter should pick only long-reach attacks at 120 units")

	# Test 10: empty range-filter result falls back to the full table.
	brain.pattern_table.clear()
	brain.pattern_table.append("bandit_slash")
	var fallback_pick: String = brain.pick_attack_from_table(brain.pattern_table, 500.0)
	if fallback_pick == "bandit_slash":
		passed += 1
	else:
		failed += 1
		failures.append("range filter should fall back to full table when nothing reaches")

	# Test 11: from_enemy_data reads teleport chance.
	var data: Dictionary = {
		"pattern_table": ["smoke_thrust", "flicker_slash"],
		"aggression": 0.7,
		"blockChance": 0.3,
		"preferredRange": 65.0,
		"retreatChance": 0.05,
		"dashChance": 0.10,
		"teleport_chance": 0.08,
	}
	var loaded: Variant = AiBrainScript.from_enemy_data(data)
	if absf(loaded.teleport_chance - 0.08) < 0.001 and loaded.pattern_table.size() == 2:
		passed += 1
	else:
		failed += 1
		failures.append("from_enemy_data should load teleport_chance and pattern table")

	return {"passed": passed, "failed": failed, "failures": failures}
