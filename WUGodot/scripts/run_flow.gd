class_name RunFlow
extends RefCounted

const BoonOfferScript = preload("res://scripts/boons/boon_offer.gd")
const RngServiceScript = preload("res://scripts/sim/rng_service.gd")
const EncounterResolverScript = preload("res://scripts/encounter_resolver.gd")

static func combat_victory_outcome(node: MapNode, gold_multiplier: int) -> Dictionary:
	var base_gold: int = 15
	var insight_gained: int = 0
	if node != null:
		match node.node_type:
			MapNode.NodeType.ELITE:
				base_gold = 30
				insight_gained = 1
			MapNode.NodeType.AMBUSH:
				base_gold = 10
			MapNode.NodeType.BOSS:
				base_gold = 0
				insight_gained = 2
	var gold_gained: int = base_gold * gold_multiplier

	if node != null and node.node_type == MapNode.NodeType.AMBUSH:
		node.ambush_remaining -= 1
		if node.ambush_remaining > 0:
			return {"gold": gold_gained, "insight": insight_gained, "next": "combat_again"}

	if node != null and node.node_type == MapNode.NodeType.BOSS:
		return {"gold": gold_gained, "insight": insight_gained, "next": "victory"}
	return {"gold": gold_gained, "insight": insight_gained, "next": "boon_offer"}

static func travel_decision(node: MapNode, player: Fighter, run_state: Variant = null) -> Dictionary:
	match node.node_type:
		MapNode.NodeType.BATTLE, MapNode.NodeType.ELITE, MapNode.NodeType.BOSS:
			return {"scene": "combat", "node": node, "combat_gold_multiplier": 1}
		MapNode.NodeType.AMBUSH:
			if node.ambush_remaining <= 0:
				var chapter: int = int(run_state.chapter) if run_state != null else 1
				node.ambush_remaining = EncounterResolverScript.ambush_length(DataManager.get_difficulty_curve(chapter), node.tier)
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
			var choice_payload: Dictionary = generate_school_choice_payload(run_state, node)
			if (choice_payload.get("school_choices", []) as Array).is_empty():
				return {"scene": "map", "mark_cleared": true}
			return choice_payload
	return {"scene": "map"}

static func generate_boon_offer_payload(run_state: Variant, node: MapNode = null, school: String = "", rng: RandomNumberGenerator = null) -> Dictionary:
	var roll_rng: RandomNumberGenerator = rng if rng != null else RngServiceScript.stream("boon_offer")
	var loadout: Variant = run_state.boon_loadout if run_state != null else null
	var depth: int = node.tier if node != null else 0
	var school_id: String = school
	var offers: Array[Dictionary] = []
	var explicit_school: bool = not school_id.is_empty()

	if school_id.is_empty() and run_state != null and _should_consume_favor(node) and not str(run_state.favored_school).is_empty():
		school_id = str(run_state.favored_school)
		run_state.favored_school = ""

	if not school_id.is_empty():
		offers = BoonOfferScript.generate(loadout, school_id, depth, roll_rng)
	if offers.is_empty() and not explicit_school:
		var candidates: Array[String] = _offer_school_pool()
		while not candidates.is_empty():
			var idx: int = roll_rng.randi_range(0, candidates.size() - 1)
			school_id = candidates[idx]
			candidates.remove_at(idx)
			offers = BoonOfferScript.generate(loadout, school_id, depth, roll_rng)
			if offers.size() == 3:
				break
			if offers.is_empty():
				school_id = ""

	return {
		"scene": "boon_offer",
		"school": school_id,
		"offers": offers,
	}

static func generate_school_choice_payload(run_state: Variant, node: MapNode = null, rng: RandomNumberGenerator = null) -> Dictionary:
	return {
		"scene": "boon_offer",
		"school_choices": generate_school_choices(run_state, node, 3, rng),
		"offers": [],
	}

static func generate_school_choices(run_state: Variant, node: MapNode = null, count: int = 3, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var roll_rng: RandomNumberGenerator = rng if rng != null else RngServiceScript.stream("school")
	var loadout: Variant = run_state.boon_loadout if run_state != null else null
	var depth: int = node.tier if node != null else 0
	var candidates: Array[String] = []
	for school in _offer_school_pool():
		var probe: RandomNumberGenerator = RandomNumberGenerator.new()
		probe.seed = 1000 + depth + candidates.size()
		if BoonOfferScript.generate(loadout, school, depth, probe).size() >= 3:
			candidates.append(school)

	var choices: Array[Dictionary] = []
	while choices.size() < count and not candidates.is_empty():
		var idx: int = roll_rng.randi_range(0, candidates.size() - 1)
		var school_id: String = candidates[idx]
		candidates.remove_at(idx)
		choices.append({
			"school": school_id,
			"school_data": DataManager.get_school(school_id),
		})
	return choices

static func apply_boon_offer_selection(run_state: Variant, offer: Dictionary) -> bool:
	if run_state == null or run_state.boon_loadout == null:
		return false
	var boon_id: String = str(offer.get("boon_id", ""))
	var tier: String = str(offer.get("tier", "common"))
	if boon_id.is_empty():
		return false
	return run_state.boon_loadout.add_boon(boon_id, tier)

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

	var rng: RandomNumberGenerator = RngServiceScript.stream("reward")
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
		option.rarity = int(pick.get("rarity", 1))
		rewards.append(option)
	return rewards

static func _owned_ids(player: Fighter) -> Array[String]:
	if player != null and player.technique_engine != null:
		return player.technique_engine.technique_ids()
	return []

static func _offer_school_pool() -> Array[String]:
	var schools: Array[String] = []
	for raw_boon in DataManager.get_all_boons().values():
		var boon: Dictionary = raw_boon as Dictionary
		var school: String = str(boon.get("school", ""))
		if not school.is_empty() and not schools.has(school):
			schools.append(school)
	return schools

static func _should_consume_favor(node: MapNode) -> bool:
	return node != null and (node.node_type == MapNode.NodeType.BATTLE or node.node_type == MapNode.NodeType.AMBUSH)

static func _rng(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	if rng != null:
		return rng
	return RngServiceScript.stream("boon_offer")
