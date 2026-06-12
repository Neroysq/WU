# Hu Video-First Re-Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-animate all 11 of Hu's visual states from video-generated frames (5 clips) and exaggerated held poses (9 stills), gated by manual keyframe approval (Gate 1) and in-game temporal review (Gate 2).

**Architecture:** Phase 0 lands pure-code foundations (presenter parity, bounds provider, collision rule, temporal harness, generalized installer, review page). Phases 1–6 then run the per-action pipeline: author keyframes (codex stills) → Gate 1 → `animate-video --reference-seq` → select by pose progress → scale/pixelize exact → install → timeline → gates → Gate 2 → commit. Spec: `docs/superpowers/specs/2026-06-12-hu-video-reanimation-design.md`.

**Tech Stack:** Godot 4.6.2 headless (GDScript), aiexp pixelforge-sprite ≥0.12.0 (`rawgen` codex backend, `animate-video --reference-seq`, `pixelize --fit-mode exact`, `despill`), ffmpeg, python3 (stdlib only).

**Conventions used throughout:**
- All Godot commands run via `./run.sh` from the repo root (`/Users/animula/GitReps/WU`).
- "Gates green" = `./run.sh --test` (0 failed), `./run.sh --import` (no ERROR/SCRIPT ERROR lines), `./run.sh --anchor-sanity` (OK).
- **✋ STOP** steps require the user's verdict in chat before continuing. Never proceed past one on your own.
- Generation scratch dirs live in `/tmp/wu-reanim/<action>/`; durable approved keyframes live in `art/keyframes/` (committed).
- Every commit message ends with the project's standard co-author line.

---

## Phase 0 — Foundations (pure code, no generation)

### Task 1: `useFighterOffset` clip field + presenter opt-in

The presenter must apply `fighter.animation_offset` for held/reactive states only (spec §5a.1). Video clips default off — `animation_offset` also carries the legacy attack lunge (`fighter.gd:244`) and walk bob (`fighter.gd:271`), which would double-apply on video motion.

**Files:**
- Modify: `WUGodot/scripts/visual/animation_clip_timeline.gd` (vars block, `load_from_file`)
- Modify: `WUGodot/scripts/visual/fighter_presenter.gd:86`
- Create: `WUGodot/tests/test_presenter_offset.gd`
- Modify: `WUGodot/tests/run_tests.gd` (`_TEST_MODULES`)

- [ ] **Step 1: Write the failing test**

Create `WUGodot/tests/test_presenter_offset.gd`:

```gdscript
extends RefCounted

const TimelineScript = preload("res://scripts/visual/animation_clip_timeline.gd")
const PresenterScript = preload("res://scripts/visual/fighter_presenter.gd")

const HELD_CLIP_JSON := """
{
  "id": "test_held",
  "duration": 0.4,
  "useFighterOffset": true,
  "keyposes": [ { "t": 0.0, "pose": "guard" } ]
}
"""
const VIDEO_CLIP_JSON := """
{
  "id": "test_video",
  "duration": 0.4,
  "keyposes": [ { "t": 0.0, "pose": "guard" } ]
}
"""
const GRAPH_JSON := """
{
  "states": {
    "HELD_TEST": { "clip": "test_held", "enter": { "mode": "snap", "time": 0.0 } },
    "VIDEO_TEST": { "clip": "test_video", "enter": { "mode": "snap", "time": 0.0 } }
  }
}
"""

func _write(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	_write("user://test_held.timeline.json", HELD_CLIP_JSON)
	_write("user://test_video.timeline.json", VIDEO_CLIP_JSON)
	_write("user://test_offset.graph.json", GRAPH_JSON)

	# 1. Loader: flag parsed, defaults false.
	var held: Variant = TimelineScript.load_from_file("user://test_held.timeline.json")
	var video: Variant = TimelineScript.load_from_file("user://test_video.timeline.json")
	if held.use_fighter_offset and not video.use_fighter_offset:
		passed += 1
	else:
		failed += 1
		failures.append("useFighterOffset should parse true and default false")

	# 2. Presenter: opted-in state renders displaced by animation_offset; opted-out ignores it.
	var catalog := AssetCatalog.new()
	var presenter: Variant = PresenterScript.new(catalog)
	presenter.configure(
		"res://assets/animation_manifests/hu.manifest.json",
		"user://test_offset.graph.json",
		["user://test_held.timeline.json", "user://test_video.timeline.json"],
		2.0)
	var fighter: Fighter = EnemyFactory.create_player()
	fighter.position = Vector2(500.0, 600.0)
	fighter.animation_offset = Vector2(8.0, -3.0)

	presenter.update(fighter, "HELD_TEST", 0.016, 0.016, Vector2.ZERO)
	var held_pos: Vector2 = presenter.position
	presenter.update(fighter, "VIDEO_TEST", 0.016, 0.016, Vector2.ZERO)
	var video_pos: Vector2 = presenter.position
	presenter.free()

	if held_pos.is_equal_approx(Vector2(508.0, 597.0)) and video_pos.is_equal_approx(Vector2(500.0, 600.0)):
		passed += 1
	else:
		failed += 1
		failures.append("held state should add animation_offset (got %s), video state should not (got %s)" % [str(held_pos), str(video_pos)])

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Register the module and run to verify it fails**

Add `"res://tests/test_presenter_offset.gd",` to `_TEST_MODULES` in `WUGodot/tests/run_tests.gd` (after the `test_animation_graph.gd` line).

Run: `./run.sh --test 2>&1 | tail -5`
Expected: FAIL — `use_fighter_offset` is not a property of the clip (script error or failure line).

- [ ] **Step 3: Implement the loader field**

In `WUGodot/scripts/visual/animation_clip_timeline.gd`, after `var rate_mode: String = "fixed"` add:

```gdscript
var use_fighter_offset: bool = false
```

In `load_from_file`, after `clip.rate_mode = str(root.get("rate", "fixed"))` add:

```gdscript
clip.use_fighter_offset = bool(root.get("useFighterOffset", false))
```

- [ ] **Step 4: Implement the presenter application**

In `WUGodot/scripts/visual/fighter_presenter.gd`, replace line 86:

```gdscript
	position = fighter.position + camera_offset
```

with:

```gdscript
	position = fighter.position + camera_offset
	if _clip.use_fighter_offset:
		position += fighter.animation_offset
```

(`animation_offset` is already facing-aware — `fighter.gd` multiplies by `facing` where it matters.)

- [ ] **Step 5: Run tests to verify pass**

Run: `./run.sh --test 2>&1 | tail -5`
Expected: PASS, count increases by 2, 0 failed.

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/visual/animation_clip_timeline.gd WUGodot/scripts/visual/fighter_presenter.gd WUGodot/tests/test_presenter_offset.gd WUGodot/tests/run_tests.gd
git commit -m "feat(presenter): opt-in fighter animation_offset via useFighterOffset clip flag"
```

### Task 2: Presenter bounds provider + overlay wiring

Overlays (telegraph/parry/stun/bleed/grab) hang off `FighterVisual.get_body_rect` (`combat_scene.gd:567-568`). Presenter-owned states need a presenter-backed rect (spec §5a.2).

**Design constraint (review finding):** bounds must go through the SAME transform the sprite was drawn with — Task 1's `animation_offset` (in `presenter.position`) and the timeline tracks offsetX/offsetY/scaleX/scaleY/rotation (in `_sprite_current.position/scale/rotation`, still live on today's heavy/idle/walk clips). Recomputing from `fighter.position` alone would make overlays lag the displaced/transformed sprite. Implementation: map the hurtbox corners through the cached `_sprite_current` transform that `update()` just set — one source of truth, no duplicated math. Contract: `get_body_rect` reflects the most recent `update()`; in `combat_scene._process`, `_update_player_presenter` runs before `queue_redraw`, so `_draw_fighter` always sees same-frame state.

**Files:**
- Modify: `WUGodot/scripts/visual/fighter_presenter.gd` (new method)
- Modify: `WUGodot/scripts/combat_scene.gd` (`_draw_fighter`)
- Create: `WUGodot/tests/test_presenter_bounds.gd`
- Modify: `WUGodot/tests/run_tests.gd`

- [ ] **Step 1: Write the failing test**

Create `WUGodot/tests/test_presenter_bounds.gd`. It uses three `user://` fixture clips so expected values are hand-computable: a bare clip (no tracks), an offset-enabled held clip, and a transformed clip standing in for today's heavy (constant offsetX 30, scaleX 1.2):

