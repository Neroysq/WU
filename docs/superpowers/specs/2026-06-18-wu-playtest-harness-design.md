# WU — Agent Playtest Harness — Design

**Date:** 2026-06-18
**Status:** draft (pre-plan) — for user review
**Goal:** Let automated agents (Claude Code, codex, scripts) playtest WU's **gameplay and visuals** without a human playing — drive seeded runs/combat deterministically, emit structured **telemetry**, and capture **arbitrary visual states** for vision review.

**Why:** The user can't playtest frequently. Agents should be able to (a) autoplay seeded runs and read telemetry to judge balance / build-scaling / difficulty, and (b) capture any state/build/matchup/UI as PNG/GIF to vision-review the visuals. This validates the boon system (#2), the upcoming difficulty curve (#1), and visual variance (#3) without manual play.

---

## 1. Decided (from brainstorming)

- **Determinism-first, then both faces** (gameplay telemetry + visual capture).
- **Full single-seed reproducibility:** one run-seed threaded through every RNG; combat stepped at **fixed dt (1/60)** → any seed replays exactly (enables exact bug-repro AND batch-over-seeds).
- **Pluggable `PlayerPolicy`:** `HeuristicPlayer` (competent Hu, tunable skill) + `ScriptedPlayer`; agent-in-the-loop later.
- **Pluggable `DecisionPolicy`:** `Random`, `GreedySynergy`, `SchoolFocused`, `Scripted` (forced builds).
- **Scene-free logic core** (sim/driver/policies) + a **thin visual-capture layer** (the only part touching the viewport).

---

## 2. Architecture

```
run-seed ──► RngService (per-domain sub-RNGs)
                  │
   ┌──────────────┴───────────────┐
   ▼  scene-free logic core         ▼  visual layer (renders)
 RunDriver ── walks RunState        VisualCapture ── sets up a state-spec,
   ├─ CombatSim (PlayerPolicy        reuses --shot viewport readback,
   │   vs enemy AI, fixed dt)        saves PNG/GIF (uses RunDriver to
   ├─ DecisionPolicy (boon/event/    reach a reachable state)
   │   shop/rest via run_flow)
   └─ emits Telemetry (JSON)
```

- **Logic core is scene-free:** it operates on `Fighter`, `RunState`, `BoonLoadout`, and the existing `run_flow.gd` logic functions — no scene tree, no rendering. So it runs **fast** (pure fixed-dt stepping, no real-time `await`) and is unit-testable. A batch of N runs is near-instant.
- **Visual layer renders:** it reuses the existing `--shot` viewport-readback path (which needs a real viewport + `await process_frame`), so it's slower and used selectively.

---

## 3. Determinism foundation

**`RngService`** (`WUGodot/scripts/sim/rng_service.gd`) — a small static service holding **one cached RNG per domain** (created on first request, seeded with `hash(run_seed, domain)`):
- `set_run_seed(seed: int)` / `clear_run_seed()` — `set_run_seed` resets the per-domain cache so streams restart deterministically.
- `stream(domain: String) -> RandomNumberGenerator` — returns the **persistent** RNG for that domain, so repeated callers (boon offers, school choices, enemy picks, shops, events) *advance the same stream* rather than re-seeding to the same sequence each call. With no run-seed, the cached stream is `randomize()`d (normal play, **unchanged**). **(Reviewer P1: do NOT return a fresh `hash(seed,domain)` RNG per call — that replays the same sequence.)**

**Migrate the gameplay RNG owners** to `RngService.stream("<domain>")` instead of `RandomNumberGenerator.new(); randomize()`: `ai_brain.gd`, `combat_system.gd`, `technique_engine.gd`, `enemy_factory.gd` (`_pick_archetype_for_node`), `run_state.create_procedural_run`, `boon_offer.gd`, `run_flow` school-choice, **`event_runner.gd`, `shop_generator.gd`, `reward_option`/reward generation**. **Cosmetic FX RNGs** (`damage_number_system`, `camera_2d_helper`) are **out of deterministic-sim scope** (they don't affect telemetry; the headless sim doesn't render). The plan must enumerate each call site and either migrate it or explicitly mark it FX-only/out-of-scope.

**Fixed-dt stepping:** `CombatSim` advances combat by calling `combat_system.update_player(...)` / `update_ai(...)` in a `while` loop with `dt = 1.0/60.0` — no rendering, no real-time wait. (Normal play and visual capture keep their existing frame-timed paths.) Result: identical seed + identical policies ⇒ identical outcome.

---

## 4. Components

