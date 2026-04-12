extends RefCounted

const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var light: Variant = AttackDefinitionScript.new()
	light.id = "hu_light"
	light.duration = 0.50
	light.windup_end = 0.18
	light.active_end = 0.30
	light.damage = 12.0
	light.posture_damage = 22.0
	light.is_heavy = false
	light.is_perilous = false

	var checks: Array[Array] = [
		[light.phase_at(0.0), AttackDefinitionScript.Phase.WINDUP, "elapsed 0.0 -> WINDUP"],
		[light.phase_at(0.10), AttackDefinitionScript.Phase.WINDUP, "elapsed 0.10 -> WINDUP"],
		[light.phase_at(0.18), AttackDefinitionScript.Phase.ACTIVE, "elapsed 0.18 -> ACTIVE"],
		[light.phase_at(0.25), AttackDefinitionScript.Phase.ACTIVE, "elapsed 0.25 -> ACTIVE"],
		[light.phase_at(0.30), AttackDefinitionScript.Phase.RECOVERY, "elapsed 0.30 -> RECOVERY"],
		[light.phase_at(0.49), AttackDefinitionScript.Phase.RECOVERY, "elapsed 0.49 -> RECOVERY"],
		[light.phase_at(0.50), AttackDefinitionScript.Phase.FINISHED, "elapsed 0.50 -> FINISHED"],
		[light.phase_at(10.0), AttackDefinitionScript.Phase.FINISHED, "elapsed 10.0 -> FINISHED"],
	]
	for check in checks:
		if check[0] == check[1]:
			passed += 1
		else:
			failed += 1
			failures.append("%s (got %d)" % [check[2], int(check[0])])

	var hit_checks: Array[Array] = [
		[light.is_hit_active(0.17), false, "just before active"],
		[light.is_hit_active(0.18), true, "active start inclusive"],
		[light.is_hit_active(0.24), true, "mid active"],
		[light.is_hit_active(0.30), false, "active end exclusive"],
	]
	for check in hit_checks:
		if check[0] == check[1]:
			passed += 1
		else:
			failed += 1
			failures.append("hit_active: %s (got %s)" % [check[2], str(check[0])])

	return {"passed": passed, "failed": failed, "failures": failures}
