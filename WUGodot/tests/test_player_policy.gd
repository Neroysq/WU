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
	enemy._attack_state.advance(AttackCatalogScript.bandit_slash().windup_end + 0.01)
	input = policy.next_input(player, enemy)
	if bool(input.get("block_down", false)) or bool(input.get("dash_pressed", false)):
		passed += 1
	else:
		failed += 1
		failures.append("HeuristicPlayer should defend during a close enemy attack")

	RngService.clear_run_seed()
	return {"passed": passed, "failed": failed, "failures": failures}

