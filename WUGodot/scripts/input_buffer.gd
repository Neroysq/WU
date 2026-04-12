class_name InputBuffer
extends RefCounted

var window_seconds: float = 0.15
var _entries: Array[Dictionary] = []

func _init(window: float = 0.15) -> void:
	window_seconds = maxf(window, 0.0)

func clear() -> void:
	_entries.clear()

func record(action: String) -> void:
	for i in range(_entries.size()):
		if str(_entries[i].get("action", "")) == action:
			_entries[i]["age"] = 0.0
			return
	_entries.append({"action": action, "age": 0.0})

func advance(dt: float) -> void:
	for i in range(_entries.size() - 1, -1, -1):
		var age: float = float(_entries[i].get("age", 0.0)) + dt
		if age > window_seconds:
			_entries.remove_at(i)
		else:
			_entries[i]["age"] = age

func has(action: String) -> bool:
	for entry in _entries:
		if str(entry.get("action", "")) == action:
			return true
	return false

func consume(action: String) -> bool:
	for i in range(_entries.size()):
		if str(_entries[i].get("action", "")) == action:
			_entries.remove_at(i)
			return true
	return false

func pending_actions() -> Array[String]:
	var actions: Array[String] = []
	for entry in _entries:
		actions.append(str(entry.get("action", "")))
	return actions
