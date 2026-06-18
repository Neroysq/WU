class_name ScriptedPlayer
extends PlayerPolicy

var actions: Array[Dictionary] = []
var frame: int = 0

func _init(scripted_actions: Array[Dictionary] = []) -> void:
	actions = scripted_actions.duplicate(true)

func next_input(_player: Fighter, _enemy: Fighter, _world: Dictionary = {}) -> Dictionary:
	var input: Dictionary = PlayerPolicy.neutral_input()
	for action in actions:
		if int(action.get("frame", -1)) != frame:
			continue
		var data: Dictionary = action.get("input", {}) as Dictionary
		for key in data.keys():
			input[key] = data[key]
	frame += 1
	return input

