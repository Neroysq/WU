class_name RandomPolicy
extends DecisionPolicy

func choose(_kind: String, options: Array, _loadout: Variant = null, _run_state: Variant = null) -> int:
	if options.is_empty():
		return -1
	return RngService.stream("decision").randi_range(0, options.size() - 1)
