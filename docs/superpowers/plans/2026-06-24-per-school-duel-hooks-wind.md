# Per-School Duel Hooks — Wind Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Wind a viable non-parry **mobility-pressure** duel path by retargeting its boons onto posture (aerial/flurry deal posture; dash-through = a "deflect" that pressures the enemy's posture), closing the rebalance's `aggressive_dash` gap (0.08 → ≥0.18).

**Architecture:** Extend the existing technique-effect hooks. The dash-through hook gains the `enemy` and **returns** a result dict that **CombatSystem applies via a shared break-aware helper** (so stun events + posture-break callbacks fire); the call is gated once per dash-through contact. Aerial/flurry effects add `ctx.posture_damage`.

**Tech Stack:** Godot 4.6.2 / GDScript. Tests: `./run.sh --test` (`failed: 0`). Harness/probe/daemon as in prior plans.

**Spec:** `docs/superpowers/specs/2026-06-24-per-school-duel-hooks-design.md`

**Ordering note (reviewer P1):** the `on_dash_through` base-signature change, the engine merge, and the `momentum_deflect` effect+registration all land in **Task 1** — the effect's 2-arg override cannot compile until the base arity changes, and the Task 1/2 tests consume the effect, so they must ship together. The **boon-data** attachment (which trips the boon-text content gate) is deferred to **Task 5**, alongside its `BoonText` template.

---

## File Structure
**Modify:** `scripts/techniques/technique_effect.gd` (hook sig) · `scripts/technique_engine.gd` (forward+merge) · `scripts/combat_system.gd` (break-aware helper, gated dash-through) · `scripts/techniques/effects/flowing_water_effect.gd` (new sig) · `scripts/techniques/effects/momentum_aerial_effect.gd` (posture) · `scripts/techniques/effects/momentum_flurry_effect.gd` (posture) · `scripts/fighter.gd` (`_dash_through_fired`) · `scripts/sim/combat_event_recorder.gd` (`record_dash_through`) · `scripts/techniques/technique_registry.gd` (register `momentum_deflect`) · `scripts/boons/boon_text.gd` (`momentum_deflect` template + posture mentions) · `data/Boons/Boons.json` (wind deflect rider) · `tools/probe_duel_ratios.gd` (`--wind`) · `tests/run_tests.gd`.
**Create:** `scripts/techniques/effects/momentum_deflect_effect.gd` · `tests/test_wind_duel_hooks.gd`.

---

## Task 1: Hook signature → `Dictionary` + engine merge + `momentum_deflect` effect

**Files:** Create `momentum_deflect_effect.gd`, `tests/test_wind_duel_hooks.gd`; Modify `technique_effect.gd`, `technique_engine.gd`, `flowing_water_effect.gd`, `technique_registry.gd`, `run_tests.gd`.

- [ ] **Step 1: Write the failing test** — create `WUGodot/tests/test_wind_duel_hooks.gd`:

```gdscript
extends RefCounted
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")
const RegistryScript = preload("res://scripts/techniques/technique_registry.gd")
const FighterScript = preload("res://scripts/fighter.gd")

func run_all() -> Dictionary:
	var passed := 0; var failed := 0; var failures: Array[String] = []

	# momentum_deflect returns a posture/momentum result dict
	var deflect = RegistryScript.create_effect_from_data({"type":"momentum_deflect","posture":18.0,"momentum":15.0}, "wd#0")
	var d: Dictionary = deflect.on_dash_through(FighterScript.new(), FighterScript.new())
	if float(d.get("posture_damage",0.0)) == 18.0 and float(d.get("momentum_gain",0.0)) == 15.0:
		passed += 1
	else:
		failed += 1; failures.append("momentum_deflect.on_dash_through should return posture/momentum, got %s" % str(d))

	# engine.on_dash_through forwards enemy + merges effect result dicts
	var eng = TechniqueEngineScript.new()
	var player: Fighter = FighterScript.new(); var enemy: Fighter = FighterScript.new()
	eng.add_effect(RegistryScript.create_effect_from_data({"type":"momentum_deflect","posture":18.0,"momentum":15.0}, "wd#1"), player)
	var res: Dictionary = eng.on_dash_through(player, enemy)
	if float(res.get("posture_damage",0.0)) == 18.0 and float(res.get("momentum_gain",0.0)) == 15.0:
		passed += 1
	else:
		failed += 1; failures.append("engine.on_dash_through should merge deflect result, got %s" % str(res))
	return {"passed": passed, "failed": failed, "failures": failures}
```
Register `"res://tests/test_wind_duel_hooks.gd",` in `run_tests.gd`.

