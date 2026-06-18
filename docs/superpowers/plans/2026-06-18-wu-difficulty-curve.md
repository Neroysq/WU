# WU Difficulty Curve (Chapter 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a chapter-1 run ramp easy→hard with depth via enemy **composition** (weak→strong pool gate + elite tier + boss), no stat inflation — validated by harness win-rate-by-depth telemetry.

**Architecture:** A data-driven `DifficultyCurve.json` defines weak/strong/elite pools + a `weak_count` gate + per-tier node-type weights. A new `EncounterResolver` selects the archetype per fight and flows it through the **existing `forced_archetype`** path (live `main._setup_combat_for_node`; harness `run_driver`→`combat_sim`). `run_state.normal_combats_started` (pre-increment, normal-only) drives the gate. Telemetry links each combat to node/ordinal/pool/wave.

**Tech Stack:** Godot 4.6.2 GDScript. Headless tests `./run.sh --test`; harness `./run.sh --playtest-batch`. Spec: `docs/superpowers/specs/2026-06-18-wu-difficulty-curve-design.md`.

**Verification (every task):** `./run.sh --test 2>&1 | tail -3` → `failed: 0`; `./run.sh --import` clean. Register new `test_*.gd` in `WUGodot/tests/run_tests.gd` `_TEST_MODULES`. Commit `feat(difficulty):` / `data(difficulty):`. End commits with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File Structure

**Create:**
- `WUGodot/data/Difficulty/DifficultyCurve.json` — chapter pools + weak_count + node-type weights + ambush config.
- `WUGodot/scripts/encounter_resolver.gd` — `begin_encounter(run_state, node, wave) -> {archetype, pool_class, normal_combat_ordinal, ambush_wave}` (selects + mutates run_state once).
- `WUGodot/tools/check_difficulty_curve.py` — assert harness batch acceptance thresholds.
- `WUGodot/tests/test_encounter_resolver.gd`, `test_difficulty_runstate.gd`.

**Modify:**
- `WUGodot/scripts/data_manager.gd` — load `DifficultyCurve.json` + getter.
- `WUGodot/scripts/run_state.gd` — `normal_combats_started` counter; `_pick_node_type` reads node-type weights.
- `WUGodot/scripts/main.gd` — `_setup_combat_for_node` resolves archetype, passes `forced_archetype` into `combat_scene.setup_combat`.
- `WUGodot/scripts/sim/run_driver.gd` + `combat_sim.gd` + `combat_result.gd` — resolver call + encounter telemetry fields.
- `WUGodot/scripts/enemy_factory.gd` — `_pick_archetype_for_node` becomes a thin fallback (resolver is primary); seed via `RngService`.

---

# Phase 1 — Data + resolver

### Task 1: `DifficultyCurve.json` + loader

**Files:** Create `WUGodot/data/Difficulty/DifficultyCurve.json`; Modify `data_manager.gd`; Test `test_encounter_resolver.gd`

- [ ] **Step 1: Failing test** — `DataManager.get_difficulty_curve(1)` returns a dict with `weak_pool`, `strong_pool`, `elite_pool` (containing `masked_assassin`, NOT in `strong_pool`), `boss == "iron_bear"`, `weak_count == 1`, and an `archetype_rank` map; **and it works COLD** — calling it (or `RunState.create_procedural_run`) without `DataManager.initialize()` (as `test_map_generator.gd` does) returns a usable curve, not `{}` (reviewer P2).
- [ ] **Step 2:** Register test in `run_tests.gd`; run → FAIL.
- [ ] **Step 3: Implement** — write `DifficultyCurve.json` (dict root, mirror existing loaders):
```json
{ "chapters": [ { "chapter": 1,
  "weak_pool": ["bandit_swordsman", "bandit_spearman"],
  "strong_pool": ["wandering_ronin", "sect_disciple"],
  "elite_pool": ["sect_disciple", "masked_assassin"],
  "boss": "iron_bear",
  "weak_count": 1,
  "no_immediate_repeat": true,
  "archetype_rank": {"bandit_spearman":1,"bandit_swordsman":1,"wandering_ronin":2,"sect_disciple":3,"masked_assassin":4,"iron_bear":9},
  "ambush": { "length_by_tier": {"1":3,"4":4}, "escalate": true },
  "node_type_weights_by_tier": {
    "1": {"BATTLE":100},
    "2": {"BATTLE":70,"ELITE":15,"AMBUSH":15,"SHOP":0},
    "4": {"BATTLE":45,"ELITE":30,"AMBUSH":25} } } ] }
```
In `data_manager.gd`, add `get_difficulty_curve(chapter:int) -> Dictionary` that **lazy-loads** the file on first call (like the attacks lazy-load) and returns a built-in **default curve** if the file is missing/cold — so `RunState`/`_pick_node_type` never get `{}` in headless tests. Also load in `initialize()`/`reload_data()` for the live path.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `data(difficulty): chapter-1 difficulty curve + loader`.

