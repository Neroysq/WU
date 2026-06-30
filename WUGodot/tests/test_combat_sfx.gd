extends RefCounted

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const EnemyFactoryScript = preload("res://scripts/enemy_factory.gd")

const DT: float = 1.0 / 60.0

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.reload_data()
	RngService.set_run_seed(4812)

	var movement: Dictionary = _movement_sfx()
	_count(movement, "movement sfx should fire only on successful transitions", failures)
	if bool(movement.get("passed", false)):
		passed += 1
	else:
		failed += 1

	var attacks: Dictionary = _attack_start_sfx()
	_count(attacks, "attack-start sfx should fire only when an attack starts", failures)
	if bool(attacks.get("passed", false)):
		passed += 1
	else:
		failed += 1

	var parry: Dictionary = _parry_sfx()
	_count(parry, "parry should emit only parry collision sfx", failures)
	if bool(parry.get("passed", false)):
		passed += 1
	else:
		failed += 1

	var block: Dictionary = _block_sfx()
	_count(block, "block should emit block without hit/hurt sfx", failures)
	if bool(block.get("passed", false)):
		passed += 1
	else:
		failed += 1

	var clean: Dictionary = _clean_hit_sfx()
	_count(clean, "clean weapon hit should emit hit and hurt sfx", failures)
	if bool(clean.get("passed", false)):
		passed += 1
	else:
		failed += 1

	var heavy: Dictionary = _heavy_hit_sfx()
	_count(heavy, "heavy weapon hit should emit hit_heavy", failures)
	if bool(heavy.get("passed", false)):
		passed += 1
	else:
		failed += 1

	var posture: Dictionary = _posture_break_sfx()
	_count(posture, "posture break should emit posture_break", failures)
	if bool(posture.get("passed", false)):
		passed += 1
	else:
		failed += 1

	var enemy_start: Dictionary = _enemy_attack_start_sfx()
	_count(enemy_start, "enemy attack start should emit telegraph and swing", failures)
	if bool(enemy_start.get("passed", false)):
		passed += 1
	else:
		failed += 1

	RngService.clear_run_seed()
	return {"passed": passed, "failed": failed, "failures": failures}

func _movement_sfx() -> Dictionary:
	var system: Variant = CombatSystemScript.new()
	var log: Array[String] = _capture(system)

	var player: Fighter = EnemyFactoryScript.create_player()
	system.update_player(player, {"jump_pressed": true}, DT, null)
	system.update_player(player, {"jump_pressed": true}, DT, null)

	player = EnemyFactoryScript.create_player()
	system.update_player(player, {"dash_pressed": true}, DT, null)
	system.update_player(player, {"dash_pressed": true}, DT, null)

	player = EnemyFactoryScript.create_player()
	player.position = Vector2(0.0, GameConstants.GROUND_Y - 4.0)
	player.velocity = Vector2(0.0, 300.0)
	player.is_grounded = false
	system.update_player(player, {}, 0.1, null)

	var passed: bool = _occurrences(log, "jump") == 1 and _occurrences(log, "dash") == 1 and _occurrences(log, "land") == 1
	return {"passed": passed, "detail": str(log)}

func _attack_start_sfx() -> Dictionary:
	var system: Variant = CombatSystemScript.new()
	var log: Array[String] = _capture(system)
	var player: Fighter = EnemyFactoryScript.create_player()
	system.update_player(player, {"light_pressed": true}, DT, null)
	system.update_player(player, {"light_pressed": true}, DT, null)
	var passed: bool = _occurrences(log, "swing") == 1
	return {"passed": passed, "detail": str(log)}

func _parry_sfx() -> Dictionary:
	var system: Variant = CombatSystemScript.new()
	var log: Array[String] = _capture(system)
	var pair: Dictionary = _pair()
	var attacker: Fighter = pair["attacker"] as Fighter
	var defender: Fighter = pair["defender"] as Fighter
	defender.trigger_parry_window()
	_strike(system, attacker, defender, AttackCatalogScript.hu_light())
	var passed: bool = log.has("parry") and not log.has("hit_light") and not log.has("hurt") and not log.has("block")
	return {"passed": passed, "detail": str(log)}