### 4.1 `PlayerPolicy` (`WUGodot/scripts/sim/player_policy.gd` + impls)
Interface: `next_input(fighter, enemy, world) -> Dictionary` returning the **exact dict `combat_scene._build_player_input` produces** (reviewer P2 — `combat_system.update_player` reads `block_down`/`block_pressed`, not `block_held`): `{move, jump_pressed, dash_pressed, parry_pressed, light_pressed, heavy_pressed, block_down, block_pressed, stance_pressed}`. Copy the schema verbatim; a shared constant/helper for the key set avoids drift.
- **`HeuristicPlayer`** — competent Hu: close to attack range, attack when in range & off-cooldown, block/dash when the enemy is in a perilous windup, use stance/dash on cooldown; a `skill: float` (0–1) gates reaction quality (skips/late reactions at low skill) so we can ask "can a *decent* player clear this?"
- **`ScriptedPlayer`** — replays a list of `{frame, action}` for targeted tests.

### 4.2 `DecisionPolicy` (`WUGodot/scripts/sim/decision_policy.gd` + impls)
Interface: `choose(kind, options, loadout, run_state) -> int` (index) for boon offers, school choice, event options, shop buys, rest actions. Consumes `run_flow` generators.
- **`Random`** (seeded), **`GreedySynergy`** (prefer boons matching held schools / fillable slots / upgrades), **`SchoolFocused`** (commit to one school → stresses mastery/duo reachability), **`Scripted`** (forced pick list → exact target build).

### 4.3 `CombatSetup` (`WUGodot/scripts/sim/combat_setup.gd`) — shared scene/sim contract
**Reviewer P1/P2:** `CombatScene.setup_combat()` does gameplay-relevant setup (enemy via `EnemyFactory.create_enemy_for_node`, `player/enemy.reset_for_combat`, placement/facing, AI-brain + boss-controller config, clear combat state) *and* visual config (presenter/visual/background). Extract the **gameplay-relevant** setup into `CombatSetup.prepare(player, node, forced_archetype) -> {enemy, ai, boss}` and have **both** `CombatScene` (which then adds visuals) and `CombatSim` call it. Otherwise the sim is deterministic but not representative.

### 4.4 `CombatSim` (`WUGodot/scripts/sim/combat_sim.gd`)
`simulate(player, node, player_policy, max_seconds) -> CombatResult`. Uses `CombatSetup.prepare` for the matchup, then loops fixed-dt (`combat_system.update_player`/`update_ai`) until a fighter dies or `max_seconds` of *simulated* time elapses (timeout ⇒ loss). No scene/render.

### 4.5 `RunDriver` (`WUGodot/scripts/sim/run_driver.gd`)
`run(seed, player_policy, decision_policy, build_script=null) -> RunTranscript`. Creates player (`EnemyFactory.create_player`), `RunState.create_procedural_run(seed)`, binds `BoonLoadout`; walks nodes via `run_flow.travel_decision`; for combat → `CombatSim`; for choices → `DecisionPolicy` **applied through the existing RefCounted services** (the same logic the UI controllers call): boon via `run_flow` generators + `BoonLoadout`, events via `EventRunner.choose()`, shop via `ShopGenerator.buy_item()`. **Reviewer P1:** where the only apply-logic lives inside a UI controller (e.g. `ShopScene._buy_boon_upgrade`, rest heal/forget in `RestScene`), the plan adds an **extraction task** to a pure `apply_*` function shared by controller and driver — never duplicate it. Stops at boss-victory or death; returns the transcript.

### 4.6 `VisualCapture` (`WUGodot/scripts/sim/visual_capture.gd` + `main.gd` flag)
Given a **state-spec**, sets up the requested scene/state and saves PNG(s)/GIF via the existing viewport readback. Specs: `matchup` (build/loadout + enemy archetype + combat state), `ui` (boon_offer/loadout/reward/map with given data), `character` (built-up Hu pose set). Uses `RunDriver` to *play to* a reachable state when asked (e.g., "seed 42, after node 4").

---

## 5. Telemetry schema (JSON)

