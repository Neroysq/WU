class_name MapNode
extends RefCounted

enum NodeType {
	BATTLE,
	ELITE,
	AMBUSH,
	MASTER,
	EVENT,
	SHOP,
	REST,
	BOSS,
}

var id: int = 0
var tier: int = 0
var node_type: int = NodeType.BATTLE
var cleared: bool = false
var next_ids: Array[int] = []
var ambush_remaining: int = 0
var event_id: String = ""

func _init(node_id: int = 0, node_tier: int = 0, type_value: int = NodeType.BATTLE, next_list: Array[int] = []) -> void:
	id = node_id
	tier = node_tier
	node_type = type_value
	cleared = false
	next_ids = next_list.duplicate()
	if node_type == NodeType.AMBUSH:
		ambush_remaining = 3
