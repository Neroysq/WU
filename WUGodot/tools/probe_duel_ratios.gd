extends SceneTree

const CombatSetupScript = preload("res://scripts/sim/combat_setup.gd")
const CombatStepScript = preload("res://scripts/sim/combat_step.gd")
const RegistryScript = preload("res://scripts/techniques/technique_registry.gd")
const RecorderScript = preload("res://scripts/sim/combat_event_recorder.gd")

const OUT_DIR: String = "/tmp/duel_ratios"
const DT: float = 1.0 / 60.0
const MAX_SWINGS: int = 300
const MAX_FRAMES_PER_SWING: int = 140
const RECOVER_GAP_FRAMES: int = 48
const ARCHETYPES: Array[String] = [
	"bandit_swordsman",
	"bandit_spearman",
	"wandering_ronin",
	"sect_disciple",
	"masked_assassin",
	"iron_bear",
]

func _init() -> void:
	DataManager.initialize()
	RngService.set_run_seed(240624)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var wind_mode: bool = OS.get_cmdline_user_args().has("--wind")
	var report: Dictionary = {}
	for archetype in ARCHETYPES:
		report[archetype] = measure(archetype)
	if wind_mode:
		report["wind"] = measure_wind("bandit_swordsman")
	var out_path: String = OUT_DIR.path_join("probe.json")
	_write_json(out_path, report)
	_print_table(report)
	if wind_mode:
		_print_wind(report["wind"] as Dictionary)
	print("JSON: %s" % out_path)
	RngService.clear_run_seed()
	quit(0)

static func measure(archetype: String) -> Dictionary:
	var fresh: Dictionary = _fresh(archetype)
	var enemy: Fighter = fresh["enemy"] as Fighter
	var posture_path: Dictionary = _break_then_punish(archetype)
	return {
		"hp_max": enemy.health_max,
		"posture_max": enemy.posture_max,
		"posture_recovery_rate": enemy.posture_recovery_rate,
		"parry_posture_damage": _parry_posture(),
		"hits_to_hp_kill_light": _hits_until(archetype, "hp", false, false),
		"hits_to_posture_break_light": _hits_until(archetype, "posture", false, false),
		"hits_to_posture_break_heavy": _hits_until(archetype, "posture", true, false),
		"blocked_pressure_break_light": _hits_until(archetype, "posture", false, true),
		"parries_to_break": _parries_to_break(archetype),
		"posture_path": posture_path,
		"timeout": bool(posture_path.get("timeout", false)),
	}

static func measure_wind(archetype: String = "bandit_swordsman") -> Dictionary:
	var aerial: Dictionary = _wind_aerial_probe(archetype)
	var flurry: Dictionary = _wind_flurry_probe(archetype)
	var dash: Dictionary = _wind_dash_through_probe(archetype)
	return {
		"archetype": archetype,
		"aerial_posture_damage": float(aerial.get("posture_damage", 0.0)),
		"aerial_hp_damage": float(aerial.get("hp_damage", 0.0)),
		"flurry_posture_damage": float(flurry.get("posture_damage", 0.0)),
		"dash_through_posture_damage": float(dash.get("posture_damage", 0.0)),
		"dash_through_events": int(dash.get("events", 0)),
		"dash_through_momentum": float(dash.get("momentum", 0.0)),
		"timeout": bool(aerial.get("timeout", false)) or bool(flurry.get("timeout", false)) or bool(dash.get("timeout", false)),
	}

static func _parry_posture() -> float:
	return float(DataManager.get_game_settings().get("parryPostureDamage", 50.0))

static func _node() -> MapNode:
	return MapNode.new(9001, 1, MapNode.NodeType.BATTLE, [])

static func _fresh(archetype: String) -> Dictionary:
	var player: Fighter = EnemyFactory.create_player()
	var setup: Dictionary = CombatSetupScript.prepare(player, _node(), archetype)
	var enemy: Fighter = setup["enemy"] as Fighter
	var combat_system: CombatSystem = setup["combat_system"] as CombatSystem
	enemy.is_ai = false
	enemy.ai_brain = null
	_place_pair(player, enemy)
	return {"player": player, "enemy": enemy, "cs": combat_system}

