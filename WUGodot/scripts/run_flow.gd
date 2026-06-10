class_name RunFlow
extends RefCounted

static func combat_victory_outcome(node: MapNode, gold_multiplier: int) -> Dictionary:
	var base_gold: int = 15
	if node != null:
		match node.node_type:
			MapNode.NodeType.ELITE:
				base_gold = 30
			MapNode.NodeType.AMBUSH:
				base_gold = 10
			MapNode.NodeType.BOSS:
				base_gold = 0
	var gold_gained: int = base_gold * gold_multiplier

	if node != null and node.node_type == MapNode.NodeType.AMBUSH:
		node.ambush_remaining -= 1
		if node.ambush_remaining > 0:
			return {"gold": gold_gained, "next": "combat_again"}

	if node != null and node.node_type == MapNode.NodeType.BOSS:
		return {"gold": gold_gained, "next": "victory"}
	return {"gold": gold_gained, "next": "reward"}

static func travel_decision(node: MapNode, player: Fighter) -> Dictionary:
	match node.node_type:
		MapNode.NodeType.BATTLE, MapNode.NodeType.ELITE, MapNode.NodeType.BOSS:
			return {"scene": "combat", "node": node, "combat_gold_multiplier": 1}
		MapNode.NodeType.AMBUSH:
			if node.ambush_remaining <= 0:
				node.ambush_remaining = 3
			return {"scene": "combat", "node": node, "combat_gold_multiplier": 1}
		MapNode.NodeType.EVENT:
			var event_data: Dictionary = {}
			if not node.event_id.is_empty():
				event_data = DataManager.get_event_by_id(node.event_id)
			if event_data.is_empty():
				event_data = DataManager.get_random_event()
				node.event_id = str(event_data.get("id", ""))
			if event_data.is_empty():
				return {"scene": "map", "mark_cleared": true}
			return {"scene": "event", "event_data": event_data.duplicate(true)}
		MapNode.NodeType.SHOP:
			return {"scene": "shop", "items": ShopGenerator.generate_shop(_owned_ids(player))}
		MapNode.NodeType.REST:
			return {"scene": "rest"}
		MapNode.NodeType.MASTER:
			var rewards: Array = generate_master_rewards(_owned_ids(player))
			if rewards.is_empty():
				return {"scene": "map", "mark_cleared": true}
			return {"scene": "reward", "rewards": rewards}
	return {"scene": "map"}

static func generate_technique_rewards(count: int, owned_ids: Array[String]) -> Array:
	var rewards: Array = []
	var used_ids: Array[String] = owned_ids.duplicate()
	for i in range(count):
		var reward: RewardOption = RewardOption.random_technique(used_ids)
		rewards.append(reward)
		if reward.technique_id != "":
			used_ids.append(reward.technique_id)
	return rewards

static func generate_master_rewards(owned_ids: Array[String]) -> Array:
	var rewards: Array = []
	var all_techniques: Dictionary = DataManager.get_all_techniques()
	var rare_pool: Array[Dictionary] = []
	for tech_id in all_techniques.keys():
		var tech_id_str: String = str(tech_id)
		if owned_ids.has(tech_id_str):
			continue
		var technique: Dictionary = all_techniques[tech_id] as Dictionary
		if int(technique.get("rarity", 1)) >= 2:
			rare_pool.append(technique)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(3):
		if rare_pool.is_empty():
			break
		var idx: int = rng.randi_range(0, rare_pool.size() - 1)
		var pick: Dictionary = rare_pool[idx]
		rare_pool.remove_at(idx)
		var option: RewardOption = RewardOption.new()
		option.id = str(pick.get("id", ""))
		option.label = "%s (%s)" % [str(pick.get("name_en", "")), str(pick.get("name_cn", ""))]
		option.effect = "technique"
		option.technique_id = option.id
		rewards.append(option)
	return rewards

static func _owned_ids(player: Fighter) -> Array[String]:
	if player != null and player.technique_engine != null:
		return player.technique_engine.technique_ids()
	return []
