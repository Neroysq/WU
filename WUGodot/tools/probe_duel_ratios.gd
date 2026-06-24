extends SceneTree

const CombatSetupScript = preload("res://scripts/sim/combat_setup.gd")
const CombatStepScript = preload("res://scripts/sim/combat_step.gd")

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
	var report: Dictionary = {}
	for archetype in ARCHETYPES:
		report[archetype] = measure(archetype)
	var out_path: String = OUT_DIR.path_join("probe.json")
	_write_json(out_path, report)
	_print_table(report)
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