- [ ] **Step 2: Run → fail** — `./run.sh --import && ./run.sh --test` fails (`momentum_deflect` type + 2-arg return not present).

- [ ] **Step 3: Base hook signature** — in `technique_effect.gd` (~line 69) change `on_dash_through`:

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
		if typeof(r) == TYPE_DICTIONARY:
			merged["posture_damage"] += float(r.get("posture_damage", 0.0))
			merged["momentum_gain"] += float(r.get("momentum_gain", 0.0))
			if r.has("message"): (merged["messages"] as Array).append(str(r["message"]))
	return merged
```
(If the existing loop records a proc/telemetry line per effect, keep that call.)

- [ ] **Step 5: Update flowing_water** — in `flowing_water_effect.gd`:

```gdscript
func on_dash_through(_fighter: Variant, _enemy: Variant = null) -> Dictionary:
	_armed = true
	return {}
```

- [ ] **Step 6: Create the deflect effect** — `WUGodot/scripts/techniques/effects/momentum_deflect_effect.gd`:

```gdscript
extends "res://scripts/techniques/technique_effect.gd"

func on_dash_through(_fighter: Variant, _enemy: Variant = null) -> Dictionary:
	return {
		"posture_damage": float(params.get("posture", 18.0)),
		"momentum_gain": float(params.get("momentum", 15.0)),
		"message": str(params.get("message", "風!")),
	}
```

- [ ] **Step 7: Register the effect** — in `technique_registry.gd` add the preload + a `_new_effect_for_type` case beside the other `momentum_*`:

```gdscript
const MomentumDeflectEffectScript = preload("res://scripts/techniques/effects/momentum_deflect_effect.gd")
# ... in _new_effect_for_type(effect_type):
		"momentum_deflect":
			return MomentumDeflectEffectScript.new()
```

- [ ] **Step 8: Run → pass; commit** — `./run.sh --import && ./run.sh --test` → both new assertions pass. `git commit -m "feat(combat): on_dash_through(fighter,enemy)->Dictionary + momentum_deflect effect"`

---

## Task 2: Break-aware posture helper + gated dash-through application

**Files:** Modify `combat_system.gd`, `fighter.gd`, `combat_event_recorder.gd`; Test `test_wind_duel_hooks.gd`.

- [ ] **Step 1: Add the fighter flag** — in `fighter.gd` near `var momentum` (~128): `var _dash_through_fired: bool = false`, and in `reset_for_combat()` (where `momentum = 0.0`, ~191) add `_dash_through_fired = false`.

- [ ] **Step 2: Recorder event** — in `combat_event_recorder.gd` add (use the same `_role(...)` helper the other records use):

```gdscript
func record_dash_through(fighter: Fighter, _enemy: Fighter, posture_amount: float) -> void:
	record("dash_through", {"fighter": _role(fighter), "posture_damage": posture_amount})
