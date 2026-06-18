# WU Agent Playtest Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A scene-free, deterministic, agent-drivable harness that autoplays seeded WU runs/combat, emits structured telemetry, and captures arbitrary visual states — so agents can playtest gameplay and visuals without a human.

**Architecture:** A single run-seed flows through `RngService` (cached per-domain streams) into the existing combat/run logic. `CombatSetup` (extracted from the scene) is shared by scene + sim. `CombatSim` loops `combat_system` at fixed dt; `RunDriver` walks a seeded `RunState`, resolving combats via `CombatSim` and choices via `PlayerPolicy`/`DecisionPolicy` through the existing RefCounted services. Telemetry is JSON; a thin `VisualCapture` layer reuses the `--shot` viewport readback.

**Tech Stack:** Godot 4.6.2, GDScript. New code under `WUGodot/scripts/sim/`. Headless via `run.sh`. Spec: `docs/superpowers/specs/2026-06-18-wu-playtest-harness-design.md`.

**Verification (every task):** `./run.sh --test 2>&1 | tail -3` → `failed: 0`; `./run.sh --import 2>&1 | grep -ciE "^ERROR|SCRIPT ERROR"` → `0`. Register every new `test_*.gd` in `WUGodot/tests/run_tests.gd` `_TEST_MODULES`. Commit `feat(sim):`; end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File Structure

**Create:**
- `WUGodot/scripts/sim/rng_service.gd` — cached per-domain seeded RNG streams.
- `WUGodot/scripts/sim/combat_setup.gd` — shared gameplay-side matchup setup.
- `WUGodot/scripts/sim/player_policy.gd` (+ `heuristic_player.gd`, `scripted_player.gd`).
- `WUGodot/scripts/sim/decision_policy.gd` (+ `random_policy.gd`, `greedy_synergy_policy.gd`, `school_focused_policy.gd`, `scripted_policy.gd`).
- `WUGodot/scripts/sim/combat_sim.gd`, `combat_result.gd`.
- `WUGodot/scripts/sim/run_driver.gd`, `run_transcript.gd`, `batch_runner.gd`.
- `WUGodot/scripts/sim/playtest_main.gd` — headless CLI entry (mirrors `tests/run_tests.gd`).
- `WUGodot/scripts/sim/visual_capture.gd`.
- `WUGodot/tests/test_rng_service.gd`, `test_combat_setup.gd`, `test_player_policy.gd`, `test_decision_policy.gd`, `test_combat_sim.gd`, `test_run_driver.gd`, `test_apply_choices.gd`.
- `docs/PLAYTEST.md` — agent usage guide.

**Modify (gameplay RNG owners → `RngService.stream`):** `ai_brain.gd`, `combat_system.gd`, `technique_engine.gd`, `enemy_factory.gd`, `run_state.gd`, `boon_offer.gd`, `run_flow.gd`, `event_runner.gd`, `shop_generator.gd`, reward generation. **Modify (extract):** `combat_scene.gd` (→ `CombatSetup`), `scenes/shop_scene.gd` + `scenes/rest_scene.gd` (→ pure `apply_*`). **Modify (CLI):** `run.sh`, `main.gd` (capture flag).

---

# Phase 1 — Determinism foundation

### Task 1: `RngService` (cached per-domain streams)

**Files:** Create `WUGodot/scripts/sim/rng_service.gd`; Test `WUGodot/tests/test_rng_service.gd`

