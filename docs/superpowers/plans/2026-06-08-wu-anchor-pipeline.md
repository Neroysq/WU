# WU Anchor Pipeline — Measure Real Per-Pose Anchors (Rev 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder anchor constants in `hu.manifest.json` with values **measured from the actual sprites** (robust to thin blades and stray specks), so Hu's feet stop floating (Track A). Then, per the approved reach decision, make the authored hitbox **match the visible blade**: derive each attack's reach from the art, write it into `range_units` so every system agrees, re-tune enemy spacing for fairness, and enable authored player hitboxes.

**Architecture:** A pure, headless-testable `AnchorMeasure` (`RefCounted`) isolates the character via **largest connected component** (drops specks), derives the **body box from tall columns** (excludes the thin blade) for `hurtbox`/`chestAnchor` and stable `footAnchor.x`, takes `footAnchor.y` from the lowest silhouette row for grounding, and takes `weaponTip` from the full silhouette's forward extent. A thin headless writer regenerates the manifest. A **real-asset sanity probe** with reject criteria runs **before** the manifest is committed. `range_units` for `hu_light`/`hu_heavy` is set from the geometry-derived reach so the scalar fallback, AI spacing, and telegraph stay consistent. The Track B flag is flipped only after light **and** heavy pass the reach-consistency check.

**Tech Stack:** Godot 4.6.2, GDScript (typed), `Image` pixel access, JSON, headless runner (`./run.sh --test`).

**Scope:** Hu only (the seven manifest poses). **Out of scope (follow-ups):** enemy manifests/anchors, generator-side metadata (aiexp `--ask-metadata`), and turning `chestAnchor`/`weaponTip` into exact rigged points (heuristics + hand-verify here).

> **Review fixes folded in (round 1):** the sanity probe now validates the **stored** manifest anchors (not just re-measures PNGs) with a stored-vs-measured drift check + override allowlist (Task 4); `range_units` convention pinned to `derived_reach − 22` with a matching consistency test (Task 6); the new test is registered in **Task 1** so it runs from the first `./run.sh --test`; `derived_reach` gets a **facing-left** assert (Task 2); Task 8 wording corrected (enemy geometry path stays off; scalar tuning is intentional).
>
> **Review fixes folded in (round 2):** Task 6 now fixes the existing **dormancy assertion** (was a hardcoded 160px that flips to a hit once `range_units` grows) by making the miss distance `range_units`-relative; Task 6 is explicitly marked a **temporary unbalanced intermediate** with Tasks 6–8 landing as one unit; the sanity ceiling is reframed as a **coarse tip-distance guard** (it omits the template radius/endpoint — the exact reach is gated by Task 6, not the probe).
>
> **Review fixes folded in (round 3):** `footAnchor.x` is measured from the stable body-box center, not the lowest opaque row center, because the lowest row swaps between lead/rear feet and creates horizontal lurch. `footAnchor.y` still uses the lowest silhouette row for grounding. The sanity probe now rejects excessive stored `footAnchor.x` spread so this regression cannot pass headless again. `range_units` is recomputed after the body-center anchor change.
>
> **Review fixes folded in (round 4):** Task 8's original manual entry path is not automatable in this environment because synthetic key events do not reach Godot's `Input.is_key_pressed`, while `--script` bypasses autoloads. The plan now uses a dev-only normal-launch capture hook (`./run.sh --shot-combat [dir]`) that boots directly into combat, forces idle/walk/windup/active states, saves screenshots, and quits.
>
> **Review fixes folded in (round 5):** the first capture showed the active hitbox firing while the presenter still held the windup pose. `hu_attack_light.timeline.json` now binds `strike_extended` to `"windup_end"` instead of hardcoded `0.55`; `AnimationClipTimeline.pose_at()` resolves symbolic keypose times against the current `AttackDefinition`, and the test suite asserts `strike_extended` is visible at `hu_light` active start.

---

## Corrected diagnosis (evidence from a connected-component probe on the real PNGs)

The earlier "disconnected opaque artifact bands / background strips" theory is **not** what's happening. Measured:

| pose | opaque px | edge px | components | naive bbox R | largest-CC bbox R |
|---|---:|---:|---:|---:|---:|
| guard | 7378 | 0 | 3 | 118 | 177 (99% one blob) |
| strike_extended | 6205 | **0** | 2 | 131 | **247** (100% one blob) |
| recover | 5853 | 0 | 3 | 120 | 175 |

- **No edge artifacts** (`edge=0`); the character is a single connected blob (99–100% of opaque), with ≤1% in tiny specks.
- `strike_extended`'s blade genuinely reaches **x=247/256** — the combat-feel pass deliberately extended the strikes. The ~2× reach is **faithful to the art**, not a measurement bug. → handled by the approved "match the blade" decision (set `range_units` from geometry + retune enemies).
- Foot rows differ per pose (guard bottom=209, strike bottom=174): the source frames carry **camera/scale drift** (aiexp Problems 1–2). Use per-pose `footAnchor.y` to ground each frame, but use body-center `footAnchor.x` to avoid visible sideways lurch when the lowest row changes from lead foot to rear foot.

