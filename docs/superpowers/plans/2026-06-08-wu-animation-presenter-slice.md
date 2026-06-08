# WU Animation Presenter — Track A (Feel) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the player (Hu) through a new JSON-driven, three-clock animation presenter that does not float (foot-anchored), does not pop (dither crossfade), synthesizes motion from sparse frames (transform tracks + shader smear), and drives its active-window flash from a timeline event — all behind validated, hot-reloadable JSON.

**Architecture:** All decision/sampling logic lives in headless-testable `RefCounted` classes (`AnimationManifest`, `AnchorMath`, `AnimationClipTimeline`, `AnimationGraph`, `AnimationClock`). The `FighterPresenter` (`Node2D`) + `fighter_presenter.gdshader` are thin Godot substrate that consume those classes and are verified by playtest + a debug overlay. Combat truth (`Fighter`/`AttackDefinition`/`AttackState`/`CombatSystem`) and combat range math are untouched. Enemies keep the existing `FighterVisual` path; only the player is migrated in this slice.

**Tech Stack:** Godot 4.6.2, GDScript (typed), JSON data files, headless test runner (`./run.sh --test`).

**Scope:** Track A only (smooth + responsive + AI-friendly feel). **Out of scope (separate plan):** authored hitbox/hurtbox geometry and the deterministic shape-math collision query (Track B, synthesis §3.4/§3.6), full roster migration, schema-file generation, and the aiexp generation loop. References: `docs/superpowers/specs/2026-06-08-wu-animation-system-revamp.md` and `...-synthesis.md`.

> **Revision 2** — incorporates a plan-review pass that found six issues in the
> first draft. Fixes: (1) **presenter↔FighterVisual fallback boundary** so states
> without a presenter clip still render (Tasks 6, 8, 9); (2) **complete hitstop
> input freeze** — neutral input + no buffer consume during freeze (Task 2);
> (3) **foot-anchored scaling** so squash/stretch never moves the foot (Task 8);
> (4) **true two-sprite dither crossfade** with separate materials (Task 8);
> (5) **camera offset** applied to the presenter root (Tasks 8, 9); (6) **heavy
> attack** falls back to `FighterVisual` rather than showing the light clip
> (Tasks 8, 9). Also adds a **presenter-owned ambient clip clock** (idle/walk
> loop on combat time) and minimal idle/walk timelines (Tasks 3, 5). The
> presenter now exposes a single `update()` method to shrink the integration
> error surface.

---

## File Structure

**New (headless-testable `RefCounted` logic):**
- `WUGodot/scripts/visual/animation_manifest.gd` — loads a character manifest (semantic pose → path + `footAnchor`/`weaponTip`/`chestAnchor`); validates required anchors.
- `WUGodot/scripts/visual/anchor_math.gd` — pure pose-pixel → world mapping with foot anchoring + facing mirror.
- `WUGodot/scripts/visual/animation_clip_timeline.gd` — normalized track sampling (lerp + easing), keypose selection, `fromAttackDef` duration mapping, event-window firing.
- `WUGodot/scripts/visual/animation_graph.gd` — states, enter mode (snap/dither), cancel windows, intent → resolved state.
- `WUGodot/scripts/visual/animation_clock.gd` — three-clock split (combat / presentation / input-active) from `delta` + `time_scale`.

**New (Godot substrate, playtest-verified):**
- `WUGodot/scripts/visual/fighter_presenter.gd` — `Node2D` presenter tree (2× `Sprite2D`, markers, shader material).
- `WUGodot/scripts/visual/shaders/fighter_presenter.gdshader` — hit-flash + dither-dissolve + directional smear.
- `WUGodot/scripts/visual/animation_debug_overlay.gd` — draws ground point, foot anchor, sprite bottom, state + normalized clip time.

**New (data):**
- `WUGodot/assets/animation_manifests/hu.manifest.json` — Phase 1.5 stub (4 poses).
- `WUGodot/assets/animation_graphs/humanoid.graph.json` — minimal graph for the slice.
- `WUGodot/assets/animation_clips/hu_attack_light.timeline.json` — vertical-proof clip.

**New (tests):**
- `WUGodot/tests/test_animation_manifest.gd`
- `WUGodot/tests/test_anchor_math.gd`
- `WUGodot/tests/test_animation_clip_timeline.gd`
- `WUGodot/tests/test_animation_graph.gd`
- `WUGodot/tests/test_animation_clock.gd`

**Modified:**
- `WUGodot/tests/run_tests.gd` — register the five new test modules.
- `WUGodot/scripts/combat_scene.gd` — three-clock input gating; player presenter wiring; debug-overlay toggle.
- `WUGodot/scripts/fighter.gd` — emit `attack_active_started` already exists; no change required (verify only).

---

## Task 1: AnimationClock (three-clock split)

Fixes synthesis R12 first because it is pure, isolated, and unblocks correct input behavior independent of the renderer.

**Files:**
- Create: `WUGodot/scripts/visual/animation_clock.gd`
- Test: `WUGodot/tests/test_animation_clock.gd`

- [ ] **Step 1: Write the failing test**

Create `WUGodot/tests/test_animation_clock.gd`:

```gdscript
extends RefCounted

const AnimationClockScript = preload("res://scripts/visual/animation_clock.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	# Normal play: time_scale 1.0 -> everything runs.
	var normal: Dictionary = AnimationClockScript.resolve(0.016, 1.0)
	if is_equal_approx(float(normal["combat"]), 0.016) and is_equal_approx(float(normal["presentation"]), 0.016) and bool(normal["input_active"]):
		passed += 1
	else:
		failed += 1
		failures.append("normal play should run all three clocks")

	# Hitstop: time_scale 0.0 -> combat frozen, presentation real, input inactive.
	var frozen: Dictionary = AnimationClockScript.resolve(0.016, 0.0)
	if is_equal_approx(float(frozen["combat"]), 0.0) and is_equal_approx(float(frozen["presentation"]), 0.016) and not bool(frozen["input_active"]):
		passed += 1
	else:
		failed += 1
		failures.append("hitstop should freeze combat + input but keep presentation")

	# Slow-mo: time_scale 0.6 -> combat scaled, input still active.
	var slow: Dictionary = AnimationClockScript.resolve(0.016, 0.6)
	if is_equal_approx(float(slow["combat"]), 0.016 * 0.6) and bool(slow["input_active"]):
		passed += 1
	else:
		failed += 1
		failures.append("slow-mo should scale combat but keep input active")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — `could not load res://tests/test_animation_clock.gd` is absent, but the module isn't registered yet, so first add it (Step 5 of Task 10 registers all modules). For an isolated check, temporarily add the module path to `run_tests.gd` and expect failure with "Parse Error" / "preload" on the missing `animation_clock.gd`.

- [ ] **Step 3: Write minimal implementation**

Create `WUGodot/scripts/visual/animation_clock.gd`:

```gdscript
class_name AnimationClock
extends RefCounted

# Three clocks from one frame delta and the combat time scale.
#   combat:       gameplay time (0 during hitstop, scaled during slow-mo)
#   presentation: real time (decorative decay keeps running on a frozen frame)
#   input_active: false while combat is frozen, so buffers/holds do not age
static func resolve(delta: float, time_scale: float) -> Dictionary:
	return {
		"combat": delta * time_scale,
		"presentation": delta,
		"input_active": time_scale > 0.0,
	}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./run.sh --test`