- [ ] **Step 1: Failing tests** — (a) with no run-seed, two `stream("ai")` calls return the **same instance** (cached) and produce a varying sequence; (b) after `set_run_seed(7)`, `stream("ai")` is reproducible: capture 5 `randi()`, call `set_run_seed(7)` again, the next 5 match; (c) different domains produce different sequences for the same seed; (d) **a single domain stream advances across calls** (two sequential `randi()` differ — NOT re-seeded per call).
- [ ] **Step 2:** Register test in `run_tests.gd`; run → FAIL.
- [ ] **Step 3: Implement**:
```gdscript
class_name RngService
extends RefCounted
static var _seed: int = -1
static var _streams: Dictionary = {}   # domain -> RandomNumberGenerator

static func set_run_seed(s: int) -> void:
    _seed = s
    _streams.clear()

static func clear_run_seed() -> void:
    _seed = -1
    _streams.clear()

static func stream(domain: String) -> RandomNumberGenerator:
    if _streams.has(domain):
        return _streams[domain]
    var r := RandomNumberGenerator.new()
    if _seed >= 0:
        r.seed = hash("%d:%s" % [_seed, domain])
    else:
        r.randomize()
    _streams[domain] = r
    return r
```
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(sim): RngService cached per-domain streams`.

### Task 2: Migrate gameplay RNG owners to `RngService.stream`

**Files:** Modify `ai_brain.gd`, `combat_system.gd`, `technique_engine.gd`, `enemy_factory.gd`, `run_state.gd`, `boon_offer.gd`, `run_flow.gd`, `event_runner.gd`, `shop_generator.gd` (+ reward gen); Test `WUGodot/tests/test_rng_service.gd`

- [ ] **Step 1: Failing test** — with `RngService.set_run_seed(42)`: two fresh `EnemyFactory.create_enemy_for_node(node)` (same node) pick the **same archetype**; `RunState.create_procedural_run(42)` twice yields identical node-type sequences; a boon offer for a fixed school+depth is identical. (Assert reproducibility end-to-end through the migrated owners.)
- [ ] **Step 2:** Run → FAIL (owners still self-randomize).
- [ ] **Step 3: Implement** — replace each `RandomNumberGenerator.new(); _rng.randomize()` (and `_pick_archetype_for_node`'s local `randomize()`, `run_state`'s seed handling, `boon_offer`/`run_flow`/`event_runner`/`shop_generator`/reward RNGs) with `_rng = RngService.stream("<domain>")` using stable domain names (`"ai"`, `"combat"`, `"effects"`, `"enemy_pick"`, `"map"`, `"boon_offer"`, `"school"`, `"event"`, `"shop"`, `"reward"`). **Enumerate every site**; for cosmetic FX (`damage_number_system`, `camera_2d_helper`) leave as-is and add a code comment `# FX-only: out of deterministic-sim scope`. Normal play unchanged (no seed ⇒ randomized).
- [ ] **Step 4:** Run → PASS (+ all existing tests green — combat/AI/technique behavior must not change).
- [ ] **Step 5: Commit** — `feat(sim): route gameplay RNGs through RngService`.

### Task 3: Fixed-dt step helper

**Files:** Modify `combat_system.gd` (confirm dt-injectable) or add a thin stepper in `combat_sim.gd` (Task 9); Test covered by Task 9

- [ ] **Step 1:** Confirm `combat_system.update_player(fighter, input, dt, enemy)` / `update_ai(...)` already take an explicit `dt` (they do — `dt` is a param). No change needed beyond *calling them with `dt = 1.0/60.0` in a loop* (done in `CombatSim`). If any per-frame logic reads real time instead of `dt`, fix it to use `dt`.
- [ ] **Step 2–5:** No standalone task if dt is already a param; otherwise add a failing test that stepping N times with `dt=1/60` advances `animation_timer` by `N/60`, fix, commit `feat(sim): ensure combat steps on explicit dt`.

---

# Phase 2 — Extractions (representativeness + reuse)

### Task 4: `CombatSetup.prepare` shared by scene + sim

**Files:** Create `WUGodot/scripts/sim/combat_setup.gd`; Modify `combat_scene.gd:setup_combat`; Test `WUGodot/tests/test_combat_setup.gd`

