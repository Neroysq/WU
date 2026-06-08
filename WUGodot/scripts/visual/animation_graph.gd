class_name AnimationGraph
extends RefCounted

var states: Dictionary = {}

static func load_from_file(path: String) -> Variant:
	var graph: Variant = (load("res://scripts/visual/animation_graph.gd") as Script).new()
	if path.is_empty() or not FileAccess.file_exists(path):
		return graph

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return graph

	graph.states = (parsed as Dictionary).get("states", {}) as Dictionary
	return graph

func has_state(name: String) -> bool:
	return states.has(name)

func clip_for(name: String) -> String:
	if states.has(name):
		return str((states[name] as Dictionary).get("clip", "idle"))
	if states.has("IDLE"):
		return str((states["IDLE"] as Dictionary).get("clip", "idle"))
	return "idle"

func enter_for(name: String) -> Dictionary:
	if states.has(name):
		return (states[name] as Dictionary).get("enter", {"mode": "dither", "time": 0.08}) as Dictionary
	return {"mode": "dither", "time": 0.08}

func can_cancel_into(from_state: String, to_state: String) -> bool:
	if not states.has(from_state):
		return false
	var cancels: Dictionary = (states[from_state] as Dictionary).get("cancelInto", {}) as Dictionary
	return cancels.has(to_state)