static func _install_wind_effects(player: Fighter) -> void:
	if player.technique_engine == null:
		return
	player.technique_engine.add_effect(RegistryScript.create_effect_from_data({"type": "momentum_deflect", "posture": 28.0, "momentum": 18.0}, "wind_probe#deflect"), player)
	player.technique_engine.add_effect(RegistryScript.create_effect_from_data({"type": "momentum_aerial", "multiplier": 1.25, "landing_gain": 10.0, "posture_multiplier": 2.0}, "wind_probe#aerial"), player)
	player.technique_engine.add_effect(RegistryScript.create_effect_from_data({"type": "momentum_flurry", "threshold": 35.0, "damage": 3.0, "cost": 15.0, "posture_damage": 12.0}, "wind_probe#flurry"), player)

static func _wind_aerial_probe(archetype: String) -> Dictionary:
	var s: Dictionary = _fresh(archetype)
	var player: Fighter = s["player"] as Fighter
	var enemy: Fighter = s["enemy"] as Fighter
	var combat_system: CombatSystem = s["cs"] as CombatSystem
	_install_wind_effects(player)
	_place_pair(player, enemy)
	player.is_grounded = false
	player.position.y = GameConstants.GROUND_Y - 8.0
	var posture_before: float = enemy.posture_current
	var hp_before: float = enemy.health_current
	player.start_light_attack()
	for _f in range(MAX_FRAMES_PER_SWING):
		_place_pair(player, enemy)
		player.is_grounded = false
		player.position.y = GameConstants.GROUND_Y - 8.0
		CombatStepScript.advance(combat_system, player, enemy, {}, DT)
		if enemy.posture_current < posture_before or enemy.health_current < hp_before:
			return {
				"posture_damage": posture_before - enemy.posture_current,
				"hp_damage": hp_before - enemy.health_current,
				"timeout": false,
			}
	return {"posture_damage": 0.0, "hp_damage": 0.0, "timeout": true}

static func _wind_flurry_probe(archetype: String) -> Dictionary:
	var s: Dictionary = _fresh(archetype)
	var player: Fighter = s["player"] as Fighter
	var enemy: Fighter = s["enemy"] as Fighter
	var combat_system: CombatSystem = s["cs"] as CombatSystem
	_install_wind_effects(player)
	player.momentum = 60.0
	_place_pair(player, enemy)
	var posture_before: float = enemy.posture_current
	player.start_light_attack()
	for _f in range(MAX_FRAMES_PER_SWING):
		_place_pair(player, enemy)
		CombatStepScript.advance(combat_system, player, enemy, {}, DT)
		if enemy.posture_current < posture_before:
			return {"posture_damage": posture_before - enemy.posture_current, "timeout": false}
	return {"posture_damage": 0.0, "timeout": true}

static func _wind_dash_through_probe(archetype: String) -> Dictionary:
	var s: Dictionary = _fresh(archetype)
	var player: Fighter = s["player"] as Fighter
	var enemy: Fighter = s["enemy"] as Fighter
	var combat_system: CombatSystem = s["cs"] as CombatSystem
	var recorder: CombatEventRecorder = RecorderScript.new()
	combat_system.event_recorder = recorder
	_install_wind_effects(player)
	enemy.position = Vector2(600.0, GameConstants.GROUND_Y)
	player.position = Vector2(590.0, GameConstants.GROUND_Y)
	player.velocity = Vector2.ZERO
	player.facing = 1
	player.start_dash()
	var guard: int = 0
	while not player.is_invulnerable and guard < 40:
		combat_system.update_player(player, {}, 1.0 / 240.0, enemy)
		guard += 1
	enemy.start_light_attack()
	guard = 0
	while not enemy.is_hit_active() and guard < 120:
		enemy._attack_state.advance(1.0 / 240.0)
		guard += 1
	var posture_before: float = enemy.posture_current
	for _f in range(8):
		combat_system.update_player(player, {}, 1.0 / 240.0, enemy)
	var count: int = 0
	var posture_damage: float = 0.0
	for event in recorder.events():
		if str(event.get("type", "")) == "dash_through":
			count += 1
			posture_damage += float(event.get("posture_damage", 0.0))
	return {
		"posture_damage": posture_damage if posture_damage > 0.0 else posture_before - enemy.posture_current,
		"events": count,
		"momentum": player.momentum,
		"timeout": count <= 0 or enemy.posture_current >= posture_before,
	}

