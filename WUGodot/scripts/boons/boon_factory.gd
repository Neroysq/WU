class_name BoonFactory
extends RefCounted

const Registry = preload("res://scripts/techniques/technique_registry.gd")
const TIER_ORDER: Array[String] = ["common", "rare", "epic", "legendary"]

static func build_boon_effects(boon: Dictionary, tier: String) -> Array:
	var effects: Array = []
	var kind: String = str(boon.get("kind", ""))
	if kind == "duo" or kind == "mastery":
		var single: Variant = Registry.create_effect_from_data(boon.get("effect", {}) as Dictionary, "%s#0" % str(boon.get("id", "")))
		if single != null:
			effects.append(single)
		return effects

	var tiers: Dictionary = boon.get("tiers", {}) as Dictionary
	var index: int = 0
	for current_tier in TIER_ORDER:
		if not tiers.has(current_tier):
			continue
		var tier_data: Dictionary = tiers[current_tier] as Dictionary
		if tier_data.has("effect"):
			var base_effect: Variant = _make_effect(tier_data.get("effect", {}) as Dictionary, boon, index)
			index += 1
			if base_effect != null:
				effects.append(base_effect)
		var riders: Array = tier_data.get("riders", []) as Array
		for rider in riders:
			if typeof(rider) != TYPE_DICTIONARY:
				continue
			var rider_effect: Variant = _make_effect(rider as Dictionary, boon, index)
			index += 1
			if rider_effect != null:
				effects.append(rider_effect)
		if current_tier == tier:
			break
	return effects

static func _make_effect(effect_data: Dictionary, boon: Dictionary, index: int) -> Variant:
	return Registry.create_effect_from_data(effect_data, "%s#%d" % [str(boon.get("id", "")), index])
