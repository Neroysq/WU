extends RefCounted

const RunStateScript = preload("res://scripts/run_state.gd")
const MapNodeScript = preload("res://scripts/map_node.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	for seed_val in range(5):
		var run: Variant = RunStateScript.create_procedural_run(seed_val * 1000 + 42)

		if run.nodes.size() >= 13 and run.nodes.size() <= 17:
			passed += 1
		else:
			failed += 1
			failures.append("seed %d: node count %d not in [13,17]" % [seed_val, run.nodes.size()])

		var master_count: int = 0
		for node in run.nodes:
			if node.node_type == MapNodeScript.NodeType.MASTER:
				master_count += 1
		if master_count == 1:
			passed += 1
		else:
			failed += 1
			failures.append("seed %d: master_count=%d (expect 1)" % [seed_val, master_count])

		var rest_count: int = 0
		var rest_is_convergence: bool = false
		for node in run.nodes:
			if node.node_type == MapNodeScript.NodeType.REST:
				rest_count += 1
				if run.count_in_tier(node.tier) == 1:
					rest_is_convergence = true
		if rest_count >= 1 and rest_is_convergence:
			passed += 1
		else:
			failed += 1
			failures.append("seed %d: rest must be on a convergence tier (count=%d, convergence=%s)" % [seed_val, rest_count, str(rest_is_convergence)])

		var boss_count: int = 0
		for node in run.nodes:
			if node.node_type == MapNodeScript.NodeType.BOSS:
				boss_count += 1
				if node.tier != run.max_tier:
					failed += 1
					failures.append("seed %d: boss not at final tier" % seed_val)
		if boss_count == 1:
			passed += 1
		else:
			failed += 1
			failures.append("seed %d: boss_count=%d (expect 1)" % [seed_val, boss_count])

		var reachable: Dictionary = {}
		var queue: Array[int] = [run.nodes[0].id]
		while not queue.is_empty():
			var current_id: int = queue.pop_front()
			if reachable.has(current_id):
				continue
			reachable[current_id] = true
			var current_node: Variant = run.get_node(current_id)
			if current_node != null:
				for next_id in current_node.next_ids:
					if not reachable.has(next_id):
						queue.append(next_id)
		if reachable.size() == run.nodes.size():
			passed += 1
		else:
			failed += 1
			failures.append("seed %d: only %d/%d nodes reachable" % [seed_val, reachable.size(), run.nodes.size()])

	return {"passed": passed, "failed": failed, "failures": failures}