### Task 2: `EncounterResolver.begin_encounter` (single select + mutate)

**Files:** Create `WUGodot/scripts/encounter_resolver.gd`; Test `test_encounter_resolver.gd`

**Reviewer P1:** make selection **and** the state mutation (counter + last_archetype) happen in **one shared call** so live and harness can't diverge. The call sites never mutate run_state themselves.

- [ ] **Step 1: Failing tests** — `EncounterResolver.begin_encounter(run_state, node, wave)` returns `{archetype, pool_class, normal_combat_ordinal, ambush_wave}` AND mutates run_state: for a BATTLE node with `normal_combats_started==0`, `weak_count==1` → `pool_class=="weak"`, archetype ∈ weak_pool, `normal_combat_ordinal==0`, and **after the call** `normal_combats_started==1`; a second call → `"strong"` ∈ strong_pool, ordinal 1; an ELITE/BOSS call → `"elite"`/`"boss"` and **does NOT** advance `normal_combats_started`; **anti-repeat is per-pool** (reviewer P2) — two consecutive *same-pool* calls don't repeat an archetype, but an elite `sect_disciple` must NOT suppress the next strong `sect_disciple` (it's in both pools); seeded `RngService` ⇒ reproducible.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — a pure `_select(c, run_state, node, wave) -> {archetype, pool_class}` (boss/elite/weak-vs-strong via `run_state.normal_combats_started < weak_count`, ambush escalation by rank — Task 1), plus the public mutator:
```gdscript
static func begin_encounter(run_state, node, wave: int = 0) -> Dictionary:
    var c := DataManager.get_difficulty_curve(run_state.chapter)
    var sel := _select(c, run_state, node, wave)          # reads pre-increment counter
    var ordinal := run_state.normal_combats_started
    if sel.pool_class in ["weak", "strong"]:
        run_state.normal_combats_started += 1             # normal-only, once
    run_state.last_archetype_by_pool[sel.pool_class] = sel.archetype   # per-pool memory
    return {"archetype": sel.archetype, "pool_class": sel.pool_class,
            "normal_combat_ordinal": ordinal, "ambush_wave": wave}
```
`_select` honors **per-pool** anti-repeat (avoid `run_state.last_archetype_by_pool.get(pool_class, "")` — not a global last, so a shared archetype like `sect_disciple` isn't suppressed across pools). Add `chapter:int=1`, `normal_combats_started:int=0`, `last_archetype_by_pool:Dictionary={}` to `RunState`.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(difficulty): EncounterResolver.begin_encounter (select+mutate once)`.

### Task 3: Wire resolver into live + harness via `forced_archetype`

**Files:** Modify `main.gd` (`_setup_combat_for_node`), `sim/run_driver.gd`, `sim/combat_sim.gd`; Test `test_difficulty_runstate.gd`

- [ ] **Step 1: Failing test** — driving a combat node through `run_driver`, the fight's `CombatResult.enemy_archetype` equals the archetype that `begin_encounter(...)` produced for that node/ordinal (assert the resolved archetype reaches the fight). `enemy_factory.create_enemy_for_node` is no longer the decision-maker for resolved paths.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — both sites call **`begin_encounter`** (which mutates run_state once) and pass `result.archetype` as `forced_archetype`; **neither site touches the counter/last_archetype itself** (reviewer P1). Live: `main._setup_combat_for_node` (~`main.gd:184`) → `begin_encounter(run_state, node, wave)` → `combat_scene.setup_combat(..., forced_archetype=result.archetype)`. Harness: `run_driver._resolve_combat_node` → `begin_encounter(...)` before each `sim.simulate(...)`. **Per ambush wave:** the ambush re-combat loop (both sites) calls `begin_encounter` again each wave with the wave index (`ambush_length − ambush_remaining`). Keep `enemy_factory._pick_archetype_for_node` as a seeded fallback only. Stash the returned `{pool_class, normal_combat_ordinal, ambush_wave}` for telemetry (Task 6).
- [ ] **Step 4:** Run → PASS (existing combat/scene tests green).
- [ ] **Step 5: Commit** — `feat(difficulty): resolve archetype at live+harness call sites`.

---

# Phase 2 — Counter + node mix

### Task 4: end-to-end counter semantics through the driver

**Files:** Test `test_difficulty_runstate.gd` (the `RunState` fields + mutation live in Task 2's `begin_encounter`)

- [ ] **Step 1: Failing tests (integration)** — drive a full run via `run_driver` and assert end-to-end (not just the unit helper): across a seeded run, the **first** normal fight is `weak`, the **second** `strong`; an **elite/boss** between two normals does **not** shift the normal ordinal; a **3-wave ambush** advances `normal_combats_started` by 3 and yields `ambush_wave` 0,1,2. (Catches a call site that forgot to route through `begin_encounter` or double-counts.)
- [ ] **Step 2:** Run → FAIL (until Task 3's wiring routes every fight, incl. ambush waves, through `begin_encounter`).
- [ ] **Step 3: Fix wiring** as needed so all combats (live + harness, incl. each ambush wave) go through `begin_encounter` exactly once.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `test(difficulty): end-to-end counter semantics`.

### Task 5: Node-type mix + ambush by tier

**Files:** Modify `run_state.gd` (`_pick_node_type`), `run_flow.gd`/ambush setup; Test `test_difficulty_runstate.gd`

- [ ] **Step 1: Failing tests** — `_pick_node_type` honors `node_type_weights_by_tier` (tier 1 → only BATTLE; tier 4 → ELITE/AMBUSH possible); a generated map has more elite/ambush at tier 4 than tier 1 (statistically, over seeds); ambush length follows `length_by_tier` (tier 4 ambush longer than tier 1).
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — `_pick_node_type(rng, tier, idx)` reads the curve's `node_type_weights_by_tier[str(tier)]` (weighted pick) instead of hardcoded logic; set `ambush_remaining` from `ambush.length_by_tier[str(tier)]` when creating AMBUSH nodes. Seed via `RngService.stream("map")`.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(difficulty): per-tier node-type weights + ambush length`.

---

# Phase 3 — Telemetry linkage

### Task 6: encounter fields on `CombatResult`

**Files:** Modify `sim/combat_result.gd`, `sim/combat_sim.gd`, `sim/run_driver.gd`; Test `test_combat_sim.gd`

- [ ] **Step 1: Failing test** — a simulated fight's `CombatResult.to_dict()` includes `node_id`, `normal_combat_ordinal`, `pool_class` (weak/strong/elite/boss), and `ambush_wave`, matching the resolver/run-state values for that fight; a 3-wave ambush yields three combats with `ambush_wave` 0,1,2 and increasing `normal_combat_ordinal`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — add the four fields to `CombatResult` + `to_dict()`; thread them via an `encounter` dict param on `sim.simulate(player, node, policy, max, encounter, seed)` (the resolver result + ordinal + wave), set on the result. `run_driver` builds the `encounter` dict from the resolver + counter.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(difficulty): combat telemetry (node/ordinal/pool/wave)`.

---

# Phase 4 — Validation + tune

### Task 7: Structure tests

**Files:** `test_encounter_resolver.gd`, `test_difficulty_runstate.gd`

- [ ] **Step 1: Tests** — over many seeded resolves: (a) **no weak-pool archetype** appears at `normal_combat_ordinal >= weak_count`; (b) `masked_assassin` appears **only** from elite resolves; (c) **enemy stats are unchanged** vs `data/Enemies/*.json` (no inflation — assert a resolved enemy's `health_max` equals its archetype data); (d) ambush waves escalate by **`archetype_rank`** (a later wave's chosen archetype has rank ≥ the earlier wave's — a deterministic strength order, not a shaky array index; reviewer P2).
- [ ] **Step 2–4:** Run → PASS; commit `test(difficulty): structure gates`.

### Task 8: Harness acceptance check

**Files:** Create `WUGodot/tools/check_difficulty_curve.py`; uses `run.sh --playtest-batch`

- [ ] **Step 1:** `check_difficulty_curve.py <batch_summary.json>` **computes its own metrics from `summary.transcripts[].combats[]`** (which carry `normal_combat_ordinal`/`tier`/`pool_class`/`node_id`/`winner` after Task 6 — today's `BatchRunner` only emits aggregates, so derive per-ordinal/tier/pool win rates and death-share-by-node in the script; alternatively extend `batch_runner.gd` to emit `win_rate_by_normal_ordinal`/`by_tier`/`by_pool_class`). Assert: **win-rate by `normal_combat_ordinal` is non-rising within ±5 pp** across mid-depth. **Boss metric (reviewer P1):** boss win rate conditional on *reaching* the boss is **biased upward** (only strong runs get there), so it is **report-only, never a gate**. The boss **gate is death-share**: the boss node has the **highest death share of any reached node**. **`tier`-1 deaths < 20%** of all deaths. Exit non-zero on violation. (Gates: ordinal win-rate non-rising ±5pp · boss = highest death share · tier-1 deaths < 20%. The conditional boss win rate is printed for context only.)
- [ ] **Step 2: Run** — `./run.sh --playtest-batch --seeds 1..50 --player heuristic --decision greedy --out /tmp/curve.json` then `python3 WUGodot/tools/check_difficulty_curve.py /tmp/curve.json` (reviewer P3 — path under `WUGodot/tools/`).
- [ ] **Step 3: Commit** — `feat(difficulty): harness acceptance check`.

### Task 9: Tune to the curve

- [ ] **Step 1:** Iterate `DifficultyCurve.json` knobs (weak_count, node-type weights, ambush length, strong/elite membership) and re-run Task 8 until acceptance passes. If it **cannot** pass with composition alone (win rate rises with depth), record it and escalate per spec §6 (more archetypes, or the cross-chapter stat lever) — **do not** add chapter-1 stat inflation silently.
- [ ] **Step 2: Commit** — `data(difficulty): tuned chapter-1 curve (harness-accepted)` with the batch summary noted in the message.

---

## Self-Review

- **Spec coverage:** pools+gate+`archetype_rank`+cold-safe loader (Task 1), `begin_encounter` single select+mutate (Task 2), wired at both call sites via forced_archetype incl. per-ambush-wave (Task 3), end-to-end counter semantics (Task 4), per-tier node mix + ambush length (Task 5), telemetry node/ordinal/pool/wave (Task 6), structure gates incl. no-inflation + elite-only assassin + rank-escalation (Task 7), harness acceptance from transcripts with selection-robust boss metric (Task 8), harness-gated escalation not silent inflation (Task 9).
- **No placeholders:** `begin_encounter` + data shown; node-type weights are data (tuned in Task 9), gated by tests.
- **Type consistency:** `EncounterResolver.begin_encounter(run_state, node, wave) -> {archetype, pool_class, normal_combat_ordinal, ambush_wave}` (selects on pre-increment, mutates once), `run_state.normal_combats_started` (normal-only), `sim.simulate(..., encounter, seed)`, CombatResult `node_id/normal_combat_ordinal/pool_class/ambush_wave`.
- **Load-bearing (reviewer P1):** **all** mutation lives in `begin_encounter` (one shared call) — call sites never touch the counter, so live and harness can't drift; every fight incl. each ambush wave routes through it exactly once (Task 4 integration test guards this); Task 7(c) guards against accidental stat inflation; Task 8 metrics derive from per-combat transcript fields and treat the boss death-share (not the selection-biased conditional win rate) as primary.
