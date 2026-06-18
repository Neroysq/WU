class_name DataManager
extends RefCounted

static var _characters: Dictionary = {}
static var _enemies: Dictionary = {}
static var _visual_profiles: Dictionary = {}
static var _game_settings: Dictionary = {}
static var _rewards: Array[Dictionary] = []
static var _techniques: Dictionary = {}
static var _schools: Dictionary = {}
static var _boons: Dictionary = {}
static var _events: Array[Dictionary] = []
static var _attacks: Dictionary = {}

# Required numeric fields: a typo (for example "range_unit") must fail loudly,
# not silently fall back to an AttackDefinition default. Flags stay optional.
const _REQUIRED_ATTACK_FIELDS: Array[String] = [
	"duration",
	"windup_end",
	"active_end",
	"damage",
	"posture_damage",
	"range_units",
	"knockback_units",
]

static func initialize() -> void:
	_load_game_settings()
	_load_attacks()
	_load_techniques()
	_load_schools()
	_load_boons()
	_load_events()
	_load_rewards()
	_load_visual_profiles()
	_load_characters()
	_load_enemies()

static func reload_data() -> void:
	_characters.clear()
	_enemies.clear()
	_visual_profiles.clear()
	_game_settings.clear()
	_rewards.clear()
	_techniques.clear()
	_schools.clear()
	_boons.clear()
	_events.clear()
	_attacks.clear()
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

static func get_visual_profile(profile_id: String) -> Dictionary:
	if _visual_profiles.has(profile_id):
		return (_visual_profiles[profile_id] as Dictionary).duplicate(true)
	return _default_visual_profile()

static func get_rewards() -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	for reward_data in _rewards:
		rewards.append((reward_data as Dictionary).duplicate(true))
	if rewards.is_empty():
		rewards.append(_default_reward_data())
	return rewards

static func get_technique(id: String) -> Dictionary:
	if _techniques.has(id):
		return (_techniques[id] as Dictionary).duplicate(true)
	return {}

static func get_all_techniques() -> Dictionary:
	return _techniques.duplicate(true)

static func get_school(id: String) -> Dictionary:
	if _schools.has(id):
		return (_schools[id] as Dictionary).duplicate(true)
	return {}

static func get_boon(id: String) -> Dictionary:
	if _boons.has(id):
		return (_boons[id] as Dictionary).duplicate(true)
	return {}

static func get_all_boons() -> Dictionary:
	return _boons.duplicate(true)

