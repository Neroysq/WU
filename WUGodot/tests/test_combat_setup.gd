extends RefCounted

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.reload_data()
	RngService.set_run_seed(11)
	var player: Fighter = EnemyFactory.create_player()
	var node: MapNode = MapNode.new(2, 1, MapNode.NodeType.BATTLE, [])
	var setup: Dictionary = CombatSetup.prepare(player, node, "")
	var enemy: Fighter = setup.get("enemy") as Fighter
	var combat_system: CombatSystem = setup.get("combat_system") as CombatSystem
	var hit_geometry: Variant = setup.get("hit_geometry")

	if enemy != null and enemy.is_ai and enemy.ai_brain != null and combat_system != null:
		passed += 1
	else:
		failed += 1
		failures.append("CombatSetup should create an AI enemy and CombatSystem")

	if player.position == Vector2(1560.0, GameConstants.GROUND_Y) and enemy.position == Vector2(360.0, GameConstants.GROUND_Y) and player.facing == -1 and enemy.facing == 1:
		passed += 1
	else:
		failed += 1
		failures.append("CombatSetup should reset placement/facing to the live matchup start")

	player._attack_state.start(AttackCatalogScript.hu_light())
	player._attack_state.advance(AttackCatalogScript.hu_light().windup_end + 0.01)
	if hit_geometry != null and hit_geometry.has_authored_hitbox(player):
		passed += 1
	else:
		failed += 1
		failures.append("CombatSetup should register Hu gameplay hit geometry")

	var curve: Dictionary = DataManager.get_difficulty_curve(1)
	var strong_context: Dictionary = {"pool_class": "strong"}
	setup = CombatSetup.prepare(EnemyFactory.create_player(), node, "sect_disciple", strong_context)
	enemy = setup.get("enemy") as Fighter
	var expected_pressure: float = float((curve.get("pressure_by_pool_class", {}) as Dictionary).get("strong", 1.0))
	var expected_block: float = float((curve.get("block_chance_by_pool_class", {}) as Dictionary).get("strong", 0.0))
	var expected_aggression: float = float((curve.get("aggression_by_pool_class", {}) as Dictionary).get("strong", 0.0))
	if enemy != null and enemy.ai_brain != null and is_equal_approx(enemy.incoming_pressure_mult, expected_pressure) and is_equal_approx(enemy.ai_brain.block_chance, expected_block) and is_equal_approx(enemy.ai_brain.aggression, expected_aggression):
		passed += 1
	else:
		failed += 1
		failures.append("CombatSetup should apply pool-class pressure/blockChance/aggression modifiers")

	setup = CombatSetup.prepare(EnemyFactory.create_player(), node, "sect_disciple")
	enemy = setup.get("enemy") as Fighter
	if enemy != null and is_equal_approx(enemy.incoming_pressure_mult, 1.0):
		passed += 1
	else:
		failed += 1
		failures.append("CombatSetup without encounter context should leave pressure multiplier at 1.0")

	RngService.clear_run_seed()
	return {"passed": passed, "failed": failed, "failures": failures}
