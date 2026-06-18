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
- `WUGodot/scripts/encounter_resolver.gd` — `resolve(run_state, node, wave) -> {archetype, pool_class}`.
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

- [ ] **Step 1: Failing test** — `DataManager.get_difficulty_curve(1)` returns a dict with `weak_pool`, `strong_pool`, `elite_pool` (containing `masked_assassin`, NOT in `strong_pool`), `boss == "iron_bear"`, `weak_count == 1`.
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
  "ambush": { "length_by_tier": {"1":3,"4":4}, "escalate": true },
  "node_type_weights_by_tier": {
    "1": {"BATTLE":100},
    "2": {"BATTLE":70,"ELITE":15,"AMBUSH":15,"SHOP":0},
    "4": {"BATTLE":45,"ELITE":30,"AMBUSH":25} } } ] }
```
In `data_manager.gd`, load it in `initialize()` (read `root.get("chapters", [])`), add `get_difficulty_curve(chapter:int) -> Dictionary`. Add to `reload_data()`.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `data(difficulty): chapter-1 difficulty curve + loader`.

### Task 2: `EncounterResolver.resolve`

**Files:** Create `WUGodot/scripts/encounter_resolver.gd`; Test `test_encounter_resolver.gd`

- [ ] **Step 1: Failing tests** — `EncounterResolver.resolve(run_state, node, wave)` returns `{archetype, pool_class}`: for a BATTLE node with `run_state.normal_combats_started == 0` and `weak_count == 1` → `pool_class == "weak"` and archetype ∈ weak_pool; with `normal_combats_started == 1` → `"strong"` ∈ strong_pool; ELITE node → `"elite"` ∈ elite_pool (never `masked_assassin` in a weak/strong result); BOSS → `{"iron_bear","boss"}`. Anti-repeat: two consecutive weak resolves don't return the same archetype. Determinism: seeded `RngService` ⇒ reproducible.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — `resolve(run_state, node, wave)`:
```gdscript
static func resolve(run_state, node, wave: int = 0) -> Dictionary:
    var c: Dictionary = DataManager.get_difficulty_curve(run_state.chapter)
    var rng = RngService.stream("enemy_pick")
    match node.node_type:
        MapNode.NodeType.BOSS: return {"archetype": c["boss"], "pool_class": "boss"}
        MapNode.NodeType.ELITE: return {"archetype": _pick(c["elite_pool"], rng, run_state), "pool_class": "elite"}
        _:
            var weak: bool = run_state.normal_combats_started < int(c["weak_count"])
            var pool: Array = c["weak_pool"] if weak else c["strong_pool"]
            return {"archetype": _pick(pool, rng, run_state, c.get("no_immediate_repeat", true)), "pool_class": "weak" if weak else "strong"}
```
`_pick` honors anti-repeat (avoid `run_state.last_archetype`); wave can bias escalation within ambush (later waves prefer the tougher end of the pool). **Selection uses the pre-increment counter; the increment happens at the call site (Task 4).** Add `chapter` to `RunState` (default 1).
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(difficulty): EncounterResolver (weak/strong/elite/boss)`.

### Task 3: Wire resolver into live + harness via `forced_archetype`

**Files:** Modify `main.gd` (`_setup_combat_for_node`), `sim/run_driver.gd`, `sim/combat_sim.gd`; Test `test_difficulty_runstate.gd`

- [ ] **Step 1: Failing test** — driving a combat node through `run_driver` produces an enemy whose archetype equals `EncounterResolver.resolve(...)`'s for that node/ordinal (assert the resolved archetype reaches the fight). `enemy_factory.create_enemy_for_node` is no longer the decision-maker for resolved paths.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — live: in `main._setup_combat_for_node` (~`main.gd:184`, has `run_state`), call `EncounterResolver.resolve(run_state, node, wave)` and pass `result.archetype` as `forced_archetype` into `combat_scene.setup_combat(...)`. Harness: in `run_driver._resolve_combat_node`, resolve before each `sim.simulate(...)` and pass the archetype as the `forced_archetype` arg (already a param). Keep `enemy_factory._pick_archetype_for_node` as a seeded fallback only.
- [ ] **Step 4:** Run → PASS (existing combat/scene tests green).
- [ ] **Step 5: Commit** — `feat(difficulty): resolve archetype at live+harness call sites`.