static func get_boons_for_school(school_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for boon_id in _boons.keys():
		var boon: Dictionary = _boons[boon_id] as Dictionary
		if str(boon.get("school", "")) == school_id:
			result.append(boon.duplicate(true))
	return result

static func get_enemy_archetypes_for_difficulty(difficulty: String) -> Array[String]:
	var result: Array[String] = []
	for key in _enemies.keys():
		var data: Dictionary = _enemies[key] as Dictionary
		if str(data.get("difficulty", "")) == difficulty:
			result.append(str(key))
	return result

static func get_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event_data in _events:
		result.append((event_data as Dictionary).duplicate(true))
	return result

static func get_event_by_id(event_id: String) -> Dictionary:
	for event_data in _events:
		var candidate: Dictionary = event_data as Dictionary
		if str(candidate.get("id", "")) == event_id:
			return candidate.duplicate(true)
	return {}

static func get_random_event(rng: RandomNumberGenerator = null) -> Dictionary:
	if _events.is_empty():
		return {}
	var roll_rng: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		roll_rng.randomize()
	return (_events[roll_rng.randi_range(0, _events.size() - 1)] as Dictionary).duplicate(true)

static func validate_attacks() -> Array[String]:
	var errors: Array[String] = []
	for attack_id in _attacks.keys():
		var raw: Dictionary = _attacks[attack_id] as Dictionary
		for field in _REQUIRED_ATTACK_FIELDS:
			if not raw.has(field):
				errors.append("%s: missing required field '%s'" % [attack_id, field])
		var windup_end: float = float(raw.get("windup_end", 0.0))
		var active_end: float = float(raw.get("active_end", 0.0))
		var duration: float = float(raw.get("duration", 0.0))
		if not (windup_end >= 0.0 and active_end >= windup_end and duration >= active_end):
			errors.append("%s: timing must satisfy 0 <= windup_end <= active_end <= duration (got %s/%s/%s)" % [attack_id, windup_end, active_end, duration])
	return errors

# Fresh AttackDefinition per call: callers (boss phase 2) mutate fetched defs.
# Lazy-loads when the store is cold: in headless tests, several modules call
# AttackCatalog wrappers BEFORE anything runs DataManager.initialize(), and module
# registration order must not decide whether the suite passes. (REQUIRED.)
static func get_attack_def(attack_id: String) -> Variant:
	if _attacks.is_empty():
		_load_attacks()
	if not _attacks.has(attack_id):
		return null
	var raw: Dictionary = _attacks[attack_id] as Dictionary
	var def: Variant = load("res://scripts/attack_definition.gd").new()
	def.id = attack_id
	def.duration = float(raw.get("duration", def.duration))
	def.windup_end = float(raw.get("windup_end", def.windup_end))
	def.active_end = float(raw.get("active_end", def.active_end))
	def.damage = float(raw.get("damage", def.damage))
	def.posture_damage = float(raw.get("posture_damage", def.posture_damage))
	def.is_heavy = bool(raw.get("is_heavy", def.is_heavy))
	def.is_perilous = bool(raw.get("is_perilous", def.is_perilous))
	def.is_parryable = bool(raw.get("is_parryable", def.is_parryable))
	def.range_units = float(raw.get("range_units", def.range_units))
	def.knockback_units = float(raw.get("knockback_units", def.knockback_units))
	def.ignores_block = bool(raw.get("ignores_block", def.ignores_block))
	def.is_grab = bool(raw.get("is_grab", def.is_grab))
	def.forward_lunge = float(raw.get("forward_lunge", def.forward_lunge))
	return def

static func _load_attacks() -> void:
	_attacks.clear()
	var path := "res://data/Attacks/Attacks.json"
	if not FileAccess.file_exists(path):
		push_error("DataManager: missing %s" % path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DataManager: %s did not parse" % path)
		return
	_attacks = (parsed as Dictionary).get("attacks", {}) as Dictionary
	for err in validate_attacks():
		push_error("DataManager: %s" % err)

static func _load_techniques() -> void:
	var dir: DirAccess = DirAccess.open("res://data/Techniques")
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

		var root: Dictionary = _load_json_file("res://data/Techniques/%s" % file_name)
		var raw_techniques: Array = []
		if typeof(root.get("techniques", [])) == TYPE_ARRAY:
			raw_techniques = root.get("techniques", []) as Array

		for entry in raw_techniques:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var tech_id: String = str((entry as Dictionary).get("id", ""))
			if tech_id.is_empty():
				continue
			_techniques[tech_id] = (entry as Dictionary).duplicate(true)
	dir.list_dir_end()

static func _load_schools() -> void:
	var root: Dictionary = _load_json_file("res://data/Schools/Schools.json")
	var raw_schools: Array = []
	if typeof(root.get("schools", [])) == TYPE_ARRAY:
		raw_schools = root.get("schools", []) as Array
	for entry in raw_schools:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var school_id: String = str((entry as Dictionary).get("id", ""))
		if school_id.is_empty():
			continue
		_schools[school_id] = (entry as Dictionary).duplicate(true)

static func _load_boons() -> void:
	var root: Dictionary = _load_json_file("res://data/Boons/Boons.json")
	var raw_boons: Array = []
	if typeof(root.get("boons", [])) == TYPE_ARRAY:
		raw_boons = root.get("boons", []) as Array
	for entry in raw_boons:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var boon_id: String = str((entry as Dictionary).get("id", ""))
		if boon_id.is_empty():
			continue
		_boons[boon_id] = (entry as Dictionary).duplicate(true)

static func _load_events() -> void:
	var dir: DirAccess = DirAccess.open("res://data/Events")
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

		var root: Dictionary = _load_json_file("res://data/Events/%s" % file_name)
		var raw_events: Array = []
		if typeof(root.get("events", [])) == TYPE_ARRAY:
			raw_events = root.get("events", []) as Array

		for entry in raw_events:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var event_id: String = str((entry as Dictionary).get("id", ""))
			if event_id.is_empty():
				continue
			_events.append((entry as Dictionary).duplicate(true))
	dir.list_dir_end()

static func _load_game_settings() -> void:
	var base: Dictionary = _default_game_settings()
	var data: Dictionary = _load_json_file("res://data/Settings/GameSettings.json")
	for key in data.keys():
		base[key] = data[key]
	_game_settings = base

static func _load_rewards() -> void:
	var dir: DirAccess = DirAccess.open("res://data/Rewards")
	if dir == null:
		_rewards.append(_default_reward_data())
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

		var root: Dictionary = _load_json_file("res://data/Rewards/%s" % file_name)
		var raw_rewards: Array = []
		if typeof(root.get("rewards", [])) == TYPE_ARRAY:
			raw_rewards = root.get("rewards", []) as Array

		for reward_entry in raw_rewards:
			if typeof(reward_entry) != TYPE_DICTIONARY:
				continue
			var reward: Dictionary = _default_reward_data()
			for key in (reward_entry as Dictionary).keys():
				reward[key] = (reward_entry as Dictionary)[key]
			if str(reward.get("id", "")).is_empty():
				continue
			_rewards.append(reward)
	dir.list_dir_end()

	if _rewards.is_empty():
		_rewards.append(_default_reward_data())

static func _load_visual_profiles() -> void:
	var dir: DirAccess = DirAccess.open("res://data/VisualProfiles")
	if dir == null:
		var fallback_profile: Dictionary = _default_visual_profile()
		var fallback_id: String = str(fallback_profile.get("id", "default_humanoid"))
		_visual_profiles[fallback_id] = fallback_profile
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

		var root: Dictionary = _load_json_file("res://data/VisualProfiles/%s" % file_name)
		var raw_profiles: Array = []
		if typeof(root.get("profiles", [])) == TYPE_ARRAY:
			raw_profiles = root.get("profiles", []) as Array

		for profile_entry in raw_profiles:
			if typeof(profile_entry) != TYPE_DICTIONARY:
				continue
			var profile: Dictionary = _default_visual_profile()
			for key in (profile_entry as Dictionary).keys():
				profile[key] = (profile_entry as Dictionary)[key]
			var profile_id: String = str(profile.get("id", ""))
			if profile_id.is_empty():
				continue
			_visual_profiles[profile_id] = profile
	dir.list_dir_end()

	if _visual_profiles.is_empty():
		var fallback_profile: Dictionary = _default_visual_profile()
		var fallback_id: String = str(fallback_profile.get("id", "default_humanoid"))
		_visual_profiles[fallback_id] = fallback_profile

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
		var archetype: String = str(enemy_data.get("archetype", enemy_data.get("type", "")))
		if archetype.is_empty():
			continue
		var normalized: Dictionary = _default_enemy_data()
		for key in enemy_data.keys():
			normalized[key] = enemy_data[key]
		normalized["colorBody"] = _parse_color(normalized.get("colorBody", "#FF7878"), Color8(255, 120, 120))
		normalized["colorAccent"] = _parse_color(normalized.get("colorAccent", "#D23C3C"), Color8(210, 60, 60))
		_enemies[archetype] = normalized
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
		"visualProfile": "player_humanoid",
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
		"visualProfile": "enemy_humanoid_basic",
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
		"attackActiveStart": 0.20,
		"attackActiveEnd": 0.34,
		"telegraphDuration": 0.45,
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
		"selectedCharacter": "Hu",
		"viewWidth": 1920,
		"viewHeight": 1080,
		"targetFPS": 60,
		"groundY": 940.0,
		"worldBoundsLeft": 80.0,
		"worldBoundsRight": 1840.0,
		"defaultPostureRecoveryRate": 12.0,
		"parryWindow": 0.12,
		"stunDuration": 0.7,
		"groundMoveControl": 0.25,
		"airMoveControl": 0.12,
		"attackMoveControlMultiplier": 2.0,
		"blockHealthMultiplier": 0.2,
		"blockPostureMultiplier": 1.6,
		"parryPostureDamage": 55.0,
		"parryStunDuration": 0.6,
		"cameraShakeDecay": 20.0,
		"timeScaleRecovery": 0.08,
		"maxParticles": 100,
		"damageNumberLifetime": 1.0,
		"damageNumberSpeed": 60.0,
		"damageNumberGravity": 120.0,
	}

static func _default_visual_profile() -> Dictionary:
	return {
		"id": "default_humanoid",
		"animationSet": "res://assets/animations/character_humanoid.json",
		"scale": 2.2,
		"yOffset": 0.0
	}

static func _default_reward_data() -> Dictionary:
	return {
		"id": "atk_up",
		"label": "+4 Attack Damage",
		"effect": "attack_damage",
		"amount": 4.0
	}
