class_name GreedySynergyPolicy
extends DecisionPolicy

func choose(kind: String, options: Array, loadout: Variant = null, run_state: Variant = null) -> int:
	if options.is_empty():
		return -1
	var best_idx: int = 0
	var best_score: float = -INF
	for i in range(options.size()):
		var score: float = _score(kind, options[i], loadout, run_state)
		if score > best_score:
			best_score = score
			best_idx = i
	return best_idx

func _score(kind: String, option: Variant, loadout: Variant, run_state: Variant) -> float:
	var score: float = 0.0
	var school: String = DecisionPolicy.option_school(option)
	var active: Array = loadout.active_schools() if loadout != null and loadout.has_method("active_schools") else []
	if not school.is_empty() and active.has(school):
		score += 5.0
	var boon: Dictionary = DecisionPolicy.option_boon(option)
	if not boon.is_empty():
		var kind_name: String = str(boon.get("kind", ""))
		if kind_name == "move":
			var slot: String = str(boon.get("slot", ""))
			if loadout != null and not (loadout.slots as Dictionary).has(slot):
				score += 8.0
		elif kind_name == "duo" or kind_name == "mastery":
			score += 12.0
		var tier: String = str((option as Dictionary).get("tier", "common"))
		score += float(BoonLoadout.TIER_ORDER.find(tier))
	if kind == "shop" and typeof(option) == TYPE_DICTIONARY:
		score -= float((option as Dictionary).get("price", 0)) * 0.01
	if run_state != null and not str(run_state.favored_school).is_empty() and school == str(run_state.favored_school):
		score += 4.0
	return score
