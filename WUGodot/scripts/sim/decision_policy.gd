class_name DecisionPolicy
extends RefCounted

func choose(_kind: String, options: Array, _loadout: Variant = null, _run_state: Variant = null) -> int:
	return 0 if not options.is_empty() else -1

static func option_school(option: Variant) -> String:
	if typeof(option) != TYPE_DICTIONARY:
		return ""
	var dict: Dictionary = option as Dictionary
	if dict.has("school"):
		return str(dict.get("school", ""))
	var boon: Dictionary = dict.get("boon", {}) as Dictionary
	return str(boon.get("school", ""))

static func option_boon(option: Variant) -> Dictionary:
	if typeof(option) != TYPE_DICTIONARY:
		return {}
	var dict: Dictionary = option as Dictionary
	return dict.get("boon", {}) as Dictionary

