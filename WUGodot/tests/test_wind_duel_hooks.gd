extends RefCounted

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const EnemyFactoryScript = preload("res://scripts/enemy_factory.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const RecorderScript = preload("res://scripts/sim/combat_event_recorder.gd")
const RegistryScript = preload("res://scripts/techniques/technique_registry.gd")
const TechniqueEffectScript = preload("res://scripts/techniques/technique_effect.gd")
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	var deflect: Variant = RegistryScript.create_effect_from_data({"type": "momentum_deflect", "posture": 18.0, "momentum": 15.0}, "wd#0")
	var d: Dictionary = deflect.on_dash_through(FighterScript.new(), FighterScript.new())
	if float(d.get("posture_damage", 0.0)) == 18.0 and float(d.get("momentum_gain", 0.0)) == 15.0:
		passed += 1
	else:
		failed += 1
		failures.append("momentum_deflect.on_dash_through should return posture/momentum, got %s" % str(d))

	var eng: TechniqueEngine = TechniqueEngineScript.new()
	var player: Fighter = FighterScript.new()
	var enemy: Fighter = FighterScript.new()
	eng.add_effect(RegistryScript.create_effect_from_data({"type": "momentum_deflect", "posture": 18.0, "momentum": 15.0}, "wd#1"), player)
	var res: Dictionary = eng.on_dash_through(player, enemy)
	if float(res.get("posture_damage", 0.0)) == 18.0 and float(res.get("momentum_gain", 0.0)) == 15.0:
		passed += 1
	else:
		failed += 1
		failures.append("engine.on_dash_through should merge deflect result, got %s" % str(res))

	var cs: CombatSystem = CombatSystemScript.new()
	var rec: CombatEventRecorder = RecorderScript.new()
	cs.event_recorder = rec
	var pl: Fighter = EnemyFactoryScript.create_player()
	var en: Fighter = EnemyFactoryScript.create_enemy_by_archetype("bandit_swordsman")
	pl.technique_engine.add_effect(RegistryScript.create_effect_from_data({"type": "momentum_deflect", "posture": 18.0, "momentum": 15.0}, "wd#2"), pl)
	en.position = Vector2(600.0, GameConstants.GROUND_Y)
	pl.position = Vector2(590.0, GameConstants.GROUND_Y)
	pl.facing = 1
	pl.start_dash()
	var guard := 0
	while not pl.is_invulnerable and guard < 40:
		cs.update_player(pl, {}, 1.0 / 240.0, en)
		guard += 1
	en.start_light_attack()
	guard = 0
	while not en.is_hit_active() and guard < 120:
		en._attack_state.advance(1.0 / 240.0)
		guard += 1
	var setup_ok: bool = pl.is_invulnerable and en.is_hit_active()
	var posture0: float = en.posture_current
	for _f in range(8):
		cs.update_player(pl, {}, 1.0 / 240.0, en)
	var cnt := 0
	for event in rec.events():
		if str(event.get("type", "")) == "dash_through":
			cnt += 1
	if setup_ok and cnt == 1 and en.posture_current < posture0:
		passed += 1
	else:
		failed += 1
		failures.append("dash-through should fire ONCE and drop enemy posture (setup_ok=%s events=%d posture=%.1f/%.1f)" % [str(setup_ok), cnt, en.posture_current, posture0])

	var aerial: Variant = RegistryScript.create_effect_from_data({"type": "momentum_aerial", "multiplier": 1.25, "landing_gain": 10.0, "posture_multiplier": 1.5}, "wa#0")
	var ctx_a: Variant = TechniqueEffectScript.HitContext.new()
	ctx_a.attacker = FighterScript.new()
	ctx_a.attacker.is_grounded = false
	ctx_a.hp_damage = 10.0
	ctx_a.posture_damage = 20.0
	aerial.modify_aerial_hit(ctx_a)
	if ctx_a.posture_damage > 20.0:
		passed += 1
	else:
		failed += 1
		failures.append("aerial hit should add posture (got %.1f)" % ctx_a.posture_damage)

	var flurry: Variant = RegistryScript.create_effect_from_data({"type": "momentum_flurry", "threshold": 50.0, "damage": 3.0, "cost": 20.0, "posture_damage": 8.0}, "wf#0")
	var ctx_f: Variant = TechniqueEffectScript.HitContext.new()
	ctx_f.attacker = FighterScript.new()
	ctx_f.attacker.momentum = 60.0
	ctx_f.attack_def = AttackCatalogScript.hu_light()
	ctx_f.posture_damage = 22.0
	flurry.modify_outgoing_hit(ctx_f)
	if ctx_f.posture_damage > 22.0:
		passed += 1
	else:
		failed += 1
		failures.append("flurry above threshold should add main-hit posture (got %.1f)" % ctx_f.posture_damage)

	return {"passed": passed, "failed": failed, "failures": failures}