So the corrections are: isolate the **body** with column thresholds (not row extents) + connected components; take `weaponTip` from the real forward extent; **gate** on a real-asset sanity probe before committing; and treat the long reach as intended.

---

## File Structure

**New (headless-testable `RefCounted`):**
- `WUGodot/scripts/visual/anchor_measure.gd` — connected-component character isolation + column-based body box + silhouette tip.

**New (headless tools):**
- `WUGodot/tools/measure_anchors.gd` — rewrite `hu.manifest.json` from measurements.
- `WUGodot/tools/anchor_sanity.gd` — real-asset reject-criteria probe + suggested `range_units`.

**New (test):**
- `WUGodot/tests/test_anchor_measure.gd`

**Modified:**
- `WUGodot/scripts/visual/presentation_collision.gd` — add correct `derived_reach()`.
- `WUGodot/assets/animation_manifests/hu.manifest.json` — regenerated (committed only after Task 5 gates pass).
- `WUGodot/scripts/attack_catalog.gd` — set `hu_light`/`hu_heavy` `range_units` from derived reach.
- `WUGodot/tests/test_animation_manifest.gd` — drop exact placeholder anchor/hurtbox asserts; use type/range/non-placeholder checks (required correction #1).
- `WUGodot/tests/test_presentation_collision.gd` — reach-consistency asserts for light **and** heavy.
- `WUGodot/scripts/combat_scene.gd` — flip `ENABLE_AUTHORED_PLAYER_HITBOXES` to `true`.
- `WUGodot/scripts/main.gd` — dev-only `--shot-combat` capture hook for Task 8 visual verification.
- `WUGodot/assets/animation_clips/hu_attack_light.timeline.json` — bind strike pose to the active-window start (`"windup_end"`).
- `WUGodot/scripts/visual/animation_clip_timeline.gd` and `WUGodot/scripts/visual/fighter_presenter.gd` — resolve symbolic keypose times against the current attack definition.
- `WUGodot/tests/test_animation_clip_timeline.gd` — regression coverage for strike pose at active start.
- `WUGodot/tests/run_tests.gd` — register `test_anchor_measure.gd`.
- `run.sh` — add `--measure-anchors` and `--anchor-sanity` cases.

---

## Task 1: AnchorMeasure (CC isolation + column body box)

**Files:**
- Create: `WUGodot/scripts/visual/anchor_measure.gd`
- Test: `WUGodot/tests/test_anchor_measure.gd`

- [ ] **Step 1: Write the failing test**

Synthetic figure: a 50-wide, 160-tall body block, a **3px-thick blade** extending right (must be excluded from the body box but define the tip), and two 1px specks that must be dropped.

Create `WUGodot/tests/test_anchor_measure.gd`:

```gdscript
extends RefCounted

const AnchorMeasureScript = preload("res://scripts/visual/anchor_measure.gd")

func _make_image() -> Image:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var solid := Color(1, 1, 1, 1)
	for y in range(40, 200):          # body: cols 100..149, rows 40..199
		for x in range(100, 150):
			img.set_pixel(x, y, solid)
	for y in range(119, 122):         # blade: 3px thick, cols 150..209 (connects to body)
		for x in range(150, 210):
			img.set_pixel(x, y, solid)
	img.set_pixel(0, 255, solid)      # speck (disconnected) -> dropped
	img.set_pixel(255, 5, solid)      # speck (disconnected) -> dropped
	return img

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	var m: Dictionary = AnchorMeasureScript.measure(_make_image())

	var foot: Vector2 = m["footAnchor"]
	if foot.y == 199 and absf(foot.x - 124.5) <= 2.0:
		passed += 1
	else:
		failed += 1; failures.append("footAnchor should be body bottom-center, got %s" % str(foot))

	# Body box EXCLUDES the thin blade: right edge stays near 149, width ~50.
	var hb: Rect2 = m["hurtbox"]
	if hb.position.x + hb.size.x <= 152.0 and hb.size.x >= 40.0 and hb.size.x <= 60.0:
		passed += 1
	else:
		failed += 1; failures.append("hurtbox must exclude the blade (got %s)" % str(hb))

	# weaponTip uses the full silhouette forward extent (the blade end ~209), not the speck (255).
	var tip: Vector2 = m["weaponTip"]
	if tip.x == 209 and absf(tip.y - 120.0) <= 2.0:
		passed += 1
	else:
		failed += 1; failures.append("weaponTip should be the blade end, not a speck (got %s)" % str(tip))

	var chest: Vector2 = m["chestAnchor"]
	if chest.x >= 100 and chest.x <= 150 and chest.y > 40 and chest.y < 199:
		passed += 1
	else:
		failed += 1; failures.append("chestAnchor should sit in the body (got %s)" % str(chest))

	# Fully transparent image returns safe defaults (no crash).
	var empty := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	empty.fill(Color(0, 0, 0, 0))
	if AnchorMeasureScript.measure(empty).has("footAnchor"):
		passed += 1
	else:
		failed += 1; failures.append("empty image should still return a footAnchor")

	return {"passed": passed, "failed": failed, "failures": failures}
```

Register it now (so every later `./run.sh --test` actually runs it). Add to `_TEST_MODULES` in `WUGodot/tests/run_tests.gd`:

```gdscript
	"res://tests/test_anchor_measure.gd",
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — preload of missing `anchor_measure.gd` (the module is registered but the script does not exist yet).

- [ ] **Step 3: Write minimal implementation**

Create `WUGodot/scripts/visual/anchor_measure.gd`:

```gdscript
class_name AnchorMeasure
extends RefCounted

const ALPHA_MIN: float = 0.05
const TIP_MIN_RUN: int = 2          # a column needs this many opaque px to be a tip candidate

# Returns {footAnchor, weaponTip, chestAnchor, hurtbox(Rect2), bbox(Rect2)} in source px.
static func measure(img: Image) -> Dictionary:
	var w: int = img.get_width()
	var h: int = img.get_height()

	# Opaque mask.
	var op := PackedByteArray(); op.resize(w * h)
	for y in range(h):
		for x in range(w):
			op[y * w + x] = 1 if img.get_pixel(x, y).a > ALPHA_MIN else 0

	# Largest connected component (4-connectivity), iterative stack.
	var lbl := PackedInt32Array(); lbl.resize(w * h); lbl.fill(-1)
	var best_pixels := PackedInt32Array()
	var cur := 0
	for s in range(w * h):
		if op[s] == 1 and lbl[s] == -1:
			var stack := [s]
			var pixels := PackedInt32Array()
			lbl[s] = cur
			while not stack.is_empty():
				var p: int = stack.pop_back()
				pixels.append(p)
				var px: int = p % w
				var py: int = p / w
				for d: Array in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var nx: int = px + d[0]
					var ny: int = py + d[1]
					if nx >= 0 and nx < w and ny >= 0 and ny < h:
						var np: int = ny * w + nx
						if op[np] == 1 and lbl[np] == -1:
							lbl[np] = cur
							stack.append(np)
			if pixels.size() > best_pixels.size():
				best_pixels = pixels
			cur += 1

	if best_pixels.is_empty():
		var cx := float(w) * 0.5
		return {
			"footAnchor": Vector2(cx, float(h - 1)), "weaponTip": Vector2(cx, float(h) * 0.5),
			"chestAnchor": Vector2(cx, float(h) * 0.5), "hurtbox": Rect2(cx - 1, float(h) * 0.5, 2, 2),
			"bbox": Rect2(cx - 1, float(h) * 0.5, 2, 2),
		}

	# Component column counts + vertical spans, and full silhouette bbox.
	var col_count := PackedInt32Array(); col_count.resize(w)
	var col_top := PackedInt32Array(); col_top.resize(w); col_top.fill(-1)
	var col_bot := PackedInt32Array(); col_bot.resize(w); col_bot.fill(-1)
	var sil_left := w; var sil_right := -1; var sil_top := h; var sil_bot := -1
	for p in best_pixels:
		var px: int = p % w
		var py: int = p / w
		col_count[px] += 1
		if col_top[px] < 0: col_top[px] = py
		col_bot[px] = py
		sil_left = mini(sil_left, px); sil_right = maxi(sil_right, px)
		sil_top = mini(sil_top, py); sil_bot = maxi(sil_bot, py)

	# Body box from TALL columns only (excludes the thin blade). Adaptive threshold.
	var comp_h: int = sil_bot - sil_top + 1
	var body_col_min: int = maxi(8, int(float(comp_h) * 0.25))
	var body_left := w; var body_right := -1; var body_top := h; var body_bot := -1
	for x in range(w):
		if col_count[x] >= body_col_min:
			body_left = mini(body_left, x); body_right = maxi(body_right, x)
			body_top = mini(body_top, col_top[x]); body_bot = maxi(body_bot, col_bot[x])
	if body_right < 0:  # degenerate (very flat pose): fall back to silhouette
		body_left = sil_left; body_right = sil_right; body_top = sil_top; body_bot = sil_bot

	# Foot: stable body-center X avoids lead/rear foot swaps; lowest silhouette Y grounds.
	var foot_y: int = sil_bot
	var foot_x: float = float(body_left + body_right) * 0.5

	# Weapon tip: rightmost silhouette column with a vertical run (drops 1px specks; specks
	# are already excluded because they are not in the largest component).
	var tip_x: int = sil_right
	var tip_y: float = float(body_top + body_bot) * 0.5
	for x in range(w - 1, -1, -1):
		if col_count[x] >= TIP_MIN_RUN:
			tip_x = x
			tip_y = float(col_top[x] + col_bot[x]) * 0.5
			break

	var chest_x: float = float(body_left + body_right) * 0.5
	var chest_y: float = float(body_top) + float(foot_y - body_top) * 0.45

	return {
		"footAnchor": Vector2(foot_x, float(foot_y)),
		"weaponTip": Vector2(float(tip_x), tip_y),
		"chestAnchor": Vector2(chest_x, chest_y),
		"hurtbox": Rect2(float(body_left), float(body_top), float(body_right - body_left), float(body_bot - body_top)),
		"bbox": Rect2(float(sil_left), float(sil_top), float(sil_right - sil_left), float(sil_bot - sil_top)),
	}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./run.sh --test`
Expected: PASS — `test_anchor_measure.gd` contributes 5 passed.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/visual/anchor_measure.gd WUGodot/tests/test_anchor_measure.gd WUGodot/tests/run_tests.gd
git commit -m "feat(anim): AnchorMeasure with connected-component body isolation"
```

---

## Task 2: Correct derived_reach() in PresentationCollision

Re-add the §3.6 cross-check that Track B deferred — now computed from the **actual world capsule extent + radius**, not `abs(tip.x - chest.x)`.

**Files:**
- Modify: `WUGodot/scripts/visual/presentation_collision.gd`
- Test: `WUGodot/tests/test_presentation_collision.gd`

- [ ] **Step 1: Write the failing assertion**

Append to `run_all()` in `test_presentation_collision.gd` (the registered `attacker` mid-active from earlier in that test already exists):

```gdscript
	# derived_reach == forward extent of the world capsule (incl. radius) from the attacker.
	var cap_dbg: Dictionary = pc.attack_capsule_world(attacker)
	var expected_reach: float = maxf((cap_dbg["a"] as Vector2).x, (cap_dbg["b"] as Vector2).x) + float(cap_dbg["r"]) - attacker.position.x
	var reach_right: float = pc.derived_reach(attacker)
	if absf(reach_right - expected_reach) <= 0.5:
		passed += 1
	else:
		failed += 1; failures.append("derived_reach should equal the world capsule forward extent (facing right)")

	# Facing-agnostic: a left-facing attacker yields the same reach magnitude.
	var atk_l: Variant = FighterScript.new()
	atk_l.position = Vector2(400, 900); atk_l.facing = -1
	atk_l._attack_state.start(AttackCatalogScript.hu_light())
	atk_l._attack_state.advance(AttackCatalogScript.hu_light().windup_end + 0.01)
	pc.register_fighter(atk_l, "hu")
	if absf(pc.derived_reach(atk_l) - reach_right) <= 0.5:
		passed += 1
	else:
		failed += 1; failures.append("derived_reach should be facing-agnostic (left == right magnitude)")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — `derived_reach` not defined.

- [ ] **Step 3: Implement**

In `presentation_collision.gd`, add:

```gdscript
# Forward reach (px from the attacker origin) of the authored capsule, radius included.
# Facing-agnostic magnitude, for setting/validating range_units (synthesis §3.6).
func derived_reach(fighter: Variant) -> float:
	var cap: Dictionary = attack_capsule_world(fighter)
	if cap.is_empty():
		return 0.0
	var forward: float = maxf((cap["a"] as Vector2).x, (cap["b"] as Vector2).x) - fighter.position.x
	# When facing left the capsule extends to -x; take magnitude.
	var back: float = fighter.position.x - minf((cap["a"] as Vector2).x, (cap["b"] as Vector2).x)
	return maxf(forward, back) + float(cap["r"])
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./run.sh --test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/visual/presentation_collision.gd WUGodot/tests/test_presentation_collision.gd
git commit -m "feat(collision): correct derived_reach from world capsule extent"
```

---

## Task 3: Writer tool (commit the TOOL only)

**Files:**
- Create: `WUGodot/tools/measure_anchors.gd`
- Modify: `run.sh`

- [ ] **Step 1: Write the writer**

Create `WUGodot/tools/measure_anchors.gd` (same as Rev 1: load manifest, measure each pose, overwrite `footAnchor`/`weaponTip`/`chestAnchor`/`hurtbox`, preserve `weaponClass`/`id`/`renderScale`/`sourceCanvas`/`path`):

```gdscript
extends SceneTree

const AnchorMeasureScript = preload("res://scripts/visual/anchor_measure.gd")
const MANIFEST_PATH := "res://assets/animation_manifests/hu.manifest.json"

func _init() -> void:
	var root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
	var poses: Dictionary = root.get("poses", {}) as Dictionary
	for pose_name in poses.keys():
		var pose: Dictionary = poses[pose_name] as Dictionary
		var tex: Texture2D = load(str(pose.get("path", ""))) as Texture2D
		if tex == null:
			print("SKIP %s" % pose_name); continue
		var img: Image = tex.get_image()
		if img.is_compressed(): img.decompress()
		var m: Dictionary = AnchorMeasureScript.measure(img)
		pose["footAnchor"] = _iv(m["footAnchor"])
		pose["weaponTip"] = _iv(m["weaponTip"])
		pose["chestAnchor"] = _iv(m["chestAnchor"])
		var hb: Rect2 = m["hurtbox"]
		pose["hurtbox"] = [int(round(hb.position.x)), int(round(hb.position.y)), int(round(hb.size.x)), int(round(hb.size.y))]
		poses[pose_name] = pose
		print("%-18s foot=%s tip=%s" % [pose_name, str(pose["footAnchor"]), str(pose["weaponTip"])])
	root["poses"] = poses
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(root, "  ")); f.close()
	print("WROTE %s" % MANIFEST_PATH)
	quit()

