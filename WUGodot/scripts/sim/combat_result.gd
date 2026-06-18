class_name CombatResult
extends RefCounted

var seed: int = -1
var enemy_archetype: String = ""
var node_id: int = -1
var normal_combat_ordinal: int = -1
var pool_class: String = ""
var ambush_wave: int = 0
var node_type: int = -1
var tier: int = 0
var winner: String = ""
var duration: float = 0.0
var frames: int = 0
var player_hp_before: float = 0.0
var player_hp_after: float = 0.0
var enemy_hp_before: float = 0.0
var enemy_hp_after: float = 0.0
var player_posture_min: float = 0.0
var enemy_posture_min: float = 0.0
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var boon_procs: Dictionary = {}
var status_applications: Dictionary = {}
var timed_out: bool = false

func to_dict() -> Dictionary:
	return {
		"seed": seed,
		"enemy_archetype": enemy_archetype,
		"node_id": node_id,
		"normal_combat_ordinal": normal_combat_ordinal,
		"pool_class": pool_class,
		"ambush_wave": ambush_wave,
		"node_type": node_type,
		"tier": tier,
		"winner": winner,
		"duration": duration,
		"frames": frames,
		"player_hp_before": player_hp_before,
		"player_hp_after": player_hp_after,
		"enemy_hp_before": enemy_hp_before,
		"enemy_hp_after": enemy_hp_after,
		"player_posture_min": player_posture_min,
		"enemy_posture_min": enemy_posture_min,
		"damage_dealt": damage_dealt,
		"damage_taken": damage_taken,
		"boon_procs": boon_procs.duplicate(true),
		"status_applications": status_applications.duplicate(true),
		"timed_out": timed_out,
	}
