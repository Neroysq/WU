class_name RunState
extends RefCounted

var nodes: Array[MapNode] = []
var current_node_id: int = 0
var max_tier: int = 0

static func create_simple_three_tier() -> RunState:
	return create_procedural_run()

static func create_procedural_run(seed: int = -1) -> RunState:
	var run: RunState = RunState.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()

	var tier_nodes: Array = []
	var next_id: int = 0

	var start_node: MapNode = MapNode.new(next_id, 0, MapNode.NodeType.EVENT, [])
	run.nodes.append(start_node)
	tier_nodes.append([start_node])
	next_id += 1

	var middle_tier_count: int = rng.randi_range(2, 3)
	for tier in range(1, middle_tier_count + 1):
		var node_count: int = 2 if tier == middle_tier_count else rng.randi_range(2, 3)
		var tier_bucket: Array = []
		for node_index in range(node_count):
			var node_type: int = _pick_node_type_for_tier(rng, tier, middle_tier_count, node_index)
			var node: MapNode = MapNode.new(next_id, tier, node_type, [])
			run.nodes.append(node)
			tier_bucket.append(node)
			next_id += 1
		tier_nodes.append(tier_bucket)

	var boss_tier: int = middle_tier_count + 1
	var boss_node: MapNode = MapNode.new(next_id, boss_tier, MapNode.NodeType.BOSS, [])
	run.nodes.append(boss_node)
	tier_nodes.append([boss_node])

	for tier_index in range(tier_nodes.size() - 1):
		var previous_tier_nodes: Array = tier_nodes[tier_index] as Array
		var next_tier_nodes: Array = tier_nodes[tier_index + 1] as Array
		_connect_tiers(previous_tier_nodes, next_tier_nodes, rng)

	run.current_node_id = start_node.id
	run.max_tier = boss_tier
	return run

static func _pick_node_type_for_tier(rng: RandomNumberGenerator, tier: int, middle_tier_count: int, node_index: int) -> int:
	if tier == middle_tier_count:
		if node_index == 0:
			return MapNode.NodeType.ELITE
		if rng.randf() < 0.45:
			return MapNode.NodeType.BATTLE
		return MapNode.NodeType.TREASURE if rng.randf() < 0.5 else MapNode.NodeType.EVENT

	if node_index == 0:
		return MapNode.NodeType.BATTLE

	var pool: Array[int] = [
		MapNode.NodeType.BATTLE,
		MapNode.NodeType.EVENT,
		MapNode.NodeType.TREASURE,
	]
	return int(pool[rng.randi_range(0, pool.size() - 1)])

static func _connect_tiers(previous_nodes: Array, next_nodes: Array, rng: RandomNumberGenerator) -> void:
	var incoming: Dictionary = {}
	for next_node_variant in next_nodes:
		var next_node: MapNode = next_node_variant as MapNode
		incoming[next_node.id] = 0

	for previous_index in range(previous_nodes.size()):
		var previous_node: MapNode = previous_nodes[previous_index] as MapNode
		previous_node.next_ids.clear()

		var anchor_index: int = int(round(float(previous_index) * float(maxi(next_nodes.size() - 1, 0)) / float(maxi(previous_nodes.size() - 1, 1))))
		var target_indices: Array[int] = [anchor_index]
		if next_nodes.size() > 1 and rng.randf() < 0.45:
			var neighbor_offset: int = -1 if rng.randf() < 0.5 else 1
			var neighbor_index: int = clampi(anchor_index + neighbor_offset, 0, next_nodes.size() - 1)
			if not target_indices.has(neighbor_index):
				target_indices.append(neighbor_index)

		for target_index in target_indices:
			var target_node: MapNode = next_nodes[target_index] as MapNode
			previous_node.next_ids.append(target_node.id)
			incoming[target_node.id] = int(incoming.get(target_node.id, 0)) + 1

	for next_index in range(next_nodes.size()):
		var candidate_node: MapNode = next_nodes[next_index] as MapNode
		if int(incoming.get(candidate_node.id, 0)) > 0:
			continue

		var source_index: int = clampi(next_index, 0, previous_nodes.size() - 1)
		var source_node: MapNode = previous_nodes[source_index] as MapNode
		if not source_node.next_ids.has(candidate_node.id):
			source_node.next_ids.append(candidate_node.id)

func get_node(node_id: int) -> MapNode:
	for node in nodes:
		if node.id == node_id:
			return node
	return null

func get_current_node() -> MapNode:
	return get_node(current_node_id)

func get_available_next() -> Array[MapNode]:
	var current: MapNode = get_current_node()
	var available: Array[MapNode] = []
	if current == null:
		return available
	for next_id in current.next_ids:
		var node: MapNode = get_node(next_id)
		if node != null:
			available.append(node)
	return available

func advance_to(node_id: int) -> void:
	current_node_id = node_id

func mark_current_node_cleared() -> void:
	var node: MapNode = get_current_node()
	if node != null:
		node.cleared = true

func count_in_tier(tier: int) -> int:
	var count: int = 0
	for node in nodes:
		if node.tier == tier:
			count += 1
	return count

func index_in_tier(target: MapNode) -> int:
	var index: int = 0
	for node in nodes:
		if node.tier != target.tier:
			continue
		if node.id == target.id:
			return index
		index += 1
	return 0
