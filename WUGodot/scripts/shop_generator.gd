class_name ShopGenerator
extends RefCounted

static func generate_shop(owned_ids: Array[String], rarity_boost: bool = false) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var items: Array[Dictionary] = []
	var used_ids: Array[String] = owned_ids.duplicate()
	var all_techniques: Dictionary = DataManager.get_all_techniques()

	for i in range(3):
		var pool: Array[Dictionary] = []
		for tech_id in all_techniques.keys():
			var technique_id: String = str(tech_id)
			if used_ids.has(technique_id):
				continue
			pool.append((all_techniques[tech_id] as Dictionary).duplicate(true))
		if pool.is_empty():
			break
		var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var rarity: int = int(pick.get("rarity", 1))
		var price: int = 20 + (rarity - 1) * 15
		if rarity_boost:
			price = int(round(price * 0.8))
		items.append({
			"type": "technique",
			"technique_id": str(pick.get("id", "")),
			"label": "%s (%s)" % [str(pick.get("name_en", "")), str(pick.get("name_cn", ""))],
			"description": str(pick.get("description", "")),
			"price": price,
		})
		used_ids.append(str(pick.get("id", "")))

	items.append({
		"type": "hp_potion",
		"label": "HP Potion",
		"description": "Heal 30% max HP.",
		"price": 20,
	})
	items.append({
		"type": "posture_potion",
		"label": "Posture Potion",
		"description": "Restore 50% max posture.",
		"price": 15,
	})
	items.append({
		"type": "forget_technique",
		"label": "Forget Technique",
		"description": "Remove one technique from your loadout.",
		"price": 25,
	})

	return items

static func buy_item(item: Dictionary, fighter: Fighter) -> Dictionary:
	var price: int = int(item.get("price", 0))
	if fighter.gold < price:
		return {"success": false, "message": "Not enough gold."}

	var item_type: String = str(item.get("type", ""))
	match item_type:
		"technique":
			var technique_id: String = str(item.get("technique_id", ""))
			if fighter.technique_engine == null or technique_id.is_empty():
				return {"success": false, "message": "Cannot learn that."}
			fighter.gold -= price
			fighter.technique_engine.add(technique_id, fighter)
			return {"success": true, "message": "Learned %s." % str(item.get("label", "technique"))}
		"hp_potion":
			fighter.gold -= price
			fighter.health_current = minf(fighter.health_current + fighter.health_max * 0.3, fighter.health_max)
			return {"success": true, "message": "Healed 30% HP."}
		"posture_potion":
			fighter.gold -= price
			fighter.posture_current = minf(fighter.posture_current + fighter.posture_max * 0.5, fighter.posture_max)
			return {"success": true, "message": "Restored 50% posture."}
		"forget_technique":
			fighter.gold -= price
			return {"success": true, "message": "Choose a technique to forget.", "open_forget": true}
		_:
			return {"success": false, "message": "Unknown item."}
