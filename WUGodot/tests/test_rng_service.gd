extends RefCounted

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	RngService.clear_run_seed()
	var a: RandomNumberGenerator = RngService.stream("ai")
	var b: RandomNumberGenerator = RngService.stream("ai")
	if a == b and a.randi() != a.randi():
		passed += 1
	else:
		failed += 1
		failures.append("RngService.stream should cache and advance one domain stream")

	RngService.set_run_seed(7)
	var seq_a: Array[int] = []
	for i in range(5):
		seq_a.append(RngService.stream("ai").randi())
	RngService.set_run_seed(7)
	var seq_b: Array[int] = []
	for i in range(5):
		seq_b.append(RngService.stream("ai").randi())
	if seq_a == seq_b:
		passed += 1
	else:
		failed += 1
		failures.append("same seed/domain should reproduce the same sequence")

	RngService.set_run_seed(7)
	var ai_roll: int = RngService.stream("ai").randi()
	var combat_roll: int = RngService.stream("combat").randi()
	if ai_roll != combat_roll:
		passed += 1
	else:
		failed += 1
		failures.append("different domains should produce different seeded streams")

	DataManager.reload_data()
	var node: MapNode = MapNode.new(1, 1, MapNode.NodeType.BATTLE, [])
	RngService.set_run_seed(42)
	var enemy_a: Fighter = EnemyFactory.create_enemy_for_node(node)
	RngService.set_run_seed(42)
	var enemy_b: Fighter = EnemyFactory.create_enemy_for_node(node)
	if enemy_a.archetype_id == enemy_b.archetype_id:
		passed += 1
	else:
		failed += 1
		failures.append("enemy factory should reproduce after resetting the run seed")

	RngService.set_run_seed(5)
	var event_a: Dictionary = DataManager.get_random_event()
	RngService.set_run_seed(5)
	var event_b: Dictionary = DataManager.get_random_event()
	if str(event_a.get("id", "")) == str(event_b.get("id", "")):
		passed += 1
	else:
		failed += 1
		failures.append("random event should reproduce after resetting the run seed")

	RngService.clear_run_seed()
	return {"passed": passed, "failed": failed, "failures": failures}