Expected: PASS — `test_animation_clock.gd` contributes 3 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/visual/animation_clock.gd WUGodot/tests/test_animation_clock.gd WUGodot/tests/run_tests.gd
git commit -m "feat(anim): add AnimationClock three-clock split"
```

---

## Task 2: Gate input aging on the combat clock in combat_scene

Applies Task 1 to fix the live mis-wiring at `combat_scene.gd:191-192` (synthesis §3.5 / R12).

**Files:**
- Modify: `WUGodot/scripts/combat_scene.gd:190-195`

- [ ] **Step 1: Read the current block**

Confirm `combat_scene.gd:188-196` currently reads:

```gdscript
	_combat_system.update_facing(_player, _enemy)

	var attack_key: int = int(_player.controls.get("attack", KEY_J))
	_input_tracker.update_hold_timers([attack_key], delta)
	_input_buffer.advance(delta)

	var input_state: Dictionary = _build_player_input()
```

- [ ] **Step 2: Apply the three-clock gating**

Replace that block with:

```gdscript
	_combat_system.update_facing(_player, _enemy)

	var clocks: Dictionary = AnimationClock.resolve(delta, _time_scale)
	var input_active: bool = bool(clocks["input_active"])

	var attack_key: int = int(_player.controls.get("attack", KEY_J))
	if input_active:
		# Hold-charge and buffer aging measure *actionable* time, not frames the
		# player is locked out of during hitstop (synthesis §3.5).
		_input_tracker.update_hold_timers([attack_key], delta)
		_input_buffer.advance(delta)

	var input_state: Dictionary = _build_player_input(input_active)
```

Note: `_time_scale` is already set to `0.0` during hitstop and to `_slow_mo_factor` during slow-mo earlier in `_process` (`combat_scene.gd:149-160`), so `AnimationClock.resolve` reads the correct value. `clocks`/`input_active` are declared here once and reused later in `_process` (Task 9) — do not redeclare them.

- [ ] **Step 3: Make `_build_player_input` neutral during freeze (Rev 2 / R-hitstop)**

Gating aging is not enough: `_build_player_input()` still reads press/release edges, records to the buffer, and consumes buffered actions, so `update_player()` can start an attack/dash/block on a `dt == 0` frame. Change the signature and short-circuit when input is frozen. At the top of `_build_player_input` (`combat_scene.gd:234`), change the signature and add the guard:

```gdscript
func _build_player_input(input_active: bool = true) -> Dictionary:
	if not input_active:
		return _neutral_input()
	var left_key: int = int(_player.controls.get("left", KEY_A))
	# ... rest of the existing function body unchanged ...
```

Add the neutral helper next to it (keys must match every field `combat_system.update_player` reads — see `combat_system.gd:19-95`):

```gdscript
func _neutral_input() -> Dictionary:
	return {
		"move": 0.0,
		"jump_pressed": false,
		"dash_pressed": false,
		"light_pressed": false,
		"heavy_pressed": false,
		"block_down": false,
		"block_pressed": false,
		"stance_pressed": false,
	}
```

During a freeze this records nothing and consumes nothing, so no new action can start while combat is frozen.

- [ ] **Step 4: Verify the project still loads and tests pass**

Run: `./run.sh --test`
Expected: PASS — existing suite unchanged (input-buffer unit tests still green).

- [ ] **Step 5: Playtest the freeze behavior**

Run: `./run.sh`
Manual check: land a heavy hit to trigger hitstop, and during the freeze tap attack — the tap must not be consumed mid-freeze (no attack starts during the freeze) and a held key must not auto-promote to heavy while frozen.

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/combat_scene.gd
git commit -m "fix(combat): freeze input fully during hitstop (neutral input + no aging)"
```

---

## Task 3: AnimationManifest loader + Hu manifest stub (Phase 1.5)

**Files:**
- Create: `WUGodot/scripts/visual/animation_manifest.gd`
- Create: `WUGodot/assets/animation_manifests/hu.manifest.json`
- Test: `WUGodot/tests/test_animation_manifest.gd`

- [ ] **Step 1: Create the Hu manifest stub**

Create `WUGodot/assets/animation_manifests/hu.manifest.json`. Anchor values are source-pixel coordinates (origin top-left, right-facing canonical) measured once from the 256×256 frames; adjust during the Task 8 playtest if the foot/tip visibly disagree.

```json
{
  "id": "hu",
  "sourceCanvas": [256, 256],
  "renderScale": 1.625,
  "poses": {
    "guard": {
      "path": "res://assets/sprites/characters/hu/idle_0.png",
      "footAnchor": [128, 238],
      "chestAnchor": [128, 150],
      "weaponTip": [150, 150]
    },
    "breath": {
      "path": "res://assets/sprites/characters/hu/idle_1.png",
      "footAnchor": [128, 238],
      "chestAnchor": [128, 150],
      "weaponTip": [150, 150]
    },
    "walk_0": {
      "path": "res://assets/sprites/characters/hu/walk_0.png",
      "footAnchor": [128, 238],
      "chestAnchor": [128, 150],
      "weaponTip": [150, 150]
    },
    "walk_1": {
      "path": "res://assets/sprites/characters/hu/walk_1.png",
      "footAnchor": [128, 238],
      "chestAnchor": [128, 150],
      "weaponTip": [150, 150]
    },
    "walk_2": {
      "path": "res://assets/sprites/characters/hu/walk_2.png",
      "footAnchor": [128, 238],
      "chestAnchor": [128, 150],
      "weaponTip": [150, 150]
    },
    "walk_3": {
      "path": "res://assets/sprites/characters/hu/walk_3.png",
      "footAnchor": [128, 238],
      "chestAnchor": [128, 150],
      "weaponTip": [150, 150]
    },
    "windup": {
      "path": "res://assets/sprites/characters/hu/attack_1.png",
      "footAnchor": [128, 238],
      "chestAnchor": [128, 150],
      "weaponTip": [120, 120]
    },
    "strike_extended": {
      "path": "res://assets/sprites/characters/hu/attack_2.png",
      "footAnchor": [128, 238],
      "chestAnchor": [128, 150],
      "weaponTip": [218, 134]
    },
    "recover": {
      "path": "res://assets/sprites/characters/hu/attack_3.png",
      "footAnchor": [128, 238],
      "chestAnchor": [128, 150],
      "weaponTip": [170, 150]
    }
  }
}
```

- [ ] **Step 2: Write the failing test**

Create `WUGodot/tests/test_animation_manifest.gd`:

```gdscript
extends RefCounted

const AnimationManifestScript = preload("res://scripts/visual/animation_manifest.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var manifest: Variant = AnimationManifestScript.load_from_file("res://assets/animation_manifests/hu.manifest.json")
	if manifest != null and manifest.id == "hu" and is_equal_approx(manifest.render_scale, 1.625):
		passed += 1
	else:
		failed += 1
		failures.append("hu manifest should load id and renderScale")

	var pose: Dictionary = manifest.get_pose("strike_extended")
	if (pose.get("footAnchor", Vector2.ZERO) as Vector2) == Vector2(128, 238) and (pose.get("weaponTip", Vector2.ZERO) as Vector2) == Vector2(218, 134):
		passed += 1
	else:
		failed += 1
		failures.append("strike_extended should expose footAnchor and weaponTip as Vector2")

	# Missing footAnchor on a combat pose is a validation error.
	var errors: Array[String] = manifest.validation_errors(["guard", "windup", "strike_extended", "recover"])
	if errors.is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("complete hu manifest should have no validation errors, got: %s" % str(errors))

	var missing: Array[String] = manifest.validation_errors(["nonexistent_pose"])
	if missing.size() == 1:
		passed += 1
	else:
		failed += 1
		failures.append("requesting an undefined pose should yield one validation error")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `./run.sh --test` (after registering the module in Task 10, or temporarily).
Expected: FAIL — preload of missing `animation_manifest.gd`.

- [ ] **Step 4: Write minimal implementation**

Create `WUGodot/scripts/visual/animation_manifest.gd`:

```gdscript
class_name AnimationManifest
extends RefCounted