```gdscript
extends RefCounted

const TimelineScript = preload("res://scripts/visual/animation_clip_timeline.gd")
const PresenterScript = preload("res://scripts/visual/fighter_presenter.gd")
const ManifestScript = preload("res://scripts/visual/animation_manifest.gd")

const BARE_JSON := """
{ "id": "b_bare", "duration": 0.4, "keyposes": [ { "t": 0.0, "pose": "guard" } ] }
"""
const HELD_JSON := """
{ "id": "b_held", "duration": 0.4, "useFighterOffset": true,
  "keyposes": [ { "t": 0.0, "pose": "guard" } ] }
"""
const XFORM_JSON := """
{ "id": "b_xform", "duration": 0.4,
  "keyposes": [ { "t": 0.0, "pose": "guard" } ],
  "tracks": {
    "offsetX": [ { "t": 0.0, "v": 30.0 } ],
    "scaleX":  [ { "t": 0.0, "v": 1.2 } ]
  } }
"""
const ROT_JSON := """
{ "id": "b_rot", "duration": 0.4,
  "keyposes": [ { "t": 0.0, "pose": "guard" } ],
  "tracks": {
    "rotation": [ { "t": 0.0, "v": 90.0 } ]
  } }
"""
const GRAPH_JSON := """
{ "states": {
  "B_BARE":  { "clip": "b_bare",  "enter": { "mode": "snap", "time": 0.0 } },
  "B_HELD":  { "clip": "b_held",  "enter": { "mode": "snap", "time": 0.0 } },
  "B_XFORM": { "clip": "b_xform", "enter": { "mode": "snap", "time": 0.0 } },
  "B_ROT":   { "clip": "b_rot",   "enter": { "mode": "snap", "time": 0.0 } }
} }
"""

func _write(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	_write("user://b_bare.timeline.json", BARE_JSON)
	_write("user://b_held.timeline.json", HELD_JSON)
	_write("user://b_xform.timeline.json", XFORM_JSON)
	_write("user://b_rot.timeline.json", ROT_JSON)
	_write("user://b_graph.graph.json", GRAPH_JSON)

	var catalog := AssetCatalog.new()
	var presenter: Variant = PresenterScript.new(catalog)
	presenter.configure(
		"res://assets/animation_manifests/hu.manifest.json",
		"user://b_graph.graph.json",
		["user://b_bare.timeline.json", "user://b_held.timeline.json", "user://b_xform.timeline.json", "user://b_rot.timeline.json"],
		2.0)
	var fighter: Fighter = EnemyFactory.create_player()
	fighter.position = Vector2(500.0, 600.0)
	fighter.facing = 1
	fighter.animation_offset = Vector2.ZERO

	var manifest: Variant = ManifestScript.load_from_file("res://assets/animation_manifests/hu.manifest.json")
	var pose: Dictionary = manifest.get_pose("guard")
	var foot: Vector2 = pose["footAnchor"]
	var hb: Rect2 = pose["hurtbox"]

	# 1. Bare clip, facing right: rect = fighter pos + (hurtbox - foot) * renderScale.
	presenter.update(fighter, "B_BARE", 0.016, 0.016, Vector2.ZERO)
	var expected := Rect2(
		500.0 + (hb.position.x - foot.x) * 2.0,
		600.0 + (hb.position.y - foot.y) * 2.0,
		hb.size.x * 2.0,
		hb.size.y * 2.0)
	var got: Rect2 = presenter.get_body_rect(fighter, Vector2.ZERO)
	if got.position.distance_to(expected.position) < 1.0 and (got.size - expected.size).length() < 1.0:
		passed += 1
	else:
		failed += 1
		failures.append("bare bounds: expected %s got %s" % [str(expected), str(got)])

	# 2. Facing left mirrors around foot x.
	fighter.facing = -1
	presenter.update(fighter, "B_BARE", 0.016, 0.016, Vector2.ZERO)
	var mirrored: Rect2 = presenter.get_body_rect(fighter, Vector2.ZERO)
	var expected_left := 500.0 + (foot.x - hb.position.x - hb.size.x) * 2.0
	if absf(mirrored.position.x - expected_left) < 1.0 and absf(mirrored.size.x - expected.size.x) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("mirrored bounds: expected x %f got %f" % [expected_left, mirrored.position.x])
	fighter.facing = 1

	# 3. Held clip: bounds move WITH animation_offset (Task 1 displacement).
	fighter.animation_offset = Vector2(8.0, -3.0)
	presenter.update(fighter, "B_HELD", 0.016, 0.016, Vector2.ZERO)
	var held: Rect2 = presenter.get_body_rect(fighter, Vector2.ZERO)
	if held.position.is_equal_approx(expected.position + Vector2(8.0, -3.0)):
		passed += 1
	else:
		failed += 1
		failures.append("held bounds should include animation_offset: expected %s got %s" % [str(expected.position + Vector2(8.0, -3.0)), str(held.position)])
	fighter.animation_offset = Vector2.ZERO

	# 4. Transformed clip: offsetX shifts the rect, scaleX widens it (track parity).
	presenter.update(fighter, "B_XFORM", 0.016, 0.016, Vector2.ZERO)
	var xf: Rect2 = presenter.get_body_rect(fighter, Vector2.ZERO)
	var exp_left := 500.0 + 30.0 + (hb.position.x - foot.x) * 2.0 * 1.2
	var exp_w := hb.size.x * 2.0 * 1.2
	if absf(xf.position.x - exp_left) < 1.0 and absf(xf.size.x - exp_w) < 1.0:
		passed += 1
	else:
		failed += 1
		failures.append("transformed bounds: expected left %f w %f got left %f w %f" % [exp_left, exp_w, xf.position.x, xf.size.x])

	# 5. Rotated clip (constant 90°, like heavy's windup lean but exact):
	# corners map (x,y) -> (-y,x), so the AABB dimensions swap.
	# Width = hurtbox HEIGHT * S, height = hurtbox WIDTH * S; left edge lands at
	# fighter.x + (foot.y - hurtbox.end.y) * S (foot-pivot rotation).
	presenter.update(fighter, "B_ROT", 0.016, 0.016, Vector2.ZERO)
	var rot: Rect2 = presenter.get_body_rect(fighter, Vector2.ZERO)
	var exp_rot_w := hb.size.y * 2.0
	var exp_rot_h := hb.size.x * 2.0
	var exp_rot_left := 500.0 + (foot.y - hb.end.y) * 2.0
	if absf(rot.size.x - exp_rot_w) < 1.0 and absf(rot.size.y - exp_rot_h) < 1.0 and absf(rot.position.x - exp_rot_left) < 1.0:
		passed += 1
	else:
		failed += 1
		failures.append("rotated bounds: expected w %f h %f left %f got w %f h %f left %f" % [exp_rot_w, exp_rot_h, exp_rot_left, rot.size.x, rot.size.y, rot.position.x])
	presenter.free()

	return {"passed": passed, "failed": failed, "failures": failures}
```

Register in `run_tests.gd` after `test_presenter_offset.gd`.

- [ ] **Step 2: Run to verify failure**

Run: `./run.sh --test 2>&1 | tail -5`
Expected: FAIL — `get_body_rect` not found on FighterPresenter.

- [ ] **Step 3: Implement `get_body_rect` on the presenter**

Add to `WUGodot/scripts/visual/fighter_presenter.gd` (after `current_norm_t()`). It maps the hurtbox corners through the **exact transform `update()` cached on `_sprite_current`** — so animation_offset, tracks, facing flip, and rotation are all included with zero duplicated math:

```gdscript
func get_body_rect(fighter: Fighter, camera_offset: Vector2) -> Rect2:
	# Bounds reflect the most recent update(); combat_scene updates the
	# presenter before _draw, so callers always see same-frame state.
	var fallback := Rect2(
		fighter.position.x - fighter.half_width + camera_offset.x,
		fighter.position.y - fighter.height + camera_offset.y,
		fighter.half_width * 2.0,
		fighter.height)
	if _clip == null or _manifest == null or _sprite_current == null or _sprite_current.texture == null:
		return fallback

	var attack_def: Variant = fighter._attack_state.def if fighter._attack_state != null else null
	var pose: Dictionary = _manifest.get_pose(_clip.pose_at(_norm_t, attack_def))
	if pose.is_empty():
		return fallback
	var hb: Rect2 = pose.get("hurtbox", Rect2()) as Rect2
	if hb.size.x <= 0.0 or hb.size.y <= 0.0:
		return fallback

	# Same mapping Sprite2D applies when drawing: presenter position
	# (fighter pos + camera + opted-in animation_offset) + sprite-local
	# position + corner * scale, rotated around the sprite origin.
	var corners: Array[Vector2] = [
		hb.position,
		hb.position + Vector2(hb.size.x, 0.0),
		hb.position + Vector2(0.0, hb.size.y),
		hb.end,
	]
	var rect := Rect2()
	for i in range(corners.size()):
		var p: Vector2 = position + _sprite_current.position \
			+ (corners[i] * _sprite_current.scale).rotated(_sprite_current.rotation)
		if i == 0:
			rect = Rect2(p, Vector2.ZERO)
		else:
			rect = rect.expand(p)
	return rect
```

Note the unused `camera_offset` asymmetry is deliberate: the cached `position` already contains the camera offset from this frame's `update()`; the parameter exists for the fallback path and signature parity with `FighterVisual.get_body_rect`.

- [ ] **Step 4: Run tests to verify pass**

Run: `./run.sh --test 2>&1 | tail -5`
Expected: PASS, 0 failed.

- [ ] **Step 5: Wire overlays through the presenter rect**

In `WUGodot/scripts/combat_scene.gd`, `_draw_fighter` currently begins:

```gdscript
	var visual: FighterVisual = _get_visual_for(fighter)
	var body_rect: Rect2 = visual.get_body_rect(fighter, camera_offset)
```

Replace with:

```gdscript
	var visual: FighterVisual = _get_visual_for(fighter)
	var body_rect: Rect2 = _body_rect_for(fighter, visual, camera_offset)
```

and add the helper (near `_resolve_player_state_name`):

```gdscript
func _body_rect_for(fighter: Fighter, visual: FighterVisual, camera_offset: Vector2) -> Rect2:
	if fighter == _player and _player_presenter != null and _player_presenter.visible \
			and _player_presenter.handles_state(_resolve_player_state_name()):
		return _player_presenter.get_body_rect(fighter, camera_offset)
	return visual.get_body_rect(fighter, camera_offset)
```

