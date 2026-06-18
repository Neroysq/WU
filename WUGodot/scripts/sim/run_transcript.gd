class_name RunTranscript
extends RefCounted

var seed: int = -1
var player_policy: String = ""
var decision_policy: String = ""
var outcome: String = ""
var depth_reached: int = 0
var death: Dictionary = {}
var gold: int = 0
var insight: int = 0
var nodes: Array[Dictionary] = []
var combats: Array[Dictionary] = []
var build_snapshots: Array[Dictionary] = []
var totals: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"seed": seed,
		"policies": {
			"player": player_policy,
			"decision": decision_policy,
		},
		"outcome": outcome,
		"depth_reached": depth_reached,
		"death": death.duplicate(true),
		"gold": gold,
		"insight": insight,
		"nodes": nodes.duplicate(true),
		"combats": combats.duplicate(true),
		"build_snapshots": build_snapshots.duplicate(true),
		"totals": totals.duplicate(true),
	}

