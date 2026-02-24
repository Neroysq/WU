class_name RunState
extends RefCounted

var nodes: Array[MapNode] = []
var current_node_id: int = 0
var max_tier: int = 0

static func create_simple_three_tier() -> RunState:
	var run: RunState = RunState.new()
	run.nodes = [
		MapNode.new(0, 0, MapNode.NodeType.EVENT, [1, 2]),
		MapNode.new(1, 1, MapNode.NodeType.BATTLE, [3]),
		MapNode.new(2, 1, MapNode.NodeType.BATTLE, [4]),
		MapNode.new(3, 2, MapNode.NodeType.ELITE, [5]),
		MapNode.new(4, 2, MapNode.NodeType.TREASURE, [5]),
		MapNode.new(5, 3, MapNode.NodeType.BOSS, []),
	]
	run.current_node_id = 0
	run.max_tier = 3
	return run

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