---

# Phase 2 — Counter + node mix

### Task 4: `normal_combats_started` gate counter

**Files:** Modify `run_state.gd`, `run_driver.gd`, `main.gd`; Test `test_difficulty_runstate.gd`

- [ ] **Step 1: Failing tests** — with `weak_count==1`: the **first** normal fight resolves `weak`, the **second** normal fight resolves `strong`; an **elite** or **boss** fight does **not** advance the counter (a normal fight after an elite still uses the right ordinal); each **ambush wave** advances it (3-wave ambush consumes 3 ordinals).
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — add `normal_combats_started: int = 0` to `RunState` + `last_archetype: String`. At each call site, the order is: **resolve (reads pre-increment value) → if `pool_class in ["weak","strong"]`, `run_state.normal_combats_started += 1`** and set `last_archetype`. Increment per ambush **wave** (the `run_driver` ambush loop and the live ambush re-combat path), not on node-clear. Elite/boss never increment.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(difficulty): normal-combat gate counter (pre-increment, normal-only)`.

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

- [ ] **Step 1: Tests** — over many seeded resolves: (a) **no weak-pool archetype** appears at `normal_combat_ordinal >= weak_count`; (b) `masked_assassin` appears **only** from elite resolves; (c) **enemy stats are unchanged** vs `data/Enemies/*.json` (no inflation — assert a resolved enemy's `health_max` equals its archetype data); (d) ambush waves escalate (later wave's pool index ≥ earlier).
- [ ] **Step 2–4:** Run → PASS; commit `test(difficulty): structure gates`.

### Task 8: Harness acceptance check

**Files:** Create `WUGodot/tools/check_difficulty_curve.py`; uses `run.sh --playtest-batch`

- [ ] **Step 1:** `check_difficulty_curve.py <batch_summary.json>` asserts the §5 thresholds: mid-depth win rate non-rising within ±5 pp; **boss win rate ≥10 pp below the pre-boss rate (or highest death share)**; **tier-1 deaths < 20%** of all deaths. Exit non-zero on violation.
- [ ] **Step 2: Run** — `./run.sh --playtest-batch --seeds 1..50 --player heuristic --decision greedy --out /tmp/curve.json` then `python3 tools/check_difficulty_curve.py /tmp/curve.json`.
- [ ] **Step 3: Commit** — `feat(difficulty): harness acceptance check`.

### Task 9: Tune to the curve

- [ ] **Step 1:** Iterate `DifficultyCurve.json` knobs (weak_count, node-type weights, ambush length, strong/elite membership) and re-run Task 8 until acceptance passes. If it **cannot** pass with composition alone (win rate rises with depth), record it and escalate per spec §6 (more archetypes, or the cross-chapter stat lever) — **do not** add chapter-1 stat inflation silently.
- [ ] **Step 2: Commit** — `data(difficulty): tuned chapter-1 curve (harness-accepted)` with the batch summary noted in the message.

---

## Self-Review

- **Spec coverage:** weak/strong/elite/boss pools + gate (Task 1/2), resolver boundary via forced_archetype live+harness (Task 3), normal-only pre-increment counter (Task 4), per-tier node mix + ambush length (Task 5), telemetry node/ordinal/pool/wave (Task 6), structure gates incl. no-inflation + elite-only assassin (Task 7), harness acceptance thresholds (Task 8), harness-gated escalation not silent inflation (Task 9).
- **No placeholders:** resolver + counter + data shown; node-type weights are data (tuned in Task 9), gated by tests.
- **Type consistency:** `EncounterResolver.resolve(run_state, node, wave) -> {archetype, pool_class}`, `run_state.normal_combats_started` (pre-increment, normal-only), `sim.simulate(..., encounter, seed)`, CombatResult `node_id/normal_combat_ordinal/pool_class/ambush_wave`.
- **Load-bearing:** Task 3 must route BOTH live and harness through the resolver (no divergence); Task 4 increment is normal-only and per-ambush-wave (the off-by-one/scope fix); Task 7(c) guards against accidental stat inflation.
