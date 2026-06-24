# Per-School Duel Hooks — Wind Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Wind a viable non-parry **mobility-pressure** duel path by retargeting its boons onto posture (aerial/flurry deal posture; dash-through = a "deflect" that pressures the enemy's posture), closing the rebalance's `aggressive_dash` gap (0.08 → ≥0.18).

**Architecture:** Extend the existing technique-effect hooks. The dash-through hook gains the `enemy` and **returns** a result dict that **CombatSystem applies via a shared break-aware helper** (so stun events + posture-break callbacks fire); the call is gated once per dash-through contact. Aerial/flurry effects add `ctx.posture_damage`. Validation is the scripted-policy gate + a Wind probe mode.

**Tech Stack:** Godot 4.6.2 / GDScript. Tests: `./run.sh --test` (`failed: 0`). Harness/probe/daemon as in prior plans.

**Spec:** `docs/superpowers/specs/2026-06-24-per-school-duel-hooks-design.md`

---

## File Structure
**Modify:** `scripts/techniques/technique_effect.gd` (hook sig) · `scripts/technique_engine.gd` (forward+merge) · `scripts/combat_system.gd` (break-aware helper, gated dash-through) · `scripts/techniques/effects/flowing_water_effect.gd` (new sig) · `scripts/techniques/effects/momentum_aerial_effect.gd` (posture) · `scripts/techniques/effects/momentum_flurry_effect.gd` (posture) · `scripts/fighter.gd` (`_dash_through_fired`) · `scripts/sim/combat_event_recorder.gd` (`record_dash_through`) · `scripts/techniques/technique_registry.gd` (register `momentum_deflect`) · `data/Boons/Boons.json` (wind deflect rider) · `tools/probe_duel_ratios.gd` (`--wind`) · `tests/run_tests.gd`.
**Create:** `scripts/techniques/effects/momentum_deflect_effect.gd` · `tests/test_wind_duel_hooks.gd`.

---

## Task 1: Hook signature — `on_dash_through(fighter, enemy) -> Dictionary` + engine merge

**Files:** Modify `technique_effect.gd`, `technique_engine.gd`, `flowing_water_effect.gd`; Test `tests/test_wind_duel_hooks.gd`; Modify `run_tests.gd`.

- [ ] **Step 1: Write the failing test** — create `WUGodot/tests/test_wind_duel_hooks.gd`:

```gdscript
extends RefCounted
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")
const RegistryScript = preload("res://scripts/techniques/technique_registry.gd")
const FighterScript = preload("res://scripts/fighter.gd")

func run_all() -> Dictionary:
	var passed := 0; var failed := 0; var failures: Array[String] = []

	# engine.on_dash_through forwards enemy + merges effect result dicts
	var eng = TechniqueEngineScript.new()
	var deflect = RegistryScript.create_effect_from_data({"type":"momentum_deflect","posture":18.0,"momentum":15.0}, "wd#0")
	var player: Fighter = FighterScript.new(); var enemy: Fighter = FighterScript.new()
	eng.add_effect(deflect, player)
	var res: Dictionary = eng.on_dash_through(player, enemy)
	if float(res.get("posture_damage",0.0)) == 18.0 and float(res.get("momentum_gain",0.0)) == 15.0:
		passed += 1
	else:
		failed += 1; failures.append("engine.on_dash_through should merge deflect result, got %s" % str(res))
	return {"passed": passed, "failed": failed, "failures": failures}
```
Register `"res://tests/test_wind_duel_hooks.gd",` in `run_tests.gd`.