- [ ] **Step 1: Failing test** — `CombatSetup.prepare(player, node, "")` returns `{enemy, ai, boss}` where the enemy matches `EnemyFactory.create_enemy_for_node(node)`'s archetype (seeded), both fighters are `reset_for_combat`, placed/facing correctly, and the AI brain (and boss controller for BOSS nodes) is configured — all **without a scene tree**.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — extract the **gameplay-relevant** half of `setup_combat` into `CombatSetup.prepare`: enemy creation (`create_enemy_by_archetype` if `forced_archetype` else `create_enemy_for_node`), `player.reset_for_combat()` / `enemy.reset_for_combat()`, placement (`player` at start x, `enemy` at preferred range, facing), AI-brain construction, boss-controller for BOSS. Leave visual config (presenter/visual/background/hit-geometry) in `setup_combat`, which now **calls `CombatSetup.prepare` first** then adds visuals. Verify `setup_combat` still works (import + existing scene-controller tests).
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(sim): extract CombatSetup shared by scene+sim`.

### Task 5: Pure `apply_*` choice functions

**Files:** Modify `scenes/shop_scene.gd`, `scenes/rest_scene.gd` (and confirm `event_runner.choose` is already pure); Test `WUGodot/tests/test_apply_choices.gd`

- [ ] **Step 1: Failing test** — `EventRunner.choose(i, fighter)` applies outcome (already pure — assert it); `ShopGenerator.buy_item(item, fighter)` applies a purchase (pure — assert gold/effect); a new `RestService.apply(action, fighter, loadout)` heals/forgets without a scene; and any boon-upgrade buy (currently `ShopScene._buy_boon_upgrade`) is callable as a pure function with a `{fighter, loadout, run_state}` context.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — where apply-logic lives only inside a UI controller (`ShopScene._buy_boon_upgrade`, rest heal/forget in `RestScene`), extract it to a pure static function (`RestService.apply`, `ShopGenerator.buy_boon_upgrade`) and have the controller **call the extracted function** (no duplication). `EventRunner.choose`/`ShopGenerator.buy_item` are already RefCounted services — driver uses them directly.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(sim): pure apply_* choice functions (event/shop/rest)`.

---

# Phase 3 — Policies

### Task 6: `PlayerPolicy` + Heuristic + Scripted

**Files:** Create `player_policy.gd`, `heuristic_player.gd`, `scripted_player.gd`; Test `WUGodot/tests/test_player_policy.gd`

- [ ] **Step 1: Failing tests** — `HeuristicPlayer.next_input(player, enemy, world)` returns a dict with **exactly** the `_build_player_input` keys (`move, jump_pressed, dash_pressed, parry_pressed, light_pressed, heavy_pressed, block_down, block_pressed, stance_pressed`); when the enemy is far it returns `move` toward the enemy; when in range and able, it sets `light_pressed`/`heavy_pressed`; when the enemy is in a perilous windup it blocks/dashes; `skill < 1.0` sometimes withholds reactions (seedable via `RngService.stream("policy")`). `ScriptedPlayer` replays a `[{frame, action}]` list.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — base interface (one method); `HeuristicPlayer` with a `skill: float = 0.8`; `ScriptedPlayer`. Pull range/window facts from `fighter`/`enemy`/`attack_state` the same way `ai_brain` reads them. Define the key set as a shared constant (mirror `combat_scene._build_player_input`).
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(sim): PlayerPolicy (heuristic@0.8 + scripted)`.

### Task 7: `DecisionPolicy` + Random/GreedySynergy/SchoolFocused/Scripted

**Files:** Create `decision_policy.gd` + the 4 impls; Test `WUGodot/tests/test_decision_policy.gd`

- [ ] **Step 1: Failing tests** — `choose(kind, options, loadout, run_state) -> int` returns a valid in-range index for each kind (boon/school/event/shop/rest); `GreedySynergy` prefers options matching held schools / empty slots / upgrades; `SchoolFocused` locks to one school once chosen; `Random` is seeded (`RngService.stream("decision")`); `Scripted` follows a fixed pick list.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** the interface + 4 policies, reading `BoonLoadout` state (`active_schools`, slot fills) for the greedy/school logic.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(sim): DecisionPolicy (random/greedy/school/scripted)`.