```

- [ ] **Step 3: Failing test (gating fires once + posture drop)** — append to `run_all()`. It advances the enemy's attack state directly to the hit-active window and ticks the player into dash i-frames, then sustains contact 8 frames so the gating is genuinely exercised:

```gdscript
	var CombatSystemScript = load("res://scripts/combat_system.gd")
	var EnemyFactoryScript = load("res://scripts/enemy_factory.gd")
	var RecorderScript = load("res://scripts/sim/combat_event_recorder.gd")
	var cs = CombatSystemScript.new(); var rec = RecorderScript.new(); cs.event_recorder = rec
	var pl: Fighter = EnemyFactoryScript.create_player()
	var en: Fighter = EnemyFactoryScript.create_enemy_by_archetype("bandit_swordsman")
	pl.technique_engine.add_effect(RegistryScript.create_effect_from_data({"type":"momentum_deflect","posture":18.0,"momentum":15.0},"wd#2"), pl)
	en.position = Vector2(600.0, GameConstants.GROUND_Y); pl.position = Vector2(590.0, GameConstants.GROUND_Y); pl.facing = 1
	# player into dash i-frames (is_invulnerable becomes true past DASH_STARTUP_END)
	pl.start_dash()
	var g := 0
	while not pl.is_invulnerable and g < 40:
		cs.update_player(pl, {}, 1.0/240.0, en); g += 1
	# enemy attack into the hit-active window (advance its attack state directly — deterministic)
	en.start_light_attack()
	g = 0
	while not en.is_hit_active() and g < 120:
		en._attack_state.advance(1.0/240.0); g += 1
	var setup_ok: bool = pl.is_invulnerable and en.is_hit_active()
	# sustained contact: dash-through must fire EXACTLY once across many frames
	var posture0: float = en.posture_current
	for _f in range(8):
		cs.update_player(pl, {}, 1.0/240.0, en)
	var cnt := 0
	for e in rec.events():
		if str(e.get("type","")) == "dash_through": cnt += 1
	if setup_ok and cnt == 1 and en.posture_current < posture0:
		passed += 1
	else:
		failed += 1; failures.append("dash-through should fire ONCE and drop enemy posture (setup_ok=%s events=%d posture=%.1f/%.1f)" % [str(setup_ok), cnt, en.posture_current, posture0])
```

- [ ] **Step 4: Extract the break-aware helper** — in `combat_system.gd`, add a method encapsulating the posture-break block currently inline in the hit path (~413-424):

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
Then **refactor the hit path** (~413-424): replace the inline `will_posture_break`/`apply_posture_damage`/break block with `apply_posture_break_aware(attacker, defender, ctx.posture_damage)`. (Pure extraction — existing combat tests must stay green; copy the emitted signal args verbatim from the current block.)

- [ ] **Step 5: Gated dash-through call** — in `combat_system.gd` replace the dash-through block (~122-127):

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
(Match `in_zone` to the exact distance/range expression the original block used at `combat_system.gd:122-127` — keep its `half_width`/range terms.)

- [ ] **Step 6: Run → pass; commit** — `./run.sh --test` → `failed: 0`. `git commit -m "fix(combat): break-aware posture helper + gated dash-through deflect"`

---

## Task 3: Aerial hits deal posture

**Files:** Modify `momentum_aerial_effect.gd`; Test `test_wind_duel_hooks.gd`.

- [ ] **Step 1: Failing test** — append to `run_all()`:

```gdscript
	var Tech = load("res://scripts/techniques/technique_effect.gd")
	var aerial = RegistryScript.create_effect_from_data({"type":"momentum_aerial","multiplier":1.25,"landing_gain":10.0,"posture_multiplier":1.5}, "wa#0")
	var ctxA = Tech.HitContext.new(); ctxA.attacker = FighterScript.new(); ctxA.attacker.is_grounded = false
	ctxA.hp_damage = 10.0; ctxA.posture_damage = 20.0
	aerial.modify_aerial_hit(ctxA)
	if ctxA.posture_damage > 20.0:
		passed += 1
	else:
		failed += 1; failures.append("aerial hit should add posture (got %.1f)" % ctxA.posture_damage)
```

- [ ] **Step 2: Run → fail.**

- [ ] **Step 3: Implement** — in `momentum_aerial_effect.gd modify_aerial_hit`, after the existing HP line add:

```gdscript
	ctx.posture_damage *= float(params.get("posture_multiplier", 1.5))