func _iv(v: Vector2) -> Array:
	return [int(round(v.x)), int(round(v.y))]
```

- [ ] **Step 2: Add run.sh cases**

In `run.sh`, before the `--editor` case:

```bash
    --measure-anchors)
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://tools/measure_anchors.gd ;;
    --anchor-sanity)
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://tools/anchor_sanity.gd ;;
```

- [ ] **Step 3: Commit the tool (NOT the manifest yet)**

```bash
git add WUGodot/tools/measure_anchors.gd run.sh
git commit -m "feat(anim): manifest anchor writer tool"
```

---

## Task 4: Real-asset sanity probe with reject criteria

Validates the **stored manifest anchors** (the data actually consumed by Track A/B) and **fails** before the manifest is committed. It (a) checks the stored values against absolute reject criteria, and (b) compares stored vs freshly-measured anchors so a stale or hand-broken manifest is caught — unless the pose is in an explicit override allowlist for intentional hand-tuning. "Match the blade" means a far tip is OK; the rejects are about *broken* values and a coarse tip-distance guard (the exact gameplay reach is gated by Task 6's consistency test, not here).

**Files:**
- Create: `WUGodot/tools/anchor_sanity.gd`

- [ ] **Step 1: Write the probe**

Create `WUGodot/tools/anchor_sanity.gd`:

```gdscript
extends SceneTree