var id: String = "unknown"
var source_canvas: Vector2 = Vector2(256, 256)
var render_scale: float = 1.0
var poses: Dictionary = {}  # pose_name -> Dictionary{path, footAnchor, chestAnchor, weaponTip}

const _REQUIRED_ANCHORS: Array[String] = ["footAnchor", "weaponTip"]

static func load_from_file(path: String) -> AnimationManifest:
	var manifest: AnimationManifest = AnimationManifest.new()
	if path.is_empty() or not FileAccess.file_exists(path):
		return manifest
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return manifest
	var root: Dictionary = parsed as Dictionary
	manifest.id = str(root.get("id", "unknown"))
	manifest.source_canvas = _vec2(root.get("sourceCanvas", [256, 256]), Vector2(256, 256))
	manifest.render_scale = float(root.get("renderScale", 1.0))
	var raw_poses: Dictionary = root.get("poses", {}) as Dictionary
	for pose_name in raw_poses.keys():
		var entry: Dictionary = raw_poses[pose_name] as Dictionary
		manifest.poses[str(pose_name)] = {
			"path": str(entry.get("path", "")),
			"footAnchor": _vec2(entry.get("footAnchor", null), Vector2.ZERO),
			"chestAnchor": _vec2(entry.get("chestAnchor", null), Vector2.ZERO),
			"weaponTip": _vec2(entry.get("weaponTip", null), Vector2.ZERO),
			"_has": entry.keys(),
		}
	return manifest

func has_pose(pose_name: String) -> bool:
	return poses.has(pose_name)

func get_pose(pose_name: String) -> Dictionary:
	return poses.get(pose_name, {}) as Dictionary

# Fail-closed for combat poses: missing pose or missing required anchor is an error.
func validation_errors(required_poses: Array) -> Array[String]:
	var errors: Array[String] = []
	for pose_name in required_poses:
		if not poses.has(pose_name):
			errors.append("missing pose '%s'" % str(pose_name))
			continue
		var entry: Dictionary = poses[pose_name] as Dictionary
		var present: Array = entry.get("_has", []) as Array
		for anchor in _REQUIRED_ANCHORS:
			if not present.has(anchor):
				errors.append("pose '%s' missing required anchor '%s'" % [str(pose_name), anchor])
	return errors

static func _vec2(raw: Variant, fallback: Vector2) -> Vector2:
	if typeof(raw) == TYPE_ARRAY:
		var list: Array = raw as Array
		if list.size() >= 2:
			return Vector2(float(list[0]), float(list[1]))
	return fallback
```

- [ ] **Step 5: Run test to verify it passes**

Run: `./run.sh --test`
Expected: PASS — `test_animation_manifest.gd` contributes 4 passed.

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/visual/animation_manifest.gd WUGodot/assets/animation_manifests/hu.manifest.json WUGodot/tests/test_animation_manifest.gd
git commit -m "feat(anim): add AnimationManifest loader and Hu stub manifest"
```

---

## Task 4: AnchorMath (no-float pose → world mapping)

This is the no-float proof (synthesis §3.4 / R11): every frame's foot maps to the same world root regardless of per-frame drift.

**Files:**
- Create: `WUGodot/scripts/visual/anchor_math.gd`
- Test: `WUGodot/tests/test_anchor_math.gd`

- [ ] **Step 1: Write the failing test**

Create `WUGodot/tests/test_anchor_math.gd`:

```gdscript
extends RefCounted

const AnchorMathScript = preload("res://scripts/visual/anchor_math.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var root: Vector2 = Vector2(360, 900)
	var scale: float = 1.625

	# The foot pixel itself always maps exactly to root, both facings.
	var foot_right: Vector2 = AnchorMathScript.pose_to_world(Vector2(128, 238), Vector2(128, 238), root, scale, 1)
	var foot_left: Vector2 = AnchorMathScript.pose_to_world(Vector2(128, 238), Vector2(128, 238), root, scale, -1)
	if foot_right.is_equal_approx(root) and foot_left.is_equal_approx(root):
		passed += 1
	else:
		failed += 1
		failures.append("foot anchor must map to root for both facings")

	# Per-frame foot drift cancels: two frames with different foot rows still ground the foot at root.
	var driftA: Vector2 = AnchorMathScript.pose_to_world(Vector2(128, 200), Vector2(128, 200), root, scale, 1)
	var driftB: Vector2 = AnchorMathScript.pose_to_world(Vector2(128, 230), Vector2(128, 230), root, scale, 1)
	if driftA.is_equal_approx(root) and driftB.is_equal_approx(root):
		passed += 1
	else:
		failed += 1
		failures.append("foot-row drift must not move the grounded point")

	# A point above the foot is scaled and sits above root (smaller y).
	var tip: Vector2 = AnchorMathScript.pose_to_world(Vector2(218, 134), Vector2(128, 238), root, scale, 1)
	var expected: Vector2 = root + Vector2((218 - 128) * scale, (134 - 238) * scale)
	if tip.is_equal_approx(expected):
		passed += 1
	else:
		failed += 1
		failures.append("right-facing offset should scale from foot anchor")

	# Facing -1 mirrors X only.
	var tip_left: Vector2 = AnchorMathScript.pose_to_world(Vector2(218, 134), Vector2(128, 238), root, scale, -1)
	var expected_left: Vector2 = root + Vector2(-(218 - 128) * scale, (134 - 238) * scale)
	if tip_left.is_equal_approx(expected_left):
		passed += 1
	else:
		failed += 1
		failures.append("facing -1 should mirror X about the foot anchor")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — preload of missing `anchor_math.gd`.

- [ ] **Step 3: Write minimal implementation**

Create `WUGodot/scripts/visual/anchor_math.gd`:

```gdscript
class_name AnchorMath
extends RefCounted

# Map a source-pixel point to world space, anchored on the measured foot.
# world = root + mirror( (px - foot_anchor) * scale )   (mirror flips X when facing < 0)
# Anchoring on the foot (not the bitmap bottom) cancels per-frame foot drift,
# which is the no-float guarantee (synthesis §3.4).
static func pose_to_world(px: Vector2, foot_anchor: Vector2, root: Vector2, scale: float, facing: int) -> Vector2:
	var local: Vector2 = (px - foot_anchor) * scale
	if facing < 0:
		local.x = -local.x
	return root + local
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./run.sh --test`
Expected: PASS — `test_anchor_math.gd` contributes 4 passed.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/visual/anchor_math.gd WUGodot/tests/test_anchor_math.gd
git commit -m "feat(anim): add AnchorMath foot-anchored world mapping"
```

---

## Task 5: AnimationClipTimeline (normalized sampling + events)

