class_name ScriptedDecisionPolicy
extends DecisionPolicy

var picks: Array[int] = []
var cursor: int = 0

func _init(scripted_picks: Array[int] = []) -> void:
	picks = scripted_picks.duplicate()

func choose(_kind: String, options: Array, _loadout: Variant = null, _run_state: Variant = null) -> int:
	if options.is_empty():
		return -1
	var pick: int = 0
	if cursor < picks.size():
		pick = picks[cursor]
	cursor += 1
	return clampi(pick, 0, options.size() - 1)

