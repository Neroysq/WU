# Interactive Agent Playtest Daemon — Design

**Date:** 2026-06-24
**Status:** draft (pre-plan) — for user review
**Builds on:** the playtest harness (`docs/superpowers/specs/2026-06-18-wu-playtest-harness-design.md`), the deterministic sim (`CombatStep`/`CombatSim`/`RunDriver`/`RunFlow`), and the non-headless capture path.

**Goal:** Let an agent (CC/Codex) **interactively play a full run** — navigate the map, take boons/rewards, and fight **frame-by-frame** — receiving structured logs of every combat followup, taking screenshots at any moment or on triggered events, and pausing at any frame to decide.

**Why:** The batch harness answers "what happens across many runs." This answers "what happens *right now* when I make this move" — the agent makes a move, sees exactly how it interacts with the enemy, snapshots key instants (attack finish, on-hit), and breakpoints on enemy actions to test reactions. It's the agent's hands-on dogfighting/debugging tool, on the same deterministic core as the batch harness.

---

## 1. Architecture — model-first, render-on-demand

**The model/sim is the single source of truth.** The session advances the run **only on command** by calling `CombatStep.advance(...)` (combat) and the run services (`RunFlow`/`RunDriver` decision steps) directly — **NOT** via the scene's real-time `_process` loop. The process runs **non-headless solely so the viewport can be rendered and read back for screenshots**; rendering is a **read-only projection** of the current model state, invoked only when a screenshot is requested or a screenshot-trigger fires. There is no wall-clock; the sim is **agent-clocked** and effectively paused at every frame by default.

This keeps the daemon compatible with the batch harness (same `CombatStep`, no UI automation) and avoids the trap of a render loop being the source of truth.

## 2. Session model & transport (atomic, sequenced files)

A long-running non-headless Godot process = one session, working in `user://playtest/<session_id>/` (mirrored to a known `/tmp/wu-playtest/<session_id>/` path for the agent).

- **Command:** the agent writes `cmd_<seq>.json.tmp` then **renames** it to `cmd_<seq>.json` (atomic publish). The daemon processes the lowest unhandled `seq`.
- **Response:** the daemon writes `resp_<seq>.json.tmp` then **renames** to `resp_<seq>.json`. The agent polls for `resp_<seq>.json`.
- Every command and response carries `{seq, session_id, status: "ok"|"error", error?}`. Sequenced files (not a single mutable `cmd.json`/`resp.json`) avoid races and give a readable history.
- Screenshots are written to `shots/<label>_<seq>.png`; response references their paths.
- A `command_log.jsonl` appends every command in order (for replay/repro).

## 3. The advance-until-agent-needed loop

The session is always at one of two pause kinds, reported as `pause: {kind, ...}` in every response:

- **Decision pause** (coarse) — at map / boon_offer / school_choice / reward / event / rest / shop. Response includes the available `options`. The agent replies `choose`.
- **Combat pause** (fine) — inside a fight. The agent drives frames (`input`/`step`/`advance`). Re-pauses when the advance budget is spent **or** a trigger fires (with which trigger).

**Command boundaries (hard errors, not silent no-ops):**
- `input` / `step` / `advance` / `screenshot`(combat) / `trigger` → **error** unless `pause.kind == "combat"`.
- `choose` → **error** unless `pause.kind == "decision"`.
This stops agents from advancing a stale scene.

## 4. Command set

- **Lifecycle:** `start {seed:int, forced_archetype?:string, build?:[{boon_id,tier}]}` · `status` · `quit`.
- **Coarse:** `choose {index}`.
- **Combat:** `input {actions:[light|heavy|dash|block|move_left|move_right|stance|jump], hold?:bool} advance {frames:N | until:<trigger-expr>}` · `step {frames:1}` (no input = neutral).
- **Observe:** `observe` (returns current state + event log since last pause, no advance).
- **Screenshot:** `screenshot {label}` (render current model state → PNG).
- **Triggers:** `trigger_add {event, screenshot?:bool} -> id` · `trigger_clear {id|all}` · `trigger_list`.

## 5. Event instrumentation (source-level) & observation

**Events are emitted at the source, never inferred.** Add a `CombatEventRecorder` handed into `CombatStep`/`CombatSystem`; the combat code emits events where they occur:
`attack_started`, `attack_active_started`, `attack_finished`, `hit {by, target, hp_damage, posture_damage, blocked, parried, critical}`, `whiff` (active window passed with no connect), `status_applied {type, stacks}`, `boon_proc {id}`, `phase_changed {fighter, phase}`, `dash {fighter, iframes}`, `stun {fighter, duration}`, `enemy_decision {action, attack_id}`, `death {fighter}`. (This recorder also satisfies the standalone live-combat instrumentation needed for the close-range whiff investigation — `2026-06-24-light-deadzone-investigation.md`.)