```

- [ ] **Step 4: Run → pass; commit** — `git commit -m "feat(wind): aerial hits pressure posture"`

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

- [ ] **Step 2: Run → fail.**

- [ ] **Step 3: Implement** — in `momentum_flurry_effect.gd modify_outgoing_hit`, inside the above-threshold branch (the same branch that appends `extra_hits`), add to the **main hit**:

```gdscript
	ctx.posture_damage += float(params.get("posture_damage", 8.0))
```
(Keep the existing HP `extra_hits` append unchanged — do NOT put posture on extra_hits.)

- [ ] **Step 4: Run → pass; commit** — `git commit -m "feat(wind): flurry adds posture on the main hit"`

---

## Task 5: Wind boon data + BoonText templates (content gate)

**Files:** Modify `data/Boons/Boons.json`, `scripts/boons/boon_text.gd`; Test `tests/test_boon_text.gd` (existing gate).

> The boon-text content gate (`test_boon_text.gd:69-79`) runs **every** Boons.json effect type through `BoonText.has_template`. Adding the `momentum_deflect` rider to Boons.json **without** a `boon_text.gd` template fails that gate — so the template lands in the same task.

- [ ] **Step 1: Add the `momentum_deflect` describe template** — in `boon_text.gd describe_effect` (the `match` at ~line 43, alphabetically beside the other `momentum_*` cases ~84-91):

```gdscript
		"momentum_deflect":
			return "dash-through deflect deals %.0f posture (+%.0f momentum)" % [float(effect_data.get("posture", 0.0)), float(effect_data.get("momentum", 0.0))]
```

- [ ] **Step 2: Short-form grouping** — in `boon_text.gd _short_effect` (~line 159), add `momentum_deflect` to the Momentum group so the summary reads cleanly:

```gdscript
		"dash_stab", "flowing_water", "gaze", "momentum", "momentum_aerial", "momentum_deflect", "momentum_flurry", "momentum_speed", "sparrow":
			return "Momentum"
```

- [ ] **Step 3: Mention posture in aerial/flurry text** — update the two existing describers (~86-89) to reflect the new posture behavior:

```gdscript
		"momentum_aerial":
			return "aerial hits deal %d%% (+%d%% posture) and landing gives %.0f momentum" % [int(round(float(effect_data.get("multiplier", 1.0)) * 100.0)), int(round((float(effect_data.get("posture_multiplier", 1.5)) - 1.0) * 100.0)), float(effect_data.get("landing_gain", 0.0))]
		"momentum_flurry":
			return "at %.0f momentum, spend %.0f for %.0f flurry damage (+%.0f posture)" % [float(effect_data.get("threshold", 0.0)), float(effect_data.get("cost", 0.0)), float(effect_data.get("damage", 0.0)), float(effect_data.get("posture_damage", 8.0))]