const AnchorMeasureScript = preload("res://scripts/visual/anchor_measure.gd")
const MANIFEST_PATH := "res://assets/animation_manifests/hu.manifest.json"
const CANVAS := 256
const TIP_DISTANCE_CEILING_WORLD := 300.0  # COARSE guard: |tip.x-foot.x|*scale. NOT the exact hit
                                           # reach (excludes template start-bias + radius). The exact
                                           # gameplay reach is gated by Task 6's consistency test.
const ANCHOR_TOLERANCE := 12.0        # stored-vs-measured px before flagging drift
const FOOT_X_SPREAD_CEILING := 24.0   # body-center X should stay stable across Hu poses
# Poses whose stored anchors were intentionally hand-tuned away from the measurement.
const OVERRIDE_ALLOWLIST := {}        # e.g. {"strike_extended": true}

func _init() -> void:
	var root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
	var scale: float = float(root.get("renderScale", 1.0))
	var poses: Dictionary = root.get("poses", {}) as Dictionary
	var fails: Array[String] = []
	var min_foot_x: float = INF
	var max_foot_x: float = -INF
	for pose_name in poses.keys():
		var pose: Dictionary = poses[pose_name] as Dictionary
		var foot: Vector2 = _v(pose.get("footAnchor"))
		var tip: Vector2 = _v(pose.get("weaponTip"))
		var hb: Rect2 = _r(pose.get("hurtbox"))

		# (a) Absolute reject criteria on the STORED values.
		if foot.y < float(CANVAS) * 0.4:
			fails.append("%s: stored foot too high (y=%.0f)" % [pose_name, foot.y])
		if hb.size.x < 8.0 or hb.size.y < 30.0:
			fails.append("%s: stored body box degenerate (%s)" % [pose_name, str(hb.size)])
		if hb.size.x > float(CANVAS) * 0.85:
			fails.append("%s: stored body box too wide (%.0f) -> blade not excluded" % [pose_name, hb.size.x])
		var tip_dist_world: float = absf(tip.x - foot.x) * scale
		if tip_dist_world > TIP_DISTANCE_CEILING_WORLD:
			fails.append("%s: tip-distance %.0f world-px beyond coarse ceiling %.0f" % [pose_name, tip_dist_world, TIP_DISTANCE_CEILING_WORLD])
		min_foot_x = minf(min_foot_x, foot.x)
		max_foot_x = maxf(max_foot_x, foot.x)

		# (b) Stored vs measured (unless intentionally overridden).
		if not OVERRIDE_ALLOWLIST.has(pose_name):
			var tex: Texture2D = load(str(pose.get("path", ""))) as Texture2D
			if tex == null:
				fails.append("%s: no texture" % pose_name); continue
			var img: Image = tex.get_image()
			if img.is_compressed(): img.decompress()
			var m: Dictionary = AnchorMeasureScript.measure(img)
			if foot.distance_to(m["footAnchor"]) > ANCHOR_TOLERANCE or tip.distance_to(m["weaponTip"]) > ANCHOR_TOLERANCE:
				fails.append("%s: stored anchors drift from measured (foot %s vs %s, tip %s vs %s) - regenerate or allowlist" % [pose_name, str(foot), str(m["footAnchor"]), str(tip), str(m["weaponTip"])])

	var foot_x_spread: float = max_foot_x - min_foot_x
	if foot_x_spread > FOOT_X_SPREAD_CEILING:
		fails.append("stored footAnchor.x spread %.0f exceeds ceiling %.0f; use body-center foot X to avoid presenter lurch" % [foot_x_spread, FOOT_X_SPREAD_CEILING])

	if fails.is_empty():
		print("ANCHOR SANITY: OK"); quit(0)
	else:
		for fail in fails: print("ANCHOR SANITY FAIL: %s" % fail)
		quit(1)

