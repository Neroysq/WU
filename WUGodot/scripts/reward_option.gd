class_name RewardOption
extends RefCounted

var id: String = ""
var label: String = ""
var effect: String = ""
var amount: float = 0.0

func apply(fighter: Fighter) -> void:
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
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	var pick: Dictionary = filtered_pool[rng.randi_range(0, filtered_pool.size() - 1)]
	return from_dictionary(pick)

static func from_dictionary(data: Dictionary) -> RewardOption:
	var option: RewardOption = RewardOption.new()
	option.id = str(data.get("id", "reward"))
	option.label = str(data.get("label", "Reward"))
	option.effect = str(data.get("effect", ""))
	option.amount = float(data.get("amount", 0.0))
	return option
