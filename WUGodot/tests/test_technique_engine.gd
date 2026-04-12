extends RefCounted

const DataManagerScript = preload("res://scripts/data_manager.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")

func _make_fighter() -> Variant:
	var fighter: Variant = FighterScript.new()
	fighter.health_max = 100.0
	fighter.health_current = 100.0
	fighter.posture_max = 100.0
	fighter.posture_current = 100.0
	fighter.move_speed = 320.0
	fighter.posture_recovery_rate = 12.0
	fighter.parry_window = 0.15
	fighter.dash_speed = 1100.0
	fighter.air_dash_speed = 950.0
	fighter.dash_cooldown = 0.80
	fighter.rage_max = 100.0
	fighter.rage_current = 0.0
	fighter.dash_duration = 0.22
	fighter.dash_iframe_end = 0.18
	return fighter

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManagerScript.reload_data()

	var fighter: Variant = _make_fighter()
	var engine: Variant = TechniqueEngineScript.new()

	if engine.technique_ids().size() == 0:
		passed += 1
	else:
		failed += 1
		failures.append("engine should start empty")

	engine.add("A6", fighter)
	if engine.has("A6"):
		passed += 1
	else:
		failed += 1
		failures.append("should have A6 after add")

	if engine.technique_ids().size() == 1 and engine.technique_ids()[0] == "A6":
		passed += 1
	else:
		failed += 1
		failures.append("technique_ids should be ['A6']")

	engine.add("A6", fighter)
	if engine.technique_ids().size() == 1:
		passed += 1
	else:
		failed += 1
		failures.append("duplicate add should not increase count")

	engine.remove("A6", fighter)
	if not engine.has("A6") and engine.technique_ids().size() == 0:
		passed += 1
	else:
		failed += 1
		failures.append("should not have A6 after remove")

	engine.add("D1", fighter)
	engine.add("D2", fighter)
	if engine.has("D2") and not engine.has("D1"):
		passed += 1
	else:
		failed += 1
		failures.append("D2 should replace D1 (D-type exclusive)")
	engine.remove("D2", fighter)

	engine.remove("FAKE", fighter)
	if engine.technique_ids().size() == 0:
		passed += 1
	else:
		failed += 1
		failures.append("remove non-existent should be no-op")

	engine.add("B1", fighter)
	engine.set_echo()
	if engine.consume_echo():
		passed += 1
	else:
		failed += 1
		failures.append("consume_echo should return true when active")
	if not engine.consume_echo():
		passed += 1
	else:
		failed += 1
		failures.append("consume_echo should return false after consumed")
	engine.remove("B1", fighter)

	engine.add("B3", fighter)
	engine.on_dash_through()
	if engine.consume_flowing_water():
		passed += 1
	else:
		failed += 1
		failures.append("consume_flowing_water should return true after dash through")
	if not engine.consume_flowing_water():
		passed += 1
	else:
		failed += 1
		failures.append("second consume_flowing_water should be false")
	engine.remove("B3", fighter)

	engine.add("B6", fighter)
	fighter.health_current = 0.0
	if engine.check_lethal_save(fighter):
		passed += 1
	else:
		failed += 1
		failures.append("phoenix should save on first lethal")
	if absf(fighter.health_current - fighter.health_max * 0.2) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("phoenix should heal to 20%% max HP (got %.1f)" % fighter.health_current)
	fighter.health_current = 0.0
	if not engine.check_lethal_save(fighter):
		passed += 1
	else:
		failed += 1
		failures.append("phoenix should not save twice per run")
	engine.remove("B6", fighter)
	fighter.health_current = fighter.health_max

	engine.add("B1", fighter)
	engine.add("B6", fighter)
	engine.set_echo()
	engine.reset_combat_state(fighter)
	if not engine.consume_echo():
		passed += 1
	else:
		failed += 1
		failures.append("reset_combat_state should clear echo")
	fighter.health_current = 0.0
	if not engine.check_lethal_save(fighter):
		passed += 1
	else:
		failed += 1
		failures.append("phoenix_used should persist through reset_combat_state")
	fighter.health_current = fighter.health_max
	engine.remove("B1", fighter)
	engine.remove("B6", fighter)

	engine.add("B4", fighter)
	var base_speed: float = fighter.move_speed
	engine.on_kill(fighter)
	if absf(fighter.move_speed - base_speed) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("on_kill should defer gaze buff, not apply immediately")
	engine.reset_combat_state(fighter)
	engine.update(0.016, fighter)
	if fighter.move_speed > base_speed + 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("first update after on_kill should apply gaze speed bonus")
	engine.update(3.0, fighter)
	if absf(fighter.move_speed - base_speed) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("gaze bonus should expire after 3s (got %.1f, expected %.1f)" % [fighter.move_speed, base_speed])
	engine.remove("B4", fighter)

	var sf: Variant = _make_fighter()
	var se: Variant = TechniqueEngineScript.new()

	se.add("A6", sf)
	if absf(sf.posture_max - 115.0) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("A6 should set posture_max to 115 (got %.1f)" % sf.posture_max)
	se.remove("A6", sf)
	if absf(sf.posture_max - 100.0) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("A6 remove should restore posture_max to 100 (got %.1f)" % sf.posture_max)

	se.add("A7", sf)
	var expected_speed: float = 320.0 * 1.15
	if absf(sf.move_speed - expected_speed) < 0.1:
		passed += 1
	else:
		failed += 1
		failures.append("A7 should set move_speed to %.1f (got %.1f)" % [expected_speed, sf.move_speed])
	se.remove("A7", sf)

	se.add("A12", sf)
	if absf(sf.health_max - 120.0) < 0.01 and absf(sf.health_current - 120.0) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("A12 should set health_max to 120 (got %.1f/%.1f)" % [sf.health_max, sf.health_current])
	se.remove("A12", sf)

	se.add("A9", sf)
	if absf(sf.parry_window - 0.18) < 0.001:
		passed += 1
	else:
		failed += 1
		failures.append("A9 should set parry_window to 0.18 (got %.3f)" % sf.parry_window)
	se.remove("A9", sf)

	se.add("A11", sf)
	if absf(sf.dash_speed - 1375.0) < 0.1 and absf(sf.dash_cooldown - 0.65) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("A11 dash_speed=%.1f (expect 1375) cooldown=%.2f (expect 0.65)" % [sf.dash_speed, sf.dash_cooldown])
	se.remove("A11", sf)

	se.add("A8", sf)
	if absf(sf.posture_recovery_rate - 15.0) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("A8 should set recovery to 15.0 (got %.1f)" % sf.posture_recovery_rate)
	se.remove("A8", sf)

	var df: Variant = _make_fighter()
	var de: Variant = TechniqueEngineScript.new()

	if not de.activate_stance(df):
		passed += 1
	else:
		failed += 1
		failures.append("activate_stance should fail with no D-type")

	de.add("D1", df)
	df.rage_current = 50.0
	if not de.activate_stance(df):
		passed += 1
	else:
		failed += 1
		failures.append("activate_stance should fail without full rage")

	df.rage_current = 100.0
	if de.activate_stance(df):
		passed += 1
	else:
		failed += 1
		failures.append("activate_stance should succeed with full rage")

	if absf(df.rage_current) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("rage should be 0 after stance activation (got %.1f)" % df.rage_current)

	# 0.26 = absolute elapsed end of i-frame phase (DASH_STARTUP_END 0.04 + 0.22s i-frames)
	if absf(df.dash_duration - 0.30) < 0.01 and absf(df.dash_iframe_end - 0.26) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("D1 dash_duration=%.2f (expect 0.30) iframe_end=%.2f (expect 0.26)" % [df.dash_duration, df.dash_iframe_end])

	df.rage_current = 100.0
	if not de.activate_stance(df):
		passed += 1
	else:
		failed += 1
		failures.append("should not activate stance when already active")

	de.deactivate_stance(df)
	if absf(df.dash_duration - 0.22) < 0.01 and absf(df.dash_iframe_end - 0.18) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("deactivate should restore dash params (got %.2f/%.2f)" % [df.dash_duration, df.dash_iframe_end])

	df.rage_current = 100.0
	de.activate_stance(df)
	var broke: bool = de.on_stance_damage(15.0, df)
	if not broke:
		passed += 1
	else:
		failed += 1
		failures.append("15 damage should not break D1 (threshold 20)")
	broke = de.on_stance_damage(6.0, df)
	if broke and not de.is_stance_active():
		passed += 1
	else:
		failed += 1
		failures.append("21 cumulative damage should break D1")
	de.remove("D1", df)

	de.add("D2", df)
	df.rage_current = 100.0
	de.activate_stance(df)
	if de.is_stance_active() and de.active_stance() == "D2":
		passed += 1
	else:
		failed += 1
		failures.append("D2 should be active after activation")
	de.update(15.1, df)
	if not de.is_stance_active():
		passed += 1
	else:
		failed += 1
		failures.append("D2 should deactivate after 15s")
	de.remove("D2", df)

	return {"passed": passed, "failed": failed, "failures": failures}
