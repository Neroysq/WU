class_name PlayerPolicy
extends RefCounted

const INPUT_KEYS: Array[String] = [
	"move",
	"jump_pressed",
	"dash_pressed",
	"light_pressed",
	"heavy_pressed",
	"block_pressed",
	"block_down",
	"stance_pressed",
	"attack_holding",
	"attack_hold_duration",
]

func next_input(_player: Fighter, _enemy: Fighter, _world: Dictionary = {}) -> Dictionary:
	return neutral_input()

static func neutral_input() -> Dictionary:
	return {
		"move": 0.0,
		"jump_pressed": false,
		"dash_pressed": false,
		"light_pressed": false,
		"heavy_pressed": false,
		"block_pressed": false,
		"block_down": false,
		"stance_pressed": false,
		"attack_holding": false,
		"attack_hold_duration": 0.0,
	}

static func has_exact_input_keys(input: Dictionary) -> bool:
	if input.size() != INPUT_KEYS.size():
		return false
	for key in INPUT_KEYS:
		if not input.has(key):
			return false
	return true