```

- [ ] **Step 4: Attach to a wind dash boon** — in `data/Boons/Boons.json`, add a `momentum_deflect` rider to a wind **dash** boon (e.g. `wind_sparrow_wing`) so wind builds acquire it — add to its lowest tier's effect list (create the list/`riders` key if absent, matching that boon's existing tier schema):

```json
{"type": "momentum_deflect", "posture": 18.0, "momentum": 15.0}
```

- [ ] **Step 5: Run → pass; commit** — `./run.sh --import && ./run.sh --test` → `test_boon_text` stays green (every type templated). `git commit -m "feat(wind): momentum_deflect boon rider + BoonText templates"`

---

## Task 6: Wind probe mode

**Files:** Modify `tools/probe_duel_ratios.gd`, `run.sh`.

- [ ] **Step 1: Add `--wind` mode** — in `probe_duel_ratios.gd`, when `--wind` is passed, build the player with a fixed wind loadout before measuring (install `momentum_deflect`, `momentum_aerial`, `momentum_flurry` onto `player.technique_engine` via `RegistryScript.create_effect_from_data`), and add a scenario asserting an aerial hit and a dash-through each produce posture > 0 on the dummy. Print a `wind:` section (vanilla probe unchanged as baseline).

- [ ] **Step 2: run.sh** — ensure args reach the script (`-- "$@"` → `OS.get_cmdline_user_args()`), so `--probe-duel-ratios --wind` works.

- [ ] **Step 3: Run; commit** — `./run.sh --probe-duel-ratios --wind` prints the wind section with posture > 0. `git commit -m "feat(tools): wind probe mode"`

---

## Task 7: Validation + tune ✋

- [ ] **Step 1: Scripted-policy gate** — over seeds 1..50:
```bash
for p in facetank aggressive_dash; do ./run.sh --playtest-batch --seeds 1..50 --player $p --decision school --school wind --out /tmp/wind_$p.json; done
```
**Headline win over all 50 seeds** for `aggressive_dash` must be **≥ 0.18** (vs 0.08), `facetank` unchanged (~0.00), **zero timeouts**.
- [ ] **Step 2: Wind acquisition report** — from `/tmp/wind_aggressive_dash.json`, compute the **% of runs whose `build_snapshots` contain a wind boon** + avg acquisition node. If too sparse to attribute the win-rate to wind, validate via a **forced wind loadout** (don't filter the seed set — the headline stays over all 50).
- [ ] **Step 3: Probe + dogfood** — `./run.sh --probe-duel-ratios --wind` (posture pressure confirmed); daemon: drive a wind run, dash-through an enemy attack, confirm one `dash_through` event and the enemy posture drops toward a break.
- [ ] **Step 4: No regression** — 120-seed greedy batch → `python3 WUGodot/tools/check_difficulty_curve.py` accepts, zero timeouts; rebalance ordering (facetank < aggressive_dash < parry) holds/improves.
- [ ] **Step 5: Tune** the deflect/aerial/flurry `posture` params (and the wind boon tiers) to hit ≥0.18 without trivializing; commit each iteration.

> **✋ STOP — present to the user:** aggressive_dash±wind win rates (all-50 headline), wind-acquisition %, the wind probe posture numbers, and a dogfood note, for the verdict.

## Task 8: Record
- [ ] Write `docs/superpowers/specs/2026-06-24-per-school-duel-hooks-results.md` (before/after non-parry win rate, wind knobs, the framework note for the next school). Verify `./run.sh --test` 0 failures. Commit.

---

## Self-Review
- **Spec coverage:** framework (§1) documented; **Wind slice** (§2) → Tasks 3 (aerial), 4 (flurry main-hit posture), 1+2 (dash-through deflect), momentum→burst folded into deflect/flurry params (separate burst effect deferred per YAGNI). **§2b hook changes** → Tasks 1+2 (sig→Dictionary, engine merge, flowing_water, gating, recorder, **CombatSystem-owned posture via `apply_posture_break_aware`**). Validation (§3) → Tasks 6,7. Out-of-scope (other schools, payoff) → not implemented.
- **Reviewer P1 fixes:** (1) `momentum_deflect` effect+registration moved into Task 1 with the base-arity change; boon-data attachment + its `BoonText` template isolated in Task 5. (2) Gating test now advances `en._attack_state.advance(dt)` to reach `is_hit_active()` and ticks the player into dash i-frames (asserts `setup_ok`) before sustaining contact 8 frames — exercising the real path. (3) Task 5 adds the `momentum_deflect` describe template (+ `_short_effect` group, + aerial/flurry posture text) in the same commit as the Boons.json edit, so `test_boon_text` stays green.
- **Placeholder scan:** code shown for every code step; Task 7 is a guided tune loop with the pinned ≥0.18 gate + STOP.
- **Type consistency:** `on_dash_through(fighter, enemy) -> Dictionary` returns `{posture_damage, momentum_gain, message}`; engine merges into `{posture_damage, momentum_gain, messages[]}`; CombatSystem reads those keys — consistent across Tasks 1/2. `apply_posture_break_aware(attacker, defender, posture_amount)` used by both hit path and dash-through. `momentum_deflect` params (`posture`,`momentum`,`message`) consistent across effect/registry/boon/text/tests. `record_dash_through(fighter, enemy, posture_amount)` + `dash_through` event consistent.