static func _hits_until(archetype: String, field: String, heavy: bool, block: bool) -> Dictionary:
	var s: Dictionary = _fresh(archetype)
	var player: Fighter = s["player"] as Fighter
	var enemy: Fighter = s["enemy"] as Fighter
	var combat_system: CombatSystem = s["cs"] as CombatSystem
	var count: int = 0
	var frames: int = 0
	for _swing in range(MAX_SWINGS):
		_wait_until_can_attack(player, enemy, combat_system, block)
		_place_pair(player, enemy)
		enemy.is_blocking = block
		if heavy:
			player.start_heavy_attack()
		else:
			player.start_light_attack()
		if not player._attack_state.is_active():
			return {"count": -1, "duration": float(frames) * DT, "timeout": true}
		count += 1
		for _f in range(MAX_FRAMES_PER_SWING):
			enemy.is_blocking = block
			_place_pair(player, enemy)
			CombatStepScript.advance(combat_system, player, enemy, {}, DT)
			frames += 1
			if field == "hp":
				if enemy.health_current <= 0.0:
					return {"count": count, "duration": float(frames) * DT, "timeout": false}
				_suppress_posture_break(enemy)
			elif enemy.is_stunned:
				return {"count": count, "duration": float(frames) * DT, "timeout": false}
			if not player._attack_state.is_active() and player._attack_cooldown <= 0.0:
				break
	return {"count": -1, "duration": float(frames) * DT, "timeout": true}

static func _parries_to_break(archetype: String) -> Dictionary:
	var s: Dictionary = _fresh(archetype)
	var enemy: Fighter = s["enemy"] as Fighter
	var count: int = 0
	var frames: int = 0
	for _p in range(40):
		enemy.apply_posture_damage(_parry_posture())
		count += 1
		if enemy.is_stunned:
			return {"count": count, "duration": float(frames) * DT, "timeout": false}
		for _f in range(RECOVER_GAP_FRAMES):
			enemy.update_timers(DT)
			frames += 1
	return {"count": -1, "duration": float(frames) * DT, "timeout": true}

static func _break_then_punish(archetype: String) -> Dictionary:
	var s: Dictionary = _fresh(archetype)
	var player: Fighter = s["player"] as Fighter
	var enemy: Fighter = s["enemy"] as Fighter
	var combat_system: CombatSystem = s["cs"] as CombatSystem
	var swings: int = 0
	var frames: int = 0
	var hits_to_break: int = -1
	var dmg_in_stun: float = 0.0
	for _swing in range(400):
		_wait_until_can_attack(player, enemy, combat_system, false)
		_place_pair(player, enemy)
		if hits_to_break < 0:
			player.start_heavy_attack()
		else:
			player.start_light_attack()
		if not player._attack_state.is_active():
			return {
				"hits_to_break": hits_to_break,
				"dmg_in_stun": dmg_in_stun,
				"swings_to_kill": -1,
				"duration": float(frames) * DT,
				"timeout": true,
			}
		swings += 1
		for _f in range(MAX_FRAMES_PER_SWING):
			_place_pair(player, enemy)
			var hp_before: float = enemy.health_current
			var was_broken: bool = hits_to_break >= 0
			CombatStepScript.advance(combat_system, player, enemy, {}, DT)
			frames += 1
			if was_broken and enemy.is_stunned:
				dmg_in_stun += maxf(0.0, hp_before - enemy.health_current)
			if hits_to_break < 0 and enemy.is_stunned:
				hits_to_break = swings
			if enemy.health_current <= 0.0:
				return {
					"hits_to_break": hits_to_break,
					"dmg_in_stun": dmg_in_stun,
					"swings_to_kill": swings,
					"duration": float(frames) * DT,
					"timeout": false,
				}
			if not player._attack_state.is_active() and player._attack_cooldown <= 0.0:
				break
	return {
		"hits_to_break": hits_to_break,
		"dmg_in_stun": dmg_in_stun,
		"swings_to_kill": -1,
		"duration": float(frames) * DT,
		"timeout": true,
	}

