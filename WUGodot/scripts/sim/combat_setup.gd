class_name CombatSetup
extends RefCounted

const PresentationCollisionScript = preload("res://scripts/visual/presentation_collision.gd")

static func prepare(player: Fighter, node: MapNode, forced_archetype: String = "") -> Dictionary:
	var combat_system: CombatSystem = CombatSystem.new()
	var hit_geometry: Variant = PresentationCollisionScript.new()
	hit_geometry.register_from_manifest_file("hu", "res://assets/animation_manifests/hu.manifest.json")
	combat_system.hit_geometry = hit_geometry

	var enemy: Fighter = EnemyFactory.create_enemy_by_archetype(forced_archetype) if not forced_archetype.is_empty() else EnemyFactory.create_enemy_for_node(node)
	player.reset_for_combat()
	enemy.reset_for_combat()
	hit_geometry.register_fighter(player, "hu")

	player.position = Vector2(360.0, GameConstants.GROUND_Y)
	enemy.position = Vector2(1560.0, GameConstants.GROUND_Y)
	player.facing = 1
	enemy.facing = -1

	return {
		"player": player,
		"enemy": enemy,
		"ai": enemy.ai_brain,
		"boss": enemy.boss_controller,
		"combat_system": combat_system,
		"hit_geometry": hit_geometry,
		"node": node,
	}

