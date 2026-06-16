extends RefCounted

const BossControllerScript = preload("res://scripts/boss_controller.gd")

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	DataManager.initialize()

	# Golden values (current live balance - change ONLY via deliberate balance edits).
	var light: Variant = DataManager.get_attack_def("hu_light")
	if light != null and light.id == "hu_light" and is_equal_approx(light.range_units, 362.0) \
			and is_equal_approx(light.duration, 0.5) and not light.is_heavy:
		passed += 1
	else:
		failed += 1
		failures.append("hu_light golden values should load from JSON")

	var grab: Variant = DataManager.get_attack_def("bear_crush_grab")
	if grab != null and grab.is_grab and is_equal_approx(grab.range_units, 273.0):
		passed += 1
	else:
		failed += 1
		failures.append("bear_crush_grab golden values should load from JSON")

	# Fresh instance per call: boss phase 2 mutates duration on fetched defs.
	var a: Variant = DataManager.get_attack_def("bear_swipe")
	a.duration = 999.0
	var b: Variant = DataManager.get_attack_def("bear_swipe")
	if b.duration < 100.0:
		passed += 1
	else:
		failed += 1
		failures.append("get_attack_def must return a fresh instance per call")

	# Unknown id -> null (AiBrain already handles null).
	if DataManager.get_attack_def("nonexistent_attack") == null:
		passed += 1
	else:
		failed += 1
		failures.append("unknown id should return null")

	# Reload path: F5 data refresh must rebuild attacks from JSON instead of keeping
	# mutated in-memory tuning values.
	var original_damage: float = light.damage if light != null else 0.0
	var raw_light: Dictionary = DataManager._attacks["hu_light"] as Dictionary
	raw_light["damage"] = original_damage + 1000.0
	DataManager._attacks["hu_light"] = raw_light
	var edited: Variant = DataManager.get_attack_def("hu_light")
	DataManager.reload_data()
	var reloaded: Variant = DataManager.get_attack_def("hu_light")
	if edited != null and reloaded != null and is_equal_approx(edited.damage, original_damage + 1000.0) \
			and is_equal_approx(reloaded.damage, original_damage):
		passed += 1
	else:
		failed += 1
		failures.append("reload_data should restore attack definitions from JSON")

	# Lazy load: a cold DataManager (cleared store) must still serve wrappers - test
	# modules run in registration order and several call AttackCatalog before this one.
	DataManager._attacks.clear()
	var lazy: Variant = DataManager.get_attack_def("hu_light")
	if lazy != null and is_equal_approx(lazy.range_units, 362.0):
		passed += 1
	else:
		failed += 1
		failures.append("get_attack_def must lazy-load when the store is empty")

	# Validation: shipped JSON must have all required fields and sane timing for EVERY attack.
	var validation_errors: Array[String] = DataManager.validate_attacks()
	if validation_errors.is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("attack data validation errors: %s" % str(validation_errors))

	# Validation catches a typoed field and bad timing ordering.
	DataManager._attacks["bad_attack"] = {
		"duration": 0.5,
		"windup_end": 0.4,
		"active_end": 0.2,
		"damage": 5.0,
		"posture_damage": 5.0,
		"range_unit": 80.0, # typo: range_unit; active < windup
	}
	var bad_errors: Array[String] = DataManager.validate_attacks()
	DataManager._attacks.erase("bad_attack")
	if bad_errors.size() >= 2:
		passed += 1
	else:
		failed += 1
		failures.append("validation should flag missing required field AND timing ordering, got %s" % str(bad_errors))

	# Coverage: every enemy pattern_table id, boss-table id, and technique-override id resolves.
	var all_ids: Array[String] = []
	for enemy_file in ["BanditSwordsman", "BanditSpearman", "WanderingRonin", "SectDisciple", "MaskedAssassin", "IronBear"]:
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/Enemies/%s.json" % enemy_file)) as Dictionary
		for atk_id in parsed.get("pattern_table", []) as Array:
			all_ids.append(str(atk_id))
	var boss: Variant = BossControllerScript.new()
	for atk_id in boss.get_phase_attack_table():
		all_ids.append(str(atk_id))
	for override_id in ["drunken_light", "drunken_heavy", "tiger_light", "tiger_heavy", "mountain_breaker", "bear_roar_aoe"]:
		all_ids.append(override_id)
	var missing: Array[String] = []
	for atk_id in all_ids:
		if DataManager.get_attack_def(atk_id) == null:
			missing.append(atk_id)
	if missing.is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("ids referenced by enemies/boss/overrides missing from Attacks.json: %s" % str(missing))

	# Data-driven AI lookup: an id with NO catalog method must resolve via AiBrain.
	DataManager._attacks["test_only_attack"] = {
		"duration": 0.4,
		"windup_end": 0.1,
		"active_end": 0.2,
		"damage": 5.0,
		"posture_damage": 3.0,
		"range_units": 80.0,
		"knockback_units": 0.0,
	}
	var AiBrainScript: Script = load("res://scripts/ai_brain.gd")
	var brain: Variant = AiBrainScript.new()
	var test_def: Variant = brain.get_attack_def("test_only_attack")
	DataManager._attacks.erase("test_only_attack")
	if test_def != null and is_equal_approx(test_def.range_units, 80.0):
		passed += 1
	else:
		failed += 1
		failures.append("AiBrain should resolve attacks from data, not catalog methods")

	return {"passed": passed, "failed": failed, "failures": failures}