static func _wait_until_can_attack(player: Fighter, enemy: Fighter, combat_system: CombatSystem, block: bool) -> void:
	for _f in range(240):
		if player.can_attack():
			return
		enemy.is_blocking = block
		_place_pair(player, enemy)
		CombatStepScript.advance(combat_system, player, enemy, {}, DT)

static func _place_pair(player: Fighter, enemy: Fighter) -> void:
	player.position = Vector2(560.0, GameConstants.GROUND_Y)
	player.velocity = Vector2.ZERO
	player.is_grounded = true
	player.facing = 1
	enemy.position = Vector2(600.0, GameConstants.GROUND_Y)
	enemy.velocity = Vector2.ZERO
	enemy.is_grounded = true
	enemy.facing = -1

static func _suppress_posture_break(enemy: Fighter) -> void:
	if not enemy.is_stunned:
		return
	enemy.is_stunned = false
	enemy._stun_timer = 0.0
	enemy.posture_current = enemy.posture_max
	if enemy.current_animation == Fighter.AnimationState.STUNNED:
		enemy.current_animation = Fighter.AnimationState.IDLE

func _print_table(report: Dictionary) -> void:
	print("DUEL RATIO PROBE")
	print("archetype,hp,posture,hp_light,break_light,break_heavy,block_break,parry_break,posture_kill,duration,timeout")
	for archetype in ARCHETYPES:
		var m: Dictionary = report[archetype] as Dictionary
		var path: Dictionary = m.get("posture_path", {}) as Dictionary
		print("%s,%.1f,%.1f,%s,%s,%s,%s,%s,%s,%.2f,%s" % [
			archetype,
			float(m.get("hp_max", 0.0)),
			float(m.get("posture_max", 0.0)),
			_metric_count(m.get("hits_to_hp_kill_light", {})),
			_metric_count(m.get("hits_to_posture_break_light", {})),
			_metric_count(m.get("hits_to_posture_break_heavy", {})),
			_metric_count(m.get("blocked_pressure_break_light", {})),
			_metric_count(m.get("parries_to_break", {})),
			str(path.get("swings_to_kill", -1)),
			float(path.get("duration", 0.0)),
			str(_any_timeout(m)),
		])

func _print_wind(wind: Dictionary) -> void:
	print("")
	print("WIND PROBE")
	print("archetype,aerial_posture,flurry_posture,dash_through_posture,dash_through_events,dash_through_momentum,timeout")
	print("%s,%.1f,%.1f,%.1f,%d,%.1f,%s" % [
		str(wind.get("archetype", "")),
		float(wind.get("aerial_posture_damage", 0.0)),
		float(wind.get("flurry_posture_damage", 0.0)),
		float(wind.get("dash_through_posture_damage", 0.0)),
		int(wind.get("dash_through_events", 0)),
		float(wind.get("dash_through_momentum", 0.0)),
		str(wind.get("timeout", false)),
	])

func _metric_count(value: Variant) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var data: Dictionary = value as Dictionary
		return "timeout" if bool(data.get("timeout", false)) else str(data.get("count", -1))
	return str(value)

func _any_timeout(row: Dictionary) -> bool:
	for key in ["hits_to_hp_kill_light", "hits_to_posture_break_light", "hits_to_posture_break_heavy", "blocked_pressure_break_light", "parries_to_break", "posture_path"]:
		if bool((row.get(key, {}) as Dictionary).get("timeout", false)):
			return true
	return false

func _write_json(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("failed to write %s" % path)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()