**Observation returned at each pause:**
- `context`: scene/pause kind; decision `options` if coarse.
- `state` (combat): per fighter — `hp`, `posture`, `position`, `facing`, `animation`, `attack {id, phase, elapsed}`, timers (`iframe`, `stun`, `cooldown`), `is_blocking`, `is_invulnerable`, `is_hit_active`.
- `events`: the ordered event log **since the last pause** (from the recorder).
- `shots`: screenshots taken since last pause (label → path).
- `pause`: why it stopped (`budget_spent` | `trigger:<id/event>` | `decision`).

## 6. Triggers & screenshot hooks

A trigger = a condition evaluated each advanced frame that **pauses** (and optionally screenshots). Conditions consume the **event stream** and **state predicates**:
- Event triggers: `enemy_windup_start`, `enemy_attack_active`, `player_attack_active`, `player_attack_finished`, `on_hit`, `on_get_hit`, `parry`, `block`, `whiff`, `combat_start`, `combat_end`, `death`.
- Predicate triggers: `hp_below {who, value}`, `frame {n}`, `distance_below {value}`.
Each: pause + optional auto-screenshot. Examples: *pause when the enemy starts a move* → `trigger_add {event:"enemy_windup_start"}`; *picture when my attack finishes / when I get hit* → `trigger_add {event:"player_attack_finished", screenshot:true}` / `{event:"on_get_hit", screenshot:true}`.

## 7. Determinism / reproducibility

The session is **seeded**; `command_log.jsonl` records every command. **Reproducibility is defined on the state/event transcript, not on pixels** — replaying the command log from the seed must yield an **identical state + event-log transcript**. Screenshots are useful artifacts but renderer output may vary by machine/GPU, so PNGs are **not** part of the determinism contract. This shares the deterministic `CombatStep` with the batch harness, so a discovered sequence can be replayed or folded into a regression.

## 8. Components (boundaries)

- **`playtest_daemon`** — process entry (non-headless), session dir, atomic file transport, command dispatch, `command_log`. (CLI: `./run.sh --playtest-daemon --session <id> [--seed N]`.)
- **`run_conductor`** — drives the run flow (reuses `RunDriver`/`RunFlow` services), pausing at each decision point and exposing its options; resumes on `choose`.
- **`combat_controller`** — owns a fight: frame stepping via `CombatStep` with agent inputs, runs the `trigger_engine` each frame, collects events.
- **`combat_event_recorder`** — source-level event sink injected into `CombatStep`/`CombatSystem`.
- **`trigger_engine`** — evaluates event/predicate triggers per frame → pause + optional screenshot.
- **`screenshot_service`** — renders the current model state and reads the viewport to PNG (reuses the capture readback).

## 9. Out of scope (v1)

- Real-time playback (agent-clocked only).
- Socket/network transport (atomic files first).
- Simulating actual keyboard/menu UI — the daemon drives the **model** and renders a projection; it does not automate the input layer.
- Multi-session parallelism within one process.

## 10. Testing

- **Headless unit tests** (deterministic): `combat_event_recorder` emits expected events for a scripted exchange; `trigger_engine` fires on the right frame; `combat_controller` honors advance budgets and command boundaries (errors when miscalled); `run_conductor` pauses at each decision and applies `choose`; transport seq/atomic-rename handling; **reproducibility** test (replay `command_log` → identical event transcript).
- **One non-headless smoke**: start a daemon session, fight a `bandit_swordsman` via a scripted command sequence, assert (a) the event log contains the expected `hit`/`death`, and (b) a `screenshot` returns a **non-blank** PNG.

## 11. Sequencing (phases — full plan after approval)

1. `combat_event_recorder` + wire into `CombatStep`/`CombatSystem` (also unblocks the dead-zone live instrumentation).
2. `combat_controller` + `trigger_engine` (headless): step/advance/triggers/event log over a real combat, unit-tested.
3. `run_conductor`: decision pauses + `choose` over a full run (headless).
4. `playtest_daemon` transport (atomic sequenced files, command log, boundaries) + `start/quit/status`.
5. `screenshot_service` (non-headless render-on-demand) + screenshot triggers + the smoke test.
6. Reproducibility test + docs for the command vocabulary.