- [ ] **Step 2: Run → fail** (`./run.sh --test`) — fails: `momentum_deflect` type + new engine return not present yet. (Task 5 adds the effect; this task adds the engine/sig — run after Task 5's effect exists, or stub the effect first. Implement Steps 3-5 here for the sig/engine; the assertion fully passes once Task 5 lands.)

- [ ] **Step 3: Base hook signature** — in `technique_effect.gd` (~line 69) change:

```gdscript
func on_dash_through(_fighter: Variant, _enemy: Variant = null) -> Dictionary:
	return {}
```

- [ ] **Step 4: Engine forward + merge** — in `technique_engine.gd` replace `on_dash_through`:

```gdscript
func on_dash_through(fighter: Fighter = null, enemy: Fighter = null) -> Dictionary:
	var merged: Dictionary = {"posture_damage": 0.0, "momentum_gain": 0.0, "messages": []}
	for effect in _effects:
		var r: Variant = effect.on_dash_through(fighter, enemy)
		ProcRecorderScript.record_effect(str(effect.id))
		if typeof(r) == TYPE_DICTIONARY:
			merged["posture_damage"] += float(r.get("posture_damage", 0.0))
			merged["momentum_gain"] += float(r.get("momentum_gain", 0.0))
			if r.has("message"): (merged["messages"] as Array).append(str(r["message"]))
	return merged
```

- [ ] **Step 5: Update flowing_water** — in `flowing_water_effect.gd`:

```gdscript
func on_dash_through(_fighter: Variant, _enemy: Variant = null) -> Dictionary:
	_armed = true
	return {}
```

- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat(combat): on_dash_through(fighter,enemy)->Dictionary + engine merge"`

---

## Task 2: Break-aware posture helper + gated dash-through application

**Files:** Modify `combat_system.gd`, `fighter.gd`, `combat_event_recorder.gd`; Test `test_wind_duel_hooks.gd`.

- [ ] **Step 1: Add the fighter flag** — in `fighter.gd` near `var momentum` (~128): `var _dash_through_fired: bool = false`, and in `reset_for_combat()` (where `momentum = 0.0`, ~191) add `_dash_through_fired = false`.

- [ ] **Step 2: Recorder event** — in `combat_event_recorder.gd` add:

```gdscript
func record_dash_through(fighter: Fighter, _enemy: Fighter, posture_amount: float) -> void:
	record("dash_through", {"fighter": _role(fighter), "posture_damage": posture_amount})
```

- [ ] **Step 3: Extract the break-aware helper** — in `combat_system.gd`, add a method that encapsulates the existing posture-break block (currently inline at ~413-424):

```gdscript
func apply_posture_break_aware(attacker: Fighter, defender: Fighter, posture_amount: float) -> bool:
	var will_break: bool = (defender.posture_current - posture_amount) <= 0.0 and not defender.is_stunned
	defender.apply_posture_damage(posture_amount)
	if will_break:
		emit_signal("hitstop", 0.18)
		emit_signal("camera_shake", 18.0)
		emit_signal("spawn_particles", defender.position + Vector2(0.0, -defender.height), 24, GameConstants.COLOR_GOLD_BRIGHT)
		emit_signal("show_feedback", "破", 0.9)
		if event_recorder != null:
			event_recorder.record_stun(defender, defender.stun_duration)
		if attacker != null and attacker.technique_engine != null:
			if attacker.technique_engine.on_posture_break(attacker):
				emit_signal("show_feedback", "回春!", 0.6)
	return will_break
```
Then **refactor the hit path** (~413-424): replace the inline `will_posture_break`/`apply_posture_damage`/break block with `apply_posture_break_aware(attacker, defender, ctx.posture_damage)`. (Existing combat tests must stay green — this is a pure extraction.)

- [ ] **Step 4: Gated dash-through call** — in `combat_system.gd` replace the dash-through block (~122-127):

```gdscript
	var in_zone: bool = enemy != null and absf(enemy.position.x - fighter.position.x) <= enemy.current_attack_range() + fighter.half_width
	var in_contact: bool = fighter.is_invulnerable and enemy != null and enemy.is_hit_active() and in_zone
	if in_contact and not fighter._dash_through_fired and fighter.technique_engine != null:
		fighter._dash_through_fired = true
		var dt_res: Dictionary = fighter.technique_engine.on_dash_through(fighter, enemy)
		var pd: float = float(dt_res.get("posture_damage", 0.0))
		if pd > 0.0:
			apply_posture_break_aware(fighter, enemy, pd)
			if event_recorder != null:
				event_recorder.record_dash_through(fighter, enemy, pd)
		fighter.momentum = minf(fighter.momentum + float(dt_res.get("momentum_gain", 0.0)), 100.0)
		for m in (dt_res.get("messages", []) as Array):
			emit_signal("show_feedback", str(m), 0.4)
	elif not in_contact:
		fighter._dash_through_fired = false
```

- [ ] **Step 5: Test (gating + break)** — append to `test_wind_duel_hooks.gd run_all()`:

```gdscript
	# dash-through applies posture once per contact (not per frame) and can break
	var CombatSystemScript = load("res://scripts/combat_system.gd")
	var EnemyFactoryScript = load("res://scripts/enemy_factory.gd")
	var CombatStepScript = load("res://scripts/sim/combat_step.gd")
	var RecorderScript = load("res://scripts/sim/combat_event_recorder.gd")
	var cs = CombatSystemScript.new(); var rec = RecorderScript.new(); cs.event_recorder = rec
	var pl: Fighter = EnemyFactoryScript.create_player()
	var en: Fighter = EnemyFactoryScript.create_enemy_by_archetype("bandit_swordsman")
	pl.technique_engine.add_effect(RegistryScript.create_effect_from_data({"type":"momentum_deflect","posture":18.0,"momentum":15.0},"wd#1"), pl)
	# set up an active enemy attack + player dashing-through in range
	en.position = Vector2(600.0, GameConstants.GROUND_Y); pl.position = Vector2(590.0, GameConstants.GROUND_Y); pl.facing = 1
	en.start_light_attack()
	for _f in range(12):
		if en._attack_state.is_active(): break
		CombatStepScript.advance(cs, pl, en, {}, 1.0/60.0)
	pl.start_dash()  # grants i-frames; player is invulnerable through the active hit
	var posture0: float = en.posture_current
	for _f in range(10):
		cs.update_player(pl, {}, 1.0/60.0, en)
	var cnt := 0
	for e in rec.events():
		if str(e.get("type","")) == "dash_through": cnt += 1
	if cnt == 1 and en.posture_current < posture0:
		passed += 1
	else:
		failed += 1; failures.append("dash-through should fire ONCE and drop enemy posture (events=%d posture=%.1f/%.1f)" % [cnt, en.posture_current, posture0])
```

- [ ] **Step 6: Run + commit** — `./run.sh --import && ./run.sh --test` → after Task 5 the deflect exists and this passes; commit `fix(combat): break-aware posture helper + gated dash-through deflect`.

---

## Task 3: Aerial hits deal posture

**Files:** Modify `momentum_aerial_effect.gd`; Test `test_wind_duel_hooks.gd`.

- [ ] **Step 1: Failing test** — append:

```gdscript
	var Tech = load("res://scripts/techniques/technique_effect.gd")
	var aerial = RegistryScript.create_effect_from_data({"type":"momentum_aerial","multiplier":1.25,"posture_multiplier":1.5}, "wa#0")
	var ctxA = Tech.HitContext.new(); ctxA.attacker = FighterScript.new(); ctxA.attacker.is_grounded = false
	ctxA.hp_damage = 10.0; ctxA.posture_damage = 20.0
	aerial.modify_aerial_hit(ctxA)
	if ctxA.posture_damage > 20.0:
		passed += 1
	else:
		failed += 1; failures.append("aerial hit should add posture (got %.1f)" % ctxA.posture_damage)
```

- [ ] **Step 2: Implement** — in `momentum_aerial_effect.gd modify_aerial_hit`, after the HP line add:

```gdscript
	ctx.posture_damage *= float(params.get("posture_multiplier", 1.5))
```

- [ ] **Step 3: Run → pass; commit** — `git commit -m "feat(wind): aerial hits pressure posture"`

---

## Task 4: Flurry adds posture on the main hit (low-risk)

**Files:** Modify `momentum_flurry_effect.gd`; Test `test_wind_duel_hooks.gd`.

- [ ] **Step 1: Failing test** — append:

```gdscript
	var flurry = RegistryScript.create_effect_from_data({"type":"momentum_flurry","threshold":50.0,"damage":3.0,"cost":20.0,"posture_damage":8.0}, "wf#0")
	var ctxF = Tech.HitContext.new(); ctxF.attacker = FighterScript.new(); ctxF.attacker.momentum = 60.0
	ctxF.attack_def = load("res://scripts/attack_catalog.gd").hu_light(); ctxF.posture_damage = 22.0
	flurry.modify_outgoing_hit(ctxF)
	if ctxF.posture_damage > 22.0:
		passed += 1
	else:
		failed += 1; failures.append("flurry (above threshold) should add main-hit posture (got %.1f)" % ctxF.posture_damage)
```

- [ ] **Step 2: Implement** — in `momentum_flurry_effect.gd modify_outgoing_hit`, after the threshold guard (before/with the extra_hits append) add to the **main hit**:

```gdscript
	ctx.posture_damage += float(params.get("posture_damage", 8.0))
```
(Keep the existing HP `extra_hits` append unchanged — do NOT put posture on extra_hits.)

- [ ] **Step 3: Run → pass; commit** — `git commit -m "feat(wind): flurry adds posture on the main hit"`

---

## Task 5: `momentum_deflect` effect + register + wind boon

**Files:** Create `momentum_deflect_effect.gd`; Modify `technique_registry.gd`, `data/Boons/Boons.json`.

- [ ] **Step 1: Create the effect** — `WUGodot/scripts/techniques/effects/momentum_deflect_effect.gd`:

```gdscript
extends "res://scripts/techniques/technique_effect.gd"

func on_dash_through(fighter: Variant, _enemy: Variant = null) -> Dictionary:
	return {
		"posture_damage": float(params.get("posture", 18.0)),
		"momentum_gain": float(params.get("momentum", 15.0)),
		"message": str(params.get("message", "風!")),
	}
```

- [ ] **Step 2: Register** — in `technique_registry.gd`, add the preload + a `_new_effect_for_type` case (next to the other `momentum_*`):

```gdscript
const MomentumDeflectEffectScript = preload("res://scripts/techniques/effects/momentum_deflect_effect.gd")
# ... in _new_effect_for_type(effect_type):
		"momentum_deflect":
			return MomentumDeflectEffectScript.new()
```

- [ ] **Step 3: Attach to a wind dash boon** — in `data/Boons/Boons.json`, add a `momentum_deflect` rider to a wind **dash** boon (e.g. `wind_sparrow_wing`) so wind builds acquire it. Add to its `tiers.common.riders` (create `riders` if absent):

```json
{"type": "momentum_deflect", "posture": 18.0, "momentum": 15.0}
```

- [ ] **Step 4: Run → the Task-1/Task-2 assertions now fully pass** — `./run.sh --import && ./run.sh --test` → `failed: 0`.

- [ ] **Step 5: Commit** — `git commit -m "feat(wind): momentum_deflect (dash-through pressures posture) + wind boon"`

---

## Task 6: Wind probe mode

**Files:** Modify `tools/probe_duel_ratios.gd`, `run.sh`.

- [ ] **Step 1: Add `--wind` mode** — in `probe_duel_ratios.gd`, when `--wind` is passed, build the player with a fixed wind loadout before measuring (install `momentum_deflect`, `momentum_aerial`, `momentum_flurry` onto `player.technique_engine` via `RegistryScript.create_effect_from_data`), and add a scenario that asserts an aerial hit and a dash-through each produce posture > 0 on the dummy. Print a `wind:` section.

- [ ] **Step 2: run.sh** — pass args through: `exec "$GODOT" ... res://tools/probe_duel_ratios.gd -- "$@"` (so `--probe-duel-ratios --wind` reaches the script via `OS.get_cmdline_user_args()`).

- [ ] **Step 3: Run** — `./run.sh --probe-duel-ratios --wind` prints the wind section with posture > 0 for aerial + dash-through. Commit `feat(tools): wind probe mode`.

---

## Task 7: Validation + tune ✋

- [ ] **Step 1: Scripted-policy gate** — run over seeds 1..50:
```bash
for p in facetank aggressive_dash; do ./run.sh --playtest-batch --seeds 1..50 --player $p --decision school --school wind --out /tmp/wind_$p.json; done
```
**Headline win over all 50 seeds** for `aggressive_dash` must be **≥ 0.18** (vs 0.08), `facetank` unchanged (~0.00), **zero timeouts**.
- [ ] **Step 2: Wind acquisition report** — from `/tmp/wind_aggressive_dash.json`, compute the **% of runs whose `build_snapshots` contain a wind boon** + avg acquisition node. If too sparse to attribute the win-rate to wind, validate via a **forced wind loadout** instead (don't filter the seed set).
- [ ] **Step 3: Probe + dogfood** — `./run.sh --probe-duel-ratios --wind` (posture pressure confirmed); daemon: drive a wind run, dash-through an enemy attack, confirm the enemy posture drops (one `dash_through` event) → toward a break.
- [ ] **Step 4: No regression** — 120-seed greedy batch → `check_difficulty_curve.py` accepts, zero timeouts; the rebalance ordering (facetank < aggressive_dash < parry) holds/improves.
- [ ] **Step 5: Tune** the deflect/aerial/flurry `posture` params (and the wind boon tiers) to hit ≥0.18 without trivializing; commit each iteration.

> **✋ STOP — present to the user:** aggressive_dash±wind win rates (all-50 headline), wind-acquisition %, the wind probe posture numbers, and a dogfood note, for the verdict.

## Task 8: Record
- [ ] Write `docs/superpowers/specs/2026-06-24-per-school-duel-hooks-results.md` (before/after non-parry win rate, wind knobs, the framework note for the next school). Verify `./run.sh --test` 0 failures. Commit.

---

## Self-Review
- **Spec coverage:** framework (§1) is documented; **Wind slice** (§2) → Tasks 3 (aerial), 4 (flurry main-hit posture), 5+2 (dash-through deflect), momentum→burst is folded into the deflect/flurry params (kept minimal per YAGNI — a separate burst effect is deferred if §2 item 4 proves needed). **§2b hook changes** → Tasks 1+2 (sig→Dictionary, engine merge, flowing_water, gating, recorder, **CombatSystem-owned posture via `apply_posture_break_aware`**). Validation (§3: ≥0.18 all-50 headline + acquisition report + Wind probe + no-regression) → Tasks 6,7. Out-of-scope (other schools, payoff) → not implemented.
- **Placeholder scan:** code shown for every code step; Task 7 is a guided tune loop with the pinned ≥0.18 gate + STOP (balance can't be unit-tested).
- **Type consistency:** `on_dash_through(fighter, enemy) -> Dictionary` returns `{posture_damage, momentum_gain, message}`; engine merges into `{posture_damage, momentum_gain, messages[]}`; CombatSystem reads `posture_damage`/`momentum_gain`/`messages` — consistent across Tasks 1/2/5. `apply_posture_break_aware(attacker, defender, posture_amount)` used by both hit path and dash-through. `momentum_deflect` type/params (`posture`,`momentum`,`message`) consistent in effect/registry/boon/tests. Recorder `record_dash_through(fighter, enemy, posture_amount)` + `dash_through` event consistent.
