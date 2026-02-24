class_name DataManager
extends RefCounted

static var _characters: Dictionary = {}
static var _enemies: Dictionary = {}
static var _game_settings: Dictionary = {}

static func initialize() -> void:
	_load_game_settings()
	_load_characters()
	_load_enemies()

static func reload_data() -> void:
	_characters.clear()
	_enemies.clear()
	_game_settings.clear()
	initialize()

static func get_character(name: String) -> Dictionary:
	if _characters.has(name):
		return (_characters[name] as Dictionary).duplicate(true)
	return _default_character_data()

static func get_enemy(enemy_type: String) -> Dictionary:
	if _enemies.has(enemy_type):
		return (_enemies[enemy_type] as Dictionary).duplicate(true)
	return _default_enemy_data()

static func get_game_settings() -> Dictionary:
	if _game_settings.is_empty():
		return _default_game_settings()
	return _game_settings.duplicate(true)

static func _load_game_settings() -> void:
	var base: Dictionary = _default_game_settings()
	var data: Dictionary = _load_json_file("res://data/Settings/GameSettings.json")
	for key in data.keys():
		base[key] = data[key]
	_game_settings = base

static func _load_characters() -> void:
	var dir: DirAccess = DirAccess.open("res://data/Characters")
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if file_name.get_extension().to_lower() != "json":
			continue
		var character_data: Dictionary = _load_json_file("res://data/Characters/%s" % file_name)
		if not character_data.has("name"):
			continue
		var normalized: Dictionary = _default_character_data()
		for key in character_data.keys():
			normalized[key] = character_data[key]
		normalized["colorBody"] = _parse_color(normalized.get("colorBody", "#6EB9FF"), Color8(110, 185, 255))
		normalized["colorAccent"] = _parse_color(normalized.get("colorAccent", "#3C78D2"), Color8(60, 120, 210))
		_characters[str(normalized["name"])] = normalized
	dir.list_dir_end()

static func _load_enemies() -> void:
	var dir: DirAccess = DirAccess.open("res://data/Enemies")
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if file_name.get_extension().to_lower() != "json":
			continue
		var enemy_data: Dictionary = _load_json_file("res://data/Enemies/%s" % file_name)
		if not enemy_data.has("type"):
			continue
		var normalized: Dictionary = _default_enemy_data()
		for key in enemy_data.keys():
			normalized[key] = enemy_data[key]
		normalized["colorBody"] = _parse_color(normalized.get("colorBody", "#FF7878"), Color8(255, 120, 120))
		normalized["colorAccent"] = _parse_color(normalized.get("colorAccent", "#D23C3C"), Color8(210, 60, 60))
		_enemies[str(normalized["type"])] = normalized
	dir.list_dir_end()

static func _load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	return {}

static func _parse_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if typeof(value) != TYPE_STRING:
		return fallback
	var hex: String = (value as String).strip_edges()
	if hex.begins_with("#"):
		hex = hex.substr(1)
	if hex.length() != 6:
		return fallback
	var r: int = hex.substr(0, 2).hex_to_int()
	var g: int = hex.substr(2, 2).hex_to_int()
	var b: int = hex.substr(4, 2).hex_to_int()
	return Color8(r, g, b)

static func _default_character_data() -> Dictionary:
	return {
		"name": "Default",
		"description": "Default character",
		"moveSpeed": 420.0,
		"jumpForce": 750.0,
		"gravity": 2800.0,
		"dashSpeed": 1100.0,
		"airDashSpeed": 950.0,
		"healthMax": 100.0,
		"postureMax": 100.0,
		"rageMax": 100.0,
		"postureRecoveryRate": 12.0,
		"attackDamage": 12.0,
		"attackPostureDamage": 22.0,
		"attackRange": 72.0,
		"attackDuration": 0.35,
		"attackActiveStart": 0.10,
		"attackActiveEnd": 0.18,
		"dashDuration": 0.16,
		"dashCooldown": 0.60,
		"parryWindow": 0.12,
		"stunDuration": 0.7,
		"comboWindow": 0.5,
		"colorBody": Color8(110, 185, 255),
		"colorAccent": Color8(60, 120, 210),
		"halfWidth": 22.0,
		"height": 88.0,
	}

static func _default_enemy_data() -> Dictionary:
	return {
		"type": "Basic",
		"name": "Enemy",
		"description": "Default enemy",
		"moveSpeed": 380.0,
		"jumpForce": 700.0,
		"gravity": 2800.0,
		"healthMax": 90.0,
		"postureMax": 100.0,
		"postureRecoveryRate": 10.0,
		"attackDamage": 10.0,
		"attackPostureDamage": 24.0,
		"attackRange": 68.0,
		"attackDuration": 0.40,
		"telegraphDuration": 0.35,
		"aggressionLevel": 0.5,
		"reactionTime": 0.3,
		"attackCooldown": 1.2,
		"blockChance": 0.25,
		"dodgeChance": 0.15,
		"colorBody": Color8(255, 120, 120),
		"colorAccent": Color8(210, 60, 60),
		"halfWidth": 22.0,
		"height": 88.0,
	}

static func _default_game_settings() -> Dictionary:
	return {
		"viewWidth": 1280,
		"viewHeight": 720,
		"targetFPS": 60,
		"groundY": 580.0,
		"worldBoundsLeft": 80.0,
		"worldBoundsRight": 1200.0,
		"defaultPostureRecoveryRate": 12.0,
		"parryWindow": 0.12,
		"stunDuration": 0.7,
		"cameraShakeDecay": 20.0,
		"timeScaleRecovery": 0.08,
		"maxParticles": 100,
		"damageNumberLifetime": 1.0,
		"damageNumberSpeed": 60.0,
		"damageNumberGravity": 120.0,
	}