**`CombatResult`:** `{ enemy_archetype, node_type, tier, winner, duration_s, frames, player_hp_before/after, player_posture_min, damage_dealt, damage_taken, boon_procs:{boon_id:count}, status_applications:{venom|jolt|bleed|deflect|momentum|intent:count}, timed_out:bool }`
> **Reviewer P2:** boons are NOT technique ids — track **`boon_procs`** and **`status_applications`** (instrumented in the effect dispatch path, e.g. count each effect's hook firing and each status applied), so the boon system's actual behavior is visible in the batch report. A "technique_procs" field would hide it.

**`RunTranscript`:** `{ seed, player_policy, decision_policy, outcome:"victory"|"defeat", depth_reached, death:{node, enemy, cause}|null, gold, insight, nodes:[{tier,type,result|choice}], build_snapshots:[{after_node, loadout}], combats:[CombatResult], totals:{damage,time} }`

**Batch summary (`run.sh --playtest-batch`):** aggregates N transcripts → `{ runs, win_rate, avg_depth, death_by_node_histogram, win_rate_by_decision_policy, win_rate_by_school, avg_build_size, mastery_reached_rate, flags:[…] }` — the file an agent reads to judge balance/build-scaling/difficulty.

Telemetry is written to a file path given on the CLI; also printed as a one-line summary to stdout (parseable, like the test harness).

---

## 6. CLI surface (all headless, deterministic, exit codes)

- `run.sh --playtest --seed N --player <heuristic|scripted> --decision <random|greedy|school|scripted> [--skill F] [--build <script.json>] --out <telemetry.json>` — one run.
- `run.sh --playtest-batch --seeds A..B --player … --decision … --out <summary.json>` — N runs + aggregate.
- `run.sh --capture <spec.json> [--seed N] [--build <script>] --out <dir>` — arbitrary-state PNG/GIF (+ reuses `assemble_action_review.py` for GIFs).

`run.sh` invokes Godot headless with `--script res://scripts/sim/playtest_main.gd` (a new headless entry mirroring `tests/run_tests.gd`), parsing args from `OS.get_cmdline_user_args()`.

---

## 7. Integration with existing systems

- **Reuse, don't rebuild:** `run_flow.gd` logic generators (already scene-separable), `combat_system`/`ai_brain` combat loop, `BoonLoadout`, the test-pattern fighter construction, the `--shot` viewport readback + `assemble_action_review.py`.
- **Minimal touch to gameplay:** the only change to shipping code paths is routing RNG construction through `RngService` (defaults to `randomize()`, so normal play is identical). Everything else is new files under `scripts/sim/`.
- **Where choices are applied:** the `DecisionPolicy` calls the same `run_flow` generators the UI scenes call, then applies via `BoonLoadout` — so the harness and the real game make choices through one logic path (no divergence).

---

## 8. Testing

Headless unit tests (existing pattern, registered in `tests/run_tests.gd`):
- `RngService` determinism (same seed+domain ⇒ same sequence; no seed ⇒ varies).
- `CombatSim` determinism (same seed+policies ⇒ identical `CombatResult`).
- `RunDriver` reaches a terminal outcome and emits a well-formed transcript; a fixed seed+policy reproduces the same transcript.
- Each `PlayerPolicy`/`DecisionPolicy` produces valid inputs/choices.
- Telemetry schema validity (required keys present).
- `VisualCapture` writes the requested PNGs for each spec kind (import-clean check).

---

## 9. Out of scope / YAGNI

- Agent-in-the-loop live decision API (later; the policy interface leaves room).
- Multi-enemy encounters (combat is single-enemy today; sim mirrors that).
- A balance-tuning UI / dashboards (agents read JSON directly).
- Meta-progression simulation.
- Replacing the human-facing scenes (the game still plays normally; this is additive).

---

## 10. Resolved (user calls)

1. **Heuristic skill:** default **0.8** (competent baseline) + an optional **`--skill-sweep`** batch mode (run a config across skill levels).
2. **Combat timeout:** default **60s simulated** time ⇒ loss, with a CLI override.
3. **Capture state-spec:** **JSON file first**; presets/flags can come later.

---

## 11. Sequencing (phases — full plan after approval)

1. **Determinism foundation** — `RngService` (cached per-domain streams); **enumerate & migrate every gameplay RNG owner** (ai/combat/technique_engine/enemy_factory/run_state/boon_offer/school-choice/event_runner/shop_generator/reward), mark FX RNGs out-of-scope; fixed-dt step helper. (Both faces depend on this.)
2. **Extractions for representativeness/reuse** — `CombatSetup.prepare` (shared by scene + sim); pure `apply_event_choice`/`apply_shop_choice`/`apply_rest_choice` where logic is controller-bound (driver and UI call the same function).
3. **Policy interfaces + impls** — `PlayerPolicy` (heuristic@0.8 + scripted; exact `_build_player_input` schema), `DecisionPolicy` (random/greedy/school/scripted).
4. **`CombatSim` + `CombatResult`** telemetry — incl. `boon_procs`/`status_applications` instrumentation in the effect dispatch path; 60s-sim timeout; tests.
5. **`RunDriver` + `RunTranscript`** + batch aggregation + `--skill-sweep` + `playtest_main.gd` + `run.sh --playtest[-batch]`.
6. **`VisualCapture`** + JSON state-spec + `run.sh --capture`.
7. **Agent-usage doc** — how CC/codex invoke the CLI and interpret telemetry/artifacts.