---

# Phase 4 — CombatSim + telemetry

### Task 8: `CombatResult` + boon/status instrumentation

**Files:** Create `combat_result.gd`; Modify `technique_engine.gd` (dispatch counters) or add a lightweight `ProcRecorder`; Test in `test_combat_sim.gd`

- [ ] **Step 1: Failing test** — after a simulated fight where a venom boon is active, the `CombatResult.boon_procs` counts the venom effect firing ≥1 and `status_applications["venom"] >= 1`. (No "technique_procs" key.)
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — `CombatResult` (the §5 schema). Add a recorder hooked into the effect dispatch path (increment per effect-hook firing keyed by boon id, and per status applied) — gated so it's only active during sim (a static recorder enabled by `CombatSim`).
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(sim): CombatResult + boon/status proc instrumentation`.

### Task 9: `CombatSim.simulate`

**Files:** Create `combat_sim.gd`; Test `WUGodot/tests/test_combat_sim.gd`

- [ ] **Step 1: Failing tests** — `simulate(player, node, policy, 60.0)` returns a `CombatResult` with a winner; **determinism:** same seed + same policy ⇒ identical `CombatResult` (winner, frames, damage); a stalled fight hits the 60s-sim timeout ⇒ `timed_out` + loss.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — use `CombatSetup.prepare`; loop `var dt := 1.0/60.0; while not done and t < max: cs.update_player(player, policy.next_input(...), dt, enemy); cs.update_ai(enemy, player, dt); t += dt; frames += 1`; record HP/posture/damage deltas + procs into `CombatResult`.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(sim): CombatSim deterministic headless fight`.

---

# Phase 5 — RunDriver + telemetry + CLI

### Task 10: `RunDriver.run` + `RunTranscript`

**Files:** Create `run_driver.gd`, `run_transcript.gd`; Test `WUGodot/tests/test_run_driver.gd`

- [ ] **Step 1: Failing tests** — `RunDriver.run(7, heuristic, greedy)` returns a `RunTranscript` that reaches a terminal `outcome` (victory|defeat) with `depth_reached >= 1`, well-formed (`nodes`, `combats`, `build_snapshots`, `death` when defeat); **reproducible:** same seed+policies ⇒ identical transcript outcome/depth.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — `set_run_seed(seed)`; build player; `RunState.create_procedural_run(seed)`; bind `BoonLoadout`; loop: `var decision := run_flow.travel_decision(node, player, run_state)`; for combat → `CombatSim` (record `CombatResult`, apply HP carryover/death); for boon/school → `DecisionPolicy.choose` over `run_flow` generators + `BoonLoadout`; for event → `EventRunner.choose`; shop → `ShopGenerator.buy_item`/`buy_boon_upgrade`; rest → `RestService.apply`; snapshot the build after each node; stop at boss-victory or death; emit `RunTranscript`.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(sim): RunDriver + RunTranscript`.

### Task 11: Batch aggregation + skill-sweep

**Files:** Create `batch_runner.gd`; Test `test_run_driver.gd`

- [ ] **Step 1: Failing test** — `BatchRunner.run(seeds=[1,2,3], player, decision)` returns the §5 batch summary (`runs, win_rate, avg_depth, death_by_node_histogram, win_rate_by_school, mastery_reached_rate`); `--skill-sweep` runs the set across skill levels and keys results by skill.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — loop seeds → `RunDriver.run` → aggregate transcripts into the summary dict; skill-sweep wraps it across `[0.5,0.65,0.8,0.95]`.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(sim): batch aggregation + skill-sweep`.

### Task 12: Headless CLI entry

**Files:** Create `playtest_main.gd`; Modify `run.sh`; Test: manual + import-clean