**Files:**
- Create: `WUGodot/scripts/visual/animation_clip_timeline.gd`
- Create: `WUGodot/assets/animation_clips/hu_attack_light.timeline.json`
- Test: `WUGodot/tests/test_animation_clip_timeline.gd`

- [ ] **Step 1: Create the clip data**

Create `WUGodot/assets/animation_clips/hu_attack_light.timeline.json`:

```json
{
  "id": "hu_attack_light",
  "duration": "fromAttackDef",
  "keyposes": [
    { "t": 0.00, "pose": "guard" },
    { "t": 0.30, "pose": "windup" },
    { "t": 0.55, "pose": "strike_extended" },
    { "t": 1.00, "pose": "recover" }
  ],
  "tracks": {
    "offsetX": [
      { "t": 0.00, "v": 0.0, "ease": "out" },
      { "t": 0.55, "v": 18.0, "ease": "inOut" },
      { "t": 1.00, "v": 0.0, "ease": "out" }
    ],
    "scaleY": [
      { "t": 0.00, "v": 1.0 },
      { "t": 0.52, "v": 0.92, "ease": "in" },
      { "t": 0.62, "v": 1.0, "ease": "out" }
    ],
    "smear": [
      { "t": 0.48, "v": 0.0 },
      { "t": 0.55, "v": 1.0 },
      { "t": 0.70, "v": 0.0 }
    ]
  },
  "events": [
    { "t": "windup_end", "event": "attack_active_start" },
    { "t": "active_end", "event": "attack_active_end" }
  ]
}
```

