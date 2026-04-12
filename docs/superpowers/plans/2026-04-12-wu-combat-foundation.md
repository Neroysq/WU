# WU Combat Foundation Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the existing WU combat primitives to deliver the Section B combat feel — Sekiro-paced tuning, a heavy attack, animation-event-style hit windows, a buffered input layer, a stance key scaffold, color-coded telegraphs, and disciplined impact feedback — using Hu vs. Bandit as the content harness.

**Architecture:** Introduce a single-source-of-truth `AttackDefinition` + `AttackState` pair so attack timing, hit-active windows, and animation visuals all derive from one elapsed counter instead of the current two parallel timers (`_attack_timer` and `animation_timer`). Layer a 0.15s `InputBuffer` on top of the existing `InputTracker`. Consolidate dash i-frames into an explicit three-phase dash state. All tuning moves into `AttackDefinition` instances and `GameConstants`; no new autoloads.

**Tech Stack:** Godot 4.6.2 (GDScript), RefCounted data classes (matches the rest of the codebase), JSON data under `WUGodot/data/`. No GUT framework — pure logic classes are validated with a minimal custom harness launched via `godot --headless --script` under `WUGodot/tests/`; feel-based items use a manual playtest checklist. Godot `AnimationPlayer` is **not** introduced in this plan — the existing procedural-animation code stays, and the "no parallel timers" discipline is met by consolidating timing into a single `AttackState.elapsed` counter that both hit detection and the visual offset read from. Switching to keyframe-based animations is a Milestone 1 (art pass) concern.

**Spec reference:** `docs/superpowers/specs/2026-04-10-wu-mvp-design.md` — this plan implements **Section B (Combat System)** in full, plus the specific refactors called out in Section E under "Code changes this design will require."

**Plan sequence (5 plans total for the WU MVP):**

1. **Plan 1 (this document) — Combat Foundation Refactor.** Output: a refined 1-vs-Bandit duel where every Section B bullet is live.
2. **Plan 2 — Technique System + 20-Technique MVP Pool.** Data pipeline, runtime application, one-copy-only duplicate policy, rage → D-type stance activation via the L hook this plan scaffolds, all 20 techniques.
3. **Plan 3 — Enemy Archetypes + Iron Bear Boss.** 5 archetypes with pattern tables, Xiong Tie 2-phase boss with Mountain-Breaker Stance and Bear Crush unparryable grab.
4. **Plan 4 — Run Structure Expansion.** 8 node types (Duel / Elite Duel / Ambush / Master / Event / Shop / Rest / Boss), procedural map-gen updates with forced master-column convergence, Event system, Shop system, acquisition-flow hookup.
5. **Plan 5 — Run Flow & Chapter 1 Polish.** Main menu, Victory scroll, Defeat screen, SFX/music integration, final balance pass.

Each plan produces working, testable software. Plan 1 validates entirely through the existing `Main` → `CombatScene` flow against a Bandit.

---

## File Structure

**New files:**

- `WUGodot/scripts/attack_definition.gd` — data class for one attack: duration, phase boundaries, damage, posture damage, parry/perilous flags, telegraph color, is_heavy flag.
- `WUGodot/scripts/attack_state.gd` — runtime: current `AttackDefinition`, `elapsed`, phase helpers, `advance(dt)` returning phase-change events.
- `WUGodot/scripts/attack_catalog.gd` — static factory returning the canonical `AttackDefinition` instances (`HU_LIGHT`, `HU_HEAVY`, `BANDIT_SLASH`, `BANDIT_THRUST_PERILOUS`). Single source of truth for combat tuning numbers, replacing the per-fighter attack timing fields.
- `WUGodot/scripts/input_buffer.gd` — 0.15s action-press buffer layered on top of `InputTracker`. Used by `CombatScene._build_player_input()`.
- `WUGodot/scripts/combat_debug_overlay.gd` — dev-only drawing: current `AttackDefinition.id`, elapsed/duration, hit-active flag, dash phase, input buffer contents, rage value. Toggled by the existing `KEY_QUOTELEFT` debug key.
- `WUGodot/tests/run_tests.gd` — minimal `SceneTree` harness that loads each test module, collects pass/fail counts, prints a summary, exits with code 0 or 1.
- `WUGodot/tests/test_attack_definition.gd` — phase lookup and hit-active probes.
- `WUGodot/tests/test_attack_state.gd` — elapsed advancement and phase-transition event emission.
- `WUGodot/tests/test_input_buffer.gd` — record / advance / consume semantics at 0.15s window.

**Modified files:**

- `WUGodot/scripts/game_constants.gd` — `DEFAULT_MOVE_SPEED` 420 → 320, `PARRY_WINDOW` 0.12 → 0.15, `DASH_DURATION` 0.16 → 0.22, `DASH_COOLDOWN` 0.60 → 0.80; add `DASH_STARTUP_END`, `DASH_IFRAME_END`, `DASH_RECOVERY_END` constants; delete `ATTACK_DURATION`, `ATTACK_ACTIVE_START`, `ATTACK_ACTIVE_END` (those values move to `AttackCatalog`).
- `WUGodot/scripts/fighter.gd` — embed `_attack_state: AttackState`; delete `attack_duration`, `attack_active_start`, `attack_active_end`, `_attack_timer`, `_iframe_timer`, `is_telegraphing`, `telegraph_timer`, `telegraph_duration`, `start_telegraph()` (see Task 4 Step 2 and Finding 5); replace `start_attack()` with `start_light_attack()` + `start_heavy_attack(def: AttackDefinition)`; add private `_start_attack_with(def)` dispatch; add `_ai_decision_timer` field to pace AI attacks now that telegraph stall is gone; derive `is_hit_active()` from `_attack_state`; derive `is_invulnerable` from dash phase; add `"stance": KEY_L` to `player_controls()` and `"stance": KEY_NONE` to `none_controls()` (so enemy-side dicts stay symmetric); add `on_stance_input()` hook; add `current_telegraph_color()` helper.
- `WUGodot/scripts/combat_system.gd` — replace raw input polling with `InputBuffer.consume_if_pressed(action)`; detect J-hold via `InputTracker.is_held_ms()` and branch to heavy attack; route stance key to `fighter.on_stance_input()`; update parry/hit callbacks to emit the new `hitstop` signal with spec values (0.05/0.10/0.15/0.18); make the AI use `AttackCatalog.BANDIT_SLASH` / `BANDIT_THRUST_PERILOUS` instead of its current hard-coded `start_attack()`.
- `WUGodot/scripts/input_tracker.gd` — add `is_held_ms(keycode: int) -> float` returning how long the key has been held in milliseconds; add `update(dt)` method that advances hold timers internally.
- `WUGodot/scripts/combat_scene.gd` — construct `InputBuffer`; replace `_build_player_input()` internals to record actions into the buffer (light/heavy via J tap-vs-hold classification, plus dash/jump/block/stance); add `_heavy_committed_attack` flag so single-button tap-vs-hold doesn't double-fire; rewrite `_sync_input_tracker()` to iterate `_player.controls.keys()` unconditionally so new action bindings (stance today, anything Plan 2-5 adds) are picked up automatically; attach `CombatDebugOverlay` behind the existing `_debug_enabled` flag; replace the single-field `_time_scale` recovery-lerp with a 3-state priority machine (`_hitstop_timer` > `_slow_mo_timer` > lerp-to-1.0) so parry hitstop and parry slow-mo layer correctly instead of clobbering each other.
- `WUGodot/scripts/enemy_factory.gd` — stop assigning per-fighter `attack_duration` / `attack_active_start` / `attack_active_end` fields (they no longer exist); Bandit is configured with the `AttackCatalog.BANDIT_SLASH` + `BANDIT_THRUST_PERILOUS` attack list.
- `WUGodot/data/Characters/Hu.json` — `moveSpeed` 420 → 320, delete `attackDuration`, `attackActiveStart`, `attackActiveEnd` (moved to `AttackCatalog`), update `dashDuration` 0.16 → 0.22, `dashCooldown` 0.60 → 0.80, `parryWindow` 0.12 → 0.15. (No `controls` entry in JSON — player key bindings are owned by `Fighter.player_controls()` which `enemy_factory.gd:63` consumes; Task 9 Step 1 adds stance there.)
- `WUGodot/data/Enemies/BasicEnemy.json` — delete `attackDuration`, `attackActiveStart`, `attackActiveEnd`, `telegraphDuration` (replaced by attack catalog).

**Fields deleted (not whole files):**

- `Fighter.attack_duration`, `Fighter.attack_active_start`, `Fighter.attack_active_end`, `Fighter._attack_timer` — replaced by `_attack_state`.
- `Fighter._iframe_timer` — replaced by dash-phase derivation.
- `Fighter.telegraph_timer`, `Fighter.telegraph_duration`, `Fighter.is_telegraphing`, `Fighter.start_telegraph()` — the legacy pre-attack "telegraph" was only used by the AI to stall before `start_attack()`. Replaced by the AI firing `_start_attack_with(def)` directly, letting the AttackDefinition's WINDUP phase be the player-visible warning. No separate telegraph state, no second timing path. The visual telegraph flash now comes from `Fighter.current_telegraph_color()` which reads `_attack_state.phase() == AttackDefinition.Phase.WINDUP`.
- `GameConstants.ATTACK_DURATION`, `ATTACK_ACTIVE_START`, `ATTACK_ACTIVE_END` — values move to `AttackCatalog`.

---

## Testing Strategy

No GUT is installed and adding it is out of scope. Two validation layers:

**Layer A — headless pure-logic tests.** For `AttackDefinition`, `AttackState`, and `InputBuffer` (all RefCounted, deterministic), use a minimal custom harness. `WUGodot/tests/run_tests.gd` extends `SceneTree`, loads each test module, calls `run_all()`, aggregates pass/fail counts, prints a summary, and `quit(0)` or `quit(1)`. Run with:

```bash
cd WUGodot && godot --headless --script res://tests/run_tests.gd
```

No external dependencies. Exit code 0 = all tests passed.

**Layer B — manual playtest checklist** (Task 13) for feel-based items that cannot be asserted in code: hitstop cadence, camera shake amplitude, parry slow-mo timing, telegraph color legibility, dash three-phase feel, heavy-attack J-hold threshold. Each item has a specific observable outcome.

**Runnable after every commit.** Each task leaves `Main.tscn` in a playable state — engineers should launch the editor and smoke-test after every commit.

---

## Task 0: Test harness scaffold

**Files:**
- Create: `WUGodot/tests/run_tests.gd`

- [ ] **Step 1: Create the harness entry point**

Write `WUGodot/tests/run_tests.gd`:

```gdscript
extends SceneTree

# Minimal headless test harness. No GUT dependency.
# Run with: godot --headless --script res://tests/run_tests.gd
# Exit code 0 on success, 1 on failure.

const _TEST_MODULES: Array[String] = [
	"res://tests/test_attack_definition.gd",
	"res://tests/test_attack_state.gd",
	"res://tests/test_input_buffer.gd",
]

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

func _init() -> void:
	for module_path in _TEST_MODULES:
		if not ResourceLoader.exists(module_path):
			# Skip modules not yet written — later tasks will add them.
			continue
		var module_script: Script = load(module_path)
		if module_script == null:
			_failed += 1
			_failures.append("could not load %s" % module_path)
			continue
		var module: RefCounted = module_script.new()
		if not module.has_method("run_all"):
			_failed += 1
			_failures.append("%s missing run_all()" % module_path)
			continue
		var results: Dictionary = module.run_all()
		_passed += int(results.get("passed", 0))
		_failed += int(results.get("failed", 0))
		var reported_failures: Array = results.get("failures", [])
		for failure in reported_failures:
			_failures.append("%s: %s" % [module_path, String(failure)])

	print("\n=== TEST RESULTS ===")
	print("passed: %d" % _passed)
	print("failed: %d" % _failed)
	if _failed > 0:
		for failure in _failures:
			print("  FAIL %s" % failure)
		quit(1)
	else:
		quit(0)
```

The `ResourceLoader.exists()` guard lets us commit this before any test module exists, so later tasks can add modules one at a time without breaking the harness.

- [ ] **Step 2: Run the harness to verify it runs clean**

```bash
cd WUGodot && godot --headless --script res://tests/run_tests.gd
```

Expected output:
```
=== TEST RESULTS ===
passed: 0
failed: 0
```
Exit code: 0 (verify with `echo $?`).

- [ ] **Step 3: Commit**

```bash
git add WUGodot/tests/run_tests.gd
git commit -m "add headless test harness for combat foundation plan"
```

---

## Task 1: Tuning pass — Sekiro-pace constants and character JSON

**Files:**
- Modify: `WUGodot/scripts/game_constants.gd:12`
- Modify: `WUGodot/scripts/game_constants.gd:20-23`
- Modify: `WUGodot/data/Characters/Hu.json:6`
- Modify: `WUGodot/data/Characters/Hu.json:24-26`
- Modify: `WUGodot/data/Enemies/BasicEnemy.json:7`

This task only changes **values**, not shapes. `ATTACK_DURATION`/`ATTACK_ACTIVE_START`/`ATTACK_ACTIVE_END` stay for now — we'll delete them in Task 4 once `AttackCatalog` exists. This keeps the game runnable at every commit.

- [ ] **Step 1: Update `game_constants.gd`**

Edit `WUGodot/scripts/game_constants.gd`:

- Line 12: change `const DEFAULT_MOVE_SPEED: float = 420.0` to `const DEFAULT_MOVE_SPEED: float = 320.0`.
- Line 17: change `const ATTACK_DURATION: float = 0.35` to `const ATTACK_DURATION: float = 0.50`.
- Line 18: change `const ATTACK_ACTIVE_START: float = 0.10` to `const ATTACK_ACTIVE_START: float = 0.18`.
- Line 19: change `const ATTACK_ACTIVE_END: float = 0.18` to `const ATTACK_ACTIVE_END: float = 0.30`.
- Line 20: change `const DASH_DURATION: float = 0.16` to `const DASH_DURATION: float = 0.22`.
- Line 21: change `const DASH_COOLDOWN: float = 0.60` to `const DASH_COOLDOWN: float = 0.80`.
- Line 22: change `const PARRY_WINDOW: float = 0.12` to `const PARRY_WINDOW: float = 0.15`.

Also add these new dash-phase constants after the existing dash block:

```gdscript
const DASH_STARTUP_END: float = 0.04
const DASH_IFRAME_END: float = 0.18
const DASH_RECOVERY_END: float = 0.22
```

The three dash constants describe cumulative elapsed time, not per-phase durations: startup is [0, 0.04), i-frames [0.04, 0.18), recovery [0.18, 0.22). Matches Section B.

- [ ] **Step 2: Update `Hu.json`**

Edit `WUGodot/data/Characters/Hu.json`:

- `"moveSpeed": 420.0` → `"moveSpeed": 320.0`
- `"attackDuration": 0.35` → `"attackDuration": 0.50`
- `"attackActiveStart": 0.10` → `"attackActiveStart": 0.18`
- `"attackActiveEnd": 0.18` → `"attackActiveEnd": 0.30`
- `"dashDuration": 0.16` → `"dashDuration": 0.22`
- `"dashCooldown": 0.60` → `"dashCooldown": 0.80`
- `"parryWindow": 0.12` → `"parryWindow": 0.15`

- [ ] **Step 3: Update `BasicEnemy.json` for Sekiro pacing**

Edit `WUGodot/data/Enemies/BasicEnemy.json`:

- `"moveSpeed": 200.0` (unchanged — enemies already slower)
- `"attackDuration": 0.62` → `"attackDuration": 0.80`
- `"attackActiveStart": 0.30` → `"attackActiveStart": 0.45`
- `"attackActiveEnd": 0.48` → `"attackActiveEnd": 0.60`
- `"telegraphDuration": 0.55` → `"telegraphDuration": 0.45`

The Bandit attack is now longer but with a cleaner active window; the telegraph is slightly shorter because Section B wants the attack windup itself (not a separate pre-windup state) to serve as the readable anticipation.

- [ ] **Step 4: Smoke-test the tuning**

Launch the Godot editor on `WUGodot/project.godot`, run `Main.tscn`, start a run, enter combat. Verify:

1. Movement feels noticeably slower (320 vs 420).
2. Attack swings feel slower but still snappy (0.50s vs 0.35s).
3. Dash feels a touch longer (0.22s vs 0.16s).
4. Parry window feels about the same (0.15s is only +0.03s).
5. No crashes, no errors in Output panel.

No code assertions — this is a feel check.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/game_constants.gd WUGodot/data/Characters/Hu.json WUGodot/data/Enemies/BasicEnemy.json
git commit -m "tune combat values toward Sekiro pace (move 320, atk 0.50, dash 0.22, parry 0.15)"
```

---

## Task 2: AttackDefinition data class

**Files:**
- Create: `WUGodot/scripts/attack_definition.gd`
- Create: `WUGodot/tests/test_attack_definition.gd`

- [ ] **Step 1: Write the failing test**

Create `WUGodot/tests/test_attack_definition.gd`:

```gdscript
extends RefCounted