- [ ] **Step 1: Implement** `playtest_main.gd` (`extends SceneTree`, parse `OS.get_cmdline_user_args()`): dispatch `--playtest` (one run → write `--out` JSON), `--playtest-batch` (seeds range → summary JSON), printing a one-line stdout summary; honor `--player`, `--decision`, `--skill`, `--build`, `--seed`/`--seeds`. Add `run.sh` cases invoking `godot --headless --script res://scripts/sim/playtest_main.gd -- <args>`.
- [ ] **Step 2: Verify** — `./run.sh --playtest --seed 1 --player heuristic --decision greedy --out /tmp/run.json` produces a valid transcript JSON; `--playtest-batch --seeds 1..20 ... --out /tmp/sum.json` produces a summary. Tests green, import clean.
- [ ] **Step 3: Commit** — `feat(sim): run.sh --playtest[-batch] CLI`.

---

# Phase 6 — Visual capture

### Task 13: `VisualCapture` + state-spec + `run.sh --capture`

**Files:** Create `visual_capture.gd`; Modify `main.gd`, `run.sh`; Test: import-clean + manual

- [ ] **Step 1: Implement** — a JSON state-spec (`{kind:"matchup"|"ui"|"character", ...}`): `matchup` (build/loadout + archetype + combat state → reuse `CombatSetup` + the `--shot` readback), `ui` (boon_offer/loadout/reward/map rendered with given data), `character` (built-up Hu pose set). Drive to a reachable state with `RunDriver` when the spec references `{seed, after_node}`. Save PNG(s) (+ GIF via `assemble_action_review.py` for sequences) to `--out`.
- [ ] **Step 2: Verify** — `run.sh --capture /tmp/spec.json --out /tmp/cap` writes the requested PNGs for each kind; import clean.
- [ ] **Step 3: Commit** — `feat(sim): arbitrary-state visual capture`.

---

# Phase 7 — Agent usage doc

### Task 14: `docs/PLAYTEST.md`

- [ ] **Step 1:** Write `docs/PLAYTEST.md`: the CLI commands, telemetry schema (`CombatResult`/`RunTranscript`/batch summary), how to read the batch report (what win-rate/death-histogram/mastery-rate mean), how to capture + vision-review visuals, and the determinism contract (same seed+policies ⇒ same result). Aimed at CC/codex.
- [ ] **Step 2: Commit** — `docs: agent playtest usage guide`.

---

## Self-Review

- **Spec coverage:** RngService cached streams (Task 1) + full RNG migration incl event/shop/reward (Task 2); fixed-dt (Task 3/9); CombatSetup shared scene+sim (Task 4); pure apply_* (Task 5); PlayerPolicy exact input schema (Task 6); DecisionPolicy 4 impls (Task 7); boon_procs/status telemetry (Task 8); CombatSim determinism+timeout (Task 9); RunDriver+transcript (Task 10); batch+skill-sweep (Task 11); CLI (Task 12); arbitrary-state capture JSON spec (Task 13); agent doc (Task 14). FX RNGs explicitly out-of-scope.
- **No placeholders:** code shown for the load-bearing pieces (RngService, CombatSetup, CombatSim loop, RunDriver loop); policy/telemetry tasks specify exact behavior + tests.
- **Type consistency:** `RngService.stream(domain)`, `CombatSetup.prepare(player,node,forced)->{enemy,ai,boss}`, `PlayerPolicy.next_input(...)->Dictionary` (exact keys), `DecisionPolicy.choose(kind,options,loadout,run_state)->int`, `CombatSim.simulate(player,node,policy,max)->CombatResult`, `RunDriver.run(seed,player,decision,build)->RunTranscript` — consistent throughout.
- **Load-bearing risks:** Task 2 must not change combat/AI/technique behavior (only RNG *source*) — keep existing tests green; Task 4 must keep `setup_combat` working for the live game; the proc-recorder (Task 8) must be sim-only (no overhead/behavior change in normal play).