- [ ] **Step 6: Full gates + visual check**

Run: `./run.sh --test 2>&1 | tail -3` (expected 0 failed), then `./run.sh --shot-combat /tmp/wu-bounds-check`.
Open `03_light_windup.png` — the telegraph outline must hug Hu's body box (not the blade, not a degenerate rect).

- [ ] **Step 7: Commit**

```bash
git add WUGodot/scripts/visual/fighter_presenter.gd WUGodot/scripts/combat_scene.gd WUGodot/tests/test_presenter_bounds.gd WUGodot/tests/run_tests.gd
git commit -m "feat(presenter): manifest-backed body bounds; overlays use presenter rect for presenter-owned states"
```

### Task 3: Max-extension collision rule (test + mapping)

`STRIKE_POSE_BY_ID` must point at the active-window keypose with the largest `|weaponTip.x − footAnchor.x|` (spec §6). Light switches now; heavy is re-asserted in Phase 4 when its clip lands.

**Files:**
- Create: `WUGodot/tests/test_strike_pose_rule.gd`
- Modify: `WUGodot/scripts/visual/presentation_collision.gd:10` (`STRIKE_POSE_BY_ID`)
- Modify: `WUGodot/tests/run_tests.gd`

- [ ] **Step 1: Write the failing test**

Create `WUGodot/tests/test_strike_pose_rule.gd`:

```gdscript
extends RefCounted

const TimelineScript = preload("res://scripts/visual/animation_clip_timeline.gd")
const ManifestScript = preload("res://scripts/visual/animation_manifest.gd")
const CollisionScript = preload("res://scripts/visual/presentation_collision.gd")
const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

const CASES := [
	{ "id": "hu_light", "clip": "res://assets/animation_clips/hu_attack_light.timeline.json" },
]

func _max_extension_active_pose(clip: Variant, def: Variant, manifest: Variant) -> String:
	var t_start: float = clip.event_time("attack_active_start", def)
	var t_end: float = clip.event_time("attack_active_end", def)
	var best_pose := ""
	var best_dist := -1.0
	for kp in clip.keyposes:
		var t: float = clip._resolve_t(kp["t"], def)
		if t < t_start - 0.0001 or t > t_end + 0.0001:
			continue
		var pose: Dictionary = manifest.get_pose(str(kp["pose"]))
		if pose.is_empty():
			continue
		var foot: Vector2 = pose["footAnchor"]
		var tip: Vector2 = pose["weaponTip"]
		var dist: float = absf(tip.x - foot.x)
		if dist > best_dist:
			best_dist = dist
			best_pose = str(kp["pose"])
	return best_pose

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	var manifest: Variant = ManifestScript.load_from_file("res://assets/animation_manifests/hu.manifest.json")
	for case in CASES:
		var clip: Variant = TimelineScript.load_from_file(str(case["clip"]))
		var def: Variant = AttackCatalogScript.hu_light() if str(case["id"]) == "hu_light" else AttackCatalogScript.hu_heavy()
		var expected: String = _max_extension_active_pose(clip, def, manifest)
		var mapped: String = str(CollisionScript.STRIKE_POSE_BY_ID.get(str(case["id"]), ""))
		if not expected.is_empty() and mapped == expected:
			passed += 1
		else:
			failed += 1
			failures.append("%s: STRIKE_POSE_BY_ID maps '%s' but max-extension active pose is '%s'" % [case["id"], mapped, expected])

	return {"passed": passed, "failed": failed, "failures": failures}
```

Register in `run_tests.gd`. Note: `clip._resolve_t` is the existing marker resolver; if it is script-private by convention only (GDScript has no real private), call it directly.

- [ ] **Step 2: Run to verify failure**

Run: `./run.sh --test 2>&1 | tail -5`
Expected: FAIL — `hu_light` maps `strike_extended` but the max-extension active pose is a `va_` pose (per the installed data: `va_053`, tip−foot = 266).

- [ ] **Step 3: Update the mapping**

In `WUGodot/scripts/visual/presentation_collision.gd` change:

```gdscript
const STRIKE_POSE_BY_ID: Dictionary = {
	"hu_light": "strike_extended",
	"hu_heavy": "heavy_strike",
}
```

to:

```gdscript
# Rule (spec 2026-06-12 §6): map each attack to its clip's max-extension
# ACTIVE keypose (largest |weaponTip.x - footAnchor.x|). Asserted by
# test_strike_pose_rule.gd — update this table when a clip changes.
const STRIKE_POSE_BY_ID: Dictionary = {
	"hu_light": "va_053",
	"hu_heavy": "heavy_strike",
}
```

- [ ] **Step 4: Atomic reach re-sync ("match the visible blade")**

The mapping flip is a **live balance change**: `va_053`'s tip sits farther out than `strike_extended`'s, and the current data is internally consistent (`range_units` 342, derived reach 364 = 342 + defender half_width 22, asserted by `WUGodot/tests/test_attack_data.gd:12`). The rule is *reach follows the visible blade* — so `range_units` IS what moves, and everything derived moves with it in ONE commit:

1. Run `./run.sh --probe-reach 2>&1 | tail -5` and record the new derived reach from the `va_053` capsule.
2. Update `WUGodot/data/Attacks/Attacks.json` `hu_light.range_units` so `range_units + 22 == new derived reach`.
3. Update the pinned expectations in `WUGodot/tests/test_attack_data.gd`.
4. Re-derive enemy ranges to hold the balance band (enemy reach = 70–85% of Hu's; same procedure as the 2026-06-09 "Tune enemy combat ranges" pass). Know where each number lives: enemy attack `range_units` are in `WUGodot/data/Attacks/Attacks.json` (enemy attack entries, ~line 288), while enemy JSON files own only `preferredRange` (e.g. `WUGodot/data/Enemies/BanditSwordsman.json:21`).
5. Run ALL gates + `--probe-reach`; expected 0 failed, band respected.

**✋ STOP before committing this step:** show the user the before/after table (hu_light reach, each enemy's reach %, c2c distances). A reach change is gameplay-felt; they may prefer deferring the flip to Phase 3 (when light regenerates as `vl_` anyway) — if so: revert the Step 3 mapping change, empty the `CASES` array with a comment `# populated per-attack as clips regenerate — see Phase 3/4`, commit the test infrastructure only, and record the decision here.

- [ ] **Step 5: Commit (one atomic commit — collision rule + the reach data it moved)**

```bash
git add WUGodot/tests/test_strike_pose_rule.gd WUGodot/scripts/visual/presentation_collision.gd WUGodot/tests/run_tests.gd \
        WUGodot/data/Attacks/Attacks.json WUGodot/tests/test_attack_data.gd WUGodot/data/Enemies/
git commit -m "feat(collision): strike pose = max-extension active keypose; reach re-synced to visible blade"
```

(If the user chose the deferral path in Step 4, drop the data files from this commit and use the infrastructure-only message from that step.)

### Task 4: `--shot-action` temporal harness

Per spec §4: per-state in-game export of every rendered frame + phase data, then ffmpeg assembly into GIF + phase-marked strip. Two cycles for loop states.

**Files:**
- Modify: `WUGodot/scripts/main.gd` (new dev flag + capture loop)
- Modify: `WUGodot/scripts/combat_scene.gd` (expose `dev_prepare_capture_state` reuse — already exists; add nothing unless missing)
- Modify: `run.sh` (new subcommand)
- Create: `tools/assemble_action_review.py`

- [ ] **Step 1: Add the flag plumbing to `main.gd`**

After the existing const block (`main.gd:3-6`) add:

```gdscript
const DEV_SHOT_ACTION_FLAG: String = "--shot-action"
const DEV_SHOT_STATE_PREFIX: String = "--shot-state="
```

In `_ready` argument handling (mirror the `--shot-combat` branch at `main.gd:27-30`):

```gdscript
	elif OS.get_cmdline_user_args().has(DEV_SHOT_ACTION_FLAG):
		_dev_shot_combat_dir = _user_arg_value(DEV_SHOT_DIR_PREFIX, DEV_SHOT_DEFAULT_DIR)
		_dev_shot_action_state = _user_arg_value(DEV_SHOT_STATE_PREFIX, "ATTACKING_LIGHT")
		call_deferred("_run_dev_action_shots")
```

with `var _dev_shot_action_state: String = ""` beside the other dev vars.

- [ ] **Step 2: Implement the capture loop**

Add to `main.gd` (after `_capture_dev_combat_state`):

```gdscript
const _ACTION_CAPTURE := {
	# state            trigger capture-state      frames (60fps)        loop
	# Attacks use dedicated full-attack prep modes (Step 2b), NOT the still-shot
	# windup fixtures: those seed elapsed = windup_end * 0.55 (combat_scene.gd:201,
	# :213), which would hide the first half of startup from Gate 2 and shift the
	# phase markers (windup_end_frame is relative to attack start).
	"ATTACKING_LIGHT": { "prep": "attack_light_full", "frames": 32, "loop": false },
	"ATTACKING_HEAVY": { "prep": "attack_heavy_full", "frames": 50, "loop": false },
	"IDLE":            { "prep": "01_idle",         "frames": 192, "loop": true },
	"WALKING":         { "prep": "02_walk",         "frames": 120, "loop": true },
	"BLOCKING":        { "prep": "08_block",        "frames": 36, "loop": false },
	"HIT_REACTION":    { "prep": "09_hit_react",    "frames": 24, "loop": false },
	"STUNNED":         { "prep": "10_stunned",      "frames": 90, "loop": true },
	"DASHING":         { "prep": "11_dash",         "frames": 20, "loop": false },
	"JUMPING":         { "prep": "12_jump",         "frames": 40, "loop": false },
}

func _run_dev_action_shots() -> void:
	var state: String = _dev_shot_action_state
	if not _ACTION_CAPTURE.has(state):
		push_error("shot-action: unknown state %s (known: %s)" % [state, str(_ACTION_CAPTURE.keys())])
		get_tree().quit(1)
		return
	var cfg: Dictionary = _ACTION_CAPTURE[state]
	var dir_path: String = _dev_shot_combat_dir if not _dev_shot_combat_dir.is_empty() else DEV_SHOT_DEFAULT_DIR
	var abs_dir: String = ProjectSettings.globalize_path(dir_path) if dir_path.begins_with("user://") or dir_path.begins_with("res://") else dir_path
	if DirAccess.make_dir_recursive_absolute(abs_dir) != OK:
		push_error("shot-action: failed to create %s" % abs_dir)
		get_tree().quit(1)
		return

	_ctx = SceneContext.new()
	_ctx.player = EnemyFactory.create_player()
	_ctx.run_state = RunState.create_procedural_run()
	_ctx.run_state.legend_seen_this_run = true
	var node: MapNode = MapNode.new(9001, 1, MapNode.NodeType.BATTLE, [])
	_combat_scene.setup_combat(_ctx.player, node, false, "")
	_combat_scene.on_enter()
	_combat_scene.dev_set_capture_mode(true)
	_current_scene = SceneContext.SCENE_COMBAT
	_ctx.current_scene = SceneContext.SCENE_COMBAT
	queue_redraw()

	_combat_scene.dev_prepare_capture_state(str(cfg["prep"]))
	await get_tree().process_frame

	var total: int = int(cfg["frames"]) * (2 if bool(cfg["loop"]) else 1)
	for i in range(total):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png("%s/frame_%03d.png" % [abs_dir.trim_suffix("/"), i])

	# Phase boundaries (attacks only) — consumed by tools/assemble_action_review.py.
	var phases: Dictionary = {"state": state, "fps": 60, "loop": bool(cfg["loop"]), "frames": total}
	var def: Variant = _ctx.player._attack_state.def if _ctx.player._attack_state != null else null
	if def != null and (state == "ATTACKING_LIGHT" or state == "ATTACKING_HEAVY"):
		phases["windup_end_frame"] = int(round(def.windup_end * 60.0))
		phases["active_end_frame"] = int(round(def.active_end * 60.0))
	var f := FileAccess.open("%s/phases.json" % abs_dir.trim_suffix("/"), FileAccess.WRITE)
	f.store_string(JSON.stringify(phases, "  "))
	f.close()
	print("SHOT ACTION: wrote %d frames to %s" % [total, abs_dir])
	get_tree().quit(0)
```

- [ ] **Step 2a: REQUIRED — dev playback path in `combat_scene.gd`** (review finding: this is not optional)

In `_dev_capture_mode`, `CombatScene._process()` returns after the presenter/visual update without advancing fighter timers, `_attack_state.elapsed`, or `_update_animation()` (`combat_scene.gd:303`). Attack clips would freeze (presenter time IS `_attack_state.elapsed`) and held states would never wobble/shake/arc. Add a playback flag, applied in the `_dev_capture_mode` early-return branch of `_process` (`combat_scene.gd:303`), before the presenter/visual update and the return. NOTE: `dt` does not exist yet at that point (it is declared at `combat_scene.gd:342`) — compute a local one. And never mutate `_attack_state.elapsed` raw: `AttackState.advance()` (`attack_state.gd:59`) owns events/finish semantics.

Physics-carried states (DASHING/JUMPING/FALLING) need more than timers: their root motion comes from gravity/velocity integration inside `CombatSystem.update_player()` (`combat_system.gd:95`, `:114`), which the dev branch skips. For those, route through `update_player` with **neutral input** — full movement physics, still no AI/hits/end-checks:

```gdscript
var _dev_capture_playback: bool = false
var _dev_capture_physics: bool = false

func dev_set_capture_playback(enabled: bool, physics: bool = false) -> void:
	_dev_capture_playback = enabled
	_dev_capture_physics = physics
```

```gdscript
	if _dev_capture_playback:
		# Advance presentation-relevant time only. No real input, no AI,
		# no resolve_hits, no victory/defeat checks.
		var capture_dt: float = delta
		if _dev_capture_physics:
			# Ballistic/dash states: full player physics with neutral input
			# (gravity, velocity integration, state transitions like
			# JUMPING -> FALLING -> LANDING happen for real).
			_combat_system.update_player(_player, _build_player_input(false), capture_dt, _enemy)
		else:
			_player.update_timers(capture_dt)
		_particle_system.update(capture_dt)
```

(`fighter.update_timers` is at `fighter.gd:178` and **already calls `_update_animation()` internally** (`fighter.gd:236`) — do NOT call `_update_animation` separately or held-state shake/wobble/bob will advance at double speed in the review GIF. `update_player` drives timers itself — never combine the two branches. Verify `update_timers` advances the attack state via `AttackState.advance()`; if it does not, add `if _player._attack_state != null: _player._attack_state.advance(capture_dt)` — discarding the returned event dict is fine for capture — but never assign `elapsed` directly. Verify `_build_player_input(false)` returns the all-neutral dict (it is the existing inactive-input shape at `combat_scene.gd:505-510`); if its signature differs, add a tiny `_neutral_capture_input()` returning that literal. Keep the whole diff inside the dev-mode branch.)

- [ ] **Step 2b: REQUIRED — full-attack prep modes in `combat_scene.gd`**

Extend `dev_prepare_capture_state` with two new modes, `"attack_light_full"` and `"attack_heavy_full"`: identical fighter/camera positioning to `"03_light_windup"` / `"06_heavy_windup"`, but start the attack at **elapsed = 0** (use the same attack-start call those fixtures use, minus the `elapsed = windup_end * 0.55` override at `combat_scene.gd:201`/`:213`). The existing still-shot fixtures stay untouched — `--shot-combat` still uses them. With elapsed starting at 0, `phases.json`'s `windup_end_frame = def.windup_end * 60` is correct as written (attack start == capture start), and Gate 2 reviews the entire startup.

Add `"physics": true` to the `_ACTION_CAPTURE` entries for `DASHING` and `JUMPING` (the jump capture rides the real arc through FALLING and LANDING — one capture reviews all three states; the table's FALLING row can then be dropped or kept for a fall-only check). `main.gd`'s `_run_dev_action_shots` calls `_combat_scene.dev_set_capture_playback(true, bool(cfg.get("physics", false)))` right after `dev_set_capture_mode(true)`. The prep state must seed real velocity (e.g. the jump impulse) — if `dev_prepare_capture_state("12_jump")` only poses the fighter without `velocity.y`, extend it to apply the actual jump impulse.

**Acceptance for this step:** `frame_000.png` ≠ `frame_015.png` for ATTACKING_LIGHT (pose advances) AND for HIT_REACTION (offset shake displaces the held pose) AND the JUMPING capture shows the fighter's y position visibly arcing across frames (real ballistic movement, not just pose wobble). If any of the three fails, this step is not done.

- [ ] **Step 3: run.sh subcommand**

In `run.sh`, beside `--shot-combat`:

```bash
    --shot-action)
        STATE="${2:?usage: ./run.sh --shot-action STATE [dir]}"
        SHOT_DIR="${3:-/tmp/wu-shot-action}"
        exec "$GODOT" --path "$PROJECT_DIR" -- --shot-action "--shot-state=$STATE" "--shot-dir=$SHOT_DIR"
        ;;
```

and add `--shot-action` to the usage line.

- [ ] **Step 4: Assembly script**

Create `tools/assemble_action_review.py`:

```python
#!/usr/bin/env python3
"""Assemble --shot-action output into review artifacts.

Usage: python3 tools/assemble_action_review.py /tmp/wu-shot-action
Emits in the same dir: action.gif (gameplay speed), strip.png (phase-marked
contact sheet, 12 columns). Requires ffmpeg on PATH.
"""
import json, pathlib, subprocess, sys

d = pathlib.Path(sys.argv[1])
phases = json.loads((d / "phases.json").read_text())
frames = sorted(d.glob("frame_*.png"))
n = len(frames)
assert n == phases["frames"], f"expected {phases['frames']} frames, found {n}"

# 1. GIF at gameplay speed.
subprocess.run([
    "ffmpeg", "-y", "-framerate", str(phases["fps"]),
    "-i", str(d / "frame_%03d.png"),
    "-vf", "split[a][b];[a]palettegen=max_colors=64[p];[b][p]paletteuse",
    str(d / "action.gif")], check=True, capture_output=True)

# 2. Contact strip: 12 frames evenly spaced, tiled 12x1, phase-tinted borders.
cols = 12
picks = [frames[round(i * (n - 1) / (cols - 1))] for i in range(cols)]
w_end = phases.get("windup_end_frame", -1)
a_end = phases.get("active_end_frame", -1)
inputs, filters = [], []
for i, p in enumerate(picks):
    idx = round(i * (n - 1) / (cols - 1))
    color = "white"
    if w_end >= 0:
        color = "yellow" if idx < w_end else ("red" if idx <= a_end else "cyan")
    inputs += ["-i", str(p)]
    filters.append(f"[{i}:v]scale=320:-1,pad=326:ih+6:3:3:{color}[f{i}]")
chain = "".join(f"[f{i}]" for i in range(cols))
filters.append(f"{chain}hstack=inputs={cols}[out]")
subprocess.run(["ffmpeg", "-y", *inputs, "-filter_complex", ";".join(filters),
                "-map", "[out]", str(d / "strip.png")], check=True, capture_output=True)
print(f"wrote {d/'action.gif'} and {d/'strip.png'} "
      f"(yellow=windup red=active cyan=recovery)")
```

- [ ] **Step 5: Verify end-to-end on the existing light attack**

```bash
./run.sh --shot-action ATTACKING_LIGHT /tmp/wu-shot-action
python3 tools/assemble_action_review.py /tmp/wu-shot-action
```

Expected: 32 PNGs + `phases.json` + `action.gif` + `strip.png`. Open `strip.png`: yellow→red→cyan border progression matching windup/active/recovery; frames show the draw→thrust→resheath arc actually advancing (NOT 32 identical stills — if identical, implement the playback note in Step 2). View `action.gif` for foot slide.

- [ ] **Step 6: Gates + commit**

`./run.sh --test 2>&1 | tail -3` (0 failed — harness is dev-only code), then:

```bash
git add WUGodot/scripts/main.gd WUGodot/scripts/combat_scene.gd run.sh tools/assemble_action_review.py
git commit -m "feat(dev): --shot-action temporal harness — per-frame export, phase-marked strip, gameplay-speed GIF"
```

### Task 5: Generalized installer `tools/install_video_frames.gd`

Promote the proven exact-mode install path into a parameterized, idempotent tool.

**Anchor-safety constraint (review finding):** the committed `install_pixelized.gd` derives the foot root from **master sidecar `foot_anchor` × pixel sidecar `scale_applied`** (`install_pixelized.gd:67-72`) and asserts constant foot spread (`:92`) — it never trusts AnchorMeasure for the foot (pixel-measured feet drift ±px in exact mode) and never assumes the foot sits at image center. The generalized tool MUST keep that path: sidecars for the foot, `AnchorMeasure` only for tip/chest/hurtbox.

**Files:**
- Create: `WUGodot/tools/install_video_frames.gd`
- Modify: `run.sh` (subcommand)

- [ ] **Step 1: Create the tool**

`WUGodot/tools/install_video_frames.gd`:

```gdscript
extends SceneTree
# Install pixelized video frames as manifest poses.
#
# Usage (via run.sh):
#   ./run.sh --install-video <run-dir> --action=<name> --frames=020,023,... \
#            [--prefix=va] [--foot-x=224] [--manifest=res://assets/animation_manifests/hu.manifest.json]
#
# <run-dir> is the scale_masters/pixelize run root: it must contain
# <action>/pixelize/pixel_NNN.png+json AND <action>/masters/master_NNN.json
# (the master sidecars scale_masters wrote).
#
# ORDER CONTRACT: sources are read sequentially — pixel_001 is installed as
# <prefix>_<first --frames label>, pixel_002 as the second, and so on.
# --frames NEVER selects sources; it only names destinations. The staging
# step (Runbook 5) must copy ONLY the selected frames (+ sidecars),
# renumbered 001..N in the same order as the --frames list.
#
# Behavior:
#   - Idempotent: first deletes every existing pose named <prefix>_* (and its PNG/.import),
#     then installs the listed frames.
#   - Foot root (exact-mode safe path, same as install_pixelized.gd:67-72): per frame,
#     foot_px = master sidecar foot_anchor × pixel sidecar scale_applied. NEVER measured
#     from pixels, NEVER assumed at image center.
#   - Foot-x spread asserted ≈0 across the batch BEFORE any file is written
#     (install_pixelized.gd:92 pattern), then every frame is cropped by
#     (round(foot_px.x) - foot_x) from the left so stored footAnchor.x == foot_x.
#   - AnchorMeasure is used ONLY for weaponTip/chestAnchor/hurtbox (on the cropped image).

const AM = preload("res://scripts/visual/anchor_measure.gd")

func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.substr(name.length() + 1)
	return fallback

func _read_dict(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: install_video_frames <run-dir> --action=x --frames=a,b,c"); quit(1); return
	var run_dir: String = args[1].trim_suffix("/")
	var action: String = _arg("--action", "")
	var frames: PackedStringArray = _arg("--frames", "").split(",", false)
	var prefix: String = _arg("--prefix", action)
	var foot_x: int = int(_arg("--foot-x", "224"))
	var mpath: String = _arg("--manifest", "res://assets/animation_manifests/hu.manifest.json")
	if action.is_empty() or frames.is_empty():
		printerr("--action and --frames are required"); quit(1); return

	# Pass 1 — derive each frame's foot from sidecars; assert the batch is consistent
	# BEFORE writing anything.
	var foots: Array[Vector2] = []
	for i in range(frames.size()):
		var pixel_sidecar: Dictionary = _read_dict("%s/%s/pixelize/pixel_%03d.json" % [run_dir, action, i + 1])
		var master_sidecar: Dictionary = _read_dict("%s/%s/masters/master_%03d.json" % [run_dir, action, i + 1])
		var sa: Array = pixel_sidecar.get("scale_applied", []) as Array
		var fa: Array = master_sidecar.get("foot_anchor", []) as Array
		if sa.size() < 2 or fa.size() < 2:
			printerr("frame %03d: missing scale_applied/foot_anchor sidecar data" % (i + 1)); quit(1); return
		if absf(float(sa[0]) - float(sa[1])) > 0.0001:
			printerr("frame %03d: non-uniform scale_applied %s — refuse to install" % [i + 1, str(sa)]); quit(1); return
		foots.append(Vector2(float(fa[0]) * float(sa[0]), float(fa[1]) * float(sa[1])))
	var min_x: float = INF
	var max_x: float = -INF
	for f in foots:
		min_x = minf(min_x, f.x)
		max_x = maxf(max_x, f.x)
	if max_x - min_x > 2.0:
		printerr("foot-x spread %.1f across batch — masters not normalized; refuse to install" % (max_x - min_x)); quit(1); return

	var root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(mpath)) as Dictionary
	var poses: Dictionary = root["poses"]

	# Idempotent cleanup of this prefix's poses.
	for existing in poses.keys().duplicate():
		if str(existing).begins_with(prefix + "_"):
			poses.erase(existing)
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://assets/sprites/characters/hu/%s.png" % existing))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://assets/sprites/characters/hu/%s.png.import" % existing))

	# Pass 2 — crop to pin foot_x, measure non-foot anchors, write pose entries.
	for i in range(frames.size()):
		var src := "%s/%s/pixelize/pixel_%03d.png" % [run_dir, action, i + 1]
		var img := Image.new()
		if img.load(src) != OK:
			printerr("load fail %s" % src); quit(1); return
		var crop: int = int(round(foots[i].x)) - foot_x
		var used := img.get_used_rect()
		if crop < 0 or used.position.x < crop:
			printerr("crop %d invalid for %s (content min x %d)" % [crop, src, used.position.x]); quit(1); return
		var cropped := Image.create(img.get_width() - crop, img.get_height(), false, Image.FORMAT_RGBA8)
		cropped.fill(Color(0, 0, 0, 0))
		cropped.blit_rect(img, Rect2i(crop, 0, img.get_width() - crop, img.get_height()), Vector2i.ZERO)
		var pose_name := "%s_%s" % [prefix, frames[i]]
		var dest := "res://assets/sprites/characters/hu/%s.png" % pose_name
		cropped.save_png(ProjectSettings.globalize_path(dest))
		var m: Dictionary = AM.measure(cropped)
		var tip: Vector2 = m["weaponTip"]
		var chest: Vector2 = m["chestAnchor"]
		var hb: Rect2 = m["hurtbox"]
		poses[pose_name] = {
			"path": dest,
			"footAnchor": [foot_x, int(round(foots[i].y))],
			"chestAnchor": [int(round(chest.x)), int(round(chest.y))],
			"weaponTip": [int(round(tip.x)), int(round(tip.y))],
			"hurtbox": [int(round(hb.position.x)), int(round(hb.position.y)), int(round(hb.size.x)), int(round(hb.size.y))],
		}
		print("%-10s foot_y=%d tip=%s" % [pose_name, int(round(foots[i].y)), str(poses[pose_name]["weaponTip"])])

	root["poses"] = poses
	var f := FileAccess.open(mpath, FileAccess.WRITE)
	f.store_string(JSON.stringify(root, "  "))
	f.close()
	print("manifest: %d poses total" % poses.size())
	quit(0)
```

(`scale_applied` may be stored as `[x, y]` or `{x, y}` depending on pixelforge version — check one sidecar from the light-attack run and adapt `_read_dict` extraction; the non-uniform-scale refusal stays either way. If the staged frame numbering does not match `master_%03d` (frames were staged renumbered), the staging step must also copy the master sidecars under the staged numbering — add that to the Runbook staging command.)

- [ ] **Step 2: run.sh subcommand**

```bash
    --install-video)
        shift
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script "$PROJECT_DIR/tools/install_video_frames.gd" -- "$@"
        ;;
```

(Match the arg-passing convention of the existing `--install-pixelized` branch — inspect it first and mirror exactly.)

- [ ] **Step 3: Verify idempotency on the live light attack (no-op reinstall)**

The current `va_` poses came from `/tmp/wu-va-run3/attack-video/pixelize` (recreate that dir by re-running the Phase-3 scale+pixelize steps if /tmp was cleared — same inputs produce the same outputs). Then:

```bash
./run.sh --install-video /tmp/wu-va-run3 --action=attack-video --prefix=va \
  --frames=020,023,026,029,032,035,038,042,046,050,053,056,059,062,065,068,072,076,080,081,082,083,084,085,086,087,088,089,090,091
git diff --stat   # manifest noise only if rounding shifts ±1px; expect near-empty
./run.sh --import 2>&1 | grep -ciE "^ERROR|SCRIPT ERROR"   # 0
./run.sh --test 2>&1 | tail -3 && ./run.sh --anchor-sanity 2>&1 | tail -1
```

Expected: identical manifest (or ±1px rounding), all gates green. Run it TWICE — second run must produce zero diff (idempotency).

- [ ] **Step 4: Commit**

```bash
git add WUGodot/tools/install_video_frames.gd run.sh
git commit -m "feat(tools): generalized idempotent video-frame installer"
```

### Task 6: Keyframe review page + provenance manifest

**Files:**
- Create: `tools/build_keyframe_review.py`
- Create: `art/keyframes/keyframes.manifest.json` (seed)

- [ ] **Step 1: Seed the provenance manifest**

`art/keyframes/keyframes.manifest.json`:

```json
{
  "character": "hu",
  "reference": "art/keyframes/hu/guard/stance.png",
  "actions": {}
}
```

Schema (documented in the file's sibling `README.md`, create it too):
each `actions.<action>.slots.<slot>` is `{ "file": "...", "prompt": "...", "backend": "codex", "seed": null, "approved": "YYYY-MM-DD", "notes": "..." }`.

- [ ] **Step 2: Create the page builder**

`tools/build_keyframe_review.py`:

```python
#!/usr/bin/env python3
"""Build a static keyframe-approval page.

Usage: python3 tools/build_keyframe_review.py <candidates-root> [--out review/index.html]

Layout convention: <candidates-root>/<action>/<slot>/cand_*.png
Each candidate renders at 2x game zoom (pixelated) next to the current in-game
art for that action (if a mapping exists below). The page is read-only; the
user gives verdicts in chat and approved files are recorded in
art/keyframes/keyframes.manifest.json by the operator.
"""
import html, pathlib, sys

CURRENT_ART = {  # action -> representative installed sprite for side-by-side
    "guard": "WUGodot/assets/sprites/characters/hu/static.png",
    "idle": "WUGodot/assets/sprites/characters/hu/idle_0.png",
    "walk": "WUGodot/assets/sprites/characters/hu/walk_0.png",
    "light": "WUGodot/assets/sprites/characters/hu/va_053.png",
    "heavy": "WUGodot/assets/sprites/characters/hu/heavy_1.png",
    "hit": "WUGodot/assets/sprites/characters/hu/hit_0.png",
    "stunned": "WUGodot/assets/sprites/characters/hu/stunned_0.png",
    "block": "WUGodot/assets/sprites/characters/hu/block_0.png",
    "dash": "WUGodot/assets/sprites/characters/hu/dash_0.png",
    "jump": "WUGodot/assets/sprites/characters/hu/jump_0.png",
}

root = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[3]) if len(sys.argv) > 3 else root / "index.html"
repo = pathlib.Path(__file__).resolve().parent.parent

rows = []
for action_dir in sorted(p for p in root.iterdir() if p.is_dir()):
    for slot_dir in sorted(p for p in action_dir.iterdir() if p.is_dir()):
        cards = []
        cur = CURRENT_ART.get(action_dir.name)
        if cur and (repo / cur).exists():
            cards.append(f'<figure><img src="{(repo/cur).as_uri()}"><figcaption>CURRENT in-game</figcaption></figure>')
        for cand in sorted(slot_dir.glob("cand_*.png")):
            cards.append(f'<figure><img src="{cand.as_uri()}"><figcaption>{html.escape(cand.name)}</figcaption></figure>')
        rows.append(f"<h2>{action_dir.name} / {slot_dir.name}</h2><div class=row>{''.join(cards)}</div>")

out.write_text(f"""<!doctype html><meta charset=utf-8>
<title>WU keyframe review</title>
<style>
 body {{ background:#1a1a2e; color:#eee; font-family:monospace }}
 .row {{ display:flex; flex-wrap:wrap; gap:16px }}
 figure {{ margin:0; text-align:center }}
 img {{ image-rendering:pixelated; height:340px; background:
       repeating-conic-gradient(#333 0% 25%, #2a2a3e 0% 50%) 0 0/24px 24px }}
</style>
<h1>Keyframe review — verdict per slot in chat: approve cand_N / redo + notes</h1>
{''.join(rows)}""")
print(f"wrote {out} — open with: python3 -m http.server -d {out.parent} 8765")
```

- [ ] **Step 3: Smoke-test with dummy candidates**

```bash
mkdir -p /tmp/wu-kf-test/light/thrust && cp WUGodot/assets/sprites/characters/hu/va_053.png /tmp/wu-kf-test/light/thrust/cand_1.png
python3 tools/build_keyframe_review.py /tmp/wu-kf-test
open /tmp/wu-kf-test/index.html
```

Expected: page shows the `light / thrust` row with CURRENT + cand_1 at pixelated zoom.

- [ ] **Step 4: Commit**

```bash
git add tools/build_keyframe_review.py art/keyframes/
git commit -m "feat(tools): keyframe approval page builder + provenance manifest seed"
```

---

## The Action Pipeline Runbook (used by every phase below)

Each action phase executes these steps with its own parameter block. Commands are written out fully in each phase; this section defines the *judgment* parts that don't vary:

1. **Keyframe authoring.** First run `aiexp sprite-extractor rawgen --help` (flag names may differ from this plan's sketch — adapt; the report guarantees codex backend + image-to-image editing exist). Generate 3–4 candidates per slot. Iteration uses plain edit framing: *"Edit the image: <minimal change>. Everything else stays unchanged."* Object-state consistency across ALL slots of ALL actions: blade drawn, scabbard visible at hip, same grip hand as the approved guard.

   **Codex recovery check (aiexp 2026-06-12 fix):** codex generation now prints `recovery: session-id (…)` on stderr — the safe, session-targeted path (pixelforge-image-gen ≥0.10.2). If a run ever reports `recovery: sessions-diff-fallback`, the image may belong to ANOTHER codex session on this machine (the cross-session leak that once returned a MadCards map as a sprite) — discard and regenerate. Record the reported `session_id`/`recovery` in `keyframes.manifest.json` provenance for each approved keyframe.
2. **✋ Gate 1.** Build + serve the review page; the user verdicts per slot. Copy each approved file to `art/keyframes/hu/<action>/<slot>.png`, record `prompt/backend/seed/approved` in `keyframes.manifest.json`, commit (`art:` prefix). Budget ~5 rounds per action family; if a slot resists after that, fall back to image-to-image edits from the nearest approved still.
3. **Video.** `animate-video --reference-seq` with approved keyframes in order (loops repeat the first as last). Check `contact_sheet.png` + `preview.gif` in the run dir: static camera, no identity drift. Reject and re-run (new seed) on camera drift — do not hand-fix frames.
4. **Selection.** List candidate frames by measuring tips/feet (AnchorMeasure probe or visual scan of masters). Select by pose progress, dense where motion supports it (light-attack precedent: ~30 frames). Skip glitch frames (object flicker). For loops, verify first≈last selected frame.
5. **Stage the SELECTED frames — order is the naming contract.** The installer reads sources *sequentially* (`pixel_001..N`, `master_001..N`) and uses `--frames` labels *only for destination pose names*: `pixel_001` becomes `<prefix>_<first label>`, and so on. Staging the full video output while passing selected labels would silently install wrong frames under right names. So: copy ONLY the selected masters **and their sidecars**, renumbered `master_001..N` in exactly the same order as the `<pose-labels>` list you will pass to `--frames`:

   ```bash
   i=1; for f in <selected source numbers, label order>; do
     n=$(printf "%03d" $i)
     cp "$VIDEO_RUN/<action>/masters/master_$f.png"  "$STAGE/<action>/masters/master_$n.png"
     cp "$VIDEO_RUN/<action>/masters/master_$f.json" "$STAGE/<action>/masters/master_$n.json"
     i=$((i+1)); done
   ```

   Sidecars MUST come along (the installer derives the foot root from them — never `echo '{}'` placeholders for video-run masters).
6. **Normalize + pixelize the staged set.** Also stage `idle/masters/master_001.png` (the SAME idle reference every action — this is what keeps texel density uniform across the character). Run `./run.sh --scale-masters <stage>`; use the printed `out-size for pixelize: W:H` EXACTLY (do not reuse a previous run's size); `aiexp sprite-extractor pixelize <stage> --out-size W:H --palette vinik24 --fit-mode exact`; verify every sidecar `scale_applied` is identical and uniform.
7. **Install.** `./run.sh --install-video <run-root> --action=<action-dir> --prefix=<pose-prefix> --frames=<pose-labels>` then `./run.sh --import`. The `<run-root>` is the directory passed to scale-masters/pixelize; `<action-dir>` is the subdirectory containing `masters/` and `pixelize/` (the installer reads both — pixel PNGs+sidecars AND master sidecars); `<pose-prefix>` names the installed poses (`vi`, `vw`, `vl`, `vh`, `vp`); `<pose-labels>` are the per-frame name suffixes.
8. **Timeline + tests.** Write/update the clip JSON; update pose-name assertions in `WUGodot/tests/test_animation_clip_timeline.gd`; keep `STRIKE_POSE_BY_ID` satisfying the rule test for attacks.
9. **Gates + temporal review.** All gates green; `./run.sh --shot-action <STATE> <dir>` + `python3 tools/assemble_action_review.py <dir>`; inspect GIF (foot slide, flicker) and strip (phase readability, loop seams).
10. **✋ Gate 2.** Show the user the GIF + strip; they play the game. Commit only on their verdict, one commit per action.

**Gate 2 rejection = rollback protocol (mandatory).** Phases rewrite live files before approval, so "rejection doesn't block the next action" only holds if the action's pre-phase state is restored before moving on. Directory-wide `git restore` is forbidden — it could revert unrelated work sitting in the same dirs.

*Before the phase's first repo edit*, record the phase's tracked-file manifest:

```bash
# After the last commit preceding this phase, the worktree may carry unrelated
# changes. Snapshot exactly what THIS phase will touch (from the phase's task
# list — clip JSONs, hu.manifest.json, graph, specific test files, etc.):
printf '%s\n' \
  WUGodot/assets/animation_clips/<this phase's clips>.timeline.json \
  WUGodot/assets/animation_manifests/hu.manifest.json \
  WUGodot/tests/test_animation_clip_timeline.gd \
  > /tmp/wu-reanim/<action>/touched.txt
```

Keep `touched.txt` current if the phase edits a file not on the list. On rejection:

```bash
# 1. Restore ONLY the recorded list:
xargs git restore -- < /tmp/wu-reanim/<action>/touched.txt
# 2. Remove the installed (untracked) sprites for this phase's prefix:
rm WUGodot/assets/sprites/characters/hu/<prefix>_*.png{,.import}
# 3. Re-import + full gates to prove the pre-phase state is back:
./run.sh --import && ./run.sh --test 2>&1 | tail -3 && ./run.sh --anchor-sanity 2>&1 | tail -1
```

The generation run dir stays in `/tmp` (nothing rejected enters the repo); record the rejection + reason in `keyframes.manifest.json` under the action's `notes` (approved keyframes stay approved — usually the video or selection is what failed, and regeneration reuses them). Only after gates confirm restoration may the next action begin.

---

## Phase 1 — Guard anchor + idle

**Parameters:** action `idle`, state `IDLE`, pose prefix `vi`, loop, fixed_duration target ≈ 2.0s.

- [ ] **Step 1: Generate guard candidates** (the single most important approval of the project)

```bash
mkdir -p /tmp/wu-reanim/keyframes/guard/stance
# Adapt flags after `aiexp sprite-extractor rawgen --help`:
aiexp sprite-extractor rawgen --backend codex \
  --reference ~/GitReps/AIexp/experiments/video-animation-spike/runs/hu-refs-seq/masters/master_001.png \
  --prompt "side view, full body, young wuxia swordsman in deep blue robes, combat guard stance, sword DRAWN and held ready in front, empty scabbard visible at his hip, exaggerated confident wide stance, comical wild energy, clean white background" \
  --count 4 --out /tmp/wu-reanim/keyframes/guard/stance
```

- [ ] **Step 2: ✋ Gate 1 (guard)** — `python3 tools/build_keyframe_review.py /tmp/wu-reanim/keyframes && python3 -m http.server -d /tmp/wu-reanim/keyframes 8765`. STOP for user verdict. On approval: copy to `art/keyframes/hu/guard/stance.png`, update `keyframes.manifest.json`, commit.

- [ ] **Step 3: Generate the breath keyframe** — image-to-image from the approved guard: *"Edit the image: the swordsman inhales deeply, chest expands, shoulders rise slightly. Everything else stays unchanged."* 3 candidates → ✋ Gate 1 → `art/keyframes/hu/idle/breath.png`.

- [ ] **Step 4: Idle video**

```bash
aiexp sprite-extractor animate-video --output-dir /tmp/wu-reanim/idle-run --action idle \
  --motion "the swordsman stands in his guard stance breathing calmly, weight shifting subtly, sword held steady, then returns exactly to the starting pose" \
  --reference-seq art/keyframes/hu/guard/stance.png \
  --reference-seq art/keyframes/hu/idle/breath.png \
  --reference-seq art/keyframes/hu/guard/stance.png
```

Verify `contact_sheet.png`: static camera, loop closure visible.

- [ ] **Step 5: Select ~16 frames across one breath cycle** (loops need fewer than attacks; selection by pose progress, first≈last). Stage + scale + pixelize per Runbook 5–6 (staged selected frames + sidecars in label order; use the printed out-size).

- [ ] **Step 6: Install** — `./run.sh --install-video /tmp/wu-reanim/idle-pix --action=idle --prefix=vi --frames=<selected labels>` (where `/tmp/wu-reanim/idle-pix` is the scale/pixelize run root containing `idle/masters/` and `idle/pixelize/`), then `./run.sh --import`.

- [ ] **Step 7: Rewrite `WUGodot/assets/animation_clips/idle.timeline.json`**: keyposes = the 16 `vi_` poses evenly over the cycle, `"duration": 2.0`, **delete the offsetX/scaleY/rotation tracks** (drawn breathing replaces synthetic sway — same rule as the light attack), no `useFighterOffset`. Update the idle assertions in `test_animation_clip_timeline.gd` (it currently asserts `breath` pose and `scaleY` track — change to first/mid `vi_` poses and absent-track default).

- [ ] **Step 8: Gates + temporal review**: all gates; `./run.sh --shot-action IDLE /tmp/wu-rev-idle && python3 tools/assemble_action_review.py /tmp/wu-rev-idle`; GIF must show two seamless cycles.

- [ ] **Step 9: ✋ Gate 2** — STOP for user feel test. On approval commit `art: idle from video frames (vi_ poses, guard anchor established)`.

## Phase 2 — Walk

**Parameters:** action `walk`, state `WALKING`, prefix `vw`, loop, velocity rate_mode (already set on the walk clip — preserve it).

- [ ] **Step 1: Keyframes** — contact-A / passing / contact-B, image-to-image from approved guard (*"Edit the image: the swordsman mid-stride, left foot planted forward, right foot pushing off behind, sword still held ready..."* etc.). ✋ Gate 1.
- [ ] **Step 2: Video** — `--reference-seq contactA passing contactB contactA`, motion: *"the swordsman walks forward with confident bouncy strides, side view, sword held ready, cyclic walking motion"*.
- [ ] **Step 3: Select ~12 frames** over one stride cycle; first≈last. Stage/normalize/pixelize per Runbook 5–6, then `./run.sh --install-video /tmp/wu-reanim/walk-pix --action=walk --prefix=vw --frames=<selected labels>`.
- [ ] **Step 4: Rewrite `walk.timeline.json`** — keyposes only + keep `"rate": "velocity"`; drop offsetY/rotation bob tracks (drawn now). Update walk assertions in `test_animation_clip_timeline.gd` (currently checks offsetY/rotation tracks exist — invert to keyposes + rate check).
- [ ] **Step 5: Gates; `--shot-action WALKING`; check FOOT SLIDE specifically** (velocity rate vs drawn stride length — if feet slide at walk speed, adjust the clip `duration` so stride matches `move_speed`; show the math in the report).
- [ ] **Step 6: ✋ Gate 2 → commit.**

## Phase 3 — Light attack (guard-start regeneration)

**Parameters:** action `light`, state `ATTACKING_LIGHT`, prefix `vl` (NOT `va` — the iaido version stays installed and live until Gate 2 passes), attack def `hu_light` (windup 0.36 / active 0.60 normalized).

- [ ] **Step 1: Keyframes** — coil (*"Edit the image: the swordsman coils low, twisting back, sword pulled far behind him, ready to explode forward. Everything else stays unchanged."*) and full-thrust (from the current `va_053` look but guard-consistent grip). Guard itself is already approved. ✋ Gate 1.
- [ ] **Step 2: Video** — `--reference-seq guard coil thrust guard`, motion: *"ready guard stance with sword drawn, deep coiled windup pulling the sword back, explosive full forward thrust with the blade extended, then back to the ready guard stance"* (the aiexp-validated storyboard).
- [ ] **Step 3: Select ~30 frames** matching the proven density: windup ≈11 (1:1 at 60fps), thrust + extension ≈6, recovery ≈12. Stage/normalize/pixelize per Runbook 5–6, then `./run.sh --install-video /tmp/wu-reanim/light-pix --action=light --prefix=vl --frames=<selected labels>`.
- [ ] **Step 4: Rewrite `hu_attack_light.timeline.json`** keyposes to the `vl_` set (markers `windup_end`/`active_end`, smear track 0.36/0.42/0.66 kept, no offsetX). Update `test_animation_clip_timeline.gd` light assertions and the `CASES` expectation flow in `test_strike_pose_rule.gd` (mapping must move to the new max-extension `vl_` pose in `STRIKE_POSE_BY_ID`).
- [ ] **Step 5: Gates incl. `--probe-reach`** (tip distance changes ⇒ confirm reach-consistency tests; re-sync if needed per Task 3 Step 4).
- [ ] **Step 6: `--shot-action ATTACKING_LIGHT`; ✋ Gate 2** — user compares against the iaido version. On approval: delete the `va_*` poses/PNGs (remove `va_` keys + files mirroring the installer's cleanup block — `--frames=` empty is invalid), commit. On rejection: run the Runbook rollback protocol (restores the `va_` timeline + manifest from git, removes the `vl_*` untracked sprites, gates prove the iaido version is fully live again), record the verdict in the spec, continue to Phase 4.

## Phase 4 — Heavy attack (+ reach re-sync)

**Parameters:** action `heavy`, state `ATTACKING_HEAVY`, prefix `vh`, def `hu_heavy`.

- [ ] **Step 1: Keyframes** — windup (*massive exaggerated wind-up, sword raised far overhead/behind, body twisted, comically telegraphed*), strike (*devastating forward cleave/lunge, blade fully extended*), recover. ✋ Gate 1.
- [ ] **Step 2: Video** — `--reference-seq guard windup strike recover guard`, 4s. If pacing bunches the strike late, fall back to bracket-chain per phase (report §Step 3) with `--start-frame/--end-frame` pairs.
- [ ] **Step 3: Select ~30 frames** weighted to the windup (heavy's identity is the telegraph); install `vh_*`.
- [ ] **Step 4: Rewrite `hu_attack_heavy.timeline.json`** — keyposes + markers + smear only; DELETE the legacy offsetX/scaleX windup transforms (this completes the motion-study transform rollback). Update heavy assertions in `test_animation_clip_timeline.gd` (currently checks `heavy_windup`/`heavy_strike` poses and offsetX>33 — rewrite for `vh_` poses and no-transform expectations). Add `hu_heavy` to `test_strike_pose_rule.gd` CASES; update `STRIKE_POSE_BY_ID` to the max-extension `vh_` pose.
- [ ] **Step 5: Reach re-sync** — `./run.sh --probe-reach`; heavy's authored capsule now derives from the new pose; if effective reach drifts from `range_units` 340 / c2c 362 band, re-sync and document numbers.
- [ ] **Step 6: Gates; `--shot-action ATTACKING_HEAVY`; ✋ Gate 2 → commit** (includes removing now-unused `heavy_0..3` legacy frames if the AnimationSet no longer references them — verify with grep first).

## Phase 5 — Held poses batch + presenter migration

**Parameters:** 9 stills, no video. States: BLOCKING, HIT_REACTION, STUNNED, DASHING, JUMPING, FALLING, LANDING.

- [ ] **Step 1: Generate all 9 keyframes** (image-to-image from approved guard; one batch, one review page):
  hit recoil (*huge comical recoil, head snapped back, feet nearly leaving the ground*), stunned ×2 (*wobbling dazed, eyes spiraling* / slight variant for ping-pong), block brace (*compact braced stance, sword held defensively across the body*), dash lunge (*low horizontal blur-lunge, body stretched forward*), jump rise / peak / fall (*crouched launch with knees up* / *airborne spread* / *descending, blade trailing*), land crouch. ✋ Gate 1 (one session, 9 verdicts).
- [ ] **Step 2: Normalize + pixelize + install** the approved stills as single-frame "actions" (each goes through the same scale/pixelize run, prefix `vp`, e.g. `vp_hit`, `vp_stun_a`, `vp_stun_b`, `vp_block`, `vp_dash`, `vp_rise`, `vp_peak`, `vp_fall`, `vp_land`). The installer's `--frames` list here is the slot names — extend the tool if its `pixel_%03d` input convention doesn't fit single stills (acceptable: stage each still as a 1-frame action dir).
- [ ] **Step 3: Create the held-state clips** (each a tiny timeline JSON in `WUGodot/assets/animation_clips/`):

`held_hit.timeline.json` (pattern for all single-pose clips):
```json
{
  "id": "held_hit",
  "duration": 0.3,
  "useFighterOffset": true,
  "keyposes": [ { "t": 0.0, "pose": "vp_hit" } ]
}
```
`held_stunned.timeline.json` (ping-pong pair):
```json
{
  "id": "held_stunned",
  "duration": 0.5,
  "useFighterOffset": true,
  "keyposes": [
    { "t": 0.0, "pose": "vp_stun_a" },
    { "t": 0.5, "pose": "vp_stun_b" }
  ]
}
```
plus `held_block` (0.4, vp_block), `held_dash` (0.2, vp_dash), `held_jump` (0.3, vp_rise), `held_fall` (0.3, vp_fall), `held_land` (0.2, vp_land). (JUMPING uses rise; peak appears via FALLING entry if desired later — YAGNI for v1.)

- [ ] **Step 4: Graph + state resolution.** Add to `WUGodot/assets/animation_graphs/humanoid.graph.json` `states`:

```json
    "BLOCKING":     { "clip": "held_block",   "enter": { "mode": "snap", "time": 0.0 }, "priority": 3 },
    "HIT_REACTION": { "clip": "held_hit",     "enter": { "mode": "snap", "time": 0.0 }, "priority": 7 },
    "STUNNED":      { "clip": "held_stunned", "enter": { "mode": "dither", "time": 0.06 }, "priority": 7 },
    "DASHING":      { "clip": "held_dash",    "enter": { "mode": "snap", "time": 0.0 }, "priority": 4 },
    "JUMPING":      { "clip": "held_jump",    "enter": { "mode": "dither", "time": 0.06 }, "priority": 2 },
    "FALLING":      { "clip": "held_fall",    "enter": { "mode": "dither", "time": 0.06 }, "priority": 2 },
    "LANDING":      { "clip": "held_land",    "enter": { "mode": "snap", "time": 0.0 }, "priority": 2 }
```

Extend `combat_scene._resolve_player_state_name()` (`combat_scene.gd:522`) with the seven new `Fighter.AnimationState` → name cases, and register the new clip paths where the presenter is configured (find with `grep -n "configure(" WUGodot/scripts/combat_scene.gd`).

- [ ] **Step 5: Tests.** Extend `test_presenter_offset.gd` with one assertion: `TimelineScript.load_from_file("res://assets/animation_clips/held_hit.timeline.json").use_fighter_offset == true`. Run all gates.

- [ ] **Step 6: Temporal review** — `--shot-action` for HIT_REACTION, STUNNED, BLOCKING, DASHING, JUMPING: the GIFs must show the procedural shake/wobble/bob/arc moving the held pose (this is the §5a parity payoff visible). ✋ Gate 2 → commit.

## Phase 6 — Entry draw + legacy retirement

- [ ] **Step 1: Keyframes** — sheathed-idle still + mid-draw still (✋ Gate 1); video `--reference-seq sheathed mid-draw guard`, motion: *"the swordsman stands relaxed with sword sheathed, then draws it in one fluid iaido motion into his ready guard stance"*.
- [ ] **Step 2: Wire as combat-entry flourish** — explicit routing contract (review finding): `COMBAT_ENTRY` is a **scene-local presenter override, NOT a `Fighter.AnimationState`** (the fighter enum and combat truth know nothing about it). Implementation:
  - `humanoid.graph.json` gains a `"COMBAT_ENTRY": { "clip": "entry_draw", "enter": { "mode": "snap", "time": 0.0 } }` state — graph state names are arbitrary strings; `handles_state` works without any enum.
  - `combat_scene.gd` gains `var _entry_timer: float = 0.0`, set to the clip's fixed duration in `on_enter()`. While `_entry_timer > 0`, `_update_player_presenter` passes `"COMBAT_ENTRY"` instead of `_resolve_player_state_name()`, and `_process` decrements the timer and suppresses player input (reuse the `input_active` gating pattern).
  - **Skippable:** any player input while `_entry_timer > 0` zeroes the timer (cancel into IDLE via the normal state resolution).
  - `_resolve_player_state_name()` itself is untouched.
- [ ] **Step 3: ✋ Gate 2 → commit.**
- [ ] **Step 4: Retirement audit.** Only after every state above passed Gate 2:

```bash
grep -rn "character_hu.json" WUGodot/ --include="*.gd" --include="*.json" | grep -v ".import"
```

For each hit, confirm the Hu render path no longer reaches it (enemy archetypes keep their own sets). Switch Hu's visual profile off the AnimationSet (in `WUGodot/data/VisualProfiles/DefaultProfiles.json`), delete `WUGodot/assets/animations/character_hu.json` and orphaned legacy sprite frames (verify each with grep before deleting). Full gates + one final `--shot-combat` strip across all 15 states. Commit `refactor(art): retire legacy Hu animation set`.

---

## Verification Summary (every phase)

| gate | command | pass condition |
|---|---|---|
| tests | `./run.sh --test 2>&1 \| tail -3` | `failed: 0` |
| import | `./run.sh --import 2>&1 \| grep -ciE "^ERROR\|SCRIPT ERROR"` | `0` |
| anchors | `./run.sh --anchor-sanity 2>&1 \| tail -1` | `ANCHOR SANITY: OK` |
| reach (attacks) | `./run.sh --probe-reach` | within balance band, or documented re-sync |
| temporal | `--shot-action` + `assemble_action_review.py` | no foot slide / flicker / loop seams in GIF+strip |
| Gate 1 | review page | user verdict per slot, recorded in keyframes.manifest.json |
| Gate 2 | in-game + GIF | user verdict, then commit |

## Execution Notes

- **Order is load-bearing**: Phase 0 entirely before any generation; within Phases 1–6, an action's Gate 2 failure never blocks the next action (record verdict, move on, return later).
- **Cost ledger**: maintain `art/keyframes/cost.md` — one line per paid run (`date, action, mode, $`). Expected total < $5.
- **aiexp CLI drift**: before the first generation step, capture `aiexp sprite-extractor rawgen --help` and `animate-video --help` output into the task log and adapt flag spellings; the report guarantees capabilities, not exact flag names sketched here.
- **What this plan does NOT do**: change `Attacks.json` timings, touch enemy archetypes, add audio, build the SF6 box viewer (parked plans).