func _v(raw: Variant) -> Vector2:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO

func _r(raw: Variant) -> Rect2:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 4:
		return Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
	return Rect2()
```

- [ ] **Step 2: Run it against the CURRENT placeholder manifest**

Run: `./run.sh --anchor-sanity`
Expected: **FAIL** — the placeholder anchors drift from measured (uniform `footAnchor=[128,238]` and `weaponTip` don't match the real silhouettes), proving the gate reads the stored data. This is the gate the next task must turn green by regenerating.

- [ ] **Step 3: Commit the probe**

```bash
git add WUGodot/tools/anchor_sanity.gd
git commit -m "feat(anim): anchor sanity probe with reject criteria"
```

---

## Task 5: Regenerate manifest, fix the manifest test, gate, THEN commit the manifest

**Files:**
- Modify: `WUGodot/assets/animation_manifests/hu.manifest.json` (generated)
- Modify: `WUGodot/tests/test_animation_manifest.gd`

- [ ] **Step 1: Fix `test_animation_manifest.gd` (required correction #1)**

The existing test asserts the exact placeholder anchors (`[128,238]`/`[218,134]`) and the old hurtbox — those become wrong after regeneration. Replace the value-exact asserts with type/range/non-placeholder checks. Find the `strike_extended` and hurtbox assertions and replace with:

```gdscript
	var pose: Dictionary = manifest.get_pose("strike_extended")
	var foot: Vector2 = pose.get("footAnchor", Vector2.ZERO) as Vector2
	var tip: Vector2 = pose.get("weaponTip", Vector2.ZERO) as Vector2
	# Real measured anchors: inside the canvas, tip ahead of the foot, not the old placeholders.
	if foot.x > 0 and foot.x < 256 and foot.y > 100 and foot.y < 256 and tip.x > foot.x and not (foot == Vector2(128, 238)):
		passed += 1
	else:
		failed += 1
		failures.append("strike_extended anchors should be measured, not placeholder (got foot %s tip %s)" % [str(foot), str(tip)])

	var hb: Variant = manifest.get_hurtbox("guard")
	if hb != null and (hb as Rect2).size.x >= 8.0 and (hb as Rect2).size.y >= 30.0:
		passed += 1
	else:
		failed += 1
		failures.append("guard hurtbox should be a sane body rect")
