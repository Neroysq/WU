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
- `WUGodot/scripts/sim/combat_setup.gd` — shared gameplay-side matchup setup (incl. hit_geometry).
- `WUGodot/scripts/sim/combat_step.gd` — shared per-frame gameplay block (facing→update→resolve_hits×2→tick_effects×2→clamp×2) + death check.
- `WUGodot/scripts/sim/player_policy.gd` (+ `heuristic_player.gd`, `scripted_player.gd`).
- `WUGodot/scripts/sim/decision_policy.gd` (+ `random_policy.gd`, `greedy_synergy_policy.gd`, `school_focused_policy.gd`, `scripted_policy.gd`).
- `WUGodot/scripts/sim/combat_sim.gd`, `combat_result.gd`.
- `WUGodot/scripts/sim/run_driver.gd`, `run_transcript.gd`, `batch_runner.gd`.
- `WUGodot/scripts/sim/playtest_main.gd` — headless CLI entry (mirrors `tests/run_tests.gd`).
- `WUGodot/scripts/sim/visual_capture.gd`.
- `WUGodot/tests/test_rng_service.gd`, `test_combat_setup.gd`, `test_player_policy.gd`, `test_decision_policy.gd`, `test_combat_sim.gd`, `test_run_driver.gd`, `test_apply_choices.gd`.
- `docs/PLAYTEST.md` — agent usage guide.

**Modify (gameplay RNG owners → `RngService.stream`):** `ai_brain.gd`, `combat_system.gd`, `technique_engine.gd`, `enemy_factory.gd`, `run_state.gd`, `boon_offer.gd`, `run_flow.gd`, `event_runner.gd`, `shop_generator.gd`, reward generation. **Modify (extract):** `combat_scene.gd` (→ `CombatSetup` + `CombatStep`), `scenes/shop_scene.gd` (→ `ShopGenerator.buy_boon_upgrade`), `scenes/rest_scene.gd` (→ `RestService.apply`), `scenes/forget_scene.gd` (→ `ForgetService.apply`). **Modify (CLI):** `run.sh`, `main.gd` (capture flag).

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

