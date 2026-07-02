class_name RewardOption
extends RefCounted

const RngServiceScript = preload("res://scripts/sim/rng_service.gd")

var id: String = ""
var label: String = ""
var effect: String = ""
var amount: float = 0.0
var technique_id: String = ""
var rarity: int = 1

func apply(fighter: Fighter) -> void:
	if effect == "technique":
		if fighter.technique_engine != null and not technique_id.is_empty():
			fighter.technique_engine.add(technique_id, fighter)
		return
	match effect:
		"attack_damage":
			fighter.attack_damage += amount
		"posture_max":
			fighter.posture_max += amount
			fighter.posture_current += amount
		"attack_posture_damage":
			fighter.attack_posture_damage += amount
		"move_speed":
			fighter.move_speed += amount

static func random(exclude: String = "") -> RewardOption:
	var pool: Array[Dictionary] = DataManager.get_rewards()
	var filtered_pool: Array[Dictionary] = []
	for reward_data in pool:
		if exclude.is_empty() or str(reward_data.get("id", "")) != exclude:
			filtered_pool.append(reward_data)
	if filtered_pool.is_empty():
		filtered_pool = pool
	var rng: RandomNumberGenerator = RngServiceScript.stream("reward")

	var pick: Dictionary = filtered_pool[rng.randi_range(0, filtered_pool.size() - 1)]
	return from_dictionary(pick)

static func from_dictionary(data: Dictionary) -> RewardOption:
	var option: RewardOption = RewardOption.new()
	option.id = str(data.get("id", "reward"))
	option.label = str(data.get("label", "Reward"))
	option.effect = str(data.get("effect", ""))
	option.amount = float(data.get("amount", 0.0))
	option.technique_id = str(data.get("technique_id", ""))
	option.rarity = int(data.get("rarity", 1))
	return option

static func random_technique(owned_ids: Array[String]) -> RewardOption:
	var all_techniques: Dictionary = DataManager.get_all_techniques()
	var pool: Array[Dictionary] = []
	for tech_id in all_techniques.keys():
		if not owned_ids.has(str(tech_id)):
			pool.append(all_techniques[tech_id] as Dictionary)
	if pool.is_empty():
		return random()
	var rng: RandomNumberGenerator = RngServiceScript.stream("reward")
	var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var option: RewardOption = RewardOption.new()
	option.id = str(pick.get("id", ""))
	option.label = "%s (%s)" % [str(pick.get("name_en", "")), str(pick.get("name_cn", ""))]
	option.effect = "technique"
	option.technique_id = option.id
	option.rarity = int(pick.get("rarity", 1))
	return option