```

- [ ] **Step 2: Regenerate + gate**

```bash
./run.sh --measure-anchors      # rewrites the manifest
./run.sh --anchor-sanity        # MUST print "ANCHOR SANITY: OK"
./run.sh --test                 # MUST be 0 failed (manifest test now passes on real values)
```

If `--anchor-sanity` fails for a pose after regeneration: if it failed an **absolute** criterion (foot too high / degenerate or too-wide body box / reach beyond ceiling), the measurement is wrong for that sprite — inspect it and hand-correct the stored anchor. If you intentionally hand-tune a pose's anchor away from the measured value, add that pose to `OVERRIDE_ALLOWLIST` in `anchor_sanity.gd` (so the stored-vs-measured drift check skips it while the absolute criteria still apply) and note why. Re-run all three. Do not proceed until all three pass.

- [ ] **Step 3: Commit the regenerated manifest + test (only now)**

```bash
git add WUGodot/assets/animation_manifests/hu.manifest.json WUGodot/tests/test_animation_manifest.gd
git commit -m "feat(anim): regenerate Hu manifest from measured anchors"
```

---

## Task 6: Set range_units from geometry + reach-consistency gate (light AND heavy)

"Match the blade" → make every system agree with the geometry by writing `range_units` from the derived reach, and assert geometry reach ≈ `range_units` for **both** attacks (required correction #5).

> **This task changes live combat reach immediately.** `attack_catalog.gd` feeds the scalar path now, even while `ENABLE_AUTHORED_PLAYER_HITBOXES` is still `false`, so Hu's reach roughly doubles the moment Task 6 lands — this is a **temporary unbalanced intermediate**. Tasks 6 → 7 → 8 should be done and landed as **one unit** (do not ship the build between Task 6 and the Task 8 balance pass). The balance/playtest must happen with geometry enabled (Task 7) so it tunes against the final reach.

**Files:**
- Modify: `WUGodot/scripts/attack_catalog.gd` (`hu_light` `:17`, `hu_heavy` `:32`)
- Modify: `WUGodot/tests/test_presentation_collision.gd`

- [ ] **Step 1: Read the derived reach for each attack**

Add a temporary print (or extend `anchor_sanity.gd`) to compute `derived_reach` for `hu_light` and `hu_heavy` against the regenerated manifest (same pattern as Task 2's test: register attacker, advance into active, call `pc.derived_reach`). Record `R_light`, `R_heavy` (world px, capsule far edge from the attacker origin).

**Convention (pinned):** the scalar gate hits when `|Δx| ≤ range_units + defender.half_width` (`combat_system.gd:269`, `half_width = 22`). To make the scalar fallback and AI hints agree with the geometry hit *distance*, set:

```text
range_units = derived_reach − 22
```

Use this for both attacks. (The geometry path uses the capsule directly; this only keeps the fallback/AI consistent.)

- [ ] **Step 2: Update attack_catalog**

In `attack_catalog.gd`, set (with the actual numbers from Step 1):

```gdscript
	def.range_units = R_LIGHT - 22.0   # hu_light: derived reach − half_width (replaces 72.0)