- [ ] **Step 1: Failing test** — reproducibility is asserted by **resetting the seed before each independent run** (reviewer P1 — a *cached* stream advances within a run, so don't compare two calls after one `set_run_seed`): `set_run_seed(42); var a = EnemyFactory.create_enemy_for_node(node)` then `set_run_seed(42); var b = EnemyFactory.create_enemy_for_node(node)` ⇒ `a.archetype == b.archetype`; same pattern for `RunState.create_procedural_run(42)` (identical node-type sequence across two seed-reset runs), a fixed school+depth boon offer, and `DataManager.get_random_event()`.
- [ ] **Step 2:** Run → FAIL (owners still self-randomize).
- [ ] **Step 3: Implement** — replace each `RandomNumberGenerator.new(); _rng.randomize()` with `_rng = RngService.stream("<domain>")`, stable domains (`"ai"`,`"combat"`,`"effects"`,`"enemy_pick"`,`"map"`,`"boon_offer"`,`"school"`,`"event"`,`"shop"`,`"reward"`). **Enumerate & cover every site:** `ai_brain`, `combat_system`, `technique_engine`, `enemy_factory._pick_archetype_for_node`, `run_state.create_procedural_run`, `boon_offer`, `run_flow` school-choice **and `RunFlow.generate_master_rewards()`**, `event_runner`, **`DataManager.get_random_event()` (`data_manager.gd:130`)**, `shop_generator`, **`RewardOption.random*`**, **`EventScene` timing randomness**. For cosmetic FX (`damage_number_system`, `camera_2d_helper`) leave as-is with a `# FX-only: out of deterministic-sim scope` comment. Normal play unchanged (no seed ⇒ randomized).
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

- [ ] **Step 1: Failing test** — `CombatSetup.prepare(player, node, "")` returns `{enemy, ai, boss, combat_system}` where the enemy matches `EnemyFactory.create_enemy_for_node(node)`'s archetype (seeded), both fighters are `reset_for_combat`, placed/facing, the AI brain (and boss controller for BOSS) is configured, **and the `CombatSystem` has `hit_geometry` registered with Hu's manifest** (`resolve_hits` needs it — reviewer P1) — all **without a scene tree**.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — extract the **gameplay-relevant** setup into `CombatSetup.prepare`: a `CombatSystem.new()` with `hit_geometry = PresentationCollision.new()` + `register_from_manifest_file("hu", ".../hu.manifest.json")` (mirrors `combat_scene._ready():63`); enemy creation (`create_enemy_by_archetype` if `forced_archetype` else `create_enemy_for_node`); `reset_for_combat()` both; placement (player start x, enemy at preferred range, facing); AI-brain; boss-controller for BOSS. **`hit_geometry` is GAMEPLAY, not visual** — it moves here. Leave only `presenter`/`visual`/`background` visual config in `setup_combat`, which now **calls `CombatSetup.prepare` first** then adds visuals. Verify `setup_combat` still works (import + scene-controller tests).
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(sim): extract CombatSetup shared by scene+sim`.

### Task 4b: `CombatStep.advance` — shared per-frame gameplay block

**Files:** Create `WUGodot/scripts/sim/combat_step.gd`; Modify `combat_scene.gd` (use it); Test `WUGodot/tests/test_combat_sim.gd`

**Reviewer P1:** the live frame is more than `update_player`/`update_ai`. Extract the exact ordered gameplay block (`combat_scene.gd:435–445`) so scene + sim are identical.

- [ ] **Step 1: Failing test** — `CombatStep.advance(cs, player, enemy, input_state, dt)` applies a hit's damage/status (not just animates): after stepping an in-range light attack, the defender's HP drops and any boon status is applied; venom/bleed tick over subsequent steps.
- [ ] **Step 2:** Run → FAIL (a loop that only calls update_player/ai deals no damage).
- [ ] **Step 3: Implement**:
```gdscript
class_name CombatStep
extends RefCounted
static func advance(cs, player, enemy, input_state, dt) -> void:
    cs.update_facing(player, enemy)
    cs.update_player(player, input_state, dt, enemy)
    cs.update_ai(enemy, player, dt)
    cs.resolve_hits(player, enemy)
    cs.resolve_hits(enemy, player)
    cs.tick_effects(player, dt)
    cs.tick_effects(enemy, dt)
    cs.clamp_world_bounds(player)
    cs.clamp_world_bounds(enemy)
```
Refactor `combat_scene`'s per-frame gameplay lines to call `CombatStep.advance(...)` (keeping camera/particles/visual/presenter/input-tracker around it). Keep the on-kill technique hook (`technique_engine.on_kill`) firing on death in both scene and sim — add `CombatStep.check_death(player, enemy) -> Variant` (returns the dead fighter or null) used by both.
- [ ] **Step 4:** Run → PASS (+ existing combat tests + the live scene unchanged in behavior).
- [ ] **Step 5: Commit** — `feat(sim): CombatStep shared per-frame gameplay block`.

### Task 5: Pure `apply_*` choice functions (incl. two-step forget)

**Files:** Modify `scenes/shop_scene.gd`, `scenes/rest_scene.gd` (and confirm `event_runner.choose` is already pure); Test `WUGodot/tests/test_apply_choices.gd`

- [ ] **Step 1: Failing test** — `EventRunner.choose(i, fighter)` applies outcome (already pure — assert it); `ShopGenerator.buy_item(item, fighter)` applies a purchase (pure — assert gold/effect); `RestService.apply("heal", fighter, run_state)` heals; **forget is TWO-STEP** (reviewer P2): rest choice "forget" only routes to a follow-up, and the actual removal is `ForgetService.apply(technique_id, fighter)` (mirrors `forget_scene.gd:31` `technique_engine.remove`). Boon upgrade buy → `ShopGenerator.buy_boon_upgrade(run_state)` (extracted from `ShopScene`).
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — extract controller-bound apply-logic to pure functions: `RestService.apply(action, fighter, run_state)` (heal / route-to-forget / insight-upgrade, matching `rest_scene.gd`), `ForgetService.apply(technique_id, fighter)` (the second-step removal from `forget_scene.gd`), `ShopGenerator.buy_boon_upgrade(run_state)`. Controllers **call these** (no duplication). `EventRunner.choose`/`ShopGenerator.buy_item` already pure — driver uses directly. (Note: with boons, `technique_engine.technique_ids()` is legacy-only, so "forget" may have nothing to remove — driver handles the empty case.)
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(sim): pure apply_* choice functions (event/shop/rest)`.

---

# Phase 3 — Policies

### Task 6: `PlayerPolicy` + Heuristic + Scripted

**Files:** Create `player_policy.gd`, `heuristic_player.gd`, `scripted_player.gd`; Test `WUGodot/tests/test_player_policy.gd`

- [ ] **Step 1: Failing tests** — `HeuristicPlayer.next_input(player, enemy, world)` returns a dict with the **literal** `_build_player_input` keys (reviewer P2 — verified at `combat_scene.gd:530`): `move, jump_pressed, dash_pressed, light_pressed, heavy_pressed, block_pressed, block_down, stance_pressed, attack_holding, attack_hold_duration` (note: **`block_pressed`/`block_down`, NOT `parry_pressed`**, and the two `attack_hold*` fields are required); when the enemy is far it returns `move` toward the enemy; when in range and able, it sets `light_pressed`/`heavy_pressed`; when the enemy is in a perilous windup it blocks/dashes; `skill < 1.0` sometimes withholds reactions (seedable via `RngService.stream("policy")`). `ScriptedPlayer` replays a `[{frame, action}]` list.
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
- [ ] **Step 3: Implement** — `var s = CombatSetup.prepare(player, node, forced)`; loop the **full shared frame**: `var dt := 1.0/60.0; while t < max: CombatStep.advance(s.combat_system, player, s.enemy, policy.next_input(player, s.enemy, world), dt); var dead = CombatStep.check_death(player, s.enemy); if dead != null: break; t += dt; frames += 1`. Use `CombatStep` (not raw update_player/ai) so hits/status/ticks actually resolve (reviewer P1). Record HP/posture/damage deltas + `boon_procs`/`status_applications` into `CombatResult`; timeout ⇒ `timed_out` + loss.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(sim): CombatSim deterministic headless fight`.

---

# Phase 5 — RunDriver + telemetry + CLI

### Task 10: `RunDriver.run` + `RunTranscript`

**Files:** Create `run_driver.gd`, `run_transcript.gd`; Test `WUGodot/tests/test_run_driver.gd`

- [ ] **Step 1: Failing tests** — `RunDriver.run(7, heuristic, greedy)` returns a `RunTranscript` that reaches a terminal `outcome` (victory|defeat) with `depth_reached >= 1`, well-formed (`nodes`, `combats`, `build_snapshots`, `death` when defeat); **reproducible:** same seed+policies ⇒ identical transcript outcome/depth.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — `set_run_seed(seed)`; build player; `RunState.create_procedural_run(seed)`; bind `BoonLoadout`; loop: `var decision := run_flow.travel_decision(node, player, run_state)`; for combat → `CombatSim` (record `CombatResult`, apply HP carryover/death); for boon/school → `DecisionPolicy.choose` over `run_flow` generators + `BoonLoadout`; for event → `EventRunner.choose`; shop → `ShopGenerator.buy_item`/`buy_boon_upgrade`; rest → `RestService.apply`, and when rest routes to **forget** (two-step), make a **second `DecisionPolicy.choose`** over `technique_engine.technique_ids()` then `ForgetService.apply(id, player)` (handle the empty-list case — boons aren't in technique_ids). Snapshot the build after each node; stop at boss-victory or death; emit `RunTranscript`.
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
- **Representativeness (reviewer P1):** the sim must run the **full live frame** via `CombatStep.advance` (facing→update→resolve_hits×2→tick_effects×2→clamp×2 + death/on-kill), and `CombatSetup` must register gameplay **hit_geometry** — otherwise attacks animate but deal no damage/status and fights time out. The live `combat_scene` is refactored to call the same `CombatSetup`/`CombatStep`, so scene and sim can't diverge.
- **Load-bearing risks:** Task 2 changes only the RNG *source* (cached streams; reset seed per run to compare) — keep existing tests green; Tasks 4/4b keep `setup_combat`/live frame behavior identical; the proc-recorder (Task 8) is sim-only; forget is a two-step driver flow (`ForgetService`).
