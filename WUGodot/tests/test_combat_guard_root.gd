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

	var press: Dictionary = _guard_press_plants_immediately()
	_count(press, "guard press should plant immediately", failures)
	if bool(press.get("passed", false)):
		passed += 1
	else:
		failed += 1

	var held: Dictionary = _held_guard_blocks_input_movement()
	_count(held, "held guard should stay rooted and not walk", failures)
	if bool(held.get("passed", false)):
		passed += 1
	else:
		failed += 1

	var tap: Dictionary = _tap_release_parry_stays_rooted()
	_count(tap, "tap-release parry window should stay rooted", failures)
	if bool(tap.get("passed", false)):
		passed += 1
	else:
		failed += 1

	var knockback: Dictionary = _blocked_hit_knockback_survives_guard_root()
	_count(knockback, "blocked hit knockback should survive guard root", failures)
	if bool(knockback.get("passed", false)):
		passed += 1
	else:
		failed += 1

	var air: Dictionary = _air_block_keeps_air_movement()
	_count(air, "air block should not root horizontal movement", failures)
	if bool(air.get("passed", false)):
		passed += 1
	else:
		failed += 1

	return {"passed": passed, "failed": failed, "failures": failures}

func _guard_press_plants_immediately() -> Dictionary:
	var system: Variant = CombatSystemScript.new()
	var player: Fighter = EnemyFactoryScript.create_player()
	player.velocity.x = 240.0
	var start_x: float = player.position.x
	system.update_player(player, {"move": 1.0, "block_pressed": true, "block_down": true}, DT, null)
	var passed: bool = is_equal_approx(player.position.x, start_x) and is_equal_approx(player.velocity.x, 0.0) and player.current_animation == Fighter.AnimationState.BLOCKING
	return {"passed": passed, "detail": "x=%.3f start=%.3f vx=%.3f anim=%d" % [player.position.x, start_x, player.velocity.x, player.current_animation]}

func _held_guard_blocks_input_movement() -> Dictionary:
	var system: Variant = CombatSystemScript.new()
	var player: Fighter = EnemyFactoryScript.create_player()
	system.update_player(player, {"block_pressed": true, "block_down": true}, DT, null)
	var start_x: float = player.position.x
	var stayed_blocking: bool = true
	for _i in range(8):
		system.update_player(player, {"move": 1.0, "block_down": true}, DT, null)
		stayed_blocking = stayed_blocking and player.current_animation == Fighter.AnimationState.BLOCKING
	var passed: bool = is_equal_approx(player.position.x, start_x) and is_equal_approx(player.velocity.x, 0.0) and stayed_blocking
	return {"passed": passed, "detail": "dx=%.3f vx=%.3f blocking=%s" % [player.position.x - start_x, player.velocity.x, str(stayed_blocking)]}

func _tap_release_parry_stays_rooted() -> Dictionary:
	var system: Variant = CombatSystemScript.new()
	var player: Fighter = EnemyFactoryScript.create_player()
	system.update_player(player, {"move": 1.0, "block_pressed": true, "block_down": false}, DT, null)
	var start_x: float = player.position.x
	var rooted_until_expiry: bool = true
	var no_walk_until_expiry: bool = true
	for _i in range(5):
		if not player.is_parrying():
			break
		system.update_player(player, {"move": 1.0}, DT, null)
		rooted_until_expiry = rooted_until_expiry and is_equal_approx(player.position.x, start_x)
		no_walk_until_expiry = no_walk_until_expiry and player.current_animation != Fighter.AnimationState.WALKING
	while player.is_parrying():
		system.update_player(player, {}, DT, null)
	var resume_x: float = player.position.x
	system.update_player(player, {"move": 1.0}, DT, null)
	var resumed: bool = player.position.x > resume_x and player.current_animation == Fighter.AnimationState.WALKING
	return {
		"passed": rooted_until_expiry and no_walk_until_expiry and resumed,
		"detail": "rooted=%s no_walk=%s resumed=%s dx=%.3f" % [str(rooted_until_expiry), str(no_walk_until_expiry), str(resumed), player.position.x - start_x],
	}

func _blocked_hit_knockback_survives_guard_root() -> Dictionary:
	var system: Variant = CombatSystemScript.new()
	var attacker: Fighter = EnemyFactoryScript.create_player()
	var defender: Fighter = EnemyFactoryScript.create_player()
	attacker.position = Vector2(0.0, GameConstants.GROUND_Y)
	defender.position = Vector2(60.0, GameConstants.GROUND_Y)
	attacker.facing = 1
	defender.facing = -1
	defender.is_blocking = true
	attacker._start_attack_with(AttackCatalogScript.hu_light())
	attacker._attack_state.advance(AttackCatalogScript.hu_light().windup_end + 0.01)
	system.resolve_hits(attacker, defender)
	var after_hit_vx: float = defender.velocity.x
	var before_bleed_x: float = defender.position.x
	system.update_player(defender, {"block_down": true}, DT, attacker)
	var passed: bool = absf(after_hit_vx) > 0.01 and absf(defender.position.x - before_bleed_x) > 0.01 and absf(defender.velocity.x) < absf(after_hit_vx)
	return {"passed": passed, "detail": "hit_vx=%.3f post_vx=%.3f dx=%.3f" % [after_hit_vx, defender.velocity.x, defender.position.x - before_bleed_x]}

func _air_block_keeps_air_movement() -> Dictionary:
	var system: Variant = CombatSystemScript.new()
	var player: Fighter = EnemyFactoryScript.create_player()
	player.is_grounded = false
	player.position.y = GameConstants.GROUND_Y - 40.0
	var start_x: float = player.position.x
	system.update_player(player, {"move": 1.0, "block_pressed": true, "block_down": true}, DT, null)
	var passed: bool = player.position.x > start_x and player.velocity.x > 0.0
	return {"passed": passed, "detail": "dx=%.3f vx=%.3f" % [player.position.x - start_x, player.velocity.x]}

func _count(result: Dictionary, label: String, failures: Array[String]) -> void:
	if bool(result.get("passed", false)):
		return
	failures.append("%s: %s" % [label, str(result.get("detail", result))])
