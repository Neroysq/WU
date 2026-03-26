class_name EnemyFactory
extends RefCounted

static func create_enemy_for_node(node: MapNode) -> Fighter:
	var enemy_type: String = "Basic"
	match node.node_type:
		MapNode.NodeType.BATTLE:
			enemy_type = "Basic"
		MapNode.NodeType.ELITE:
			enemy_type = "Elite"
		MapNode.NodeType.BOSS:
			enemy_type = "Boss"
		_:
			enemy_type = "Basic"

	var enemy_data: Dictionary = DataManager.get_enemy(enemy_type)
	var settings: Dictionary = DataManager.get_game_settings()

	var enemy: Fighter = Fighter.new()
	enemy.name = str(enemy_data.get("name", "Enemy"))
	enemy.visual_profile_id = str(enemy_data.get("visualProfile", "enemy_humanoid_basic"))
	enemy.position = Vector2(float(settings.get("viewWidth", 1920)) - 360.0, float(settings.get("groundY", 940.0)))
	enemy.facing = -1
	enemy.color_body = enemy_data.get("colorBody", Color8(255, 120, 120)) as Color
	enemy.color_accent = enemy_data.get("colorAccent", Color8(210, 60, 60)) as Color
	enemy.is_ai = true
	enemy.health_max = float(enemy_data.get("healthMax", 90.0))
	enemy.health_current = enemy.health_max
	enemy.posture_max = float(enemy_data.get("postureMax", 100.0))
	enemy.posture_current = enemy.posture_max
	enemy.posture_recovery_rate = float(enemy_data.get("postureRecoveryRate", settings.get("defaultPostureRecoveryRate", 12.0)))
	enemy.attack_damage = float(enemy_data.get("attackDamage", 10.0))
	enemy.attack_posture_damage = float(enemy_data.get("attackPostureDamage", 24.0))
	enemy.attack_range = float(enemy_data.get("attackRange", 68.0))
	enemy.move_speed = float(enemy_data.get("moveSpeed", 380.0))
	enemy.jump_force = float(enemy_data.get("jumpForce", 700.0))
	enemy.gravity = float(enemy_data.get("gravity", 2800.0))
	enemy.half_width = float(enemy_data.get("halfWidth", 22.0))
	enemy.height = float(enemy_data.get("height", 88.0))
	enemy.attack_duration = float(enemy_data.get("attackDuration", 0.40))
	enemy.attack_active_start = float(enemy_data.get("attackActiveStart", 0.20))
	enemy.attack_active_end = float(enemy_data.get("attackActiveEnd", 0.34))
	enemy.telegraph_duration = float(enemy_data.get("telegraphDuration", 0.45))
	enemy.parry_window = float(settings.get("parryWindow", 0.12))
	enemy.stun_duration = float(settings.get("stunDuration", 0.7))
	enemy.controls = Fighter.none_controls()
	return enemy

static func create_player(character_name: String = "") -> Fighter:
	var settings: Dictionary = DataManager.get_game_settings()
	var selected_character: String = character_name
	if selected_character.is_empty():
		selected_character = str(settings.get("selectedCharacter", "Hu"))
	var character_data: Dictionary = DataManager.get_character(selected_character)

	var player: Fighter = Fighter.new()
	player.name = str(character_data.get("name", selected_character))
	player.visual_profile_id = str(character_data.get("visualProfile", "player_humanoid"))
	player.position = Vector2(360.0, float(settings.get("groundY", 940.0)))
	player.facing = 1
	player.color_body = character_data.get("colorBody", Color8(110, 185, 255)) as Color
	player.color_accent = character_data.get("colorAccent", Color8(60, 120, 210)) as Color
	player.controls = Fighter.player_controls()
	player.is_ai = false

	player.health_max = float(character_data.get("healthMax", 100.0))
	player.health_current = player.health_max
	player.posture_max = float(character_data.get("postureMax", 100.0))
	player.posture_current = player.posture_max
	player.rage_max = float(character_data.get("rageMax", 100.0))
	player.rage_current = 0.0
	player.posture_recovery_rate = float(character_data.get("postureRecoveryRate", settings.get("defaultPostureRecoveryRate", 12.0)))

	player.attack_damage = float(character_data.get("attackDamage", 12.0))
	player.attack_posture_damage = float(character_data.get("attackPostureDamage", 22.0))
	player.attack_range = float(character_data.get("attackRange", 72.0))
	player.move_speed = float(character_data.get("moveSpeed", 420.0))
	player.jump_force = float(character_data.get("jumpForce", 750.0))
	player.gravity = float(character_data.get("gravity", 2800.0))
	player.half_width = float(character_data.get("halfWidth", 22.0))
	player.height = float(character_data.get("height", 88.0))
	player.attack_duration = float(character_data.get("attackDuration", 0.35))
	player.attack_active_start = float(character_data.get("attackActiveStart", 0.10))
	player.attack_active_end = float(character_data.get("attackActiveEnd", 0.18))
	player.dash_duration = float(character_data.get("dashDuration", 0.16))
	player.dash_cooldown = float(character_data.get("dashCooldown", 0.60))
	player.dash_speed = float(character_data.get("dashSpeed", 1100.0))
	player.air_dash_speed = float(character_data.get("airDashSpeed", 950.0))
	player.parry_window = float(character_data.get("parryWindow", 0.12))
	player.stun_duration = float(character_data.get("stunDuration", 0.7))
	player.combo_window_duration = float(character_data.get("comboWindow", 0.5))
	return player
