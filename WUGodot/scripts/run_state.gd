class_name RunState
extends RefCounted

var nodes: Array[MapNode] = []
var current_node_id: int = 0
var max_tier: int = 0

static func create_simple_three_tier() -> RunState:
	return create_procedural_run()

static func create_procedural_run(seed_value: int = -1) -> RunState:
	var run: RunState = RunState.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	var next_id: int = 0
	var tier_nodes: Array = []

	var start: MapNode = MapNode.new(next_id, 0, MapNode.NodeType.EVENT, [])
	run.nodes.append(start)
	tier_nodes.append([start])
	next_id += 1

	for tier in range(1, 6):
		var bucket: Array = []
		if tier == 3:
			var master: MapNode = MapNode.new(next_id, tier, MapNode.NodeType.MASTER, [])
			run.nodes.append(master)
			bucket.append(master)
			next_id += 1
		elif tier == 5:
			var rest: MapNode = MapNode.new(next_id, tier, MapNode.NodeType.REST, [])
			run.nodes.append(rest)
			bucket.append(rest)
			next_id += 1
		else:
			var node_count: int = 3 if tier <= 2 else rng.randi_range(3, 4)
			for idx in range(node_count):
				var node_type: int = _pick_node_type(rng, tier, idx)
				var node: MapNode = MapNode.new(next_id, tier, node_type, [])
				run.nodes.append(node)
				bucket.append(node)
				next_id += 1
		tier_nodes.append(bucket)

	var boss: MapNode = MapNode.new(next_id, 6, MapNode.NodeType.BOSS, [])
	run.nodes.append(boss)
	tier_nodes.append([boss])

	for tier_idx in range(tier_nodes.size() - 1):
		_connect_tiers(tier_nodes[tier_idx] as Array, tier_nodes[tier_idx + 1] as Array, rng)

	run.current_node_id = start.id
	run.max_tier = 6
	return run

static func _pick_node_type(rng: RandomNumberGenerator, tier: int, idx: int) -> int:
	if tier == 4:
		if idx == 0:
			return MapNode.NodeType.ELITE
		if idx == 1:
			return MapNode.NodeType.SHOP
		var late_pool: Array[int] = [
			MapNode.NodeType.BATTLE,
			MapNode.NodeType.EVENT,
			MapNode.NodeType.SHOP,
		]
		return int(late_pool[rng.randi_range(0, late_pool.size() - 1)])

	if idx == 0:
		return MapNode.NodeType.BATTLE

	var roll: float = rng.randf()
	if roll < 0.4:
		return MapNode.NodeType.BATTLE
	if roll < 0.6:
		return MapNode.NodeType.EVENT
	if roll < 0.75:
		return MapNode.NodeType.AMBUSH
	if roll < 0.85:
		return MapNode.NodeType.SHOP
	return MapNode.NodeType.ELITE

static func _connect_tiers(prev_nodes: Array, next_nodes: Array, rng: RandomNumberGenerator) -> void:
	var incoming: Dictionary = {}
	for next_variant in next_nodes:
		var next_node: MapNode = next_variant as MapNode
		incoming[next_node.id] = 0

	for prev_idx in range(prev_nodes.size()):
		var prev_node: MapNode = prev_nodes[prev_idx] as MapNode
		prev_node.next_ids.clear()
		var anchor: int = int(round(float(prev_idx) * float(maxi(next_nodes.size() - 1, 0)) / float(maxi(prev_nodes.size() - 1, 1))))
		var targets: Array[int] = [anchor]
		if next_nodes.size() > 1 and rng.randf() < 0.5:
			var offset: int = -1 if rng.randf() < 0.5 else 1
			var neighbor: int = clampi(anchor + offset, 0, next_nodes.size() - 1)
			if not targets.has(neighbor):
				targets.append(neighbor)
		for target_idx in targets:
			var target_node: MapNode = next_nodes[target_idx] as MapNode
			prev_node.next_ids.append(target_node.id)
			incoming[target_node.id] = int(incoming.get(target_node.id, 0)) + 1

	for next_idx in range(next_nodes.size()):
		var candidate: MapNode = next_nodes[next_idx] as MapNode
		if int(incoming.get(candidate.id, 0)) > 0:
			continue
		var source_idx: int = clampi(next_idx, 0, prev_nodes.size() - 1)
		var source: MapNode = prev_nodes[source_idx] as MapNode
		if not source.next_ids.has(candidate.id):
			source.next_ids.append(candidate.id)

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
