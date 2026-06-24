extends RefCounted

const CombatSystemScript = preload("res://scripts/combat_system.gd")
const EnemyFactoryScript = preload("res://scripts/enemy_factory.gd")
const CombatStepScript = preload("res://scripts/sim/combat_step.gd")
const RecorderScript = preload("res://scripts/sim/combat_event_recorder.gd")

const DT: float = 1.0 / 60.0

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.reload_data()
	RngService.set_run_seed(3301)

	var modern: Dictionary = _modern_ai_block_is_not_parry()
	_count(modern, "modern AI block must not open a parry window", failures)
	if bool(modern.get("passed", false)):
		passed += 1
	else:
		failed += 1

	var resolved: Dictionary = _held_block_resolves_as_block_not_parry()
	_count(resolved, "held-block hit should be blocked, not parried, and damage enemy posture", failures)
	if bool(resolved.get("passed", false)):
		passed += 1
	else:
		failed += 1

	var legacy: Dictionary = _legacy_ai_block_is_not_parry()
	_count(legacy, "legacy AI block must not open a parry window", failures)
	if bool(legacy.get("passed", false)):
		passed += 1
	else:
		failed += 1

	RngService.clear_run_seed()
	return {"passed": passed, "failed": failed, "failures": failures}

func _setup() -> Dictionary:
	var player: Fighter = EnemyFactoryScript.create_player()
	var enemy: Fighter = EnemyFactoryScript.create_enemy_by_archetype("bandit_swordsman")
	enemy.position = Vector2(600.0, GameConstants.GROUND_Y)
	player.position = Vector2(560.0, GameConstants.GROUND_Y)
	player.facing = 1
	enemy.facing = -1
	return {"player": player, "enemy": enemy}

func _modern_ai_block_is_not_parry() -> Dictionary:
	var setup: Dictionary = _setup()
	var player: Fighter = setup["player"] as Fighter
	var enemy: Fighter = setup["enemy"] as Fighter
	var combat_system: CombatSystem = CombatSystemScript.new()
	enemy.ai_brain.block_chance = 1.0
	player.start_light_attack()
	_advance_to_active(combat_system, player, enemy)
	combat_system.update_ai(enemy, player, DT)
	return {
		"passed": enemy.is_blocking and not enemy.is_parrying(),
		"detail": "is_blocking=%s is_parrying=%s" % [str(enemy.is_blocking), str(enemy.is_parrying())],
	}

func _held_block_resolves_as_block_not_parry() -> Dictionary:
	var setup: Dictionary = _setup()
	var player: Fighter = setup["player"] as Fighter
	var enemy: Fighter = setup["enemy"] as Fighter
	var combat_system: CombatSystem = CombatSystemScript.new()
	var recorder: Variant = RecorderScript.new()
	combat_system.event_recorder = recorder
	enemy.is_ai = false
	var posture_before: float = enemy.posture_current
	player.start_light_attack()
	for _frame in range(60):
		enemy.is_blocking = true
		CombatStepScript.advance(combat_system, player, enemy, {}, DT, recorder)
		if not player._attack_state.is_active() and player._attack_cooldown <= 0.0:
			break
	var hit: Dictionary = {}
	for event in recorder.events():
		var data: Dictionary = event as Dictionary
		if str(data.get("type", "")) == "hit" and str(data.get("by", "")) == "player":
			hit = data
			break
	var passed: bool = not hit.is_empty() \
			and bool(hit.get("blocked", false)) \
			and not bool(hit.get("parried", false)) \
			and not player.is_stunned \
			and enemy.posture_current < posture_before
	return {
		"passed": passed,
		"detail": "hit=%s player_stunned=%s posture=%.1f/%.1f" % [str(hit), str(player.is_stunned), enemy.posture_current, posture_before],
	}

func _legacy_ai_block_is_not_parry() -> Dictionary:
	var setup: Dictionary = _setup()
	var player: Fighter = setup["player"] as Fighter
	var enemy: Fighter = setup["enemy"] as Fighter
	var combat_system: CombatSystem = CombatSystemScript.new()
	enemy.ai_brain = null
	player.start_light_attack()
	var ever_blocked: bool = false
	var ever_parried: bool = false
	for _frame in range(240):
		if not player._attack_state.is_active() and player._attack_cooldown <= 0.0:
			player.start_light_attack()
		combat_system.update_player(player, {}, DT, enemy)
		combat_system.update_ai(enemy, player, DT)
		if enemy.is_blocking:
			ever_blocked = true
		if enemy.is_parrying():
			ever_parried = true
	return {
		"passed": ever_blocked and not ever_parried,
		"detail": "ever_blocked=%s ever_parried=%s" % [str(ever_blocked), str(ever_parried)],
	}

func _advance_to_active(combat_system: CombatSystem, player: Fighter, enemy: Fighter) -> void:
	for _frame in range(30):
		if player.is_hit_active():
			return
		combat_system.update_player(player, {}, DT, enemy)

func _count(result: Dictionary, label: String, failures: Array[String]) -> void:
	if bool(result.get("passed", false)):
		return
	failures.append("%s: %s" % [label, str(result.get("detail", result))])
