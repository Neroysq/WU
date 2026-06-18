class_name BoonOffer
extends RefCounted

const TIERS: Array[String] = ["common", "rare", "epic", "legendary"]

static func generate(loadout: Variant, school: String, depth: int = 0, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var roll_rng: RandomNumberGenerator = _rng(rng)
	var empty_slot_moves: Array[Dictionary] = []
	var other_offers: Array[Dictionary] = []

	for boon in DataManager.get_boons_for_school(school):
		if not _is_offerable(loadout, boon, depth):
			continue
		if _is_empty_slot_move(loadout, boon):
			empty_slot_moves.append(boon)
		else:
			other_offers.append(boon)

	var selected: Array[Dictionary] = []
	_pick_from_pool(empty_slot_moves, selected, 3, roll_rng)
	_pick_from_pool(other_offers, selected, 3, roll_rng)

	var offers: Array[Dictionary] = []
	for boon in selected:
		var boon_id: String = str(boon.get("id", ""))
		offers.append({
			"boon_id": boon_id,
			"boon": boon.duplicate(true),
			"tier": _roll_tier(depth, roll_rng),
		})
	return offers

static func tier_weights(depth: int) -> Dictionary:
	var t: float = clampf(float(depth) / 10.0, 0.0, 1.0)
	return {
		"common": 80.0 - 45.0 * t,
		"rare": 18.0 + 15.0 * t,
		"epic": 2.0 + 20.0 * t,
		"legendary": 10.0 * t,
	}

static func _is_offerable(loadout: Variant, boon: Dictionary, depth: int) -> bool:
	var boon_id: String = str(boon.get("id", ""))
	if boon_id.is_empty() or _loadout_has_boon(loadout, boon_id):
		return false
	var kind: String = str(boon.get("kind", ""))
	match kind:
		"move":
			return not str(boon.get("slot", "")).is_empty()
		"passive":
			return true
		"duo":
			return depth >= 3 and loadout != null and loadout.is_duo_eligible(boon)
		"mastery":
			return depth >= 3 and loadout != null and loadout.is_mastery_eligible(boon)
		_:
			return false

static func _is_empty_slot_move(loadout: Variant, boon: Dictionary) -> bool:
	if loadout == null or str(boon.get("kind", "")) != "move":
		return false
	var slot: String = str(boon.get("slot", ""))
	return not slot.is_empty() and not loadout.slots.has(slot)

static func _loadout_has_boon(loadout: Variant, boon_id: String) -> bool:
	if loadout == null:
		return false
	var data: Dictionary = loadout.serialize()
	for identity in (data.get("slots", {}) as Dictionary).values():
		if str((identity as Dictionary).get("boon_id", "")) == boon_id:
			return true
	for key in ["passives", "duos", "masteries"]:
		for identity in data.get(key, []) as Array:
			if typeof(identity) == TYPE_DICTIONARY and str((identity as Dictionary).get("boon_id", "")) == boon_id:
				return true
	return false

static func _pick_from_pool(pool: Array[Dictionary], selected: Array[Dictionary], target_count: int, rng: RandomNumberGenerator) -> void:
	var candidates: Array[Dictionary] = pool.duplicate(true)
	while selected.size() < target_count and not candidates.is_empty():
		var index: int = rng.randi_range(0, candidates.size() - 1)
		selected.append(candidates[index])
		candidates.remove_at(index)

static func _roll_tier(depth: int, rng: RandomNumberGenerator) -> String:
	var weights: Dictionary = tier_weights(depth)
	var total: float = 0.0
	for tier in TIERS:
		total += float(weights.get(tier, 0.0))
	var roll: float = rng.randf() * total
	var cursor: float = 0.0
	for tier in TIERS:
		cursor += float(weights.get(tier, 0.0))
		if roll <= cursor:
			return tier
	return "common"

static func _rng(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	if rng != null:
		return rng
	var generated: RandomNumberGenerator = RandomNumberGenerator.new()
	generated.randomize()
	return generated