Create `WUGodot/assets/animation_clips/idle.timeline.json` (ambient: fixed
duration, looped by the presenter's ambient clock — Task 8):

```json
{
  "id": "idle",
  "duration": 1.6,
  "keyposes": [
    { "t": 0.00, "pose": "guard" },
    { "t": 0.50, "pose": "breath" }
  ]
}
```

Create `WUGodot/assets/animation_clips/walk.timeline.json`:

```json
{
  "id": "walk",
  "duration": 0.6,
  "keyposes": [
    { "t": 0.00, "pose": "walk_0" },
    { "t": 0.25, "pose": "walk_1" },
    { "t": 0.50, "pose": "walk_2" },
    { "t": 0.75, "pose": "walk_3" }
  ]
}
```

- [ ] **Step 2: Write the failing test**

Create `WUGodot/tests/test_animation_clip_timeline.gd`:

```gdscript
extends RefCounted

const TimelineScript = preload("res://scripts/visual/animation_clip_timeline.gd")
const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")

func _light_def() -> Variant:
	var def: Variant = AttackDefinitionScript.new()
	def.duration = 0.50
	def.windup_end = 0.20
	def.active_end = 0.32
	return def

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var clip: Variant = TimelineScript.load_from_file("res://assets/animation_clips/hu_attack_light.timeline.json")

	# Track sampling: offsetX is 0 at t=0, peaks near t=0.55.
	if is_equal_approx(clip.sample_track("offsetX", 0.0), 0.0) and clip.sample_track("offsetX", 0.55) > 17.0:
		passed += 1
	else:
		failed += 1
		failures.append("offsetX should ramp from 0 to ~18")

	# Missing track returns the supplied default.
	if is_equal_approx(clip.sample_track("nonexistent", 0.5, 3.0), 3.0):
		passed += 1
	else:
		failed += 1
		failures.append("missing track should return default")

	# Keypose selection: holds the most recent keypose at/under t.
	if clip.pose_at(0.0) == "guard" and clip.pose_at(0.40) == "windup" and clip.pose_at(0.99) == "strike_extended" and clip.pose_at(1.0) == "recover":
		passed += 1
	else:
		failed += 1
		failures.append("pose_at should hold the most recent keypose")

	# Named markers resolve from the attack definition.
	var def: Variant = _light_def()
	var active_start_t: float = clip.event_time("attack_active_start", def)  # windup_end/duration = 0.40
	if is_equal_approx(active_start_t, 0.40):
		passed += 1
	else:
		failed += 1
		failures.append("attack_active_start should resolve to windup_end/duration=0.40, got %f" % active_start_t)

	# Event firing window: events whose resolved t is in (prev, cur] fire once.
	var fired: Array[String] = clip.events_in_window(0.30, 0.45, def)
	if fired.size() == 1 and fired[0] == "attack_active_start":
		passed += 1
	else:
		failed += 1
		failures.append("active_start should fire once when crossing t=0.40, got %s" % str(fired))

	var none_again: Array[String] = clip.events_in_window(0.45, 0.50, def)
	if none_again.is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("active_start should not refire after its window passed")

	# Ambient fixed-duration clip exposes its duration and cycles keyposes.
	var idle: Variant = TimelineScript.load_from_file("res://assets/animation_clips/idle.timeline.json")
	if idle.pose_at(0.0) == "guard" and idle.pose_at(0.6) == "breath" and not idle.duration_from_attack_def and is_equal_approx(idle.fixed_duration, 1.6):
		passed += 1
	else:
		failed += 1
		failures.append("idle ambient clip should expose fixed duration and cycle poses")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — preload of missing `animation_clip_timeline.gd`.

- [ ] **Step 4: Write minimal implementation**

Create `WUGodot/scripts/visual/animation_clip_timeline.gd`:

```gdscript
class_name AnimationClipTimeline
extends RefCounted

const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")

var id: String = "unknown"
var duration_from_attack_def: bool = false
var fixed_duration: float = 0.5
var keyposes: Array[Dictionary] = []   # [{t, pose}] sorted by t
var tracks: Dictionary = {}            # name -> Array[{t, v, ease}]
var events: Array[Dictionary] = []     # [{t (float|marker string), event}]

static func load_from_file(path: String) -> AnimationClipTimeline:
	var clip: AnimationClipTimeline = AnimationClipTimeline.new()
	if path.is_empty() or not FileAccess.file_exists(path):
		return clip
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return clip
	var root: Dictionary = parsed as Dictionary
	clip.id = str(root.get("id", "unknown"))
	var dur: Variant = root.get("duration", 0.5)
	if typeof(dur) == TYPE_STRING and str(dur) == "fromAttackDef":
		clip.duration_from_attack_def = true
	else:
		clip.fixed_duration = float(dur)
	for kp_variant in root.get("keyposes", []) as Array:
		var kp: Dictionary = kp_variant as Dictionary
		clip.keyposes.append({"t": float(kp.get("t", 0.0)), "pose": str(kp.get("pose", ""))})
	clip.keyposes.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	var raw_tracks: Dictionary = root.get("tracks", {}) as Dictionary
	for track_name in raw_tracks.keys():
		var keys: Array[Dictionary] = []
		for k_variant in raw_tracks[track_name] as Array:
			var k: Dictionary = k_variant as Dictionary
			keys.append({"t": float(k.get("t", 0.0)), "v": float(k.get("v", 0.0)), "ease": str(k.get("ease", "linear"))})
		keys.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
		clip.tracks[str(track_name)] = keys
	for e_variant in root.get("events", []) as Array:
		var e: Dictionary = e_variant as Dictionary
		clip.events.append({"t": e.get("t", 0.0), "event": str(e.get("event", ""))})
	return clip

func sample_track(track_name: String, t: float, default_value: float = 0.0) -> float:
	if not tracks.has(track_name):
		return default_value
	var keys: Array = tracks[track_name] as Array
	if keys.is_empty():
		return default_value
	if t <= float(keys[0]["t"]):
		return float(keys[0]["v"])
	for i in range(1, keys.size()):
		var a: Dictionary = keys[i - 1] as Dictionary
		var b: Dictionary = keys[i] as Dictionary
		if t <= float(b["t"]):
			var span: float = maxf(float(b["t"]) - float(a["t"]), 0.0001)
			var local: float = clampf((t - float(a["t"])) / span, 0.0, 1.0)
			return lerpf(float(a["v"]), float(b["v"]), _ease(local, str(b["ease"])))
	return float((keys[keys.size() - 1] as Dictionary)["v"])

func pose_at(t: float) -> String:
	var current: String = ""
	for kp in keyposes:
		if t >= float(kp["t"]):
			current = str(kp["pose"])
		else:
			break
	if current.is_empty() and not keyposes.is_empty():
		current = str((keyposes[0] as Dictionary)["pose"])
	return current

func event_time(event_name: String, attack_def: Variant) -> float:
	for e in events:
		if str(e["event"]) == event_name:
			return _resolve_t(e["t"], attack_def)
	return -1.0

# Events whose resolved normalized t lies in (prev_t, cur_t].
func events_in_window(prev_t: float, cur_t: float, attack_def: Variant) -> Array[String]:
	var fired: Array[String] = []
	for e in events:
		var rt: float = _resolve_t(e["t"], attack_def)
		if rt > prev_t and rt <= cur_t:
			fired.append(str(e["event"]))
	return fired

func _resolve_t(raw: Variant, attack_def: Variant) -> float:
	if typeof(raw) == TYPE_STRING:
		var dur: float = _duration(attack_def)
		if dur <= 0.0:
			return 0.0
		match str(raw):
			"windup_end":
				return clampf(attack_def.windup_end / dur, 0.0, 1.0)
			"active_end":
				return clampf(attack_def.active_end / dur, 0.0, 1.0)
			_:
				return 0.0
	return float(raw)

func _duration(attack_def: Variant) -> float:
	if duration_from_attack_def and attack_def != null:
		return float(attack_def.duration)
	return fixed_duration

func _ease(x: float, ease_name: String) -> float:
	match ease_name:
		"in":
			return x * x
		"out":
			return 1.0 - (1.0 - x) * (1.0 - x)
		"inOut":
			return 3.0 * x * x - 2.0 * x * x * x
		_:
			return x
```

- [ ] **Step 5: Run test to verify it passes**

Run: `./run.sh --test`
Expected: PASS — `test_animation_clip_timeline.gd` contributes 7 passed.

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/visual/animation_clip_timeline.gd WUGodot/assets/animation_clips/hu_attack_light.timeline.json WUGodot/assets/animation_clips/idle.timeline.json WUGodot/assets/animation_clips/walk.timeline.json WUGodot/tests/test_animation_clip_timeline.gd
git commit -m "feat(anim): add AnimationClipTimeline sampling and fromAttackDef events"
```

---

## Task 6: AnimationGraph (states, enter mode, cancel windows)

**Files:**
- Create: `WUGodot/scripts/visual/animation_graph.gd`
- Create: `WUGodot/assets/animation_graphs/humanoid.graph.json`
- Test: `WUGodot/tests/test_animation_graph.gd`

- [ ] **Step 1: Create the graph data**

Create `WUGodot/assets/animation_graphs/humanoid.graph.json`. `enter.mode` is `snap` for committed states and `dither` for ambient ones (synthesis §3.2/§3.3).

Only the three states this slice renders through the presenter are defined here;
every other animation state (heavy, dash, jump, hit, stun, block, …) is
deliberately absent so the presenter reports `handles_state == false` and the
player falls back to `FighterVisual` for those (Task 8/9, Rev 2). `cancelInto`
keys are plain strings and need not be defined states.

```json
{
  "states": {
    "IDLE":            { "clip": "idle",        "enter": { "mode": "dither", "time": 0.08 }, "priority": 0 },
    "WALKING":         { "clip": "walk",        "enter": { "mode": "dither", "time": 0.08 }, "priority": 1 },
    "ATTACKING_LIGHT": { "clip": "hu_attack_light", "duration": "fromAttackDef", "enter": { "mode": "snap", "time": 0.0 }, "priority": 5,
                          "cancelInto": { "DASH": "recovery", "ATTACKING_LIGHT": "recovery" } }
  }
}
```

- [ ] **Step 2: Write the failing test**

Create `WUGodot/tests/test_animation_graph.gd`:

```gdscript
extends RefCounted

const AnimationGraphScript = preload("res://scripts/visual/animation_graph.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var graph: Variant = AnimationGraphScript.load_from_file("res://assets/animation_graphs/humanoid.graph.json")

	if graph.has_state("ATTACKING_LIGHT") and graph.clip_for("ATTACKING_LIGHT") == "hu_attack_light":
		passed += 1
	else:
		failed += 1
		failures.append("graph should map ATTACKING_LIGHT to its clip")

	# Committed states snap; ambient states dither.
	var atk_enter: Dictionary = graph.enter_for("ATTACKING_LIGHT")
	var idle_enter: Dictionary = graph.enter_for("IDLE")
	if str(atk_enter.get("mode", "")) == "snap" and str(idle_enter.get("mode", "")) == "dither":
		passed += 1
	else:
		failed += 1
		failures.append("committed states snap, ambient states dither")

	# Cancel window: DASH may cancel ATTACKING_LIGHT during recovery.
	if graph.can_cancel_into("ATTACKING_LIGHT", "DASH") and not graph.can_cancel_into("ATTACKING_LIGHT", "WALKING"):
		passed += 1
	else:
		failed += 1
		failures.append("cancelInto should permit DASH and reject WALKING")

	# Unknown state resolves to IDLE fallback.
	if graph.clip_for("BOGUS") == "idle":
		passed += 1
	else:
		failed += 1
		failures.append("unknown state should fall back to idle clip")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — preload of missing `animation_graph.gd`.

- [ ] **Step 4: Write minimal implementation**

Create `WUGodot/scripts/visual/animation_graph.gd`:

```gdscript
class_name AnimationGraph
extends RefCounted

var states: Dictionary = {}  # name -> Dictionary

static func load_from_file(path: String) -> AnimationGraph:
	var graph: AnimationGraph = AnimationGraph.new()
	if path.is_empty() or not FileAccess.file_exists(path):
		return graph
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return graph
	graph.states = (parsed as Dictionary).get("states", {}) as Dictionary
	return graph

func has_state(name: String) -> bool:
	return states.has(name)

func clip_for(name: String) -> String:
	if states.has(name):
		return str((states[name] as Dictionary).get("clip", "idle"))
	if states.has("IDLE"):
		return str((states["IDLE"] as Dictionary).get("clip", "idle"))
	return "idle"

func enter_for(name: String) -> Dictionary:
	if states.has(name):
		return (states[name] as Dictionary).get("enter", {"mode": "dither", "time": 0.08}) as Dictionary
	return {"mode": "dither", "time": 0.08}

func can_cancel_into(from_state: String, to_state: String) -> bool:
	if not states.has(from_state):
		return false
	var cancels: Dictionary = (states[from_state] as Dictionary).get("cancelInto", {}) as Dictionary
	return cancels.has(to_state)
```

- [ ] **Step 5: Run test to verify it passes**

Run: `./run.sh --test`
Expected: PASS — `test_animation_graph.gd` contributes 4 passed.

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/visual/animation_graph.gd WUGodot/assets/animation_graphs/humanoid.graph.json WUGodot/tests/test_animation_graph.gd
git commit -m "feat(anim): add AnimationGraph states, enter modes, cancel windows"
```

---

## Task 7: fighter_presenter.gdshader (flash + dither dissolve + smear)

This is Godot substrate; verification is visual (playtest), not headless. Code is complete; tune constants during Task 9 playtest.

**Files:**
- Create: `WUGodot/scripts/visual/shaders/fighter_presenter.gdshader`

- [ ] **Step 1: Write the shader**

Create `WUGodot/scripts/visual/shaders/fighter_presenter.gdshader`:

```glsl
shader_type canvas_item;

// Hit flash: blends toward white. 0 = none, 1 = full white.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// Directional smear: samples along facing*dir with decaying alpha. 0 = off.
uniform float smear : hint_range(0.0, 1.0) = 0.0;
uniform vec2 smear_dir = vec2(1.0, 0.0);
// Dither dissolve threshold for crossfade: pixels below threshold are hidden.
uniform float dissolve : hint_range(0.0, 1.0) = 1.0;

// 4x4 Bayer matrix for ordered dithering (crisp pixel-art dissolve, no ghosting).
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int idx = x + y * 4;
	float m[16] = {0.0,8.0,2.0,10.0, 12.0,4.0,14.0,6.0, 3.0,11.0,1.0,9.0, 15.0,7.0,13.0,5.0};
	return m[idx] / 16.0;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	// Directional smear: accumulate a few trailing samples.
	if (smear > 0.001) {
		vec2 step_uv = smear_dir * TEXTURE_PIXEL_SIZE * 6.0 * smear;
		for (int i = 1; i <= 3; i++) {
			vec4 s = texture(TEXTURE, UV - step_uv * float(i));
			col.a = max(col.a, s.a * (0.5 / float(i)) * smear);
			col.rgb = mix(col.rgb, s.rgb, 0.25 * smear);
		}
	}

	// Ordered-dither dissolve for ambient crossfades.
	if (dissolve < 0.999) {
		if (bayer4(FRAGCOORD.xy) > dissolve) {
			col.a = 0.0;
		}
	}

	// Hit flash toward white, preserving alpha.
	col.rgb = mix(col.rgb, vec3(1.0), flash);
	COLOR = col * COLOR;
}
```

- [ ] **Step 2: Verify it compiles (project loads without shader errors)**

Run: `./run.sh --import`
Expected: completes without shader compile errors printed for `fighter_presenter.gdshader`.

- [ ] **Step 3: Commit**

```bash
git add WUGodot/scripts/visual/shaders/fighter_presenter.gdshader
git commit -m "feat(anim): add fighter presenter shader (flash, dither dissolve, smear)"
```

---

## Task 8: FighterPresenter node + debug overlay

Godot substrate; verified by playtest. Consumes Tasks 3–7. Wires into the player only.

**Files:**
- Create: `WUGodot/scripts/visual/fighter_presenter.gd`
- Create: `WUGodot/scripts/visual/animation_debug_overlay.gd`

- [ ] **Step 1: Write the presenter**

Create `WUGodot/scripts/visual/fighter_presenter.gd`. One public `update()` keeps the integration surface small; `handles_state()` lets the caller fall back to `FighterVisual` for unsupported states (Rev 2).

```gdscript
class_name FighterPresenter
extends Node2D

const AnimationManifestScript = preload("res://scripts/visual/animation_manifest.gd")
const AnimationGraphScript = preload("res://scripts/visual/animation_graph.gd")
const TimelineScript = preload("res://scripts/visual/animation_clip_timeline.gd")

const FLASH_DECAY: float = 0.08

var _catalog: AssetCatalog
var _manifest: Variant
var _graph: Variant
var _clips: Dictionary = {}        # clip_id -> AnimationClipTimeline
var _render_scale: float = 1.0

var _sprite_current: Sprite2D
var _sprite_previous: Sprite2D
var _mat_current: ShaderMaterial
var _mat_previous: ShaderMaterial

var _state: String = ""
var _clip: Variant = null
var _clip_time: float = 0.0        # ambient accumulator (combat time)
var _norm_t: float = 0.0
var _prev_norm_t: float = 0.0
var _dissolve_t: float = 1.0       # 1 = fully shown (no crossfade in progress)
var _dissolve_time: float = 0.08
var _flash: float = 0.0

signal timeline_event(event_name: String)

func _init(catalog: AssetCatalog) -> void:
	_catalog = catalog

func configure(manifest_path: String, graph_path: String, clip_paths: Array, render_scale: float) -> void:
	_manifest = AnimationManifestScript.load_from_file(manifest_path)
	_graph = AnimationGraphScript.load_from_file(graph_path)
	for p in clip_paths:
		var clip: Variant = TimelineScript.load_from_file(str(p))
		_clips[clip.id] = clip
	_render_scale = render_scale  # applied to the SPRITES, not the root (no double-scale)

	var shader: Shader = load("res://scripts/visual/shaders/fighter_presenter.gdshader") as Shader
	# Separate materials so the two sprites can dissolve with inverse thresholds.
	_mat_previous = ShaderMaterial.new()
	_mat_previous.shader = shader
	_mat_current = ShaderMaterial.new()
	_mat_current.shader = shader

	_sprite_previous = Sprite2D.new()
	_sprite_previous.material = _mat_previous
	_sprite_current = Sprite2D.new()
	_sprite_current.material = _mat_current
	for s in [_sprite_previous, _sprite_current]:
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
	_sprite_previous.visible = false

# True only for states the graph defines AND that have a loaded clip. The caller
# falls back to FighterVisual otherwise (heavy/dash/jump/hit/... this slice).
func handles_state(state_name: String) -> bool:
	if _graph == null or not _graph.has_state(state_name):
		return false
	return _clips.has(_graph.clip_for(state_name))

func current_norm_t() -> float:
	return _norm_t

func set_flash(amount: float) -> void:
	_flash = clampf(amount, 0.0, 1.0)

# Single per-frame entry point. Caller guarantees handles_state(state_name).
func update(fighter: Fighter, state_name: String, combat_dt: float, presentation_dt: float, camera_offset: Vector2) -> void:
	_maybe_change_state(state_name)
	if _clip == null:
		return

	# Resolve normalized clip time: attacks ride AttackState; ambient clips loop
	# on combat time via a presenter-owned accumulator (Rev 2 ambient clock).
	_prev_norm_t = _norm_t
	var attack_def: Variant = fighter._attack_state.def if fighter._attack_state != null else null
	if _clip.duration_from_attack_def and attack_def != null and attack_def.duration > 0.0:
		_norm_t = clampf(fighter._attack_state.elapsed / attack_def.duration, 0.0, 1.0)
	else:
		var dur: float = maxf(_clip.fixed_duration, 0.0001)
		_clip_time += combat_dt
		_norm_t = fposmod(_clip_time, dur) / dur

	# Fire timeline events crossing (prev, cur]. Skip across an ambient loop wrap.
	if _norm_t >= _prev_norm_t:
		for e in _clip.events_in_window(_prev_norm_t, _norm_t, attack_def):
			emit_signal("timeline_event", e)

	# Root = combat ground/contact point + camera offset (camera does not move
	# the scene root; offset is passed into draws — Rev 2 camera fix).
	position = fighter.position + camera_offset

	var facing: int = fighter.facing
	var pose: Dictionary = _manifest.get_pose(_clip.pose_at(_norm_t))
	_sprite_current.texture = _catalog.get_texture(str(pose.get("path", "")))
	var foot: Vector2 = pose.get("footAnchor", Vector2.ZERO) as Vector2

	var off_x: float = _clip.sample_track("offsetX", _norm_t, 0.0)
	var scale_y: float = _clip.sample_track("scaleY", _norm_t, 1.0)
	var smear_v: float = _clip.sample_track("smear", _norm_t, 0.0)

	# Foot-anchored scale (Rev 2 no-float fix): a source pixel p renders at
	# sprite.position + p * S. We want the foot pixel on the root, so
	# sprite.position = -foot * S. The same S scales both, so the foot stays
	# fixed under any scale_y. Facing mirrors via a signed X scale (NOT flip_h,
	# which mirrors about the rect, not the foot).
	var sx: float = _render_scale * float(facing)
	var sy: float = _render_scale * scale_y
	_sprite_current.scale = Vector2(sx, sy)
	_sprite_current.position = Vector2(-foot.x * sx, -foot.y * sy) + Vector2(off_x * float(facing), 0.0)

	# Crossfade + flash advance on presentation time (a frozen frame still settles).
	if _dissolve_t < 1.0:
		_dissolve_t = minf(1.0, _dissolve_t + presentation_dt / _dissolve_time)
		if _dissolve_t >= 1.0:
			_sprite_previous.visible = false
	_flash = maxf(0.0, _flash - presentation_dt / FLASH_DECAY)

	_mat_current.set_shader_parameter("smear", smear_v)
	_mat_current.set_shader_parameter("smear_dir", Vector2(float(facing), 0.0))
	_mat_current.set_shader_parameter("flash", _flash)
	_mat_current.set_shader_parameter("dissolve", _dissolve_t)
	_mat_previous.set_shader_parameter("dissolve", 1.0 - _dissolve_t)

func _maybe_change_state(state_name: String) -> void:
	if state_name == _state:
		return
	var enter: Dictionary = _graph.enter_for(state_name)
	if str(enter.get("mode", "dither")) == "dither" and _sprite_current.texture != null:
		# Snapshot the outgoing frame into the previous sprite and dither it out.
		_sprite_previous.texture = _sprite_current.texture
		_sprite_previous.position = _sprite_current.position
		_sprite_previous.scale = _sprite_current.scale
		_sprite_previous.visible = true
		_dissolve_t = 0.0
		_dissolve_time = maxf(float(enter.get("time", 0.08)), 0.001)
	else:
		_dissolve_t = 1.0  # snap (committed states): no crossfade
		_sprite_previous.visible = false
	_state = state_name
	_clip = _clips.get(_graph.clip_for(state_name), null)
	_clip_time = 0.0
	_norm_t = 0.0
	_prev_norm_t = 0.0
```

Draw-order note (integration, verify in playtest): a tree-child `Node2D` draws *after* the parent's `_draw()`, so the presenter renders above `CombatScene`'s arena/enemy (fine) **and above the HUD** (not fine). If the playtest shows the player sprite over HUD panels/text, the fix is to lift the HUD into a higher `CanvasLayer`: in `_ready` create `var _hud_layer := CanvasLayer.new(); _hud_layer.layer = 10; add_child(_hud_layer)` and move the HUD/feedback/overlay draw calls onto a node parented to it. The world (arena, enemy, presenter) stays on layer 0. Keep this out of the first commit; apply only if occlusion is observed.

- [ ] **Step 2: Write the debug overlay**

Create `WUGodot/scripts/visual/animation_debug_overlay.gd`:

```gdscript
class_name AnimationDebugOverlay
extends RefCounted

# Draws ground point, foot line, sprite bottom, and state/clip text.
# Called from CombatScene._draw when debug is enabled.
static func draw(canvas: CanvasItem, fighter: Fighter, camera_offset: Vector2, state_name: String, norm_t: float) -> void:
	var ground: Vector2 = fighter.position + camera_offset
	canvas.draw_circle(ground, 4.0, Color(0.2, 1.0, 0.4, 0.9))
	canvas.draw_line(ground + Vector2(-40, 0), ground + Vector2(40, 0), Color(0.2, 1.0, 0.4, 0.6), 1.0)
	var label: String = "%s  t=%.2f" % [state_name, norm_t]
	var font: Font = ThemeDB.fallback_font
	canvas.draw_string(font, ground + Vector2(-40, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 1.0, 0.4, 0.9))
```

- [ ] **Step 3: Verify the project imports cleanly**

Run: `./run.sh --import`
Expected: no parse errors for the two new scripts.

- [ ] **Step 4: Commit**

```bash
git add WUGodot/scripts/visual/fighter_presenter.gd WUGodot/scripts/visual/animation_debug_overlay.gd
git commit -m "feat(anim): add FighterPresenter node and animation debug overlay"
```

---

## Task 9: Wire the presenter into combat_scene for the player

Routes the player through `FighterPresenter` for the states it supports (IDLE, WALKING, ATTACKING_LIGHT) and **falls back to `FighterVisual` for every other state** (heavy, dash, jump, hit, stun, block). Enemy always stays on `FighterVisual`. Verified by playtest.

**Files:**
- Modify: `WUGodot/scripts/combat_scene.gd` (`_ready` ~45-63, `setup_combat` ~65-75, `_process` ~224-232, `_draw_fighter` ~330-365)

- [ ] **Step 1: Add the presenter field and instantiate it**

In `combat_scene.gd` near the visual fields (`:19-21`), add:

```gdscript
const FighterPresenterScript = preload("res://scripts/visual/fighter_presenter.gd")
const AnimationDebugOverlayScript = preload("res://scripts/visual/animation_debug_overlay.gd")
var _player_presenter: FighterPresenter
```

In `_ready` after `_player_visual = FighterVisual.new(_asset_catalog)` (`:51`), add:

```gdscript
	_player_presenter = FighterPresenterScript.new(_asset_catalog)
	add_child(_player_presenter)
	_player_presenter.visible = false
```

- [ ] **Step 2: Configure the presenter in setup_combat**

In `setup_combat` after `_player_visual.configure(...)` (`:72`), add (all three clips — attack, idle, walk):

```gdscript
	_player_presenter.configure(
		"res://assets/animation_manifests/hu.manifest.json",
		"res://assets/animation_graphs/humanoid.graph.json",
		[
			"res://assets/animation_clips/hu_attack_light.timeline.json",
			"res://assets/animation_clips/idle.timeline.json",
			"res://assets/animation_clips/walk.timeline.json",
		],
		float(DataManager.get_visual_profile(_player.visual_profile_id).get("scale", 1.625))
	)
	_player_presenter.timeline_event.connect(_on_player_timeline_event)
```

Add the handler near the other private methods (replaces the bespoke active-flash signal for the player — synthesis §3.3 / base spec Phase 3):

```gdscript
func _on_player_timeline_event(event_name: String) -> void:
	match event_name:
		"attack_active_start":
			_player_presenter.set_flash(1.0)
```

- [ ] **Step 3: Drive the presenter each frame (with fallback)**

In `_process`, inside the `if not _is_paused:` block (`:224-229`), after the existing `_player_visual.update(_player, dt)` and `_enemy_visual.update(_enemy, dt)`, add. **Reuse the `clocks`/`input_active` already declared in Task 2** — do not redeclare `clocks`:

```gdscript
		# clocks was computed near the top of _process (Task 2).
		var state_name: String = _resolve_player_state_name()
		if _player_presenter.handles_state(state_name):
			_player_presenter.visible = true
			_player_presenter.update(_player, state_name, float(clocks["combat"]), float(clocks["presentation"]), _camera.offset)
		else:
			# Unsupported state (heavy/dash/jump/hit/...): fall back to FighterVisual,
			# which keeps animating because _player_visual.update ran above.
			_player_presenter.visible = false
```

Add the state-name helper. Only the three presenter-backed states map to graph names; everything else returns a sentinel the graph does not define, so `handles_state` is false and the player renders via `FighterVisual` (this is the heavy-attack fix — heavy keeps its real visual instead of showing the light clip):

```gdscript
func _resolve_player_state_name() -> String:
	match _player.current_animation:
		Fighter.AnimationState.ATTACKING_LIGHT:
			return "ATTACKING_LIGHT"
		Fighter.AnimationState.WALKING:
			return "WALKING"
		Fighter.AnimationState.IDLE:
			return "IDLE"
		_:
			return "FALLBACK"  # not a graph state -> FighterVisual draws it
```

- [ ] **Step 4: Draw the player via presenter or fallback**

In `_draw_fighter` (`:330-365`), keep all existing telegraph/combo overlays. For the player, draw the immediate-mode sprite **only when the presenter is not handling this frame**; the presenter node draws itself when visible. Use `_player_presenter.visible` (set in Step 3) as the flag:

```gdscript
func _draw_fighter(fighter: Fighter, camera_offset: Vector2) -> void:
	var visual: FighterVisual = _get_visual_for(fighter)
	var body_rect: Rect2 = visual.get_body_rect(fighter, camera_offset)
	# ... keep existing telegraph outline + combo-count overlays unchanged ...
	if fighter == _player and _player_presenter.visible:
		# Presenter renders the sprite (scene-tree child). Draw only the debug overlay.
		if _debug_enabled:
			AnimationDebugOverlayScript.draw(self, fighter, camera_offset, _resolve_player_state_name(), _player_presenter.current_norm_t())
	else:
		visual.draw(self, fighter, camera_offset)
```

Note (accepted slice limitation): while the presenter renders the player, the `FighterVisual` body-tint telegraph pulse and weapon-arc trail are not shown (the immediate-mode `visual.draw` is skipped). The separate telegraph *outline* drawn in `_draw_fighter` still appears. Porting the telegraph tint/trail to the presenter shader is a follow-up, not part of this slice.

- [ ] **Step 5: Playtest the vertical proof**

Run: `./run.sh`
Manual acceptance (synthesis §5):
- Hu's feet stay planted across idle / walk / **light attack** (no float). Toggle debug with `` ` `` — the green ground point sits at the feet in every frame, and the squash on the light-attack impact does not lift the feet.
- Light attack: windup eases forward, a white flash fires at the active window (from the timeline event), smear streaks the strike, no hard pop entering the attack.
- Idle↔walk transitions dither rather than pop; idle/walk cycle continuously (ambient clock).
- The presenter follows camera shake/pan (e.g., on a heavy hit the player shakes with the arena).
- **Heavy attack** still shows its own (FighterVisual) animation, not the light clip; dash/jump/hit also render via FighterVisual without error.
- If the player sprite renders over HUD panels/text, apply the HUD `CanvasLayer` fix from Task 8's draw-order note.

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/combat_scene.gd
git commit -m "feat(anim): render player via FighterPresenter with FighterVisual fallback"
```

---

## Task 10: Register tests and final validation

**Files:**
- Modify: `WUGodot/tests/run_tests.gd:3-16`

- [ ] **Step 1: Register the five new test modules**

In `run_tests.gd`, add to `_TEST_MODULES` (after the existing entries):

```gdscript
	"res://tests/test_animation_clock.gd",
	"res://tests/test_animation_manifest.gd",
	"res://tests/test_anchor_math.gd",
	"res://tests/test_animation_clip_timeline.gd",
	"res://tests/test_animation_graph.gd",
```

- [ ] **Step 2: Run the full suite**

Run: `./run.sh --test`
Expected: PASS — `failed: 0`. New modules contribute 3 + 4 + 4 + 7 + 4 = 22 additional passing assertions; existing suite (including `test_animation_set.gd`) remains green.

- [ ] **Step 3: Commit**

```bash
git add WUGodot/tests/run_tests.gd
git commit -m "test(anim): register presenter-slice test modules"
```

---

## Self-Review Notes (coverage map)

- **Synthesis §3.1 (smooth from sparse frames)** → transform tracks + smear (Tasks 5, 7, 8).
- **Synthesis §3.2/§3.3 (dither vs snap, committed-not-pressed)** → graph `enter.mode` (Task 6); snap-on-commit + two-sprite dither (Task 8). The *neutral attack-intent pose on key-down* (synthesis §3.3 option A) is deferred — this slice snaps at the existing combat commit, which is correct and non-regressive.
- **Synthesis §3.4 (foot anchor, no float)** → AnchorMath + manifest (Tasks 3, 4); foot-anchored scaling in the presenter, including under squash/stretch (Task 8, Rev 2).
- **Synthesis §3.5 (three clocks)** → AnimationClock + full input freeze (Tasks 1, 2, Rev 2); presentation-time dissolve/flash decay; ambient combat-time clip clock (Task 8).
- **Base spec Phase 3 (timeline events replace bespoke signal)** → timeline events + `_on_player_timeline_event` (Tasks 5, 9).
- **Coverage completeness (Rev 2):** every player animation state renders — IDLE/WALKING/ATTACKING_LIGHT via the presenter, all others (heavy, dash, jump, fall, land, hit, stun, block) via the `FighterVisual` fallback (Tasks 8 `handles_state`, 9). No state is left textureless.
- **Explicitly out of scope (Track B / follow-up plans):** authored hitbox geometry + deterministic shape-math query (synthesis §3.4 query, §3.6 templates), enemy migration, JSON schema file, neutral intent pose, presenter-side telegraph tint/weapon trail, aiexp generation loop. None are required for the player-feel vertical proof.

**Rev 2 review fixes — where each finding landed:**
1. Player invisible/stale outside light clip → `handles_state` fallback + idle/walk clips/poses (Tasks 3, 5, 6, 8, 9).
2. Incomplete hitstop input freeze → neutral input + no consume during freeze (Task 2 Step 3).
3. Squash breaks no-float → foot-anchored scale `position = -foot*S` (Task 8).
4. Single-sprite "crossfade" → two materials, inverse dither thresholds, snapshot on transition (Task 8).
5. Wrong camera-offset note → `position = fighter.position + _camera.offset` passed into `update()` (Tasks 8, 9).
6. Heavy regresses to light → heavy returns `"FALLBACK"` → FighterVisual (Task 9 `_resolve_player_state_name`).

**Remaining integration item to validate in playtest (Task 8 note):** scene-tree draw order — the presenter child draws above the HUD; the HUD `CanvasLayer` fix is specified and applied only if occlusion is observed. This is the one structural item the reviewer flagged as "tighten before coding"; it is now documented with a concrete remedy rather than left implicit.
