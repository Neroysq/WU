class_name CombatSetup
extends RefCounted

const PresentationCollisionScript = preload("res://scripts/visual/presentation_collision.gd")

static func prepare(player: Fighter, node: MapNode, forced_archetype: String = "", encounter_context: Dictionary = {}) -> Dictionary:
	var combat_system: CombatSystem = CombatSystem.new()
	var hit_geometry: Variant = PresentationCollisionScript.new()
	hit_geometry.register_from_manifest_file("hu", "res://assets/animation_manifests/hu.manifest.json")
	combat_system.hit_geometry = hit_geometry

	var enemy: Fighter = EnemyFactory.create_enemy_by_archetype(forced_archetype) if not forced_archetype.is_empty() else EnemyFactory.create_enemy_for_node(node)
	player.reset_for_combat()
	enemy.reset_for_combat()
	_apply_encounter_modifiers(enemy, encounter_context)
	hit_geometry.register_fighter(player, "hu")

	player.position = Vector2(1560.0, GameConstants.GROUND_Y)
	enemy.position = Vector2(360.0, GameConstants.GROUND_Y)
	player.facing = -1
	enemy.facing = 1

	return {
		"player": player,
		"enemy": enemy,
		"ai": enemy.ai_brain,
		"boss": enemy.boss_controller,
		"combat_system": combat_system,
		"hit_geometry": hit_geometry,
		"node": node,
	}

static func _apply_encounter_modifiers(enemy: Fighter, encounter_context: Dictionary) -> void:
	if enemy == null:
		return
	var pool_class: String = str(encounter_context.get("pool_class", ""))
	if pool_class.is_empty():
		return
	var curve: Dictionary = DataManager.get_difficulty_curve(1)
	var pressure_by_pool: Dictionary = curve.get("pressure_by_pool_class", {}) as Dictionary
	if pressure_by_pool.has(pool_class):
		enemy.incoming_pressure_mult = maxf(0.0, float(pressure_by_pool[pool_class]))
	var block_by_pool: Dictionary = curve.get("block_chance_by_pool_class", {}) as Dictionary
	if enemy.ai_brain != null and block_by_pool.has(pool_class):
		enemy.ai_brain.block_chance = clampf(float(block_by_pool[pool_class]), 0.0, 1.0)
	var aggression_by_pool: Dictionary = curve.get("aggression_by_pool_class", {}) as Dictionary
	if enemy.ai_brain != null and aggression_by_pool.has(pool_class):
		enemy.ai_brain.aggression = clampf(float(aggression_by_pool[pool_class]), 0.0, 1.0)
