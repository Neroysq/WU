extends RefCounted

const RewardSceneScript = preload("res://scripts/scenes/reward_scene.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.reload_data()
	RngService.set_run_seed(7102)

	var from_dict: RewardOption = RewardOption.from_dictionary({"id": "test", "label": "Test", "rarity": 3})
	if from_dict.rarity == 3:
		passed += 1
	else:
		failed += 1
		failures.append("RewardOption.from_dictionary should copy rarity")

	var single: RewardOption = RewardOption.random_technique(_owned_except(["B6"]))
	if single.id == "B6" and single.rarity == 3:
		passed += 1
	else:
		failed += 1
		failures.append("RewardOption.random_technique should preserve technique rarity, got %s r%d" % [single.id, single.rarity])

	var master_rewards: Array = RunFlow.generate_master_rewards(_owned_except(["A9", "B6"]))
	var master_ok: bool = master_rewards.size() == 2
	for item in master_rewards:
		var reward: RewardOption = item as RewardOption
		var tech: Dictionary = DataManager.get_technique(reward.technique_id)
		master_ok = master_ok and reward.rarity == int(tech.get("rarity", 0)) and reward.rarity >= 2
	if master_ok:
		passed += 1
	else:
		failed += 1
		failures.append("RunFlow.generate_master_rewards should preserve rare technique rarity")

	var shop_items: Array[Dictionary] = ShopGenerator.generate_shop(_owned_except(["A1", "A9", "B6"]))
	var shop_ok: bool = true
	var technique_rows: int = 0
	for item in shop_items:
		if str(item.get("type", "")) != "technique":
			continue
		technique_rows += 1
		var rarity: int = int(item.get("rarity", 0))
		shop_ok = shop_ok and rarity > 0 and int(item.get("price", -1)) == 20 + (rarity - 1) * 15
	if shop_ok and technique_rows == 3:
		passed += 1
	else:
		failed += 1
		failures.append("ShopGenerator technique rows should expose rarity and matching price")

	var scene: Variant = RewardSceneScript.new()
	scene.enter(null, {"rewards": [
		{"id": "A1", "label": "Descending Leaf", "effect": "technique", "technique_id": "A1", "rarity": 1},
		{"id": "B6", "label": "Phoenix Rising", "effect": "technique", "technique_id": "B6", "rarity": 3},
	]})
	if scene.rewards.size() == 2 and (scene.rewards[0] is RewardOption) and int(scene.rewards[1].rarity) == 3:
		passed += 1
	else:
		failed += 1
		failures.append("RewardScene.enter should convert JSON dictionaries into RewardOption instances")

	RngService.clear_run_seed()
	return {"passed": passed, "failed": failed, "failures": failures}

func _owned_except(open_ids: Array[String]) -> Array[String]:
	var owned: Array[String] = []
	for id in DataManager.get_all_techniques().keys():
		var technique_id: String = str(id)
		if not open_ids.has(technique_id):
			owned.append(technique_id)
	return owned
