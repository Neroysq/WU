extends RefCounted

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	RngService.set_run_seed(13)
	var player: Fighter = EnemyFactory.create_player()
	var enemy: Fighter = EnemyFactory.create_enemy_by_archetype("bandit_swordsman")
	var policy: HeuristicPlayer = HeuristicPlayer.new(1.0)
	enemy.position = player.position + Vector2(500.0, 0.0)
	var input: Dictionary = policy.next_input(player, enemy)
	if PlayerPolicy.has_exact_input_keys(input):
		passed += 1
	else:
		failed += 1
		failures.append("HeuristicPlayer should emit the literal combat input key set")

	if float(input.get("move", 0.0)) > 0.0:
		passed += 1
	else:
		failed += 1
		failures.append("HeuristicPlayer should move toward a far enemy")

	enemy.position = player.position + Vector2(60.0, 0.0)
	input = policy.next_input(player, enemy)
	if bool(input.get("light_pressed", false)) or bool(input.get("heavy_pressed", false)):
		passed += 1
	else:
		failed += 1
		failures.append("HeuristicPlayer should attack when in range")

	enemy._attack_state.start(AttackCatalogScript.bandit_slash())
	enemy._attack_state.advance(0.01)
	input = policy.next_input(player, enemy)
	if bool(input.get("light_pressed", false)) or bool(input.get("heavy_pressed", false)):
		passed += 1
	else:
		failed += 1
		failures.append("HeuristicPlayer should not freeze through early enemy windup")

	enemy._attack_state.advance(AttackCatalogScript.bandit_slash().windup_end + 0.01)
	input = policy.next_input(player, enemy)
	if bool(input.get("block_down", false)) or bool(input.get("dash_pressed", false)):
		passed += 1
	else:
		failed += 1
		failures.append("HeuristicPlayer should defend during a close enemy attack")

	var parry_policy: ParryDuelistPolicy = ParryDuelistPolicy.new()
	enemy._attack_state.clear()
	enemy._attack_state.start(AttackCatalogScript.bandit_slash())
	enemy._attack_state.advance(AttackCatalogScript.bandit_slash().windup_end + 0.01)
	input = parry_policy.next_input(player, enemy)
	if bool(input.get("block_down", false)) and bool(input.get("block_pressed", false)):
		passed += 1
	else:
		failed += 1
		failures.append("ParryDuelistPolicy should parry close parryable attacks")

	var dash_policy: AggressiveDashPolicy = AggressiveDashPolicy.new()
	enemy._attack_state.clear()
	enemy._attack_state.start(AttackCatalogScript.bandit_thrust_perilous())
	enemy._attack_state.advance(AttackCatalogScript.bandit_thrust_perilous().windup_end + 0.01)
	input = dash_policy.next_input(player, enemy)
	if bool(input.get("dash_pressed", false)) and not bool(input.get("block_pressed", false)) and not bool(input.get("block_down", false)):
		passed += 1
	else:
		failed += 1
		failures.append("AggressiveDashPolicy should dash perilous attacks without blocking")

	enemy._attack_state.clear()
	enemy._attack_state.start(AttackCatalogScript.bandit_slash())
	enemy._attack_state.advance(AttackCatalogScript.bandit_slash().windup_end + 0.01)
	input = dash_policy.next_input(player, enemy)
	if not bool(input.get("block_pressed", false)) and not bool(input.get("block_down", false)):
		passed += 1
	else:
		failed += 1
		failures.append("AggressiveDashPolicy should never block or parry active parryable threats")

	enemy._attack_state.clear()
	player.position = Vector2(600.0, GameConstants.GROUND_Y)
	enemy.position = player.position + Vector2(320.0, 0.0)
	input = dash_policy.next_input(player, enemy)
	if bool(input.get("light_pressed", false)):
		passed += 1
	else:
		failed += 1
		failures.append("AggressiveDashPolicy should attack from authored light reach instead of idle range")

	var facetank_policy: FacetankPolicy = FacetankPolicy.new()
	input = facetank_policy.next_input(player, enemy)
	if not bool(input.get("dash_pressed", false)) and not bool(input.get("block_pressed", false)) and not bool(input.get("block_down", false)):
		passed += 1
	else:
		failed += 1
		failures.append("FacetankPolicy should never dash, block, or parry")

	var batch: Dictionary = BatchRunner.new().run([1], facetank_policy, GreedySynergyPolicy.new())
	var transcripts: Array = batch.get("transcripts", []) as Array
	var policy_name: String = ""
	if not transcripts.is_empty():
		var transcript: Dictionary = transcripts[0] as Dictionary
		var policies: Dictionary = transcript.get("policies", {}) as Dictionary
		policy_name = str(policies.get("player", ""))
	if policy_name == "facetank_policy":
		passed += 1
	else:
		failed += 1
		failures.append("BatchRunner should preserve custom PlayerPolicy subclasses, got '%s'" % policy_name)

	RngService.clear_run_seed()
	return {"passed": passed, "failed": failed, "failures": failures}