```
```gdscript
	def.range_units = R_HEAVY - 22.0   # hu_heavy: derived reach − half_width (replaces 84.0)
```

With the Rev 3 body-center anchors, the current measured values are:

```gdscript
	def.range_units = 226.625  # hu_light: 248.625 derived reach − 22
	def.range_units = 236.375  # hu_heavy: 258.375 derived reach − 22
```

- [ ] **Step 3: Fix the existing dormancy assertion (it hardcodes a now-in-range distance)**

The Track B dormancy regression test places a defender at a hardcoded `x ≈ attacker.x + 160` and asserts dormant (scalar) Hu does **not** hit it — valid when `range_units = 72` (scalar reach 94 < 160). After this task lengthens `range_units`, 160px is inside scalar reach and that assertion flips to a hit, failing the suite. Make the distance **relative to `range_units`** so it stays a genuine out-of-range miss. Find that assertion (it positions a defender ~160px away and expects no hit / no damage) and change the defender position to:

```gdscript
	# Beyond the (now longer) scalar reach: range_units + half_width + margin.
	var miss_x: float = attacker.position.x + hu_light_def.range_units + 22.0 + 40.0
	# ...place the dormant-path defender at miss_x and keep the "should not hit" assertion...
```

(Use whatever attacker/def variables that assertion already has; the point is to derive the distance from `range_units`, not a literal 160.)

- [ ] **Step 4: Write the reach-consistency asserts (light AND heavy)**

Append to `run_all()` in `test_presentation_collision.gd`:

```gdscript
	for atk_name in ["hu_light", "hu_heavy"]:
		var atk: Variant = AttackCatalogScript.hu_light() if atk_name == "hu_light" else AttackCatalogScript.hu_heavy()
		var ra: Variant = FighterScript.new()
		ra.position = Vector2(0, 900); ra.facing = 1
		ra._attack_state.start(atk)
		ra._attack_state.advance(atk.windup_end + 0.01)
		pc.register_fighter(ra, "hu")
		var reach: float = pc.derived_reach(ra)
		# Pinned convention: range_units = derived_reach - half_width(22), so geometry
		# reach must equal range_units + 22 within tolerance (no silent drift).
		if absf(reach - (atk.range_units + 22.0)) <= maxf(20.0, atk.range_units * 0.25):
			passed += 1
		else:
			failed += 1
			failures.append("%s reach %.0f should equal range_units+22 (%.0f)" % [atk_name, reach, atk.range_units + 22.0])
```

- [ ] **Step 5: Run tests**

Run: `./run.sh --test`
Expected: PASS — both attacks consistent; the dormancy assertion (now `range_units`-relative) still proves the dormant scalar miss.

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/attack_catalog.gd WUGodot/tests/test_presentation_collision.gd
git commit -m "feat(combat): set Hu range_units from geometry-derived reach"
```

---

## Task 7: Enable authored player hitboxes

**Files:**
- Modify: `WUGodot/scripts/combat_scene.gd`

- [ ] **Step 1: Flip the flag** (only after Tasks 5–6 gates are green)

```gdscript
const ENABLE_AUTHORED_PLAYER_HITBOXES: bool = true
```

- [ ] **Step 2: Verify**

Run: `./run.sh --test` → `failed: 0`. Run: `./run.sh --import` → no errors.

- [ ] **Step 3: Commit**