func _block_sfx() -> Dictionary:
	var system: Variant = CombatSystemScript.new()
	var log: Array[String] = _capture(system)
	var pair: Dictionary = _pair()
	var attacker: Fighter = pair["attacker"] as Fighter
	var defender: Fighter = pair["defender"] as Fighter
	defender.is_blocking = true
	_strike(system, attacker, defender, AttackCatalogScript.hu_light())
	var passed: bool = log.has("block") and not log.has("hit_light") and not log.has("hurt")
	return {"passed": passed, "detail": str(log)}

func _clean_hit_sfx() -> Dictionary:
	var system: Variant = CombatSystemScript.new()
	var log: Array[String] = _capture(system)
	var pair: Dictionary = _pair()
	_strike(system, pair["attacker"] as Fighter, pair["defender"] as Fighter, AttackCatalogScript.hu_light())
	var passed: bool = log.has("hit_light") and log.has("hurt") and not log.has("block")
	return {"passed": passed, "detail": str(log)}

func _heavy_hit_sfx() -> Dictionary:
	var system: Variant = CombatSystemScript.new()
	var log: Array[String] = _capture(system)
	var pair: Dictionary = _pair()
	_strike(system, pair["attacker"] as Fighter, pair["defender"] as Fighter, AttackCatalogScript.hu_heavy())
	var passed: bool = log.has("hit_heavy") and not log.has("hit_light")
	return {"passed": passed, "detail": str(log)}

func _posture_break_sfx() -> Dictionary:
	var system: Variant = CombatSystemScript.new()
	var log: Array[String] = _capture(system)
	var pair: Dictionary = _pair()
	var attacker: Fighter = pair["attacker"] as Fighter
	var defender: Fighter = pair["defender"] as Fighter
	system.apply_posture_break_aware(attacker, defender, defender.posture_current + 1.0)
	return {"passed": log.has("posture_break"), "detail": str(log)}

func _enemy_attack_start_sfx() -> Dictionary:
	var system: Variant = CombatSystemScript.new()
	var log: Array[String] = _capture(system)
	var enemy: Fighter = EnemyFactoryScript.create_enemy_by_archetype("bandit_swordsman")
	var player: Fighter = EnemyFactoryScript.create_player()
	enemy.position = Vector2(80.0, GameConstants.GROUND_Y)
	player.position = Vector2(0.0, GameConstants.GROUND_Y)
	enemy.facing = -1
	player.facing = 1
	system._execute_ai_action(enemy, player, {"type": "attack", "attack_id": "bandit_slash"}, DT, -1.0)
	var passed: bool = log.has("enemy_telegraph") and log.has("swing")
	return {"passed": passed, "detail": str(log)}

func _pair() -> Dictionary:
	var attacker: Fighter = EnemyFactoryScript.create_player()
	var defender: Fighter = EnemyFactoryScript.create_player()
	attacker.position = Vector2(0.0, GameConstants.GROUND_Y)
	defender.position = Vector2(60.0, GameConstants.GROUND_Y)
	attacker.facing = 1
	defender.facing = -1
	return {"attacker": attacker, "defender": defender}

func _strike(system: Variant, attacker: Fighter, defender: Fighter, attack: Variant) -> void:
	attacker._start_attack_with(attack)
	attacker._attack_state.advance(attack.windup_end + 0.01)
	system.resolve_hits(attacker, defender)

func _capture(system: Variant) -> Array[String]:
	var log: Array[String] = []
	system.sfx.connect(func(id: String) -> void: log.append(id))
	return log

func _occurrences(log: Array[String], id: String) -> int:
	var count: int = 0
	for item in log:
		if item == id:
			count += 1
	return count

func _count(result: Dictionary, label: String, failures: Array[String]) -> void:
	if bool(result.get("passed", false)):
		return
	failures.append("%s: %s" % [label, str(result.get("detail", result))])
