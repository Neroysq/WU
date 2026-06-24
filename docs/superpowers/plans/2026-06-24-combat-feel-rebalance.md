# Combat-Feel Rebalance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retune combat so facetank-DPS loses and the posture/parry duel is the path to victory (build = the punish), via one fairness code change + data tuning, measured by a duel-ratio probe + the batch harness and dogfooded with the interactive daemon.

**Architecture:** Mostly **data tuning** (Attacks/Enemies/GameSettings JSON) guard-railed by a new **duel-ratio probe** and the harness skill-sweep, plus **one code change** (enemy reactive block no longer opens a parry window). Balance can't be unit-tested, so tuning is a **guided iterative loop with measurement + STOP gates**, not autonomous TDD.

**Tech Stack:** Godot 4.6.2 / GDScript. Tests via `./run.sh --test` (expect `failed: 0`). Tools via `./run.sh`. Harness: `./run.sh --playtest-batch ...` + `WUGodot/tools/check_difficulty_curve.py`. Daemon: `./run.sh --playtest-daemon --session <id>`.

**Spec:** `docs/superpowers/specs/2026-06-24-combat-feel-rebalance-design.md`

---

## File Structure

**Create:**
- `WUGodot/tools/probe_duel_ratios.gd` — headless probe: per-archetype duel-ratio metrics (mirrors `probe_light_deadzone.gd`'s script harness).
- `WUGodot/tests/test_duel_ratios_probe.gd` — unit test for the probe's metric helpers.
- `docs/superpowers/specs/2026-06-24-combat-feel-rebalance-results.md` — baseline → code-only → final tables (the record).

**Modify:**
- `run.sh` — add `--probe-duel-ratios`.
- `WUGodot/scripts/combat_system.gd` — Lever 3: remove `trigger_parry_window()` from both AI block branches.
- `WUGodot/tests/test_technique_combat.gd` (or a new `test_enemy_block_no_parry.gd`) — lever-3 test.
- `WUGodot/data/Attacks/Attacks.json`, `WUGodot/data/Enemies/*.json`, `WUGodot/data/Settings/GameSettings.json` — the rebalance numbers (Task 4).
- `WUGodot/tests/run_tests.gd` — register new test(s).

---

## Task 1: Duel-ratio probe tool

**Files:**
- Create: `WUGodot/tools/probe_duel_ratios.gd`
- Create: `WUGodot/tests/test_duel_ratios_probe.gd`
- Modify: `run.sh`, `WUGodot/tests/run_tests.gd`

The probe drives `CombatStep` with a **passive enemy** (AI disabled) and a scripted player, counting hits/parries until a break/kill — per archetype.

- [ ] **Step 1: Write the probe** — create `WUGodot/tools/probe_duel_ratios.gd` (mirror the script scaffold of `WUGodot/tools/probe_light_deadzone.gd` — same `extends`, same `_initialize`/`_init` + `quit()` pattern; copy that boilerplate). Core logic:

```gdscript
const ARCHETYPES := ["bandit_swordsman","bandit_spearman","wandering_ronin","sect_disciple","masked_assassin","iron_bear"]
const DT := 1.0/60.0
const RECOVER_GAP_FRAMES := 48 # ~0.8s between parries (realistic cadence)

# CRITICAL: apply_posture_damage() resets posture to 40% AND stuns on break
# (fighter.gd) — so a break is detected by is_stunned, NOT posture_current<=0.
static func _parry_posture() -> float:
	return float(DataManager.get_game_settings().get("parryPostureDamage", 50.0))

static func _node() -> MapNode:
	return MapNode.new(9001, 1, MapNode.NodeType.BATTLE, [])

static func _fresh(archetype: String) -> Dictionary:
	var player: Fighter = EnemyFactory.create_player()
	var setup: Dictionary = CombatSetup.prepare(player, _node(), archetype)
	var enemy: Fighter = setup["enemy"]
	var cs: CombatSystem = setup["combat_system"]
	enemy.is_ai = false                      # passive dummy
	enemy.position = Vector2(600.0, GameConstants.GROUND_Y)
	player.position = Vector2(600.0 - 40.0, GameConstants.GROUND_Y)
	player.facing = 1
	return {"player": player, "enemy": enemy, "cs": cs}

# repeated attacks (optionally vs a held block); count to kill (hp<=0) or break (is_stunned)
# returns {count, timeout}
static func _hits_until(archetype: String, field: String, heavy: bool, block: bool) -> Dictionary:
	var s := _fresh(archetype)
	var player: Fighter = s["player"]; var enemy: Fighter = s["enemy"]; var cs: CombatSystem = s["cs"]
	var count := 0
	for _swing in range(300):
		if heavy: player.start_heavy_attack() else: player.start_light_attack()
		count += 1
		for _f in range(70):
			if block: enemy.is_blocking = true            # hold block every frame
			CombatStep.advance(cs, player, enemy, {}, DT)
			if field == "hp" and enemy.health_current <= 0.0: return {"count": count, "timeout": false}
			if field == "posture" and enemy.is_stunned: return {"count": count, "timeout": false}  # break => stun
			if not player._attack_state.is_active() and player._attack_cooldown <= 0.0: break
	return {"count": -1, "timeout": true}

# apply parry posture damage at a realistic cadence (recovery between); count to break (is_stunned)
static func _parries_to_break(archetype: String) -> Dictionary:
	var s := _fresh(archetype); var enemy: Fighter = s["enemy"]
	var pd := _parry_posture(); var count := 0
	for _p in range(40):
		enemy.apply_posture_damage(pd); count += 1
		if enemy.is_stunned: return {"count": count, "timeout": false}   # broke
		for _f in range(RECOVER_GAP_FRAMES):
			enemy.update_timers(DT)  # ticks posture recovery
	return {"count": -1, "timeout": true}

# break→punish payoff: heavy pressure to break, sum HP damage dealt DURING the stun, kill cost
static func _break_then_punish(archetype: String) -> Dictionary:
	var s := _fresh(archetype)
	var player: Fighter = s["player"]; var enemy: Fighter = s["enemy"]; var cs: CombatSystem = s["cs"]
	var swings := 0; var frames := 0; var dmg_in_stun := 0.0; var hits_to_break := -1
	for _swing in range(400):
		if heavy_first(swings): player.start_heavy_attack() else: player.start_heavy_attack()
		swings += 1
		for _f in range(90):
			var hp0 := enemy.health_current
			CombatStep.advance(cs, player, enemy, {}, DT); frames += 1
			if enemy.is_stunned and hits_to_break < 0: hits_to_break = swings
			if enemy.is_stunned: dmg_in_stun += maxf(0.0, hp0 - enemy.health_current)
			if enemy.health_current <= 0.0:
				return {"hits_to_break": hits_to_break, "dmg_in_stun": dmg_in_stun, "swings_to_kill": swings, "duration": frames*DT, "timeout": false}
			if not player._attack_state.is_active() and player._attack_cooldown <= 0.0: break
	return {"hits_to_break": hits_to_break, "dmg_in_stun": dmg_in_stun, "swings_to_kill": -1, "duration": frames*DT, "timeout": true}

static func heavy_first(_n: int) -> bool: return true  # always heavy for the posture path

static func measure(archetype: String) -> Dictionary:
	var s := _fresh(archetype); var e: Fighter = s["enemy"]
	var pp := _break_then_punish(archetype)
	return {
		"hp_max": e.health_max, "posture_max": e.posture_max,
		"hits_to_hp_kill_light": _hits_until(archetype, "hp", false, false),
		"hits_to_posture_break_light": _hits_until(archetype, "posture", false, false),
		"hits_to_posture_break_heavy": _hits_until(archetype, "posture", true, false),
		"blocked_pressure_break_light": _hits_until(archetype, "posture", false, true),
		"parries_to_break": _parries_to_break(archetype),
		"posture_path": pp,   # {hits_to_break, dmg_in_stun, swings_to_kill, duration, timeout}
	}
```
The entry point loops `ARCHETYPES`, builds `{a: measure(a)}`, writes `/tmp/duel_ratios/probe.json`, prints a table (flag any `timeout:true` rows), and `quit()`s. **avg combat duration** comes from the harness batch (`summary.transcripts[].combats[].duration`) — record it alongside in Task 2; the probe's `posture_path.duration`/`timeout` cover the per-archetype break→punish payoff. (`Fighter.update_timers` ticks posture recovery when not stunned — confirmed.)

- [ ] **Step 2: Add the run.sh entry** — in `run.sh`, alongside `--probe-light-deadzone`:

```bash
    --probe-duel-ratios)
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://tools/probe_duel_ratios.gd
        ;;
```

- [ ] **Step 3: Write the failing test** — create `WUGodot/tests/test_duel_ratios_probe.gd`:

```gdscript
extends RefCounted
const Probe = preload("res://tools/probe_duel_ratios.gd")

func run_all() -> Dictionary:
	var passed := 0; var failed := 0; var failures: Array[String] = []
	var m: Dictionary = Probe.measure("bandit_swordsman")
	# sane, finite, non-timeout metrics for a weak enemy (break detected via is_stunned)
	if int(m["hits_to_posture_break_light"]["count"]) > 0 and not bool(m["hits_to_posture_break_light"]["timeout"]) \
		and int(m["hits_to_hp_kill_light"]["count"]) > 0 \
		and int(m["parries_to_break"]["count"]) >= 1 and not bool(m["parries_to_break"]["timeout"]) \
		and int(m["blocked_pressure_break_light"]["count"]) > 0:
		passed += 1
	else:
		failed += 1; failures.append("bandit metrics should be finite/positive/non-timeout: %s" % str(m))
	# weak-enemy parries_to_break should be small (~2 at 50 posture vs 85)
	if int(m["parries_to_break"]["count"]) <= 4:
		passed += 1
	else:
		failed += 1; failures.append("weak-enemy parries_to_break should be small, got %d" % int(m["parries_to_break"]["count"]))
	return {"passed": passed, "failed": failed, "failures": failures}
```
Register it in `WUGodot/tests/run_tests.gd` (add `"res://tests/test_duel_ratios_probe.gd",`).

- [ ] **Step 4: Run → fail** (`./run.sh --test`) — fails to load `probe_duel_ratios.gd` until Step 1 is in place; if you did Step 1 first, the test passes. Run `./run.sh --import` first so the new tool is recognized.

- [ ] **Step 5: Run the probe** — `./run.sh --probe-duel-ratios` → prints the per-archetype table, writes `/tmp/duel_ratios/probe.json`. Sanity-check the numbers are plausible.

- [ ] **Step 6: Commit**

```bash
git add WUGodot/tools/probe_duel_ratios.gd WUGodot/tests/test_duel_ratios_probe.gd WUGodot/tests/run_tests.gd run.sh
git commit -m "feat(tools): duel-ratio probe (per-archetype hit/posture/parry counts)"
```

---

## Task 2: Baseline capture (BEFORE any balance change)

**Files:** Create `docs/superpowers/specs/2026-06-24-combat-feel-rebalance-results.md`

Capture the "before" on the **current** build — this must precede Lever 3 (Task 3) and all tuning.

- [ ] **Step 1: Duel ratios** — `./run.sh --probe-duel-ratios` → copy the table into the results doc under "## Baseline".
- [ ] **Step 2: Harness win/skill** — run:

```bash
./run.sh --playtest-batch --seeds 1..50 --player heuristic --skill 0.8 --decision greedy --out /tmp/cfr_base_greedy.json
./run.sh --playtest-batch --seeds 1..50 --decision greedy --skill-sweep --out /tmp/cfr_base_sweep.json
python3 WUGodot/tools/check_difficulty_curve.py /tmp/cfr_base_greedy.json   # observational here
```
Record into the doc: overall win_rate, avg_depth, the **skill-sweep win rates** (0.5/0.65/0.8/0.95 — expect the inverted ~0.72→0.48), boss death share, **avg combat duration** (`transcripts[].combats[].duration`), timeout count, and the checker's output. **Baseline is observational** — a nonzero `check_difficulty_curve.py` exit is recorded as a baseline fact, **not blocking**; it only gates at final acceptance (Task 5).

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-06-24-combat-feel-rebalance-results.md
git commit -m "docs: combat rebalance baseline (pre-change) metrics"
```

---

## Task 3: Lever 3 — enemy reactive block is block-only (the one code change)

**Files:**
- Modify: `WUGodot/scripts/combat_system.gd` (both AI block branches)
- Create: `WUGodot/tests/test_enemy_block_no_parry.gd`; Modify `WUGodot/tests/run_tests.gd`

- [ ] **Step 1: Write the failing test** — create `WUGodot/tests/test_enemy_block_no_parry.gd`:

```gdscript
extends RefCounted
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const EnemyFactoryScript = preload("res://scripts/enemy_factory.gd")
const CombatStepScript = preload("res://scripts/sim/combat_step.gd")
const RecorderScript = preload("res://scripts/sim/combat_event_recorder.gd")
const DT := 1.0/60.0

func _setup(archetype: String) -> Dictionary:
	var player: Fighter = EnemyFactoryScript.create_player()
	var enemy: Fighter = EnemyFactoryScript.create_enemy_by_archetype(archetype)
	enemy.position = Vector2(600.0, GameConstants.GROUND_Y)
	player.position = Vector2(560.0, GameConstants.GROUND_Y)
	player.facing = 1
	return {"player": player, "enemy": enemy}

func run_all() -> Dictionary:
	var passed := 0; var failed := 0; var failures: Array[String] = []

	# --- Case A: modern AI block (forced) opens NO parry window ---
	var a := _setup("bandit_swordsman"); var cs := CombatSystemScript.new()
	a.enemy.ai_brain.block_chance = 1.0
	a.player.start_light_attack()
	for _f in range(20):
		if a.player._attack_state.is_active(): break
		cs.update_player(a.player, {}, DT, a.enemy)
	cs.update_ai(a.enemy, a.player, DT)
	if a.enemy.is_blocking and not a.enemy.is_parrying():
		passed += 1
	else:
		failed += 1; failures.append("A: modern AI block must not open a parry window (is_parrying=%s)" % str(a.enemy.is_parrying()))

	# --- Case B: resolving a player hit on a held-blocking enemy = block, not parry ---
	var b := _setup("bandit_swordsman"); var cs2 := CombatSystemScript.new()
	var rec = RecorderScript.new(); cs2.event_recorder = rec
	b.enemy.is_ai = false
	var posture0: float = b.enemy.posture_current
	b.player.start_light_attack()
	for _f in range(40):
		b.enemy.is_blocking = true
		CombatStepScript.advance(cs2, b.player, b.enemy, {}, DT)
		if not b.player._attack_state.is_active() and b.player._attack_cooldown <= 0.0: break
	var player_hit := {}
	for e in rec.events():
		if str(e.get("type","")) == "hit" and str(e.get("by","")) == "player": player_hit = e
	var no_parry: bool = not player_hit.is_empty() and not bool(player_hit.get("parried", false)) and bool(player_hit.get("blocked", false))
	if no_parry and not b.player.is_stunned and b.enemy.posture_current < posture0:
		passed += 1
	else:
		failed += 1; failures.append("B: blocked player hit should be blocked (not parried), no player stun, enemy posture loss. hit=%s player_stunned=%s posture=%.1f/%.1f" % [str(player_hit), str(b.player.is_stunned), b.enemy.posture_current, posture0])

	# --- Case C: legacy AI (ai_brain=null) block opens NO parry window over many frames ---
	var c := _setup("bandit_swordsman"); var cs3 := CombatSystemScript.new()
	c.enemy.ai_brain = null
	var ever_parried := false; var ever_blocked := false
	for _f in range(180):
		if not c.player._attack_state.is_active(): c.player.start_light_attack()
		cs3.update_player(c.player, {}, DT, c.enemy)
		cs3.update_ai(c.enemy, c.player, DT)
		if c.enemy.is_parrying(): ever_parried = true
		if c.enemy.is_blocking: ever_blocked = true
	if ever_blocked and not ever_parried:
		passed += 1
	else:
		failed += 1; failures.append("C: legacy AI block ran=%s and must never parry (ever_parried=%s)" % [str(ever_blocked), str(ever_parried)])

	return {"passed": passed, "failed": failed, "failures": failures}
```
Register in `run_tests.gd`. (`CombatEventRecorder.record_hit` carries `blocked`/`parried`; parry path also calls `record_stun(attacker)` — Case B asserts neither fires.)

- [ ] **Step 2: Run → fail** — `./run.sh --test` → `test_enemy_block_no_parry` FAILS (current code calls `trigger_parry_window()` on block, so `is_parrying()` is true).

- [ ] **Step 3: Implement** — in `WUGodot/scripts/combat_system.gd`, remove the parry-window call from **both** AI block branches. In `_execute_ai_action` (the `"block"` case, ~228-230):

```gdscript
		"block":
			ai.is_blocking = true
			# (removed) ai.trigger_parry_window()  -- reactive block is block-only
```
and in `_execute_legacy_ai` (the block branch, ~258-260):

```gdscript
				ai.is_blocking = true
				# (removed) ai.trigger_parry_window()  -- reactive block is block-only
			else:
				ai.is_blocking = false
```
Leave the player path (`update_player` `block_pressed` → `trigger_parry_window`, ~80-81) untouched — the *player* still parries.

- [ ] **Step 4: Run → pass** — `./run.sh --test` → `failed: 0`.

- [ ] **Step 5: Record code-only effect** — re-run the probe + harness from Task 2 into the results doc under "## Code-only (after Lever 3)": `blocked_pressure_break_light` should now reflect posture loss (no parry), and confirm a player attacking a blocking enemy bleeds its posture. Note the win/skill deltas (often small — the big shift comes from Task 4).

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/combat_system.gd WUGodot/tests/test_enemy_block_no_parry.gd WUGodot/tests/run_tests.gd docs/superpowers/specs/2026-06-24-combat-feel-rebalance-results.md
git commit -m "fix(combat): enemy reactive block is block-only (no auto parry window)"
```

---

## Task 4: Rebalance tuning (data) — guided iterative loop ✋

**Files:** `WUGodot/data/Attacks/Attacks.json`, `WUGodot/data/Enemies/*.json`, `WUGodot/data/Settings/GameSettings.json`

Balance is judgment, not a unit test. This task is an **iterate-measure-judge loop** against the spec's duel-ratio targets, ending in a user STOP. Make **small, recorded** changes; re-measure after each.

- [ ] **Step 1: Curb the HP race (lever 1).** Adjust so posture-break is the *efficient* kill: raise enemy HP and/or lower player attack `damage` (shift weight toward `posture_damage`) in `Attacks.json`/`Enemies`. Target: `hits_to_hp_kill_light` goes **up** (≤ ~1.5× baseline, no sponge) while a break→punish line kills **faster** than pure HP. Re-run `./run.sh --probe-duel-ratios`.
- [ ] **Step 2: Punish facetank (lever 2).** Raise enemy offense — **authored attack `damage`/`posture_damage` live in `Attacks.json`** (e.g. `bandit_slash`, `bandit_overhead`); **`Enemies/*.json` controls aggression / `blockChance` / ranges / HP / posture / pools**. Tune both, and ensure tougher archetypes use **perilous** (`is_parryable:false`) attacks. Target: standing-and-trading bleeds the player out.
- [ ] **Step 3: Keep posture tier-relative (lever 5).** Verify `parries_to_break` stays ~2 weak / ~2–3 ronin·disciple / higher for `iron_bear` — **don't flatten posture** across the roster. Tune per-archetype `postureMax`/recovery only as needed.
- [ ] **Step 4: Dogfood both playstyles (daemon).** Start a session (`./run.sh --playtest-daemon --session cfr-tune`) and drive: (a) a **parry-duel** fight (parry→break→punish reads, build burst lands in the stun), and (b) an **aggressive-dash** fight that wins **without parrying** (dash perilous, pressure posture). Both must be winnable. Capture a screenshot of a posture-break punish.
- [ ] **Step 5: Re-measure harness** — re-run the Task-2 harness commands. Iterate Steps 1–4 until: skill-sweep **no longer inverted** (win non-decreasing with skill; facetank/low-skill win drops from ~0.72), overall win ~0.5, difficulty curve intact (`check_difficulty_curve.py` accepted), **zero timeouts**, and the duel-ratio targets met.
- [ ] **Step 6: Commit each iteration** — `git commit -m "balance(combat): <what changed> (iter N)"`, updating the results doc's "## Tuning iterations" with the numbers each time.

> **✋ STOP — present results to the user** (duel-ratio before/after, skill-sweep before/after, dogfood screenshots/notes for both playstyles) for a balance verdict before finalizing.

---

## Task 5: Acceptance + record

**Files:** `docs/superpowers/specs/2026-06-24-combat-feel-rebalance-results.md`

- [ ] **Step 1: Final acceptance run** — full harness suite (greedy, skill-sweep, `check_difficulty_curve.py`) + `./run.sh --probe-duel-ratios`; confirm every acceptance criterion from the spec's Validation + Duel-ratio gate.
- [ ] **Step 2: Record** — fill the results doc with **baseline → code-only → final** tables and the chosen knob values; note any criterion not met + why.
- [ ] **Step 3: Verify suite green** — `./run.sh --import && ./run.sh --test` → `failed: 0`.
- [ ] **Step 4: Commit** — `git commit -m "docs: combat rebalance final results + tuned knobs"`.

---

## Self-Review

**Spec coverage:**
- Lever 1 (curb HP race) → Task 4 Step 1. Lever 2 (punish facetank/perilous) → Task 4 Step 2. **Lever 3 (block-only, both sites, test)** → Task 3. Lever 4 (no turtling, 1.5×) → preserved (untouched) + verified in dogfood. Lever 5 (tier-relative parry) → Task 4 Step 3.
- Multi-path principle (parry not mandatory; aggressive-dash viable) → Task 4 Step 4 (both playstyles dogfooded + must win).
- Duel-ratio gate (per-archetype table, no sponge/flatten) → Task 1 (probe) + Task 4 targets.
- Validation: harness skill-sweep un-inverts + difficulty intact → Tasks 2/4/5; daemon dogfooding → Task 4 Step 4; heuristic-already-parries premise → respected (player path untouched in Task 3).
- Phase order (baseline BEFORE lever 3) → Tasks 2 then 3. Record baseline→code-only→final → results doc across Tasks 2/3/5.
- Out of scope (payoff/deathblow, per-school hooks, scripted policies) → not implemented.

**Placeholder scan:** code shown for the probe + lever-3 test; Task 4 is intentionally an iterative tuning loop (balance can't be unit-tested) with concrete knobs/targets/commands + a STOP, not vague "tune it."

**Type consistency:** `probe_duel_ratios.gd` hit/parry metrics return `{count, timeout}` (test reads `["count"]`/`["timeout"]`); `posture_path` returns `{hits_to_break, dmg_in_stun, swings_to_kill, duration, timeout}`. Break is detected via `is_stunned` (not `posture<=0`) everywhere, matching `apply_posture_damage`'s reset-on-break. `parryPostureDamage` read from `DataManager.get_game_settings()`. `is_parrying()`/`is_blocking`/`trigger_parry_window()`/`apply_posture_damage()`/`update_timers()`/`resolve_hits()` match `combat_system.gd`/`fighter.gd`; recorder `record_hit(...,blocked,parried,...)`/`record_stun` per `combat_event_recorder.gd`. Both lever-3 sites cited (`_execute_ai_action` ~228-230, `_execute_legacy_ai` ~258-260).