const AttackDefinition = preload("res://scripts/attack_definition.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	# Build a Hu light-attack-shaped definition.
	var light: AttackDefinition = AttackDefinition.new()
	light.id = "hu_light"
	light.duration = 0.50
	light.windup_end = 0.18
	light.active_end = 0.30
	light.damage = 12.0
	light.posture_damage = 22.0
	light.is_heavy = false
	light.is_perilous = false

	# Phase lookups.
	var checks: Array[Array] = [
		[light.phase_at(0.0), AttackDefinition.Phase.WINDUP, "elapsed 0.0 → WINDUP"],
		[light.phase_at(0.10), AttackDefinition.Phase.WINDUP, "elapsed 0.10 → WINDUP"],
		[light.phase_at(0.18), AttackDefinition.Phase.ACTIVE, "elapsed 0.18 → ACTIVE"],
		[light.phase_at(0.25), AttackDefinition.Phase.ACTIVE, "elapsed 0.25 → ACTIVE"],
		[light.phase_at(0.30), AttackDefinition.Phase.RECOVERY, "elapsed 0.30 → RECOVERY"],
		[light.phase_at(0.49), AttackDefinition.Phase.RECOVERY, "elapsed 0.49 → RECOVERY"],
		[light.phase_at(0.50), AttackDefinition.Phase.FINISHED, "elapsed 0.50 → FINISHED"],
		[light.phase_at(10.0), AttackDefinition.Phase.FINISHED, "elapsed 10.0 → FINISHED"],
	]
	for check in checks:
		if check[0] == check[1]:
			passed += 1
		else:
			failed += 1
			failures.append("%s (got %d)" % [check[2], int(check[0])])

	# Hit-active derivations.
	var hit_checks: Array[Array] = [
		[light.is_hit_active(0.17), false, "just before active"],
		[light.is_hit_active(0.18), true, "active start inclusive"],
		[light.is_hit_active(0.24), true, "mid active"],
		[light.is_hit_active(0.30), false, "active end exclusive"],
	]
	for check in hit_checks:
		if check[0] == check[1]:
			passed += 1
		else:
			failed += 1
			failures.append("hit_active: %s (got %s)" % [check[2], str(check[0])])

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd WUGodot && godot --headless --script res://tests/run_tests.gd
```

Expected: non-zero exit code, failure message about missing `attack_definition.gd`.

- [ ] **Step 3: Write the minimal implementation**

Create `WUGodot/scripts/attack_definition.gd`:

```gdscript
class_name AttackDefinition
extends RefCounted

# Describes one attack's timing, damage, and telegraph data.
# A single AttackDefinition is the source of truth for hit windows —
# Fighter and CombatSystem both derive from it instead of running
# parallel timers.

enum Phase {
	WINDUP,   # [0, windup_end)
	ACTIVE,   # [windup_end, active_end)
	RECOVERY, # [active_end, duration)
	FINISHED, # [duration, ∞)
}

var id: String = ""
var duration: float = 0.5
var windup_end: float = 0.18
var active_end: float = 0.30
var damage: float = 12.0
var posture_damage: float = 22.0
var is_heavy: bool = false
var is_perilous: bool = false   # true → red telegraph, must be dashed
var is_parryable: bool = true   # false → must be dashed even if not perilous
var range_units: float = 72.0
var knockback_units: float = 300.0

func phase_at(elapsed: float) -> int:
	if elapsed < windup_end:
		return Phase.WINDUP
	if elapsed < active_end:
		return Phase.ACTIVE
	if elapsed < duration:
		return Phase.RECOVERY
	return Phase.FINISHED

func is_hit_active(elapsed: float) -> bool:
	return elapsed >= windup_end and elapsed < active_end

func is_finished(elapsed: float) -> bool:
	return elapsed >= duration
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd WUGodot && godot --headless --script res://tests/run_tests.gd
```

Expected output:
```
=== TEST RESULTS ===
passed: 12
failed: 0
```
Exit code: 0.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/attack_definition.gd WUGodot/tests/test_attack_definition.gd
git commit -m "add AttackDefinition data class with phase lookups"
```

---

## Task 3: AttackState runtime

**Files:**
- Create: `WUGodot/scripts/attack_state.gd`
- Create: `WUGodot/tests/test_attack_state.gd`

- [ ] **Step 1: Write the failing test**

Create `WUGodot/tests/test_attack_state.gd`:

```gdscript
extends RefCounted

const AttackDefinition = preload("res://scripts/attack_definition.gd")
const AttackState = preload("res://scripts/attack_state.gd")

func _make_light() -> AttackDefinition:
	var def: AttackDefinition = AttackDefinition.new()
	def.id = "hu_light"
	def.duration = 0.50
	def.windup_end = 0.18
	def.active_end = 0.30
	return def

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var state: AttackState = AttackState.new()

	# Initial state is inactive.
	if not state.is_active() and not state.is_hit_active():
		passed += 1
	else:
		failed += 1
		failures.append("fresh state should be inactive")

	# Start an attack and advance in 0.05s steps. Collect events.
	var def: AttackDefinition = _make_light()
	state.start(def)
	if state.is_active():
		passed += 1
	else:
		failed += 1
		failures.append("after start, should be active")

	var hit_start_seen: bool = false
	var hit_end_seen: bool = false
	var finished_seen: bool = false
	for i in range(60):  # 3.0s worth
		var events: Dictionary = state.advance(0.05)
		if bool(events.get("hit_started", false)):
			hit_start_seen = true
			if absf(state.elapsed - def.windup_end) > 0.06:
				failed += 1
				failures.append("hit_started fired at elapsed %.3f, expected ~%.3f" % [state.elapsed, def.windup_end])
		if bool(events.get("hit_ended", false)):
			hit_end_seen = true
		if bool(events.get("finished", false)):
			finished_seen = true
			break

	if hit_start_seen:
		passed += 1
	else:
		failed += 1
		failures.append("hit_started event never fired")
	if hit_end_seen:
		passed += 1
	else:
		failed += 1
		failures.append("hit_ended event never fired")
	if finished_seen:
		passed += 1
	else:
		failed += 1
		failures.append("finished event never fired")
	if not state.is_active():
		passed += 1
	else:
		failed += 1
		failures.append("state should be inactive after finished event")

	# Clear should reset.
	state.start(_make_light())
	state.clear()
	if not state.is_active() and state.elapsed == 0.0:
		passed += 1
	else:
		failed += 1
		failures.append("clear() did not reset state")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd WUGodot && godot --headless --script res://tests/run_tests.gd
```

Expected: failure on missing `attack_state.gd`.

- [ ] **Step 3: Write the minimal implementation**

Create `WUGodot/scripts/attack_state.gd`:

```gdscript
class_name AttackState
extends RefCounted

# Runtime state machine for one in-flight attack.
# Wraps an AttackDefinition + an elapsed counter and emits phase events
# when advance(dt) crosses phase boundaries. There is ONE counter for
# both hit detection and visual offset — no parallel timers.

var def: AttackDefinition = null
var elapsed: float = 0.0
var _was_hit_active: bool = false
var _was_finished: bool = true

func start(definition: AttackDefinition) -> void:
	def = definition
	elapsed = 0.0
	_was_hit_active = false
	_was_finished = false

func clear() -> void:
	def = null
	elapsed = 0.0
	_was_hit_active = false
	_was_finished = true

func is_active() -> bool:
	return def != null and not _was_finished

func is_hit_active() -> bool:
	if def == null:
		return false
	return def.is_hit_active(elapsed)

func phase() -> int:
	if def == null:
		return AttackDefinition.Phase.FINISHED
	return def.phase_at(elapsed)

func progress() -> float:
	if def == null or def.duration <= 0.0:
		return 0.0
	return clampf(elapsed / def.duration, 0.0, 1.0)

# Advances the state machine. Returns a dict of edge events that fired this step.
# Keys: hit_started, hit_ended, finished — all bool.
func advance(dt: float) -> Dictionary:
	var events: Dictionary = {
		"hit_started": false,
		"hit_ended": false,
		"finished": false,
	}
	if def == null or _was_finished:
		return events

	elapsed += dt

	var now_hit_active: bool = def.is_hit_active(elapsed)
	if now_hit_active and not _was_hit_active:
		events["hit_started"] = true
	elif (not now_hit_active) and _was_hit_active:
		events["hit_ended"] = true
	_was_hit_active = now_hit_active

	if def.is_finished(elapsed):
		events["finished"] = true
		_was_finished = true
		if _was_hit_active:
			events["hit_ended"] = true
			_was_hit_active = false

	return events
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd WUGodot && godot --headless --script res://tests/run_tests.gd
```

Expected:
```
=== TEST RESULTS ===
passed: 18
failed: 0
```
(12 from Task 2 + 6 from this task.)

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/attack_state.gd WUGodot/tests/test_attack_state.gd
git commit -m "add AttackState runtime with phase-transition events"
```

---

## Task 4: AttackCatalog — replace per-fighter attack timing fields

**Files:**
- Create: `WUGodot/scripts/attack_catalog.gd`
- Modify: `WUGodot/scripts/fighter.gd:88-93`
- Modify: `WUGodot/scripts/enemy_factory.gd:40-43` and `:82-84`
- Modify: `WUGodot/scripts/game_constants.gd:17-19`
- Modify: `WUGodot/data/Characters/Hu.json:20-22`
- Modify: `WUGodot/data/Enemies/BasicEnemy.json:18-21`

This is the single-source-of-truth move. After this task, `AttackCatalog` owns all attack timing numbers. Fighter still has a `_attack_state` but gets the `AttackDefinition` from the catalog.

- [ ] **Step 1: Create `WUGodot/scripts/attack_catalog.gd`**

```gdscript
class_name AttackCatalog
extends RefCounted

# Authoritative list of AttackDefinitions for every in-game attack.
# Numbers here come from Section B of the WU MVP design spec.
# Do not duplicate these values in Fighter or JSON — always read from here.

static func hu_light() -> AttackDefinition:
	var def: AttackDefinition = AttackDefinition.new()
	def.id = "hu_light"
	def.duration = 0.50
	def.windup_end = 0.18
	def.active_end = 0.30
	def.damage = 12.0
	def.posture_damage = 22.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 72.0
	def.knockback_units = 300.0
	return def

static func hu_heavy() -> AttackDefinition:
	var def: AttackDefinition = AttackDefinition.new()
	def.id = "hu_heavy"
	def.duration = 0.85
	def.windup_end = 0.40
	def.active_end = 0.55
	def.damage = 22.0
	def.posture_damage = 42.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 84.0
	def.knockback_units = 420.0
	return def

static func bandit_slash() -> AttackDefinition:
	var def: AttackDefinition = AttackDefinition.new()
	def.id = "bandit_slash"
	def.duration = 0.80
	def.windup_end = 0.45
	def.active_end = 0.60
	def.damage = 10.0
	def.posture_damage = 24.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 68.0
	def.knockback_units = 260.0
	return def

static func bandit_thrust_perilous() -> AttackDefinition:
	var def: AttackDefinition = AttackDefinition.new()
	def.id = "bandit_thrust_perilous"
	def.duration = 0.90
	def.windup_end = 0.55
	def.active_end = 0.68
	def.damage = 14.0
	def.posture_damage = 20.0
	def.is_heavy = false
	def.is_perilous = true     # red telegraph — must be dashed
	def.is_parryable = false
	def.range_units = 88.0
	def.knockback_units = 320.0
	return def
```

- [ ] **Step 2: Remove obsolete fields and the legacy telegraph path from Fighter**

Edit `WUGodot/scripts/fighter.gd`.

**Delete lines 91-93** (attack timing fields, moved to AttackCatalog):
```gdscript
var attack_duration: float = GameConstants.ATTACK_DURATION
var attack_active_start: float = GameConstants.ATTACK_ACTIVE_START
var attack_active_end: float = GameConstants.ATTACK_ACTIVE_END
```

**Delete lines 107, 110-111** (`was_hit_this_swing` on 108 is kept; the next three are the telegraph state):
```gdscript
var is_telegraphing: bool = false
...
var telegraph_timer: float = 0.0
var telegraph_duration: float = 0.35
```
There is no longer any "pre-attack telegraph" concept; the AI fires its AttackDefinition directly and the WINDUP phase of that definition IS the telegraph.

**Delete the `start_telegraph()` method** (lines 251-254):
```gdscript
func start_telegraph() -> void:
    if can_attack():
        is_telegraphing = true
        telegraph_timer = telegraph_duration
```

**Delete the telegraph block inside `update_timers()`** (lines 178-181):
```gdscript
if is_telegraphing:
    telegraph_timer -= dt
    if telegraph_timer < -1.0:
        is_telegraphing = false
```

**Delete the `is_telegraphing = false` line in `apply_stun()`** (line 313). Stun already implies no in-flight attack; the AttackState clear in Task 5 Step 7 covers the rest.

**Remove `not is_telegraphing` from `can_attack()`** (line 225) — the attack state itself now gates whether a new attack can start. This line is fully rewritten in Task 5 Step 5.

**Add the AttackState at the location of the old attack timing fields** (around where lines 91-93 used to be):
```gdscript
var _attack_state: AttackState = AttackState.new()
```

**Keep `attack_damage`** (line 88) — still used by enemies that don't have a full AttackDefinition pipeline yet. The new rule: during an attack, damage comes from `_attack_state.def.damage`; outside an attack, reference `attack_damage` as the fallback base.

> **Why now and not Task 5:** The telegraph fields do not compile alongside the new `_attack_state` flow (the references to them would block the parser), so they must go in the same commit as the other field deletions. The intermediate-regression commit from Task 4 to Task 5 already expects attacks to whiff; removing telegraph fields here does not add any new regression.

- [ ] **Step 3: Remove obsolete constants from GameConstants**

Edit `WUGodot/scripts/game_constants.gd`, delete lines 17-19:
```gdscript
const ATTACK_DURATION: float = 0.50
const ATTACK_ACTIVE_START: float = 0.18
const ATTACK_ACTIVE_END: float = 0.30
```

- [ ] **Step 4: Stop writing those fields in `enemy_factory.gd`**

Edit `WUGodot/scripts/enemy_factory.gd`:

Delete lines 40-43 in `create_enemy_for_node`:
```gdscript
enemy.attack_duration = float(enemy_data.get("attackDuration", 0.40))
enemy.attack_active_start = float(enemy_data.get("attackActiveStart", 0.20))
enemy.attack_active_end = float(enemy_data.get("attackActiveEnd", 0.34))
enemy.telegraph_duration = float(enemy_data.get("telegraphDuration", 0.45))
```

Delete lines 82-84 in `create_player`:
```gdscript
player.attack_duration = float(character_data.get("attackDuration", 0.35))
player.attack_active_start = float(character_data.get("attackActiveStart", 0.10))
player.attack_active_end = float(character_data.get("attackActiveEnd", 0.18))
```

- [ ] **Step 5: Remove obsolete JSON fields**

Edit `WUGodot/data/Characters/Hu.json` — remove `attackDuration`, `attackActiveStart`, `attackActiveEnd` lines.

Edit `WUGodot/data/Enemies/BasicEnemy.json` — remove `attackDuration`, `attackActiveStart`, `attackActiveEnd`, `telegraphDuration` lines.

- [ ] **Step 6: Temporarily stub `Fighter.is_hit_active()` to always return false**

Edit `WUGodot/scripts/fighter.gd` — `is_hit_active()` currently reads `_attack_timer` which we still need for one more task (Task 5). Leave `is_hit_active()` as a stub that returns `false` for this task — the game will not deal attack damage until Task 5, which is the next task. This intermediate commit is deliberately a non-functional-combat state because Task 5 immediately restores it via the new `AttackState` path.

Replace lines 273-274:
```gdscript
func is_hit_active() -> bool:
	return _attack_timer > 0.0 and _attack_timer <= (attack_duration - attack_active_start) and _attack_timer >= (attack_duration - attack_active_end)
```

With:
```gdscript
func is_hit_active() -> bool:
	# TEMPORARY stub — Task 5 restores this via _attack_state.
	return _attack_state.is_hit_active()
```

Since `_attack_state` is never `start()`ed yet (Task 5 wires that), this returns false and attacks whiff. **This single-task regression is intentional** — the following task immediately fixes it, and both tasks should ideally be reviewed together or executed back-to-back.

- [ ] **Step 7: Run headless tests to confirm nothing broke**

```bash
cd WUGodot && godot --headless --script res://tests/run_tests.gd
```

Expected: same 18/0 pass as before. If Godot's parser rejects a referenced-but-deleted field, fix the reference immediately.

- [ ] **Step 8: Commit**

```bash
git add WUGodot/scripts/attack_catalog.gd WUGodot/scripts/fighter.gd WUGodot/scripts/game_constants.gd WUGodot/scripts/enemy_factory.gd WUGodot/data/Characters/Hu.json WUGodot/data/Enemies/BasicEnemy.json
git commit -m "introduce AttackCatalog; migrate attack timing fields out of Fighter/JSON (non-functional intermediate — Task 5 restores hit resolution)"
```

---

## Task 5: Fighter uses AttackState; delete parallel `_attack_timer`

**Files:**
- Modify: `WUGodot/scripts/fighter.gd` (multiple locations — see steps)
- Modify: `WUGodot/scripts/combat_system.gd:50-58`

- [ ] **Step 1: Add `start_light_attack()` on Fighter**

Edit `WUGodot/scripts/fighter.gd`:

Delete line 124 `var _attack_timer: float = 0.0` (replaced by `_attack_state`).

Replace `start_attack()` (lines 256-271) entirely:

```gdscript
func start_light_attack() -> void:
	_start_attack_with(AttackCatalog.hu_light())

func start_heavy_attack() -> void:
	_start_attack_with(AttackCatalog.hu_heavy())

func _start_attack_with(def: AttackDefinition) -> void:
	if _attack_state.is_active() or _attack_cooldown > 0.0 or is_stunned or _landing_recovery > 0.0:
		return

	combo_count = combo_count + 1 if combo_window > 0.0 else 1
	combo_window = combo_window_duration

	_attack_state.start(def)
	_attack_cooldown = def.duration * (0.8 if combo_count > 2 else 1.0)
	was_hit_this_swing = false
	current_animation = AnimationState.ATTACKING
	animation_timer = 0.0

	if not is_grounded:
		velocity.y *= 0.5
```

- [ ] **Step 2: Update `update_timers(dt)` to advance the AttackState**

Replace lines 164-169 (the old `_attack_timer` countdown block) with:

```gdscript
if _attack_state.is_active():
	var events: Dictionary = _attack_state.advance(dt)
	if bool(events.get("finished", false)):
		was_hit_this_swing = false
		current_animation = AnimationState.IDLE
```

- [ ] **Step 3: Update `_update_animation` to use `_attack_state.progress()`**

Replace lines 189-191:
```gdscript
AnimationState.ATTACKING:
	var attack_progress: float = 1.0 - (_attack_timer / maxf(attack_duration, 0.001))
	animation_offset.x = sin(attack_progress * PI) * 15.0 * float(facing)
```

With:
```gdscript
AnimationState.ATTACKING:
	var attack_progress: float = _attack_state.progress()
	animation_offset.x = sin(attack_progress * PI) * 15.0 * float(facing)
```

- [ ] **Step 4: Update `is_hit_active()` to derive from `_attack_state`**

Replace the stub from Task 4 Step 6 with the real implementation:

```gdscript
func is_hit_active() -> bool:
	return _attack_state.is_hit_active()
```

(This line is already there from Task 4 Step 6 — this step is confirming it stays put.)

- [ ] **Step 5: Update `can_attack()`**

Replace line 225:
```gdscript
return _attack_timer <= 0.0 and _attack_cooldown <= 0.0 and not is_stunned and not is_telegraphing and _landing_recovery <= 0.0
```

With:
```gdscript
return not _attack_state.is_active() and _attack_cooldown <= 0.0 and not is_stunned and _landing_recovery <= 0.0
```

Note the double removal: `_attack_timer <= 0.0` → `not _attack_state.is_active()` (AttackState is the single source of truth), and `not is_telegraphing` is gone (the field is deleted in Task 4 Step 2; the AttackState's WINDUP phase replaces that concept). After this edit, all fighter attack-readiness logic flows through `_attack_state`.

- [ ] **Step 6: Update `is_in_recovery()`**

Replace line 322:
```gdscript
return _attack_timer <= 0.0 and _attack_cooldown > 0.0
```

With:
```gdscript
return not _attack_state.is_active() and _attack_cooldown > 0.0
```

- [ ] **Step 7: Update `apply_stun()`**

Replace line 311:
```gdscript
_attack_timer = 0.0
```

With:
```gdscript
_attack_state.clear()
```

- [ ] **Step 8: Update `CombatSystem.update_player` to call the new function**

Edit `WUGodot/scripts/combat_system.gd` lines 50-51:

Replace:
```gdscript
if bool(input_state.get("attack_pressed", false)) and fighter.can_attack():
	fighter.start_attack()
```

With:
```gdscript
if bool(input_state.get("attack_pressed", false)) and fighter.can_attack():
	fighter.start_light_attack()
```

(Heavy attack support is added in Task 7.)

- [ ] **Step 9: Replace `CombatSystem.update_ai` telegraph dance with a direct attack commit**

The old update_ai had a two-stage attack path: when the AI decided to attack, it called `ai.start_telegraph()`, which set `is_telegraphing = true` and burned `telegraph_timer` seconds before `ai.start_attack()` was finally called. That second timing path is now deleted — the AttackDefinition's WINDUP phase provides all the player-visible warning the old telegraph used to provide, and the silver/red flash comes from `current_telegraph_color()` reading `_attack_state.phase() == WINDUP`.

Edit `WUGodot/scripts/combat_system.gd` `update_ai()`.

**Replace lines 123-125** (the old attack-decision block):
```gdscript
var attack_chance: float = 0.25 * aggression_multiplier
if ai.can_attack() and _rng.randf() < attack_chance:
	ai.start_telegraph()
```

With:
```gdscript
# Rolling a 25% * aggression chance per frame is very aggressive at 60fps;
# the old telegraph stage added ~0.35s of enforced delay that compensated.
# Without it, we need a per-decision cooldown so the AI does not spam-fire
# the instant its cooldown ends. 0.25s decision gate keeps the cadence similar
# to the old flow's total time-from-can_attack to attack-fire.
if ai.can_attack() and ai._ai_decision_timer <= 0.0 and _rng.randf() < 0.25 * aggression_multiplier:
	ai._start_attack_with(AttackCatalog.bandit_slash())
	ai._ai_decision_timer = 0.25
```

**Replace lines 133-136** (the old "telegraph timer expired, now fire" block):
```gdscript
if ai.is_telegraphing and ai.telegraph_timer <= 0.0:
	ai.start_attack()
	if ai.combo_count > 0 and _rng.randf() < 0.3 * aggression_multiplier:
		ai.combo_window = 0.4
```

With:
```gdscript
# Removed: the two-stage telegraph→fire dance is gone. AI now fires directly
# from the decision block above; the AttackDefinition's WINDUP phase provides
# the player-visible warning. Combo extension is simpler too:
if ai._attack_state.is_active() and ai._attack_state.elapsed < 0.01 and ai.combo_count > 0 and _rng.randf() < 0.3 * aggression_multiplier:
	ai.combo_window = 0.4
```

- [ ] **Step 9b: Add the decision-timer field to Fighter**

The AI decision gate needs a field on Fighter to persist across frames. Edit `WUGodot/scripts/fighter.gd`, add near the other timer fields (around line 132, next to `_iframe_timer`):

```gdscript
var _ai_decision_timer: float = 0.0
```

And add its countdown inside `update_timers(dt)` (wherever the other timers are counted):

```gdscript
if _ai_decision_timer > 0.0:
	_ai_decision_timer -= dt
```

- [ ] **Step 9c: Headless tests — still 18/0**

```bash
cd WUGodot && godot --headless --script res://tests/run_tests.gd
```

Expected: 18/0 unchanged. None of the test modules touch the AI path, so the refactor is pure-logic-safe.

- [ ] **Step 10: Smoke-test in editor**

Launch `Main.tscn`, enter combat. Verify:

1. Player light attack connects and deals damage (was broken after Task 4 step 6 stub; now fixed).
2. Bandit attacks and deals damage.
3. No parser errors, no runtime errors.
4. Parry still works.
5. Hit windows feel consistent with the new 0.50s / 0.18–0.30 active window.

- [ ] **Step 11: Run headless tests**

```bash
cd WUGodot && godot --headless --script res://tests/run_tests.gd
```

Expected: still 18/0.

- [ ] **Step 12: Commit**

```bash
git add WUGodot/scripts/fighter.gd WUGodot/scripts/combat_system.gd
git commit -m "refactor Fighter to use AttackState as single source of truth (delete parallel _attack_timer)"
```

---

## Task 6: `InputTracker` hold-duration and edge helpers for J-tap-vs-hold

**Files:**
- Modify: `WUGodot/scripts/input_tracker.gd`

The heavy attack in Task 7 needs to classify "tap" vs "hold" for the J key. That decision is made when the threshold (0.25s) is crossed or when the key is released. On the release frame the hold duration has to still be readable — if we zero it the moment Godot reports the key is no longer pressed, the release-frame classifier sees 0.0 and misfires. The `update_hold_timers` implementation below preserves the final duration across the release frame by explicit edge-based bookkeeping, then zeros on the first fully-idle frame.

- [ ] **Step 1: Extend `input_tracker.gd`**

Replace the full file with:

```gdscript
class_name InputTracker
extends RefCounted

var _prev_keys: Dictionary = {}
var _prev_mouse_buttons: Dictionary = {}
var _key_hold_ms: Dictionary = {}  # keycode -> float seconds (or last final hold, preserved across release frame)

func clear() -> void:
	_prev_keys.clear()
	_prev_mouse_buttons.clear()
	_key_hold_ms.clear()

func pressed_key(keycode: int) -> bool:
	var current: bool = Input.is_key_pressed(keycode)
	var previous: bool = bool(_prev_keys.get(keycode, false))
	return current and not previous

func released_key(keycode: int) -> bool:
	var current: bool = Input.is_key_pressed(keycode)
	var previous: bool = bool(_prev_keys.get(keycode, false))
	return (not current) and previous

func pressed_mouse(button_index: int) -> bool:
	var current: bool = Input.is_mouse_button_pressed(button_index)
	var previous: bool = bool(_prev_mouse_buttons.get(button_index, false))
	return current and not previous

func is_held(keycode: int) -> bool:
	return Input.is_key_pressed(keycode)

func hold_duration(keycode: int) -> float:
	return float(_key_hold_ms.get(keycode, 0.0))

# Advances per-key hold timers once per frame. CRITICAL ordering requirement:
# call this BEFORE any consumer reads hold_duration() and BEFORE sync_keys()
# syncs _prev_keys for the next frame. Semantics:
#
#   current=true,  prev=false → rising edge: start hold at `dt`
#   current=true,  prev=true  → continuing hold: accumulate `dt`
#   current=false, prev=true  → falling edge: PRESERVE the value so the
#                               release handler on this same frame reads
#                               the true final hold duration
#   current=false, prev=false → idle: zero
#
# Because _prev_keys is only updated at end-of-frame by sync_keys(), reading
# _prev_keys here correctly reflects last frame's state.
func update_hold_timers(keys: Array[int], dt: float) -> void:
	for key in keys:
		var current: bool = Input.is_key_pressed(key)
		var previous: bool = bool(_prev_keys.get(key, false))
		if current and not previous:
			_key_hold_ms[key] = dt
		elif current and previous:
			_key_hold_ms[key] = float(_key_hold_ms.get(key, 0.0)) + dt
		elif (not current) and previous:
			# Falling edge: keep the value so the release handler reads the full hold.
			pass
		else:
			# Idle: ensure zero so the next press starts clean.
			_key_hold_ms[key] = 0.0

func sync_keys(keys: Array[int]) -> void:
	for key in keys:
		_prev_keys[key] = Input.is_key_pressed(key)

func sync_mouse_buttons(buttons: Array[int]) -> void:
	for button in buttons:
		_prev_mouse_buttons[button] = Input.is_mouse_button_pressed(button)
```

The additions:
- `released_key()` — edge detection on key-up.
- `is_held()` — thin wrapper on `Input.is_key_pressed` for consistency.
- `hold_duration()` — returns seconds the key has been continuously held; preserved across the release frame so a same-frame release handler sees the true final hold.
- `update_hold_timers(keys, dt)` — must be called once per frame, BEFORE the frame's release handlers and BEFORE `sync_keys()`.

- [ ] **Step 2: Smoke-test that existing callers still work**

Launch `Main.tscn` and play through map → combat → map. Nothing new added yet, so existing behavior must match Task 5.

- [ ] **Step 3: Commit**

```bash
git add WUGodot/scripts/input_tracker.gd
git commit -m "add hold-duration and released_key helpers to InputTracker"
```

---

## Task 7: Heavy attack on J-hold ≥ 0.25s

**Files:**
- Modify: `WUGodot/scripts/fighter.gd` — `controls` dict
- Modify: `WUGodot/scripts/combat_scene.gd` — `_build_player_input()` and `_sync_input_tracker()`
- Modify: `WUGodot/scripts/combat_system.gd` — `update_player()` heavy-attack branch

- [ ] **Step 1: Add a `_heavy_committed_attack` field to CombatScene**

Edit `WUGodot/scripts/combat_scene.gd`. Add near the other state flags (e.g. right after line 25 `var _debug_enabled: bool = false`):

```gdscript
var _heavy_committed_attack: bool = false  # true after J-hold has crossed 0.25s this press; reset on release
```

Also clear it inside `setup_combat()` near `_input_tracker.clear()` (line 74):

```gdscript
_heavy_committed_attack = false
```

- [ ] **Step 2: Advance the hold timer once per frame, BEFORE reading it**

In `_process(delta)`, right after line 124 (`_combat_system.update_facing(_player, _enemy)`) and BEFORE the `_build_player_input()` call on line 126, add:

```gdscript
var attack_key: int = int(_player.controls.get("attack", KEY_J))
_input_tracker.update_hold_timers([attack_key], delta)  # NB: delta, not dt — hold threshold is real clock time, not game time
```

The `delta`-vs-`dt` choice matters: the 0.25s hold threshold is a human-perception window, so it should elapse in real time. If we used `dt` (scaled by slow-motion), the heavy-charge threshold would stretch during parry slow-mo, which the player would feel as the button "getting stuck."

- [ ] **Step 3: Replace `_build_player_input()` (lines 153-177)**

```gdscript
func _build_player_input() -> Dictionary:
	var left_key: int = int(_player.controls.get("left", KEY_A))
	var right_key: int = int(_player.controls.get("right", KEY_D))
	var jump_key: int = int(_player.controls.get("jump", KEY_W))
	var dash_key: int = int(_player.controls.get("dash", KEY_SPACE))
	var attack_key: int = int(_player.controls.get("attack", KEY_J))
	var block_key: int = int(_player.controls.get("block", KEY_K))

	var left_down: bool = Input.is_key_pressed(left_key)
	var right_down: bool = Input.is_key_pressed(right_key)
	var move: float = 0.0
	if left_down:
		move -= 1.0
	if right_down:
		move += 1.0

	# --- Tap-vs-hold classification for J ---
	# Spec: light attack = tap J, heavy attack = hold J ≥ 0.25s then release.
	# Responsiveness discipline:
	#   * Heavy fires on THRESHOLD CROSSING while still held — zero latency past 0.25s.
	#   * Light fires on RELEASE, but only if heavy has not already fired this press.
	# This is the cleanest latency profile for single-button tap-vs-hold: the only
	# latency cost is on the light attack's release frame (~1-2 frames), which is
	# inherent to not knowing the player's intent until they either release or hold
	# long enough. Task 10 (InputBuffer) makes press-during-recovery chain cleanly.
	var attack_press_edge: bool = _input_tracker.pressed_key(attack_key)
	var attack_release_edge: bool = _input_tracker.released_key(attack_key)
	var attack_held: bool = Input.is_key_pressed(attack_key)
	var attack_hold: float = _input_tracker.hold_duration(attack_key)

	if attack_press_edge:
		_heavy_committed_attack = false  # fresh press: clear the commit flag

	var heavy_pressed: bool = false
	var light_pressed: bool = false

	# Heavy on the single frame the hold crosses 0.25s while still held.
	if attack_held and attack_hold >= 0.25 and not _heavy_committed_attack:
		heavy_pressed = true
		_heavy_committed_attack = true

	# Light on release IF heavy did not already commit this press.
	if attack_release_edge and not _heavy_committed_attack:
		light_pressed = true
	if attack_release_edge:
		_heavy_committed_attack = false  # always reset on release

	return {
		"move": move,
		"jump_pressed": _input_tracker.pressed_key(jump_key),
		"dash_pressed": _input_tracker.pressed_key(dash_key),
		"light_pressed": light_pressed,
		"heavy_pressed": heavy_pressed,
		"block_pressed": _input_tracker.pressed_key(block_key),
		"block_down": Input.is_key_pressed(block_key),
		"attack_holding": attack_held,
		"attack_hold_duration": attack_hold,
	}
```

**Walkthrough of the four cases:**

| Scenario | What happens |
|---|---|
| Tap J (press→release in < 0.25s) | frame 0: press_edge resets commit. frame N (release): not committed → `light_pressed = true`. ✓ |
| Press-and-hold past 0.25s | frame 0: press_edge resets. frame ~15 (hold reaches 0.25s): `heavy_pressed = true`, commit set. frame N (release): committed → light suppressed. ✓ |
| Very long hold (player keeps holding forever) | Heavy fires at threshold crossing, committed stays true, release never happens. Fine. |
| Press during recovery (can't act yet) | Same classification runs; combat_system gates with `can_attack()` so the event is dropped. Task 10 replaces this drop with buffering. |

- [ ] **Step 4: Update `CombatSystem.update_player` to read the new keys**

Edit `WUGodot/scripts/combat_system.gd` lines 50-58:

Replace:
```gdscript
if bool(input_state.get("attack_pressed", false)) and fighter.can_attack():
	fighter.start_light_attack()
	var attack_pos: Vector2 = Vector2(fighter.position.x + float(fighter.facing) * fighter.half_width, fighter.position.y - fighter.height * 0.4)
	var particle_count: int = 6 + fighter.combo_count * 2
	var attack_color: Color = Color8(255, 180, 100) if fighter.combo_count > 2 else Color8(255, 255, 200)
	emit_signal("spawn_particles", attack_pos, particle_count, attack_color)
	emit_signal("camera_shake", 2.0 + fighter.combo_count * 0.5)
	if fighter.combo_count > 2:
		emit_signal("show_feedback", "COMBO x%d!" % fighter.combo_count, 0.5)
```

With:
```gdscript
var attack_pos: Vector2 = Vector2(fighter.position.x + float(fighter.facing) * fighter.half_width, fighter.position.y - fighter.height * 0.4)
if bool(input_state.get("heavy_pressed", false)) and fighter.can_attack():
	fighter.start_heavy_attack()
	emit_signal("spawn_particles", attack_pos, 16, Color8(240, 220, 255))
	emit_signal("camera_shake", 4.5)
	emit_signal("show_feedback", "HEAVY", 0.4)
elif bool(input_state.get("light_pressed", false)) and fighter.can_attack():
	fighter.start_light_attack()
	var particle_count: int = 6 + fighter.combo_count * 2
	var attack_color: Color = Color8(255, 180, 100) if fighter.combo_count > 2 else Color8(255, 255, 200)
	emit_signal("spawn_particles", attack_pos, particle_count, attack_color)
	emit_signal("camera_shake", 2.0 + fighter.combo_count * 0.5)
	if fighter.combo_count > 2:
		emit_signal("show_feedback", "COMBO x%d!" % fighter.combo_count, 0.5)
```

- [ ] **Step 5: Manual playtest the hold threshold**

Launch `Main.tscn`, enter combat. Verify:

1. Tap J quickly → light attack (0.50s).
2. Hold J for visibly longer (~half a second) and release → heavy attack (0.85s, higher damage, "HEAVY" feedback text).
3. Hold J for only ~0.2s and release → still a light attack.
4. Combo chaining still works with taps.

The 0.25s threshold is first-draft tuning; Task 14's playtest checklist includes a line for re-tuning if it feels wrong.

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/combat_scene.gd WUGodot/scripts/combat_system.gd
git commit -m "add heavy attack on J-hold ≥ 0.25s (threshold-crossing heavy, release-classified light)"
```

---

## Task 8: Dash three-phase consolidation

**Files:**
- Modify: `WUGodot/scripts/fighter.gd` — delete `_iframe_timer`, derive `is_invulnerable` from dash phase

Section B wants dash to have a crisp three-phase shape (0.04 / 0.14 / 0.04) with i-frames cleanly in the middle phase. The current code has two overlapping invulnerability systems (`_iframe_timer` AND `_dash_timer > dash_duration * 0.2`) that are hard to reason about.

- [ ] **Step 1: Delete `_iframe_timer` field**

Edit `WUGodot/scripts/fighter.gd`.

Delete line 132: `var _iframe_timer: float = 0.0`.

Delete lines 148-149 in `update_timers(dt)`:
```gdscript
if _iframe_timer > 0.0:
	_iframe_timer -= dt
```

- [ ] **Step 2: Replace `is_invulnerable` derivation**

Replace line 156:
```gdscript
is_invulnerable = _iframe_timer > 0.0 or (_dash_timer > 0.0 and _dash_timer > dash_duration * 0.2)
```

With:
```gdscript
is_invulnerable = _compute_is_invulnerable()
```

Add the helper after `update_timers`:

```gdscript
func _compute_is_invulnerable() -> bool:
	if _dash_timer <= 0.0:
		return false
	# _dash_timer counts DOWN from dash_duration. Convert to elapsed.
	var dash_elapsed: float = dash_duration - _dash_timer
	return dash_elapsed >= GameConstants.DASH_STARTUP_END and dash_elapsed < GameConstants.DASH_IFRAME_END
```

- [ ] **Step 3: Remove `_iframe_timer` from `start_dash`**

Delete line 287 in `start_dash`:
```gdscript
_iframe_timer = dash_duration * 0.7
```

- [ ] **Step 4: Expose dash phase for the debug overlay**

Add a method after `_compute_is_invulnerable`:

```gdscript
func dash_phase_label() -> String:
	if _dash_timer <= 0.0:
		return "idle"
	var dash_elapsed: float = dash_duration - _dash_timer
	if dash_elapsed < GameConstants.DASH_STARTUP_END:
		return "startup"
	if dash_elapsed < GameConstants.DASH_IFRAME_END:
		return "iframes"
	return "recovery"
```

- [ ] **Step 5: Manual playtest**

Launch `Main.tscn`, enter combat. Dash through a Bandit attack:

1. Dashing at the exact moment of a Bandit active frame: you still get hit if you dash too early or too late (no invulnerability).
2. Dashing ~0.05s before the Bandit's active frame: you phase through cleanly (i-frames 0.04–0.18).
3. Dashing feels committed — there's a small tail where you can't act again.

- [ ] **Step 6: Run headless tests**

```bash
cd WUGodot && godot --headless --script res://tests/run_tests.gd
```

Expected: still 18/0.

- [ ] **Step 7: Commit**

```bash
git add WUGodot/scripts/fighter.gd
git commit -m "consolidate dash into explicit three-phase state, delete _iframe_timer"
```

---

## Task 9: Stance L key scaffold

**Files:**
- Modify: `WUGodot/scripts/fighter.gd` — `controls` dict, `on_stance_input()` hook
- Modify: `WUGodot/scripts/combat_scene.gd` — `_sync_input_tracker` and `_build_player_input` handle stance
- Modify: `WUGodot/scripts/combat_system.gd` — route stance input to fighter

The L key is the designated D-type activation key (Section B, dedicated-key rationale). Plan 1's job is to wire the input path end-to-end with a no-op hook that later plans hang behavior on.

- [ ] **Step 1: Add stance control mapping**

Edit `WUGodot/scripts/fighter.gd`. Update `player_controls()` (lines 324-332):

```gdscript
static func player_controls() -> Dictionary:
	return {
		"left": KEY_A,
		"right": KEY_D,
		"attack": KEY_J,
		"block": KEY_K,
		"dash": KEY_SPACE,
		"jump": KEY_W,
		"stance": KEY_L,
	}
```

And `none_controls()` (lines 334-342):

```gdscript
static func none_controls() -> Dictionary:
	return {
		"left": KEY_NONE,
		"right": KEY_NONE,
		"attack": KEY_NONE,
		"block": KEY_NONE,
		"dash": KEY_NONE,
		"jump": KEY_NONE,
		"stance": KEY_NONE,
	}
```

Same `controls` field default on line 115-122 — add `"stance": KEY_L,` as the last entry.

- [ ] **Step 2: Add `on_stance_input()` hook on Fighter**

Add at the end of `fighter.gd`:

```gdscript
# Hook called when the stance (L) key is pressed.
# In Plan 1 this is a no-op with a debug print. Plan 2 wires D-type stance
# activation here (drunken_form / tiger_stance) gated on rage_current == rage_max.
func on_stance_input() -> void:
	print("[fighter] stance input (no D-type equipped yet)")
```

- [ ] **Step 3: Pick up the stance key in combat_scene input state**

Edit `WUGodot/scripts/combat_scene.gd` `_build_player_input()`:

Add this block right before the return statement:

```gdscript
var stance_key: int = int(_player.controls.get("stance", KEY_NONE))
var stance_pressed: bool = stance_key != KEY_NONE and _input_tracker.pressed_key(stance_key)
```

Add `"stance_pressed": stance_pressed,` as a new key in the returned dict.

- [ ] **Step 4: Route stance in combat_system**

Edit `WUGodot/scripts/combat_system.gd` `update_player()`. Add after the block-handling code at line 72 (just before the `if not fighter.is_grounded:` block):

```gdscript
if bool(input_state.get("stance_pressed", false)):
	fighter.on_stance_input()
```

- [ ] **Step 5: Smoke-test**

Launch `Main.tscn`, enter combat, press L. The Godot console should print `[fighter] stance input (no D-type equipped yet)` on every press.

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/fighter.gd WUGodot/scripts/combat_scene.gd WUGodot/scripts/combat_system.gd
git commit -m "add L-key stance input scaffold with no-op hook for future D-type techniques"
```

---

## Task 10: InputBuffer — 0.15s action buffer

**Files:**
- Create: `WUGodot/scripts/input_buffer.gd`
- Create: `WUGodot/tests/test_input_buffer.gd`
- Modify: `WUGodot/scripts/combat_scene.gd` — record actions into buffer, consume in `_build_player_input`

Section B rule 3: inputs are buffered for 0.15s. If you press attack during the last 9 frames of recovery, it chains automatically.

- [ ] **Step 1: Write the failing test**

Create `WUGodot/tests/test_input_buffer.gd`:

```gdscript
extends RefCounted

const InputBuffer = preload("res://scripts/input_buffer.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var buf: InputBuffer = InputBuffer.new()

	# Record "attack", consume immediately → true.
	buf.record("attack")
	if buf.consume("attack"):
		passed += 1
	else:
		failed += 1
		failures.append("immediate consume should succeed")

	# Consuming again returns false (single-consume).
	if not buf.consume("attack"):
		passed += 1
	else:
		failed += 1
		failures.append("double consume should return false")

	# Record, advance 0.10s, consume → true (within window).
	buf.record("dash")
	buf.advance(0.10)
	if buf.consume("dash"):
		passed += 1
	else:
		failed += 1
		failures.append("consume at 0.10s should succeed (window 0.15)")

	# Record, advance 0.20s, consume → false (past window).
	buf.record("parry")
	buf.advance(0.20)
	if not buf.consume("parry"):
		passed += 1
	else:
		failed += 1
		failures.append("consume at 0.20s should fail (window 0.15)")

	# Different actions are independent.
	buf.record("attack")
	buf.record("jump")
	if buf.consume("attack") and buf.consume("jump"):
		passed += 1
	else:
		failed += 1
		failures.append("independent actions should consume independently")

	# Custom window.
	var short_buf: InputBuffer = InputBuffer.new(0.05)
	short_buf.record("a")
	short_buf.advance(0.08)
	if not short_buf.consume("a"):
		passed += 1
	else:
		failed += 1
		failures.append("custom 0.05 window should expire before 0.08")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd WUGodot && godot --headless --script res://tests/run_tests.gd
```

Expected: failure on missing `input_buffer.gd`.

- [ ] **Step 3: Write the minimal implementation**

Create `WUGodot/scripts/input_buffer.gd`:

```gdscript
class_name InputBuffer
extends RefCounted

# Records timestamped action presses and lets callers consume them within
# a bounded window. One-shot: a successful consume removes the entry.
# Default window is 0.15s (9 frames at 60 fps), per Section B rule 3.

const DEFAULT_WINDOW_SECONDS: float = 0.15

var _window: float
var _pending: Dictionary = {}  # action_name -> age seconds (0.0 when just recorded)

func _init(window_seconds: float = DEFAULT_WINDOW_SECONDS) -> void:
	_window = window_seconds

func record(action: String) -> void:
	_pending[action] = 0.0

func advance(dt: float) -> void:
	var expired: Array[String] = []
	for action in _pending.keys():
		var age: float = float(_pending[action]) + dt
		if age > _window:
			expired.append(String(action))
		else:
			_pending[action] = age
	for action in expired:
		_pending.erase(action)

func has(action: String) -> bool:
	return _pending.has(action)

func consume(action: String) -> bool:
	if not _pending.has(action):
		return false
	_pending.erase(action)
	return true

func clear() -> void:
	_pending.clear()

func pending_actions() -> Array[String]:
	var result: Array[String] = []
	for action in _pending.keys():
		result.append(String(action))
	return result
```

- [ ] **Step 4: Run to verify pass**

```bash
cd WUGodot && godot --headless --script res://tests/run_tests.gd
```

Expected:
```
=== TEST RESULTS ===
passed: 24
failed: 0
```

- [ ] **Step 5: Wire the buffer into combat_scene**

Edit `WUGodot/scripts/combat_scene.gd`.

Add at line 27 (next to `_input_tracker`):

```gdscript
var _input_buffer: InputBuffer = InputBuffer.new()
```

Add buffer advancement in `_process(delta)`, right after the existing `_input_tracker.update_hold_timers(...)` line added in Task 7:

```gdscript
_input_buffer.advance(delta)
```

(Note: `delta`, not `dt`. The buffer's time cost is clock-time, not game-time — a buffered input recorded 0.15s of real clock time ago should still expire even if the game is in slow-mo.)

Replace `_build_player_input()` so the light/heavy/dash/jump/block/stance inputs flow through the buffer:

```gdscript
func _build_player_input() -> Dictionary:
	var left_key: int = int(_player.controls.get("left", KEY_A))
	var right_key: int = int(_player.controls.get("right", KEY_D))
	var jump_key: int = int(_player.controls.get("jump", KEY_W))
	var dash_key: int = int(_player.controls.get("dash", KEY_SPACE))
	var attack_key: int = int(_player.controls.get("attack", KEY_J))
	var block_key: int = int(_player.controls.get("block", KEY_K))
	var stance_key: int = int(_player.controls.get("stance", KEY_NONE))

	# Record edge events into the buffer.
	if _input_tracker.pressed_key(jump_key):
		_input_buffer.record("jump")
	if _input_tracker.pressed_key(dash_key):
		_input_buffer.record("dash")
	if _input_tracker.pressed_key(block_key):
		_input_buffer.record("parry")
	if stance_key != KEY_NONE and _input_tracker.pressed_key(stance_key):
		_input_buffer.record("stance")

	# --- Tap-vs-hold classification for J (buffered variant) ---
	# Identical semantics to Task 7 Step 3 — heavy fires on threshold-crossing,
	# light on release-if-not-committed — but the events go into the buffer
	# instead of the input_state dict. That way a press-during-recovery queues
	# the appropriate action for the first frame can_attack() returns true.
	var attack_press_edge: bool = _input_tracker.pressed_key(attack_key)
	var attack_release_edge: bool = _input_tracker.released_key(attack_key)
	var attack_held: bool = Input.is_key_pressed(attack_key)
	var attack_hold: float = _input_tracker.hold_duration(attack_key)

	if attack_press_edge:
		_heavy_committed_attack = false

	if attack_held and attack_hold >= 0.25 and not _heavy_committed_attack:
		_input_buffer.record("heavy")
		_heavy_committed_attack = true

	if attack_release_edge and not _heavy_committed_attack:
		_input_buffer.record("light")
	if attack_release_edge:
		_heavy_committed_attack = false

	# Consume into the input dict. Consuming removes the pending entry, so a
	# buffered input will fire on the first frame the fighter is allowed to act.
	var can_act_now: bool = _player.can_attack()  # proxy for "ready to honor buffered actions"
	var jump_pressed: bool = _input_buffer.consume("jump") if _player.can_jump() else false
	var dash_pressed: bool = _input_buffer.consume("dash") if _player.can_dash() else false
	var parry_pressed: bool = _input_buffer.consume("parry")  # parry can fire in most states
	var light_pressed: bool = _input_buffer.consume("light") if can_act_now else false
	var heavy_pressed: bool = _input_buffer.consume("heavy") if can_act_now else false
	var stance_pressed: bool = _input_buffer.consume("stance")

	var left_down: bool = Input.is_key_pressed(left_key)
	var right_down: bool = Input.is_key_pressed(right_key)
	var move: float = 0.0
	if left_down:
		move -= 1.0
	if right_down:
		move += 1.0

	return {
		"move": move,
		"jump_pressed": jump_pressed,
		"dash_pressed": dash_pressed,
		"light_pressed": light_pressed,
		"heavy_pressed": heavy_pressed,
		"block_pressed": parry_pressed,
		"block_down": Input.is_key_pressed(block_key),
		"stance_pressed": stance_pressed,
		"attack_holding": attack_held,
		"attack_hold_duration": attack_hold,
	}
```

The key change: actions are only consumed from the buffer **when the fighter is ready to act**. A late attack press during recovery stays in the buffer until `can_attack()` becomes true, at which point it fires on the next frame. That's the chained-attack feel Section B rule 3 promises.

**Buffer expiration and the heavy threshold interact cleanly:** if the player presses J during the last third of a swing's recovery and holds past 0.25s, the buffer receives "heavy" at threshold crossing. If can_attack() is still false at that moment, "heavy" sits in the buffer for up to 0.15s waiting to fire. If recovery ends within 0.15s, the heavy chains; otherwise it expires and the player gets no free action — consistent with the spec's 0.15s buffer window.

Also clear the buffer inside `setup_combat()` — add at line 74 (next to `_input_tracker.clear()`):

```gdscript
_input_buffer.clear()
```

- [ ] **Step 6: Add stance to the synced-keys list in `_sync_input_tracker()`**

The existing `_sync_input_tracker()` (lines 393-401 of `combat_scene.gd`) hardcodes exactly six control keys — `["left", "right", "attack", "block", "dash", "jump"]`. It does NOT iterate the whole `controls` dict, so the new `"stance"` key is NOT synced automatically. Without this fix, `_prev_keys[KEY_L]` never gets updated, which means `_input_tracker.pressed_key(KEY_L)` compares `current=true` against `previous=false` (default) every frame while the key is held, and would re-fire the stance edge event continuously.

Edit `WUGodot/scripts/combat_scene.gd` `_sync_input_tracker()`. Replace lines 393-401:

```gdscript
func _sync_input_tracker() -> void:
	var keys: Array[int] = [KEY_QUOTELEFT, KEY_P, KEY_ENTER, KEY_J]
	if _player != null:
		var control_keys: Array[String] = ["left", "right", "attack", "block", "dash", "jump"]
		for control in control_keys:
			var key: int = int(_player.controls.get(control, KEY_NONE))
			if key != KEY_NONE and not keys.has(key):
				keys.append(key)
	_input_tracker.sync_keys(keys)
```

With:
```gdscript
func _sync_input_tracker() -> void:
	var keys: Array[int] = [KEY_QUOTELEFT, KEY_P, KEY_ENTER, KEY_J]
	if _player != null:
		# Iterate every key the player has declared in controls so new actions
		# (stance L in Task 9, future action keys) are picked up automatically.
		for control_name in _player.controls.keys():
			var key: int = int(_player.controls[control_name])
			if key != KEY_NONE and not keys.has(key):
				keys.append(key)
	_input_tracker.sync_keys(keys)
```

This both fixes the stance edge-detection bug and future-proofs the sync list against new control bindings added in later plans.

- [ ] **Step 6b: Verify KEY_L shows up in the synced list**

Quick debug: add a temporary `print("[sync] ", keys)` inside `_sync_input_tracker` on the first frame of combat and confirm `KEY_76` (the integer value of KEY_L) appears. Remove the print before committing.

- [ ] **Step 7: Playtest the buffering**

Launch `Main.tscn`, enter combat. Specific tests:

1. **Chained attacks.** Start a light attack. During its recovery phase, tap J once. The second light attack should fire on the first frame after `can_attack()` returns true — no "eaten" feeling.
2. **Buffered dash.** Attack and, before recovery ends, press Space. The dash should fire as soon as the attack finishes.
3. **Late inputs expire.** Attack, wait ~0.3s (well past recovery), then tap J. This should NOT queue a second attack — the buffer has expired.
4. **Parry during recovery.** Tap K during a committed swing. Parry should fire immediately if the window is still available, otherwise on the first frame after the attack finishes.

- [ ] **Step 8: Commit**

```bash
git add WUGodot/scripts/input_buffer.gd WUGodot/tests/test_input_buffer.gd WUGodot/scripts/combat_scene.gd
git commit -m "add InputBuffer and route player actions through 0.15s buffer for chainable inputs"
```

---

## Task 11: Color-coded attack telegraphs

**Files:**
- Modify: `WUGodot/scripts/fighter.gd` — `current_telegraph_color()` helper
- Modify: `WUGodot/scripts/combat_scene.gd` — `_draw_fighter` uses telegraph color during windup
- Modify: `WUGodot/scripts/combat_system.gd` — AI sometimes uses the perilous attack

- [ ] **Step 1: Add `current_telegraph_color()` to Fighter**

Add to `WUGodot/scripts/fighter.gd` (near the other helpers):

```gdscript
# Returns the windup flash color for the current attack, or a transparent
# color if the fighter is not currently telegraphing an attack.
# Silver/white → standard parryable attack.
# Red           → perilous attack, must be dashed.
func current_telegraph_color() -> Color:
	if not _attack_state.is_active():
		return Color(0.0, 0.0, 0.0, 0.0)
	if _attack_state.phase() != AttackDefinition.Phase.WINDUP:
		return Color(0.0, 0.0, 0.0, 0.0)
	if _attack_state.def.is_perilous:
		return Color8(227, 66, 52, 220)
	return Color8(220, 220, 240, 200)
```

- [ ] **Step 2: Rip out the legacy `is_telegraphing` flash and replace with the new one**

Edit `WUGodot/scripts/combat_scene.gd` `_draw_fighter()`. The current block (lines 218-228) draws a red flash whenever `fighter.is_telegraphing`. Replace that block with:

```gdscript
var telegraph_color: Color = fighter.current_telegraph_color()
if telegraph_color.a > 0.0:
	var def: AttackDefinition = fighter._attack_state.def
	var windup_progress: float = clampf(fighter._attack_state.elapsed / maxf(def.windup_end, 0.001), 0.0, 1.0)
	var intensity: float = 0.4 + 0.6 * windup_progress
	for size in range(1, 5):
		var outline: Rect2 = Rect2(
			body_rect.position.x - size * 2.0,
			body_rect.position.y - size * 2.0,
			body_rect.size.x + size * 4.0,
			body_rect.size.y + size * 4.0
		)
		var flash_color: Color = Color(telegraph_color.r, telegraph_color.g, telegraph_color.b, telegraph_color.a * intensity / float(size))
		draw_rect(outline, flash_color, false)
```

- [ ] **Step 3: Give the Bandit a chance to throw the perilous thrust**

Edit `WUGodot/scripts/combat_system.gd` `update_ai()`. The Task 5 Step 9 block fires `AttackCatalog.bandit_slash()` directly. Replace that single-attack commit with a weighted pick so ~30% of Bandit attacks are the perilous thrust — the player needs repeated red-flash training examples to learn the color-coding rule in Plan 1. Plan 3 will replace this with proper per-enemy pattern tables.

Replace:
```gdscript
if ai.can_attack() and ai._ai_decision_timer <= 0.0 and _rng.randf() < 0.25 * aggression_multiplier:
	ai._start_attack_with(AttackCatalog.bandit_slash())
	ai._ai_decision_timer = 0.25
```

With:
```gdscript
if ai.can_attack() and ai._ai_decision_timer <= 0.0 and _rng.randf() < 0.25 * aggression_multiplier:
	var next_attack: AttackDefinition = AttackCatalog.bandit_thrust_perilous() if _rng.randf() < 0.30 else AttackCatalog.bandit_slash()
	ai._start_attack_with(next_attack)
	ai._ai_decision_timer = 0.25
```

- [ ] **Step 4: Make perilous attacks ignore BOTH parry and block**

Edit `WUGodot/scripts/combat_system.gd` `resolve_hits()`. "Must be dashed" means the defender gets no benefit from either the parry window OR the hold-block damage reduction — the attack passes straight through for full damage. The current plan only gated the parry branch; the block branch at line 186 still reduces damage whenever `defender.is_blocking` is true, which contradicts the spec.

**Edit 1 — hoist the perilous flag** so both branches can gate on it.

Immediately after the `var vertical_range` line (line 160) and before the `if in_range and vertical_range ...` block, add:
```gdscript
var attack_def: AttackDefinition = attacker._attack_state.def
var attack_is_perilous: bool = attack_def != null and not attack_def.is_parryable
```

**Edit 2 — gate the parry branch.**

Replace lines 166-180 (the entire parry branch):
```gdscript
if defender.consume_parry_if_active():
	attacker.apply_posture_damage(float(settings.get("parryPostureDamage", 55.0)))
	attacker.apply_stun(float(settings.get("parryStunDuration", 0.6)))
	defender.gain_rage(12.0)
	emit_signal("camera_shake", 12.0)

	var parry_pos: Vector2 = defender.position + Vector2(float(defender.facing) * -6.0, -defender.height + 24.0)
	for i in range(24):
		var angle: float = (float(i) / 24.0) * TAU
		var spark_pos: Vector2 = parry_pos + Vector2(cos(angle), sin(angle)) * 30.0
		emit_signal("spawn_particles", spark_pos, 2, Color8(255, 230, 90))

	emit_signal("slow_motion", 0.55, 0.30)
	emit_signal("show_feedback", "PARRY!", 0.8)
	return
```

With:
```gdscript
if defender.consume_parry_if_active() and not attack_is_perilous:
	attacker.apply_posture_damage(float(settings.get("parryPostureDamage", 55.0)))
	attacker.apply_stun(float(settings.get("parryStunDuration", 0.6)))
	defender.gain_rage(12.0)
	emit_signal("camera_shake", 12.0)

	var parry_pos: Vector2 = defender.position + Vector2(float(defender.facing) * -6.0, -defender.height + 24.0)
	for i in range(24):
		var angle: float = (float(i) / 24.0) * TAU
		var spark_pos: Vector2 = parry_pos + Vector2(cos(angle), sin(angle)) * 30.0
		emit_signal("spawn_particles", spark_pos, 2, Color8(255, 230, 90))

	emit_signal("slow_motion", 0.55, 0.30)
	emit_signal("show_feedback", "PARRY!", 0.8)
	return
```

Note: `consume_parry_if_active()` still fires (consuming the parry window) even on a perilous attack — the player's parry attempt is spent. That is the intended punishment: they misread the color and lost their parry. The `not attack_is_perilous` gate only skips the *reward* block.

**Edit 3 — gate the block branch.**

Replace lines 186-192 (the block branch):
```gdscript
if defender.is_blocking:
	hp_damage *= float(settings.get("blockHealthMultiplier", 0.2))
	posture_damage *= float(settings.get("blockPostureMultiplier", 1.6))
	defender.gain_rage(6.0)
	emit_signal("show_feedback", "BLOCKED", 0.5)
else:
	emit_signal("show_feedback", "HIT", 0.3)
```

With:
```gdscript
if defender.is_blocking and not attack_is_perilous:
	hp_damage *= float(settings.get("blockHealthMultiplier", 0.2))
	posture_damage *= float(settings.get("blockPostureMultiplier", 1.6))
	defender.gain_rage(6.0)
	emit_signal("show_feedback", "BLOCKED", 0.5)
elif defender.is_blocking and attack_is_perilous:
	# Perilous attacks bypass block entirely — full damage lands.
	emit_signal("show_feedback", "UNBLOCKABLE!", 0.6)
else:
	emit_signal("show_feedback", "HIT", 0.3)
```

Perilous attacks now cannot be parried AND cannot be reduced by block — they pass through for full damage. Dash is the only answer. This wires the "must be dashed" half of Section B rule 4.

- [ ] **Step 5: Manual playtest**

Launch `Main.tscn`, enter combat. Verify:

1. Most Bandit attacks flash **silver/white** during windup.
2. Roughly 30% of attacks flash **red** instead.
3. Parrying a silver attack works and triggers the parry reward (stun, posture damage, slow-mo).
4. Parrying a red attack does NOT trigger a parry — you get hit anyway. You must dash to avoid it.
5. The color is visible during the attack's windup phase (0.45s for Bandit) — enough time to read and react.

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/fighter.gd WUGodot/scripts/combat_scene.gd WUGodot/scripts/combat_system.gd
git commit -m "add color-coded telegraphs (silver parryable, red perilous); unparryable gate"
```

---

## Task 12: Feedback discipline — hitstop, camera shake, particles

**Files:**
- Modify: `WUGodot/scripts/combat_system.gd` — new `hitstop` signal; updated particle/shake values
- Modify: `WUGodot/scripts/combat_scene.gd` — `hitstop` signal handler + tighter slow-motion clamp

Section B rule 5 specifies exact hitstop values: 0.05 normal, 0.10 heavy, 0.15 parry, 0.18 posture break. Current code has no hitstop at all — only the post-parry 0.55 slow-motion. Add a proper hitstop mechanism that layers on top of slow-motion.

- [ ] **Step 1: Add `hitstop` signal to CombatSystem**

Edit `WUGodot/scripts/combat_system.gd`. Add after line 8 (`signal damage_dealt`):

```gdscript
signal hitstop(duration: float)
```

- [ ] **Step 2: Emit `hitstop` from `resolve_hits`**

In `resolve_hits()`, immediately after the parry branch emits `slow_motion(0.55, 0.30)` (line 178), add:

```gdscript
emit_signal("hitstop", 0.15)
```

Right after the non-parry damage block's `emit_signal("camera_shake", 6.0)` (line 215), add:

```gdscript
var hit_stop_duration: float = 0.10 if (attacker._attack_state.def != null and attacker._attack_state.def.is_heavy) else 0.05
emit_signal("hitstop", hit_stop_duration)
```

And in `Fighter.apply_posture_damage()` — wait, that's Fighter, not CombatSystem. The posture-break hitstop needs to fire from `CombatSystem` where we know about the attacker/signal bus. Add this immediately after the `defender.apply_posture_damage(posture_damage)` call in `resolve_hits` (line 195):

```gdscript
if defender.posture_current <= 0.0:
	emit_signal("hitstop", 0.18)
	emit_signal("camera_shake", 18.0)
	emit_signal("spawn_particles", defender.position + Vector2(0.0, -defender.height), 24, Color8(255, 220, 60))
	emit_signal("show_feedback", "破", 0.9)
```

Wait — `apply_posture_damage` clamps posture back above zero after applying a stun. We need to check posture state **before** calling it. Refactor: check the pre-damage posture threshold. Replace the block around line 195:

```gdscript
defender.health_current -= hp_damage

var will_posture_break: bool = (defender.posture_current - posture_damage) <= 0.0 and not defender.is_stunned
defender.apply_posture_damage(posture_damage)

if will_posture_break:
	emit_signal("hitstop", 0.18)
	emit_signal("camera_shake", 18.0)
	emit_signal("spawn_particles", defender.position + Vector2(0.0, -defender.height), 24, Color8(255, 220, 60))
	emit_signal("show_feedback", "破", 0.9)
```

(Note: `破` is the kanji for "break" from the spec.)

- [ ] **Step 3: Update camera shake amplitudes to spec values**

In `resolve_hits()`, replace `emit_signal("camera_shake", 6.0)` near line 215 with:

```gdscript
var shake_amount: float = 12.0 if (attacker._attack_state.def != null and attacker._attack_state.def.is_heavy) else 4.0
emit_signal("camera_shake", shake_amount)
```

Section B rule 5: "Small hits 3-5 units; parry 12 units; posture break 18 units." The existing parry block already uses 12; posture break now uses 18; normal hits 4 (middle of the 3-5 range); heavy hits 12 (distinct from normals).

- [ ] **Step 4: Replace the time-scale model with a hitstop/slow-mo state machine**

The existing `combat_scene.gd` has a single `_time_scale_recover_timer` field and a `_process` block that *immediately starts lerping `_time_scale` back to 1.0* as long as that timer is positive (lines 111-115). That model cannot hold `_time_scale = 0` for the requested hitstop duration — the lerp begins on the same frame the hitstop is set — and a parry's hitstop emitted *after* its slow-mo would clobber the 0.55 slow-mo value instead of freezing-then-falling-back to it.

Replace the single-field model with two independent timers and a priority state machine: hitstop > slow-mo > normal. Both timers tick down in **real time** (`delta`), not scaled time. While hitstop is active the slow-mo timer is **paused**, so the full slow-mo duration runs after the freeze ends — player sees: freeze, then cinematic slow-mo, then recovery.

**Edit 1 — replace the field declarations.**

Edit `WUGodot/scripts/combat_scene.gd`. Find line 21:

```gdscript
var _time_scale: float = 1.0
var _time_scale_recover_timer: float = 0.0
```

Replace with:

```gdscript
var _time_scale: float = 1.0
var _hitstop_timer: float = 0.0     # real-time seconds of freeze remaining (priority 1)
var _slow_mo_timer: float = 0.0     # real-time seconds of slow-mo remaining (priority 2)
var _slow_mo_factor: float = 1.0    # current slow-mo target (0.0-1.0); 1.0 when idle
```

Also update `on_enter()` and `setup_combat()` to reset the new fields. In `on_enter()` (around line 81), replace:
```gdscript
_time_scale = 1.0
_time_scale_recover_timer = 0.0
```
With:
```gdscript
_time_scale = 1.0
_hitstop_timer = 0.0
_slow_mo_timer = 0.0
_slow_mo_factor = 1.0
```

And do the same inside `setup_combat()` around line 67-68 where the same two fields are reset.

**Edit 2 — replace the `_process` time-scale block.**

Find lines 111-115:

```gdscript
if _time_scale_recover_timer > 0.0:
	_time_scale_recover_timer -= delta
	_time_scale = lerp(_time_scale, 1.0, GameConstants.TIME_SCALE_RECOVERY)
```

Replace with:

```gdscript
# Time-scale state machine. Priority: hitstop > slow-mo > normal.
# During hitstop the slow-mo timer is paused (does not decrement) so the full
# slow-mo duration is preserved for post-freeze cinematic play.
if _hitstop_timer > 0.0:
	_hitstop_timer -= delta
	_time_scale = 0.0
elif _slow_mo_timer > 0.0:
	_slow_mo_timer -= delta
	_time_scale = _slow_mo_factor
else:
	if _time_scale < 1.0:
		_time_scale = lerp(_time_scale, 1.0, GameConstants.TIME_SCALE_RECOVERY)
		if _time_scale > 0.99:
			_time_scale = 1.0
	_slow_mo_factor = 1.0
```

**Edit 3 — connect the hitstop signal.**

Add after line 42 (`_combat_system.damage_dealt.connect(...)`):

```gdscript
_combat_system.hitstop.connect(_trigger_hitstop)
```

**Edit 4 — replace `_trigger_slow_mo` and add `_trigger_hitstop`.**

Replace the existing `_trigger_slow_mo` (lines 412-414):

```gdscript
func _trigger_slow_mo(factor: float, duration: float) -> void:
	_time_scale = clampf(factor, 0.3, 1.0)
	_time_scale_recover_timer = maxf(_time_scale_recover_timer, duration)
```

With:

```gdscript
func _trigger_slow_mo(factor: float, duration: float) -> void:
	_slow_mo_factor = clampf(factor, 0.0, 1.0)
	_slow_mo_timer = maxf(_slow_mo_timer, duration)

func _trigger_hitstop(duration: float) -> void:
	# Independent of slow-mo. Overrides _time_scale to 0.0 for the duration,
	# then the _process state machine falls back to the active slow-mo (if any)
	# before recovering to 1.0.
	_hitstop_timer = maxf(_hitstop_timer, duration)
```

- [ ] **Step 5: Walk through the interaction matrix**

Before committing, trace each impact type through the state machine on paper and verify:

| Impact | Emits | Hitstop frames | Slow-mo frames | Total feel |
|---|---|---|---|---|
| Normal hit (light) | `hitstop(0.05)` | 3 @ 60fps | 0 | brief pop |
| Heavy hit | `hitstop(0.10)` | 6 @ 60fps | 0 | punchy |
| Parry | `slow_motion(0.55, 0.30)` then `hitstop(0.15)` | 9 @ 60fps | 18 @ 60fps (after freeze) | freeze → cinematic slow-mo → recover |
| Posture break | `hitstop(0.18)` | 11 @ 60fps | 0 | biggest freeze |

For the parry row: frame 0 sets both timers. Frame 0-8: hitstop active, slow-mo timer PAUSED (elif branch not taken). Frame 9: hitstop ends, slow-mo takes over, slow-mo timer starts draining. Frame 9-26: slow-mo at 0.55x. Frame 27+: recovery lerp. This is the behavior the spec calls for.

If a NEW hit lands during an ongoing parry slow-mo, `_trigger_hitstop(0.05)` sets `_hitstop_timer = 0.05`, the state machine immediately re-enters the if branch, and the slow-mo timer pauses again. After the new freeze, slow-mo resumes with whatever remained. That is the correct layering.

- [ ] **Step 6: Playtest the feedback pass**

Launch `Main.tscn`, enter combat. Check each impact type:

1. **Normal hit.** Slash connects → very brief freeze (~3 frames), small camera shake. Does not feel mushy.
2. **Heavy hit.** Land a heavy attack → longer freeze (~6 frames), stronger shake. Clearly distinct from light hit.
3. **Parry.** Tap K into a silver Bandit windup at the right moment → freeze (~9 frames), big shake, gold spark particles, then slow-mo 0.55x for 0.30s (the post-parry cinematic beat), plus "PARRY!" text.
4. **Posture break.** Land several heavies in a row to drain Bandit posture → freeze (~11 frames), huge shake, yellow burst, 破 kanji on-screen, Bandit stun.
5. No stuttering, no runaway time_scale. The game returns to normal within ~0.3s of every impact.

If any value feels off, adjust in the task before committing.

- [ ] **Step 7: Commit**

```bash
git add WUGodot/scripts/combat_system.gd WUGodot/scripts/combat_scene.gd
git commit -m "add hitstop signal with per-impact-type durations; tune camera shake to spec"
```

---

## Task 13: Combat debug overlay

**Files:**
- Create: `WUGodot/scripts/combat_debug_overlay.gd`
- Modify: `WUGodot/scripts/combat_scene.gd` — construct the overlay, route `_draw_debug_overlay` to it

The existing debug overlay (lines 373-380 of `combat_scene.gd`) prints HP/posture/rage and animation state. Section B refactors require visibility into AttackState phase, hit-active flag, dash phase, input buffer contents, and the stance-ready flag. Extract the overlay into its own file and enrich it.

- [ ] **Step 1: Create the overlay**

Create `WUGodot/scripts/combat_debug_overlay.gd`:

```gdscript
class_name CombatDebugOverlay
extends RefCounted

# Dev-only overlay printed behind the existing _debug_enabled toggle in CombatScene.
# Shows everything the combat foundation refactor introduced: AttackState phase,
# dash phase, invulnerability, input buffer contents.

func draw(canvas: CanvasItem, player: Fighter, enemy: Fighter, buffer: InputBuffer) -> void:
	var rect: Rect2 = Rect2(14, 14, 620, 232)
	canvas.draw_rect(rect, Color(0, 0, 0, 0.60), true)

	_text(canvas, "DEBUG", 24, 34, Color.LIME_GREEN, 18)

	var y: int = 58
	_text(canvas, "Player  HP %s  PST %s  Rage %s" % [_fmt(player.health_current), _fmt(player.posture_current), _fmt(player.rage_current)], 24, y, Color.WHITE, 14)
	y += 20
	_text(canvas, "  state=%s  atk=%s  dash=%s  inv=%s" % [
		Fighter.AnimationState.keys()[player.current_animation],
		_attack_label(player),
		player.dash_phase_label(),
		"yes" if player.is_invulnerable else "no",
	], 24, y, Color.LIGHT_BLUE, 13)
	y += 20

	_text(canvas, "Enemy   HP %s  PST %s  Rage %s" % [_fmt(enemy.health_current), _fmt(enemy.posture_current), _fmt(enemy.rage_current)], 24, y, Color.WHITE, 14)
	y += 20
	_text(canvas, "  state=%s  atk=%s  dash=%s  inv=%s" % [
		Fighter.AnimationState.keys()[enemy.current_animation],
		_attack_label(enemy),
		enemy.dash_phase_label(),
		"yes" if enemy.is_invulnerable else "no",
	], 24, y, Color.LIGHT_CORAL, 13)
	y += 24

	var buffered: String = ", ".join(buffer.pending_actions())
	if buffered.is_empty():
		buffered = "(empty)"
	_text(canvas, "InputBuffer: %s" % buffered, 24, y, Color.YELLOW, 14)
	y += 20

	_text(canvas, "Rage ready for stance: %s" % ("YES" if player.rage_current >= player.rage_max else "no"), 24, y, Color.YELLOW, 13)

func _attack_label(fighter: Fighter) -> String:
	if not fighter._attack_state.is_active():
		return "idle"
	var def: AttackDefinition = fighter._attack_state.def
	if def == null:
		return "?"
	var phase_name: String = AttackDefinition.Phase.keys()[fighter._attack_state.phase()]
	return "%s %s %.0f%%" % [def.id, phase_name, fighter._attack_state.progress() * 100.0]

func _fmt(value: float) -> String:
	return "%d" % int(round(value))

func _text(canvas: CanvasItem, text: String, x: float, y: float, color: Color, size: int) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	canvas.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
```

- [ ] **Step 2: Wire the overlay into `combat_scene.gd`**

Add at line 27 near the other members:

```gdscript
var _debug_overlay: CombatDebugOverlay = CombatDebugOverlay.new()
```

Replace `_draw_debug_overlay()` (lines 373-380) entirely:

```gdscript
func _draw_debug_overlay() -> void:
	_debug_overlay.draw(self, _player, _enemy, _input_buffer)
```

- [ ] **Step 3: Playtest the overlay**

Launch `Main.tscn`, enter combat, press **`** (backtick) to toggle debug. Verify:

1. Every field updates live as the fight progresses.
2. During a player light attack, the `atk` field shows `hu_light WINDUP 23%` → `hu_light ACTIVE 52%` → `hu_light RECOVERY 74%` → `idle`.
3. During a Bandit perilous thrust, `atk` shows `bandit_thrust_perilous ...`.
4. Dashing updates `dash` to `startup` → `iframes` → `recovery` → `idle`.
5. Pressing J during recovery shows `InputBuffer: light` until it's consumed on the next legal frame.
6. Rage fills as you hit / get hit. When full, `Rage ready for stance: YES`.

- [ ] **Step 4: Commit**

```bash
git add WUGodot/scripts/combat_debug_overlay.gd WUGodot/scripts/combat_scene.gd
git commit -m "add combat debug overlay showing AttackState, dash phase, input buffer"
```

---

## Task 14: Playtest checklist and Section B validation

**Files:**
- Create: `WUGodot/docs/combat_foundation_playtest_checklist.md`

The final gate for Plan 1 is a manual playtest checklist that walks through every Section B bullet and verifies it is live in the built game. Any item that fails goes back into the relevant earlier task.

- [ ] **Step 1: Create the checklist**

Create `WUGodot/docs/combat_foundation_playtest_checklist.md`:

```markdown
# WU Combat Foundation — Playtest Checklist

Launch `Main.tscn` in the Godot editor and run a single combat encounter
against the Bandit. Work through every checkbox. A failing item goes back
to the plan task it belongs to.

## Base moveset (Section B)

- [ ] Movement speed feels Sekiro-slow — clearly slower than a twitch
      platformer. The player takes about 3 seconds to cross half the arena.
- [ ] Jump is a single jump, no double jump. No air dash.
- [ ] Tapping J produces a light attack. Total ~0.50s. Wind-up is visible
      before the slash connects.
- [ ] Holding J for at least ~0.25s then releasing produces a heavy
      attack. "HEAVY" feedback text appears. Damage is visibly larger.
      Total ~0.85s.
- [ ] Holding K reduces damage on incoming hits; releasing K ends block.
- [ ] Tapping K within ~0.15s of an incoming silver attack triggers a
      parry — "PARRY!" text, gold sparks, camera shake, post-parry
      slow-motion, Bandit staggers.
- [ ] Tapping K within that window on a RED (perilous) Bandit thrust does
      NOT parry — the player takes full damage. "UNBLOCKABLE!" flashes.
- [ ] HOLDING K (block-down) through a RED Bandit thrust also does NOT
      reduce the damage — perilous attacks bypass block entirely. Dash is
      the only answer, confirming Section B rule 4.
- [ ] Dash has a 3-phase feel: brief startup, clearly invulnerable middle,
      brief recovery tail. Dashing AT an active frame fails unless timed
      into the i-frame window.
- [ ] Dash cooldown is long enough that spam-dashing is not viable.

## Resources

- [ ] HP bar visible and drains on hits.
- [ ] Posture bar visible, fills on blocks, recovers when not under
      pressure, triggers stun + 破 kanji burst when filled.
- [ ] Rage bar visible, fills on landing/taking hits, does nothing on L
      press yet (prints to console) — this is the stance scaffold.

## Readability discipline

- [ ] Attack hit windows are consistent between what the player sees
      (visual offset during ATTACKING state) and what the game does
      (damage resolution). Enable the debug overlay (`) and verify the
      progress% moves smoothly and hit-active lights up exactly when the
      visual slash crosses the enemy.
- [ ] Bandit has at least two visually distinct attacks: silver horizontal
      slash and red perilous thrust. You can tell which one is coming
      from the windup color alone.
- [ ] Inputs are buffered. Press J during the last third of an attack's
      recovery — the next attack fires automatically as soon as it's
      legal. No "eaten" input feeling.
- [ ] Parryable vs perilous attacks are color-coded: silver vs red, and
      the red telegraph is clearly more alarming.

## Feedback discipline

- [ ] Normal hit: brief freeze (~3 frames of hitstop), small camera shake
      (amplitude 4).
- [ ] Heavy hit: longer freeze (~6 frames), bigger shake (amplitude 12).
- [ ] Parry: hard freeze (~9 frames), large shake (12), gold particle
      burst, then a short slow-motion beat at 0.55x for ~0.3s.
- [ ] Posture break: biggest freeze (~11 frames), strongest shake (18),
      破 kanji burst, yellow particles, stunned defender.
- [ ] Damage numbers pop up on every hit.
- [ ] No desync — the visual slash and the damage number land on the
      same frame.

## Debug overlay

- [ ] Press ` to toggle the debug overlay. Verify:
- [ ] Player and enemy attack state show current AttackDefinition id,
      phase, and progress percentage during an attack.
- [ ] Dash phase label transitions `startup` → `iframes` → `recovery` →
      `idle` during a dash.
- [ ] Input buffer pending list populates when you press ahead of legal
      frames and empties when the buffered action fires.
- [ ] Rage-ready flag flips to YES at 100 rage.

## Headless tests

- [ ] `cd WUGodot && godot --headless --script res://tests/run_tests.gd`
      prints `passed: 24 failed: 0` and exits with code 0.

## Stance key scaffold

- [ ] Pressing L in combat prints `[fighter] stance input (no D-type
      equipped yet)` to the Godot console. No crash, no visible effect
      (correct — Plan 2 wires the actual D-type activation).
```

- [ ] **Step 2: Run the full checklist**

Actually go through every checkbox above. If any item fails, go back to the task that introduced it, fix the issue, re-commit, and re-run the checklist.

- [ ] **Step 3: Run the headless suite one final time**

```bash
cd WUGodot && godot --headless --script res://tests/run_tests.gd
```

Expected: `passed: 24  failed: 0`, exit 0.

- [ ] **Step 4: Commit**

```bash
git add WUGodot/docs/combat_foundation_playtest_checklist.md
git commit -m "add combat foundation playtest checklist for Section B validation"
```

---

## Self-Review

**1. Spec coverage.** Section B requirements → tasks that implement them:

| Section B item | Task |
|---|---|
| Move speed 320 | 1 |
| Light attack 0.50s with 0.18/0.12/0.20 phases | 1 + 4 + 5 |
| Heavy attack 0.85s with 0.40/0.15/0.30 phases | 4 + 7 |
| Block (existing) | 1 retunes, existing code handles |
| Parry window 0.15s | 1 |
| Dash 0.22s with 0.04/0.14/0.04 phases | 1 + 8 |
| Dash cooldown 0.80s | 1 |
| Stance L key | 9 |
| Resources HP/Posture/Rage | existing — no changes required |
| Rule 1 — hit windows single-source-of-truth | 2 + 3 + 4 + 5 |
| Rule 2 — distinct silhouette windups | Plan 1 provides *mechanism*; Plan 3 authors the content. Bandit gets one silver + one red attack in Task 4/11 as a validation case. |
| Rule 3 — input buffering 0.15s | 10 |
| Rule 4 — color-coded parryable/perilous | 11 |
| Rule 5 — feedback discipline (hitstop, shake, particles, parry slow-mo, posture break VFX) | 12 |
| AI runs pattern tables | Plan 3 concern; Plan 1 uses random Bandit attacks |
| Open tuning values | Deferred to implementation — checklist flags these |

**2. Placeholder scan.** Every task contains real code. No "TBD", no "handle edge cases", no "similar to Task N". Every step has either code, an exact command, or a specific observable outcome.

**3. Type consistency.**

- `AttackDefinition` fields used consistently: `id`, `duration`, `windup_end`, `active_end`, `damage`, `posture_damage`, `is_heavy`, `is_perilous`, `is_parryable`, `range_units`, `knockback_units`. Used identically across Tasks 2, 4, 11, 12, 13.
- `AttackState` methods: `start()`, `clear()`, `advance()`, `is_active()`, `is_hit_active()`, `phase()`, `progress()`. Used identically across Tasks 3, 5, 11, 13.
- `InputBuffer` methods: `record()`, `advance()`, `consume()`, `clear()`, `pending_actions()`, `has()`. Consistent across Tasks 10, 13.
- `Fighter` new/changed members: `_attack_state`, `start_light_attack()`, `start_heavy_attack()`, `_start_attack_with()`, `current_telegraph_color()`, `dash_phase_label()`, `on_stance_input()`. All cross-referenced consistently.
- `CombatSystem` new signal: `hitstop(duration: float)` — declared in Task 12, connected in same task.
- `InputTracker` new methods: `released_key()`, `hold_duration()`, `update_hold_timers()`, `is_held()`. Declared in Task 6, used in Tasks 7 and 10.

**4. Known intermediate-regression commit.** Task 4 step 6 deliberately leaves the game in a "player attacks whiff" state; Task 5 immediately restores it in the next commit. This is documented in Task 4's commit message and at the top of Task 5. Reviewers executing task-by-task must treat Tasks 4 and 5 as a pair.

**5. Headless test count progression.** Task 0 → 0 tests. Task 2 → +12 = 12. Task 3 → +6 = 18. Task 10 → +6 = 24. Task 14 asserts 24. Consistent.

**6. What Plan 1 does NOT ship (deferred to later plans):**

- The 20 techniques from Section C (Plan 2).
- Rage consumption via L key → D-type stance activation (Plan 2 — the hook is scaffolded here).
- The 5 enemy archetypes and Iron Bear boss (Plan 3 — Plan 1 uses the existing Bandit).
- Procedural map expansion, Event system, Shop system, Master/Rest mechanics (Plan 4).
- Main menu, Victory/Defeat screens, SFX/music integration (Plan 5).

These are intentional scope cuts. Plan 1 is complete when a player can enter the existing combat scene and feel every Section B bullet working correctly.

**7. 2026-04-12 review cycle fixes.** An external review caught five correctness bugs in the first draft of this plan. All five were fixed inline; the notes below record what was wrong so future reviewers can audit the fix reasoning.

- **Finding 1 (Task 6 + Task 7 + Task 10) — hold-duration ordering + tap-vs-hold semantics.** The original `update_hold_timers` zeroed a key's hold the frame it was released, *before* `_build_player_input()` read it, so the release-frame classifier always saw 0.0 and never fired heavy. Additionally, classifying both light and heavy on release added latency to every light. Fixed by: (a) rewriting `update_hold_timers` with preserve-on-release semantics (falling-edge frame keeps the final value, idle frame zeros it), (b) ordering `update_hold_timers` BEFORE `_build_player_input` using `delta` not `dt` (real clock time), (c) firing heavy on threshold-crossing while still held and firing light only on release-if-not-committed, with a `_heavy_committed_attack` flag on CombatScene. Single-button tap-vs-hold inherently puts ~1 release frame of latency on light attacks; the commentary in Task 7 Step 3 documents this trade-off.

- **Finding 2 (Task 11 Step 4) — perilous attacks remained blockable.** The original fix only gated the parry branch of `resolve_hits` on `is_parryable`; the block branch still reduced perilous damage to 20% whenever `defender.is_blocking` was true, contradicting the spec's "must be dashed" rule. Fixed by hoisting `attack_is_perilous` above both branches and gating BOTH: perilous attacks now skip the parry reward AND the block damage reduction, showing "UNBLOCKABLE!" feedback text instead. Dash is genuinely the only answer.

- **Finding 3 (Task 12 Steps 4-5) — hitstop could not hold a freeze.** The original hitstop handler set `_time_scale = 0.0` and reused `_time_scale_recover_timer`, but the existing `_process` block starts lerping `_time_scale` back to 1.0 the instant that timer is positive, so the freeze lasted exactly one frame. The parry sequence also emitted hitstop AFTER slow-motion, which clobbered the 0.55 slow-mo state instead of layering on top. Fixed by replacing the single-field recovery-lerp model with an explicit priority state machine: `_hitstop_timer > 0` wins (time_scale=0, slow-mo timer is PAUSED), else `_slow_mo_timer > 0` wins (time_scale = `_slow_mo_factor`, drains normally), else recovery lerp toward 1.0. Both timers use real `delta` time, and hitstop deliberately pauses slow-mo so the full cinematic slow-mo duration runs *after* the freeze ends.

- **Finding 4 (Task 10 Step 6) — stance key was not actually synced.** The original step claimed `_sync_input_tracker()` would pick up `KEY_L` automatically via Task 9's `player_controls()` update, but the existing method hardcodes `["left", "right", "attack", "block", "dash", "jump"]` and does not iterate the whole `controls` dict. `pressed_key(KEY_L)` would compare against a stale `previous=false` and re-fire every frame while held. Fixed by rewriting `_sync_input_tracker()` to iterate `_player.controls.keys()` unconditionally, picking up stance today and any future action bindings automatically.

- **Finding 5 (File Structure + Task 4 Step 2 + Task 5 Steps 5 & 9 + Task 11 Step 3) — legacy telegraph timing path was never purged.** The plan's top-level architecture note promised single-source-of-truth via `AttackDefinition`, but later tasks still drove AI attacks through `ai.is_telegraphing` / `ai.telegraph_timer` / `ai.start_telegraph()`, leaving a parallel timing path alive. Fixed by: (a) deleting `is_telegraphing`, `telegraph_timer`, `telegraph_duration`, and `start_telegraph()` from Fighter in Task 4 Step 2 (alongside the `attack_*` field deletions so the parser doesn't trip), (b) removing `not is_telegraphing` from `can_attack()` in Task 5 Step 5, (c) replacing the two-stage "decide-to-telegraph → wait → fire" dance in `update_ai` with a direct `_start_attack_with(def)` call plus a new 0.25s `_ai_decision_timer` field on Fighter to keep the attack cadence similar, and (d) updating Task 11 Step 3 to choose the perilous vs. standard attack inside the direct-fire block. The AttackDefinition's WINDUP phase is now the only source of player-visible attack-telegraph warning; `current_telegraph_color()` reads it via `_attack_state.phase() == AttackDefinition.Phase.WINDUP`.

- **Finding 6 (File Structure section) — stale inventory claims.** A follow-up review spotted two stale entries in the "Modified files" list: (a) the `main.gd` entry claimed Plan 1 would construct the `InputBuffer` there and add `KEY_L` to its synced-keys list, but the buffer is actually instantiated in `combat_scene.gd` (Task 10 Step 2, plan:1618) and the stance sync lives in Task 10 Step 6's `_sync_input_tracker` rewrite — no Plan 1 task modifies `main.gd`; (b) the `Hu.json` entry claimed Plan 1 would add `"stance": "KEY_L"` under a `controls` dict in the JSON, but the runtime sources controls from `Fighter.player_controls()` via `enemy_factory.gd:63` (unchanged in Plan 1), and the stance key is added to that static method in Task 9 Step 1 (plan:1389), not to the data file. Fixed by: removing the `main.gd` entry entirely, trimming the spurious controls clause from `Hu.json` and adding a clarifying parenthetical about where stance actually lives, updating the `fighter.gd` entry to call out adding `"stance": KEY_L` to `player_controls()` / `none_controls()` and to note the legacy-telegraph field deletions and `_ai_decision_timer` addition from Finding 5, and updating the `combat_scene.gd` entry to mention the `_sync_input_tracker` rewrite, the `_heavy_committed_attack` flag, and the new priority-state-machine hitstop handler from Findings 1 and 3.
