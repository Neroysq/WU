class_name AiBrain
extends RefCounted

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

static var _attack_catalog: Variant = null

var pattern_table: Array[String] = []
var aggression: float = 0.5
var block_chance: float = 0.25
var preferred_range: float = 70.0
var retreat_chance: float = 0.02
var dash_chance: float = 0.05
var teleport_chance: float = 0.0
var _decision_cooldown: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func update_cooldowns(dt: float) -> void:
	if _decision_cooldown > 0.0:
		_decision_cooldown -= dt

func decide(ai: Fighter, target: Fighter) -> Dictionary:
	if ai.is_stunned or ai.is_in_recovery():
		return {"type": "idle"}

	if _decision_cooldown > 0.0:
		return {"type": "idle"}

	var distance: float = target.position.x - ai.position.x
	var abs_distance: float = absf(distance)
	var direction: float = signf(distance)

	# React to the start of an attack during windup, not just active hit frames.
	if target._attack_state.is_active() and abs_distance < preferred_range * 1.5:
		if _rng.randf() < block_chance:
			_decision_cooldown = 0.15
			return {"type": "block"}

	if abs_distance <= preferred_range + ai.half_width + target.half_width:
		if pattern_table.is_empty():
			return {"type": "idle"}

		if _rng.randf() < retreat_chance:
			_decision_cooldown = 0.3
			return {"type": "move", "direction": -direction}

		if ai.can_attack() and _rng.randf() < aggression:
			var attack_id: String = _pick_attack(abs_distance)
			_decision_cooldown = 0.25
			return {"type": "attack", "attack_id": attack_id}

		return {"type": "idle"}

	if abs_distance > preferred_range * 2.5 and _rng.randf() < dash_chance and ai.can_dash():
		_decision_cooldown = 0.2
		return {"type": "dash", "direction": direction}

	return {"type": "move", "direction": direction}

func pick_attack_from_table(table: Array[String], distance: float) -> String:
	if table.is_empty():
		return ""
	var candidates: Array[String] = []
	for atk_id in table:
		var atk: Variant = get_attack_def(atk_id)
		if atk != null and atk.range_units + 30.0 >= distance:
			candidates.append(atk_id)
	if candidates.is_empty():
		candidates = table.duplicate()
	return candidates[_rng.randi_range(0, candidates.size() - 1)]

func _pick_attack(distance: float) -> String:
	return pick_attack_from_table(pattern_table, distance)

func get_attack_def(attack_id: String) -> Variant:
	if _attack_catalog == null:
		_attack_catalog = AttackCatalogScript.new()
	if not _attack_catalog.has_method(attack_id):
		return null
	return _attack_catalog.call(attack_id)

static func from_enemy_data(data: Dictionary) -> Variant:
	var brain: Variant = load("res://scripts/ai_brain.gd").new()
	var raw_table: Variant = data.get("pattern_table", [])
	if typeof(raw_table) == TYPE_ARRAY:
		for entry in (raw_table as Array):
			brain.pattern_table.append(str(entry))
	brain.aggression = float(data.get("aggression", 0.5))
	brain.block_chance = float(data.get("blockChance", 0.25))
	brain.preferred_range = float(data.get("preferredRange", 70.0))
	brain.retreat_chance = float(data.get("retreatChance", 0.02))
	brain.dash_chance = float(data.get("dashChance", 0.05))
	brain.teleport_chance = float(data.get("teleport_chance", 0.0))
	return brain
