class_name SchoolFocusedPolicy
extends DecisionPolicy

var focus_school: String = ""

func _init(school: String = "") -> void:
	focus_school = school

func choose(kind: String, options: Array, loadout: Variant = null, run_state: Variant = null) -> int:
	if options.is_empty():
		return -1
	if focus_school.is_empty():
		for option in options:
			var school: String = DecisionPolicy.option_school(option)
			if not school.is_empty():
				focus_school = school
				break
	var fallback: GreedySynergyPolicy = GreedySynergyPolicy.new()
	var best_idx: int = fallback.choose(kind, options, loadout, run_state)
	for i in range(options.size()):
		if DecisionPolicy.option_school(options[i]) == focus_school:
			return i
	return best_idx