```bash
git add WUGodot/scripts/combat_scene.gd
git commit -m "feat(collision): enable authored Hu hitboxes (match-the-blade reach)"
```

---

## Task 8: Enemy spacing / balance retune + playtest

"Match the blade" roughly doubles Hu's reach, so encounters tuned for the old range need a fairness pass. This is inherently playtested; the knobs are concrete.

**Files:**
- Modify (as needed): `WUGodot/scripts/attack_catalog.gd` (enemy `range_units`), `WUGodot/scripts/ai_brain.gd` (spacing/approach distances), `WUGodot/scripts/enemy_factory.gd` (per-archetype stats).
- Modify: `WUGodot/scripts/main.gd` and `WUGodot/scripts/combat_scene.gd` only if the dev capture hook is missing.

- [ ] **Step 1: Capture the no-float + reach + capsule alignment evidence**

Run:

```bash
./run.sh --shot-combat /tmp/wu-shot-combat-anchor
```

Expected output:
- `/tmp/wu-shot-combat-anchor/01_idle.png`
- `/tmp/wu-shot-combat-anchor/02_walk.png`
- `/tmp/wu-shot-combat-anchor/03_light_windup.png`
- `/tmp/wu-shot-combat-anchor/04_light_active.png`

Review the four images:
- Feet planted across idle/walk/light (no float/bob); the squash on impact does not lift the feet.
- Red capsule overlays the blade and reaches about as far as the visible swing (now intended).
- Light/heavy connect at the new, longer, art-matching distance.
- Enemies stay on the scalar path (no enemy manifests, so the authored-geometry path remains off for them); their scalar reach/spacing is intentionally retuned in Step 2 below.

- [ ] **Step 2: Fairness pass**

With Hu reaching further, check that enemies aren't trivially outranged. Adjust as needed:
- enemy `range_units` (bring melee enemies' reach closer to Hu's so trades are fair),
- AI approach/spacing distances in `ai_brain.gd` so enemies don't sit permanently inside Hu's new range or permanently outside it,
- aggression/cooldowns if the player now dominates or gets overwhelmed.
Re-playtest until duels feel like the pre-change rhythm at the new spacing.

- [ ] **Step 3: Commit**

```bash
git add WUGodot/scripts/attack_catalog.gd WUGodot/scripts/ai_brain.gd WUGodot/scripts/enemy_factory.gd
git commit -m "balance: retune enemy spacing for Hu's match-the-blade reach"
```

---

## Task 9: Final full-suite validation

(`test_anchor_measure.gd` was registered in Task 1, so it has been running throughout.)

- [ ] **Step 1: Full suite + import**

Run: `./run.sh --test`
Expected: PASS — `failed: 0`. Covers `test_anchor_measure` (5), the `derived_reach` (right + left facing) asserts, the reach-consistency asserts (light + heavy), and the rewritten manifest test on measured values.
Run: `./run.sh --import`
Expected: no script errors.

- [ ] **Step 2: Confirm `--anchor-sanity` still green on the committed manifest**

Run: `./run.sh --anchor-sanity`
Expected: `ANCHOR SANITY: OK` (the committed manifest matches its sprites within tolerance / is allowlisted).

---

## Self-Review Notes (coverage map / required corrections)

- **Required correction #1 (manifest test)** → Task 5 Step 1: placeholder-exact asserts replaced with type/range/non-placeholder checks.
- **Required correction #2 (robust body isolation)** → Task 1: largest-connected-component to drop specks + **column-threshold** body box (not row extents) so the thin blade is excluded; unit-tested with a 3px blade.
- **Required correction #3 (real-asset pre-write probe)** → Task 4: `anchor_sanity.gd` reject criteria (foot too high, degenerate/too-wide body box, coarse tip-distance, excessive `footAnchor.x` spread), run before the manifest is committed.
- **Required correction #4 (commit order)** → tool committed in Task 3, manifest only in Task 5 after `--anchor-sanity` + `--test` pass.
- **Required correction #5 (hu_heavy in gate)** → Task 6 Step 4 loops light **and** heavy.
- **Reach decision (match the blade)** → Task 6 sets `range_units` from geometry; Task 8 retunes enemy spacing for fairness.
- **Corrected diagnosis** → documented from the connected-component probe (no artifact bands; intended blade extension + camera/scale drift).

**Deliberately deferred:** enemy manifests/anchors; generator-side metadata; turning `chestAnchor`/`weaponTip` heuristics into rigged points. The Task 4 probe + Task 8 playtest are the safety nets for the heuristic's approximations.

**Validation reality check:** measurement (incl. blade exclusion + speck rejection + empty-image safety) and reach consistency (light/heavy, both facings) are unit-tested headless and run from Task 1; the sanity probe validates the **stored** manifest anchors (stored-vs-measured drift + absolute criteria + coarse tip-distance + `footAnchor.x` spread) before the manifest is committed; the only thing needing eyes is Task 8 — and with real anchors + matched range_units it should look and play right.
