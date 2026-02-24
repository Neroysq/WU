class_name RewardOption
extends RefCounted

var id: String = ""
var label: String = ""

func apply(fighter: Fighter) -> void:
	match id:
		"atk_up":
			fighter.attack_damage += 4.0
		"posture_up":
			fighter.posture_max += 25.0
			fighter.posture_current += 25.0
		"rage_gain":
			fighter.attack_posture_damage += 6.0
		"dash_cd":
			fighter.move_speed += 40.0

static func random(exclude: String = "") -> RewardOption:
	var pool: Array[Dictionary] = [
		{"id": "atk_up", "label": "+4 Attack Damage"},
		{"id": "posture_up", "label": "+25 Posture Max"},
		{"id": "rage_gain", "label": "+6 Posture Damage"},
		{"id": "dash_cd", "label": "+40 Move Speed"},
	]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	var pick: Dictionary = {}
	while true:
		pick = pool[rng.randi_range(0, pool.size() - 1)]
		if exclude.is_empty() or pick["id"] != exclude:
			break

	var option: RewardOption = RewardOption.new()
	option.id = str(pick["id"])
	option.label = str(pick["label"])
	return option
