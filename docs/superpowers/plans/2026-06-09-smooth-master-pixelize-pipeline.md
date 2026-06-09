# Smooth-Master → Constant-Density Pixelize Pipeline (Hu, all states) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Regenerate **all of Hu's** frames through PixelForge's smooth-master + deferred-pixelize flow so every state renders at a **consistent character size** and a **uniform pixel density** at **integer render scale 2×** — fixing the attack size-pop and the texel-resolution mismatch across all states (presenter *and* FighterVisual fallback).

**Architecture:** Generate full-res smooth masters for every action. Consumer-side, scale each master in the **smooth domain** to a **single reference base scale** (from the idle master) times a **manual per-pose override** for drift frames, foot-align, and pad all frames to **one common canvas divisible by F**. Then run **one uniform-density pixelize** (single `--out-size = canvas/F`). Install into **canonical sprite slots** so both the presenter (manifest) and the FighterVisual fallback (`character_hu.json`) use the new consistent art. Flip render scale to integer **2×** (profile + manifest together).

**Tech Stack:** Godot 4.6.2 (GDScript, `Image.resize` Lanczos), `aiexp sprite-extractor` (smooth + pixelize), JSON sidecars, headless runner (`./run.sh --test`).

**Computed targets:** current Hu = 179 texels × 1.625 ≈ 291 px. Keep size/balance with integer scale: **R = 2**, **T = 145** texels (290 px, Δ −0.3%), **F = 4** pixels-per-texel (uniform). Base scale comes from the **idle** master; drift frames get a **manual `scaleNorm`** (default 1.0), calibrated by capture.

**Key decisions (locked):**
- **Scale metric = manual per-pose overrides** (no pose-invariant tool hint exists; **do NOT normalize by silhouette height** — it distorts lunges). Base scale from the idle reference; per-pose `scaleNorm` for outliers, calibrated via capture.
- **Scope = all Hu actions → canonical slots → integer 2×.** Required because flipping scale affects fallback states (heavy/dash/jump/hit/block) and uniform density needs integer scale.

**Scope:** Hu only. The 6 enemies follow later with per-character T. **Prerequisite:** PixelForge smooth + pixelize (shipped 2026-06-09).

---

## Prerequisite / integration assumptions (verify in Task 1)

- `aiexp sprite-extractor run ... --render-mode smooth --canvas-ratio W:H --fit-mode pad --actions <list>` → `<run>/<action>/masters/master_NNN.png` + `master_NNN.json` with `bbox`, `foot_anchor`, `native_size`.
- `aiexp sprite-extractor pixelize <run> --out-size W:H --palette vinik24 --fit-mode pad` → `<run>/<action>/pixelize/pixel_NNN.png` + sidecars. **One `--out-size` for the whole run** (so we pad to a common canvas, Task 3).
- **Assumption:** `pixelize` consumes masters we overwrite in `<run>/<action>/masters/`. Confirm in Task 1; if it needs a separate dir, point it there in Task 4.

**Action set — use the tool's REAL action names** (run `aiexp sprite-extractor actions` first; bare invented names like `attack-windup` are rejected). The current tool exposes a single `attack` action (not split into windup/strike/recovery), plus `block`, `hit-react`, `dash`, etc. — confirm the exact names + default frame counts in Task 1 and reconcile the table below to them. The installer **samples** each action's frames into its canonical slots (so a single `attack` action of ≥4 frames fills `attack_0..3`, and a 3- or 4-frame `block`/`dash` samples down to 2 — keeping the end pose).

**Canonical slot map (tool action → WU PNG slots; reconcile names in Task 1):**

| tool action (confirm name) | → canonical slots |
|---|---|
| idle | idle_0, idle_1 |
| walk-cycle | walk_0, walk_1, walk_2, walk_3 |
| **attack** (single action, ≥4 frames) | attack_0, attack_1, attack_2, attack_3 |
| block | block_0, block_1 |
| hit-react | hit_0, hit_1 |
| stunned | stunned_0, stunned_1 |
| dash | dash_0, dash_1 |
| jump | jump_0, jump_1, jump_2 |

The presenter's pose→slot mapping is unchanged: `windup=attack_1`, `strike_extended=attack_2`, `recover=attack_3`, `guard=idle_0`, `breath=idle_1`, `walk_0..3`. If you'd rather author the attack frames explicitly, custom specs of the form `name:count:loop:hint` (e.g. `attack:4:false:"light slash windup→recover"`) are accepted — but the *bare* split names are not.

---

## File Structure

**New (headless-testable `RefCounted`):**
- `WUGodot/scripts/visual/master_normalizer.gd` — pure: from a base scale + per-pose `scaleNorm`, compute resample factor, scaled foot/bbox/size. **Reference-based, not per-frame-bbox.**

**New (headless tools, GDScript `SceneTree`):**
- `WUGodot/tools/scale_masters.gd` — measure idle reference, apply base × `scaleNorm`, `Image.resize` (Lanczos), pad all to a common F-divisible canvas, write masters + sidecars back.
- `WUGodot/tools/install_pixelized.gd` — copy `pixelize/` PNGs into canonical slots, rebuild `hu.manifest.json` from sidecars, zero `character_hu.json` per-frame offsets, set profile yOffset.

**New (authored data, optional):**
- `WUGodot/tools/hu_capsule_overrides.json` — hand-tuned `chestAnchor`/`weaponTip` per pose; the **source of truth** for capsule anchors, applied by `install_pixelized.gd` over its heuristic (so tuning survives reinstalls). The generated `hu.manifest.json` is build output, never hand-edited.

**New (test):** `WUGodot/tests/test_master_normalizer.gd`

**Modified:**
- `WUGodot/assets/sprites/characters/hu/*.png` — replaced (canonical slots).
- `WUGodot/assets/animation_manifests/hu.manifest.json` — rebuilt from sidecars; `renderScale` → 2.
- `WUGodot/assets/animations/character_hu.json` — per-frame `offset` → `[0,0]` (new art is foot-consistent).
- `WUGodot/data/VisualProfiles/DefaultProfiles.json` — Hu `scale` 1.625 → 2; `yOffset` recomputed.
- `WUGodot/scripts/attack_catalog.gd` — re-derive `hu_light`/`hu_heavy` `range_units` (expected ~unchanged).
- `WUGodot/tests/run_tests.gd` — register `test_master_normalizer.gd`.
- `run.sh` — add `--scale-masters`, `--install-pixelized`.

---

## Task 1: Confirm interface + generate all Hu masters

**Files:** none (verification + asset gen).

- [ ] **Step 1: List the real action names + default counts**

```bash
aiexp sprite-extractor actions
```

Record the exact names (e.g. `attack`, `block`, `hit-react`, `dash`, …) and default frame counts. Reconcile the slot-map table's left column to these real names. **Do not invent split names** like `attack-windup` as bare actions — they are rejected.

- [ ] **Step 2: Generate smooth masters for every needed action**

Use the real names from Step 1 (the single `attack` action covers windup/strike/recover slots). Custom specs `name:count:loop:hint` are accepted if you want to pin counts:

```bash
aiexp sprite-extractor run --photo <hu_ref>.png --describe "Hu, wuxia light attacker" \
    --render-mode smooth --canvas-ratio 3:2 --fit-mode pad \
    --actions idle,walk-cycle,attack:4:false:"light slash windup to recover",block,hit-react,stunned,dash,jump
```

Expected: a `<run>/` dir with one `<action>/masters/` per requested action. (If a default-count action like `block`/`dash` yields more frames than its slots, the installer samples them down — Task 5.)

- [ ] **Step 3: Confirm sidecar keys + pixelize input dir**

Open a `master_NNN.json`; confirm `bbox`, `foot_anchor`, `native_size` (note exact key names). Run a throwaway `pixelize <run> --out-size 256:171 --palette vinik24 --fit-mode pad` and confirm it reads `<run>/<action>/masters/`. Record both in a comment atop `tools/scale_masters.gd` (Task 3).

---

## Task 2: MasterNormalizer (reference base scale × manual override)

**Files:**
- Create: `WUGodot/scripts/visual/master_normalizer.gd`
- Test: `WUGodot/tests/test_master_normalizer.gd`

- [ ] **Step 1: Write the failing test**

Create `WUGodot/tests/test_master_normalizer.gd`. Base scale comes from the **idle reference** char height; per-pose `scaleNorm` multiplies it. (T=145, F=4 → reference character maps to 580 smooth px.)

```gdscript
extends RefCounted

const MN = preload("res://scripts/visual/master_normalizer.gd")

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	# idle reference character height = 900 smooth px. Base maps it to T*F = 580.
	var base: float = MN.base_scale(900.0, 145, 4)   # 580/900
	if absf(base - (580.0 / 900.0)) <= 0.0001:
		passed += 1
	else:
		failed += 1; failures.append("base_scale should map reference to T*F")

	# A non-drift frame (scaleNorm 1.0): plan scales by base only.
	var r: Dictionary = MN.plan(base, Vector2(2250, 1500), Rect2(700, 480, 400, 900), Vector2(900, 1380), 1.0)
	if absf(float(r["scale"]) - base) <= 0.0001:
		passed += 1
	else:
		failed += 1; failures.append("scaleNorm 1.0 should scale by base only")

	# A drift frame (scaleNorm 1.25): scale = base * 1.25 (does NOT use this frame's own bbox).
	var d: Dictionary = MN.plan(base, Vector2(1200, 800), Rect2(100, 60, 700, 300), Vector2(600, 740), 1.25)
	if absf(float(d["scale"]) - base * 1.25) <= 0.0001:
		passed += 1
	else:
		failed += 1; failures.append("drift frame should scale by base*scaleNorm, ignoring own bbox")

	# scaled foot/size track the scale.
	if (d["scaled_foot"] as Vector2).is_equal_approx(Vector2(600, 740) * base * 1.25):
		passed += 1
	else:
		failed += 1; failures.append("scaled_foot should be foot*scale")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./run.sh --test` (register in Task 8, or temporarily). Expected: FAIL — missing `master_normalizer.gd`.

- [ ] **Step 3: Write minimal implementation**

Create `WUGodot/scripts/visual/master_normalizer.gd`:

```gdscript
class_name MasterNormalizer
extends RefCounted

# Base scale maps the IDLE reference character height to T*F smooth px.
# Used for ALL frames (a single reference), NOT each frame's own silhouette
# (which is pose-dependent and would distort crouches/lunges).
static func base_scale(reference_char_px: float, target_texels: int, density: float) -> float:
	return (float(target_texels) * density) / maxf(reference_char_px, 1.0)

# Per-frame plan: scale = base * scaleNorm (scaleNorm is a manual per-pose override,
# default 1.0; > 1.0 to enlarge a frame the model drew too small).
static func plan(base: float, native_size: Vector2, bbox: Rect2, foot: Vector2, scale_norm: float) -> Dictionary:
	var scale: float = base * scale_norm
	return {
		"scale": scale,
		"scaled_size": native_size * scale,
		"scaled_foot": foot * scale,
		"scaled_bbox": Rect2(bbox.position * scale, bbox.size * scale),
	}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./run.sh --test`. Expected: PASS — 4 asserts.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/visual/master_normalizer.gd WUGodot/tests/test_master_normalizer.gd WUGodot/tests/run_tests.gd
git commit -m "feat(pipeline): MasterNormalizer (reference base scale + manual override)"
```

---

## Task 3: scale_masters (base from idle + manual overrides, common F-divisible canvas)

**Files:**
- Create: `WUGodot/tools/scale_masters.gd`
- Modify: `run.sh`

- [ ] **Step 1: Write the tool**

Create `WUGodot/tools/scale_masters.gd`. Pass 1: read idle reference + all sidecars, compute each frame's scaled bbox. Pass 2: pick a **common canvas** = max scaled bbox + pad, rounded **up to a multiple of F**, then resample + foot-align each frame onto it. `SCALE_NORM` is the manual override map (default 1.0; start empty, fill the strike after Task 7's capture).

```gdscript
extends SceneTree

const MN = preload("res://scripts/visual/master_normalizer.gd")
const TARGET_TEXELS := 145
const DENSITY := 4
const PAD := 48
# Manual drift overrides, keyed PER FRAME ("<action>/<master_basename>") so a strike-only
# correction does not scale the windup/recover frames of the same `attack` action.
# Identify the offending master from the Task 7 capture. Default 1.0.
const SCALE_NORM := {
	# "attack/master_003": 1.25,
}

func _init() -> void:
	var run_dir := _arg()
	if run_dir.is_empty():
		printerr("usage: --scale-masters <abs_run_dir>"); quit(1); return

	# Idempotency: snapshot pristine masters on first run, restore from them on every rerun,
	# so re-calibrating SCALE_NORM never scales an already-scaled frame (no compounding).
	_ensure_fresh(run_dir)

	# Reference: idle master character height (from the freshly-restored originals).
	var ref_px := _idle_reference(run_dir)
	if ref_px <= 0.0:
		printerr("no idle master to use as reference"); quit(1); return
	var base := MN.base_scale(ref_px, TARGET_TEXELS, DENSITY)

	# Pass 1: max scaled extents RELATIVE TO THE FOOT in each direction, so asymmetric
	# forward poses (long sword lunges extend far +x) are not clipped. Sizing from bbox
	# w/h + a centered foot would clip them.
	var frames := _collect(run_dir)  # [{png, side, action, native, bbox, foot}]
	var max_left := 0.0; var max_right := 0.0; var max_up := 0.0; var max_down := 0.0
	for f in frames:
		var sc := base * float(SCALE_NORM.get(_norm_key(f), 1.0))
		var bb: Rect2 = f.bbox
		var ft: Vector2 = f.foot
		max_left = maxf(max_left, (ft.x - bb.position.x) * sc)
		max_right = maxf(max_right, (bb.position.x + bb.size.x - ft.x) * sc)
		max_up = maxf(max_up, (ft.y - bb.position.y) * sc)
		max_down = maxf(max_down, (bb.position.y + bb.size.y - ft.y) * sc)
	# Horizontal: keep the foot CENTERED in the canvas. The FighterVisual fallback anchors
	# every frame at image bottom-CENTER, so an off-center foot would shift heavy/dash/jump/
	# hit/block/stun sideways by (foot_x - width/2)*scale. Size the half-width to the LARGER
	# of left/right so the most-extended pose still fits on the short side.
	var half_w := maxf(max_left, max_right)
	var cw := _round_up(int(ceil(half_w * 2.0)) + PAD * 2, DENSITY)
	# Vertical: bottom-anchored via yOffset, so asymmetric up/down is fine.
	var ch := _round_up(int(ceil(max_up + max_down)) + PAD * 2, DENSITY)
	var foot_canvas := Vector2(float(cw) * 0.5, float(PAD) + max_up)

	# Pass 2: resample + place each frame.
	for f in frames:
		var sn := float(SCALE_NORM.get(_norm_key(f), 1.0))
		var plan := MN.plan(base, f.native, f.bbox, f.foot, sn)
		var img := Image.new(); img.load(f.png)
		var ss: Vector2 = plan["scaled_size"]
		img.resize(int(round(ss.x)), int(round(ss.y)), Image.INTERPOLATE_LANCZOS)
		var canvas := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0, 0, 0, 0))
		# Align the scaled foot to foot_canvas.
		var sfoot: Vector2 = plan["scaled_foot"]
		var dst := Vector2i(int(round(foot_canvas.x - sfoot.x)), int(round(foot_canvas.y - sfoot.y)))
		canvas.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), dst)
		canvas.save_png(f.png)
		var meta := JSON.parse_string(FileAccess.get_file_as_string(f.side)) as Dictionary
		meta["native_size"] = [cw, ch]
		meta["foot_anchor"] = [foot_canvas.x, foot_canvas.y]
		# Keep bbox canvas-relative after scale + reposition (don't leave it stale).
		var sbb: Rect2 = plan["scaled_bbox"]
		meta["bbox"] = [sbb.position.x + float(dst.x), sbb.position.y + float(dst.y), sbb.size.x, sbb.size.y]
		var fs := FileAccess.open(f.side, FileAccess.WRITE); fs.store_string(JSON.stringify(meta, "  ")); fs.close()
		print("%s/%s scale=%.3f norm=%.2f" % [f.action, f.png.get_file(), float(plan["scale"]), sn])
	print("common canvas %dx%d  out-size for pixelize: %d:%d" % [cw, ch, cw / DENSITY, ch / DENSITY])
	quit()

func _idle_reference(run_dir: String) -> float:
	var masters := run_dir.path_join("idle").path_join("masters")
	if not DirAccess.dir_exists_absolute(masters): return 0.0
	for f in DirAccess.open(masters).get_files():
		if f.ends_with(".json"):
			var m := JSON.parse_string(FileAccess.get_file_as_string(masters.path_join(f))) as Dictionary
			return _r(m.get("bbox")).size.y
	return 0.0

func _collect(run_dir: String) -> Array:
	var out := []
	for action in DirAccess.open(run_dir).get_directories():
		var masters := run_dir.path_join(action).path_join("masters")
		if not DirAccess.dir_exists_absolute(masters): continue
		for f in DirAccess.open(masters).get_files():
			if not f.ends_with(".png"): continue
			var png := masters.path_join(f)
			var side := png.get_basename() + ".json"
			var m := JSON.parse_string(FileAccess.get_file_as_string(side)) as Dictionary
			out.append({"png": png, "side": side, "action": action,
				"native": _v(m.get("native_size")), "bbox": _r(m.get("bbox")), "foot": _v(m.get("foot_anchor"))})
	return out

func _round_up(v: int, m: int) -> int: return int(ceil(float(v) / float(m))) * m
func _norm_key(f: Dictionary) -> String: return "%s/%s" % [f.action, String(f.png).get_file().get_basename()]

# Snapshot/restore pristine masters so reruns scale the ORIGINALS, never compound.
func _ensure_fresh(run_dir: String) -> void:
	for action in DirAccess.open(run_dir).get_directories():
		var masters := run_dir.path_join(action).path_join("masters")
		var pristine := run_dir.path_join(action).path_join("masters_pristine")
		if not DirAccess.dir_exists_absolute(masters):
			continue
		if DirAccess.dir_exists_absolute(pristine):
			_copy_dir(pristine, masters)   # rerun: restore fresh originals
		else:
			_copy_dir(masters, pristine)   # first run: snapshot originals
func _copy_dir(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)
	for f in DirAccess.open(src).get_files():
		DirAccess.copy_absolute(src.path_join(f), dst.path_join(f))
func _arg() -> String:
	var a := ""
	for x in OS.get_cmdline_user_args(): a = x
	return a
func _v(raw: Variant) -> Vector2:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2: return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO
func _r(raw: Variant) -> Rect2:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 4: return Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
	return Rect2()
```

- [ ] **Step 2: Add run.sh case**

```bash
    --scale-masters)
        shift
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://tools/scale_masters.gd -- "$@" ;;
```

- [ ] **Step 3: Run + note the printed out-size**

Run: `./run.sh --scale-masters /abs/<run>`. Expected: per-frame `scale=`/`norm=` lines, then `common canvas WxH  out-size for pixelize: W/4:H/4`. **Record that out-size** for Task 4. All masters are now the same canvas, foot-aligned.

- [ ] **Step 4: Commit**

```bash
git add WUGodot/tools/scale_masters.gd run.sh
git commit -m "feat(pipeline): scale_masters (idle-ref base + manual overrides, common canvas)"
```

---

## Task 4: Single uniform-density pixelize

**Files:** none (external tool).

- [ ] **Step 1: Pixelize once at the common out-size**

Use the out-size printed by Task 3 (`canvas/F`):

```bash
aiexp sprite-extractor pixelize <run> --out-size <W>:<H> --palette vinik24 --fit-mode pad
```

Expected: every `<action>/pixelize/pixel_NNN.png` at the same dimensions, character ≈ 145 texels.

- [ ] **Step 2: Verify uniform pixel density (NOT equal bbox height)**

Density is uniform by construction (one common canvas → one `--out-size` → one downscale factor). Confirm it: every `pixel_NNN.png` should have the **same image dimensions**. **Do not** check that `bbox` heights are equal — with idle-reference base × `scaleNorm`, crouches/lunges *legitimately* have different silhouette heights, and forcing them equal would re-introduce the silhouette-normalization bug. Perceived **character/head scale** consistency is judged visually in Task 7, not by bbox height here. (If a frame's character clearly reads too small/large there, fix it via that action's `SCALE_NORM` in Task 3 — not by equalizing bbox.)

---

## Task 5: install_pixelized (canonical slots + manifest + fallback offsets)

**Files:**
- Create: `WUGodot/tools/install_pixelized.gd`
- Modify: `run.sh`

- [ ] **Step 1: Write the installer**

Create `WUGodot/tools/install_pixelized.gd`. Copies pixel frames into **canonical slot names** (so both the manifest and `character_hu.json` reference the same new art), rebuilds `hu.manifest.json` from sidecars, **zeros `character_hu.json` per-frame offsets**, and writes the profile `yOffset` for the common foot row. (Profile `scale` + manifest `renderScale` are set together in Task 6.)

```gdscript
extends SceneTree

# Keyed by the REAL tool action dir names (reconcile with Task 1). A single `attack`
# action fills attack_0..3 via even sampling. Frame counts > slots are sampled, not
# truncated, so the end pose (block/dash/hit) is preserved.
const SLOTS := {
	"idle": ["idle_0", "idle_1"],
	"walk-cycle": ["walk_0", "walk_1", "walk_2", "walk_3"],
	"attack": ["attack_0", "attack_1", "attack_2", "attack_3"],
	"block": ["block_0", "block_1"],
	"hit-react": ["hit_0", "hit_1"],
	"stunned": ["stunned_0", "stunned_1"],
	"dash": ["dash_0", "dash_1"],
	"jump": ["jump_0", "jump_1", "jump_2"],
}
# manifest pose -> canonical slot (presenter poses only need these)
const POSE_SLOT := {
	"guard": "idle_0", "breath": "idle_1",
	"walk_0": "walk_0", "walk_1": "walk_1", "walk_2": "walk_2", "walk_3": "walk_3",
	"windup": "attack_1", "strike_extended": "attack_2", "recover": "attack_3",
}
const DEST := "res://assets/sprites/characters/hu/"
const MANIFEST := "res://assets/animation_manifests/hu.manifest.json"
const ANIMSET := "res://assets/animations/character_hu.json"
const RENDER_SCALE := 2.0  # target integer scale; written here so re-install never reverts it

func _init() -> void:
	var run_dir := _arg()
	if run_dir.is_empty(): printerr("usage: --install-pixelized <abs_run_dir>"); quit(1); return

	var side_by_slot := {}  # slot -> sidecar dict
	for action in SLOTS.keys():
		var pdir := run_dir.path_join(action).path_join("pixelize")
		if not DirAccess.dir_exists_absolute(pdir): printerr("missing %s" % pdir); continue
		var pngs := []
		for f in DirAccess.open(pdir).get_files():
			if f.ends_with(".png"): pngs.append(f)
		pngs.sort()
		var names: Array = SLOTS[action]
		var idxs := _sample_indices(pngs.size(), names.size())
		if idxs.is_empty():
			printerr("not enough frames for %s (%d < %d)" % [action, pngs.size(), names.size()]); continue
		for i in range(names.size()):
			var src := pdir.path_join(pngs[idxs[i]])
			DirAccess.copy_absolute(src, ProjectSettings.globalize_path(DEST + names[i] + ".png"))
			side_by_slot[names[i]] = JSON.parse_string(FileAccess.get_file_as_string(src.get_basename() + ".json")) as Dictionary
			# Print slot <- source-master key (pixel_NNN ↔ master_NNN) for the SCALE_NORM key.
			print("slot %s <- %s/%s" % [names[i], action, pngs[idxs[i]].get_basename().replace("pixel", "master")])

	# Manifest (presenter) — paths to canonical slots, anchors from sidecars.
	var poses := {}
	for pose_name in POSE_SLOT.keys():
		var slot: String = POSE_SLOT[pose_name]
		var meta: Dictionary = side_by_slot.get(slot, {})
		var foot: Array = meta.get("foot_anchor", [0, 0])
		var bbox: Array = meta.get("bbox", [0, 0, 0, 0])
		poses[pose_name] = {
			"path": DEST + slot + ".png",
			"footAnchor": [int(round(float(foot[0]))), int(round(float(foot[1])))],
			"chestAnchor": [int(round(float(foot[0]))), int(round(float(foot[1])) - 95)],
			"weaponTip": [int(round(float(bbox[0]) + float(bbox[2]))), int(round(float(foot[1])) - 80)],
			"hurtbox": [int(round(float(bbox[0]))), int(round(float(bbox[1]))), int(round(float(bbox[2]))), int(round(float(bbox[3]))) ],
		}
	# Persistent capsule overrides: hand-tuned chest/weaponTip live in a file (NOT the
	# generated manifest), so they survive reinstalls during calibration.
	var ov_path := "res://tools/hu_capsule_overrides.json"
	if FileAccess.file_exists(ov_path):
		var ov := JSON.parse_string(FileAccess.get_file_as_string(ov_path)) as Dictionary
		for pose_name in ov.keys():
			if poses.has(pose_name):
				var o: Dictionary = ov[pose_name]
				if o.has("chestAnchor"): poses[pose_name]["chestAnchor"] = o["chestAnchor"]
				if o.has("weaponTip"): poses[pose_name]["weaponTip"] = o["weaponTip"]

	var root := {"id": "hu", "renderScale": RENDER_SCALE, "weaponClass": "sword", "poses": poses}
	var mf := FileAccess.open(MANIFEST, FileAccess.WRITE); mf.store_string(JSON.stringify(root, "  ")); mf.close()

	# FighterVisual fallback AnimationSet — zero all per-frame offsets (art is now foot-consistent).
	var anim := JSON.parse_string(FileAccess.get_file_as_string(ANIMSET)) as Dictionary
	for clip in (anim.get("clips", {}) as Dictionary).values():
		for fr in ((clip as Dictionary).get("frames", []) as Array):
			(fr as Dictionary)["offset"] = [0, 0]
	var af := FileAccess.open(ANIMSET, FileAccess.WRITE); af.store_string(JSON.stringify(anim, "  ")); af.close()

	# Compute the profile yOffset in PIXELIZED space (foot row from the pixel sidecar,
	# canvas height = the installed PNG's height), times render scale. Using the smooth
	# canvas height here would be ~F times too large.
	var any: Dictionary = side_by_slot.get("idle_0", {})
	var foot_row: float = float((any.get("foot_anchor", [0, 0]) as Array)[1])
	var idle_img := Image.new(); idle_img.load(DEST + "idle_0.png")
	var y_off: float = (float(idle_img.get_height()) - foot_row) * RENDER_SCALE
	print("installed; profile yOffset = %.3f  (set in Task 6), renderScale = %.1f" % [y_off, RENDER_SCALE])
	quit()

func _arg() -> String:
	var a := ""
	for x in OS.get_cmdline_user_args(): a = x
	return a

# Evenly spaced indices (keeps first AND end pose), mirroring install_regen_256.py.
func _sample_indices(src_n: int, want_n: int) -> Array:
	if src_n < want_n: return []
	if want_n <= 1: return [0]
	if src_n == want_n: return range(src_n)
	var out := []
	for i in range(want_n):
		out.append(int(round(float(i) * float(src_n - 1) / float(want_n - 1))))
	return out
```

Note: `chestAnchor`/`weaponTip` are heuristic (chest ≈ foot−95 texels; tip ≈ bbox right edge) and **overridable** via `tools/hu_capsule_overrides.json` (reinstall-safe — see Task 7); verify in the Task 7 capture and hand-tune **there**, never in the generated manifest. `footAnchor`/`hurtbox` come from sidecars.

- [ ] **Step 2: Add run.sh case + run + import**

```bash
    --install-pixelized)
        shift
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://tools/install_pixelized.gd -- "$@" ;;
```

Run: `./run.sh --install-pixelized /abs/<run>` → note the printed `foot_anchor`. Then `./run.sh --import` → no errors.

- [ ] **Step 3: Commit the TOOL only — leave regenerated assets uncommitted**

After this step the working tree is in a **temporary mismatched state**: the new T=145 art is in place, the manifest reads `renderScale: 2.0` (the installer wrote it), but the **profile `scale` is still 1.625**. So the presenter would render at 1.625 while collision computes at 2.0 — inconsistent. This is acceptable **only because it is uncommitted and not playtested** until Task 6 sets the profile to 2.0 and commits everything together. **Do not commit the assets or playtest here.** Commit only the tooling now.

```bash
git add WUGodot/tools/install_pixelized.gd run.sh
git commit -m "feat(pipeline): add install_pixelized tool"
```

---

## Task 6: Atomic install + integer 2× scale + re-derive reach (one commit)

The working tree from Task 5 already holds the new T=145 sprites/manifest/`character_hu.json` (uncommitted). This task flips the scale and commits **everything together** so the repo never contains the intermediate (T=145 art at scale 1.625) state.

**Files (committed together):**
- Modify: `WUGodot/data/VisualProfiles/DefaultProfiles.json` (Hu `scale`, `yOffset`)
- Modify: `WUGodot/assets/animation_manifests/hu.manifest.json` (`renderScale`)
- Modify: `WUGodot/scripts/attack_catalog.gd` (`hu_light`/`hu_heavy` `range_units`)
- Plus the uncommitted Task 5 outputs: `WUGodot/assets/sprites/characters/hu/`, `hu.manifest.json`, `WUGodot/assets/animations/character_hu.json`

- [ ] **Step 1: Set both scales to 2 in the same commit (avoids the §5 mismatch)**

In `DefaultProfiles.json` set Hu `"scale": 2` and `"yOffset"` to the value the installer **printed in Task 5** (`yOffset = (pixelized_canvas_h − pixelized_foot_row) × 2`, computed in pixel space — do NOT use the smooth canvas height, which is F× too large). The manifest `renderScale` is **already 2.0** (the installer wrote it), so confirm it reads 2.0 — both presenter (profile `scale`) and collision (manifest `renderScale`) now agree, committed together below.

- [ ] **Step 2: Re-derive range_units**

Run the derived-reach probe (register Hu, advance into active, read `pc.derived_reach`) against the new manifest; set `hu_light`/`hu_heavy` `range_units = derived_reach − 22`. Because 145×2 ≈ 179×1.625, expect values within ~1% of current — confirm.

- [ ] **Step 3: Tests + import**

Run: `./run.sh --test` → `failed: 0` (reach-consistency asserts hold; balance preserved). `./run.sh --import` → clean.

- [ ] **Step 4: Commit install + scale atomically**

```bash
git add WUGodot/assets/sprites/characters/hu/ \
        WUGodot/assets/animation_manifests/hu.manifest.json \
        WUGodot/assets/animations/character_hu.json \
        WUGodot/data/VisualProfiles/DefaultProfiles.json \
        WUGodot/scripts/attack_catalog.gd
git commit -m "feat(pipeline): Hu consistent-scale art + integer 2x scale + re-derived reach (atomic)"
```

---

## Task 7: Capture verification + manual override calibration

**Files:**
- `WUGodot/tools/scale_masters.gd` (`SCALE_NORM` per-frame overrides, if drift)
- Create/Modify: `WUGodot/tools/hu_capsule_overrides.json` (**authored** capsule tuning — the source of truth for chest/weaponTip)
- `WUGodot/scripts/attack_catalog.gd` (re-derived reach, if the capsule changed)
- `WUGodot/assets/animation_manifests/hu.manifest.json` is committed as **build output** (regenerated by the installer), never hand-edited.

- [ ] **Step 1: Extend the capture hook to force ALL Hu states**

The current hook only forces the player's idle / walk / light-windup / light-active (and `--shot-archetype` selects the *enemy*, not Hu's state). Since this plan changes **every** Hu state, the visual gate must cover them. Extend the player-state forcing in `main.gd`/`combat_scene.gd` (the same place the existing forced states live) to also stage and shoot: **heavy** (windup+active), **block**, **hit-react**, **stunned**, **dash**, **jump / fall / land**, and **light recover**. Output one PNG per state into the capture dir.

- [ ] **Step 2: Capture**

Run: `./run.sh --shot-combat /tmp/wu-smooth-hu` (or the flag the extended hook uses). Expected: a PNG per forced Hu state.

- [ ] **Step 3: Verify (all states)**

- **No size pop / consistent character scale** across idle/walk/light *and* heavy/dash/jump/hit/block/stun — head/body the same size in every state (judge by eye; do **not** expect equal silhouette heights — poses differ).
- **Uniform pixel density** — identical texel size every frame; integer 2× renders crisp.
- **Feet planted** every frame; **capsule aligned** to the blade.

- [ ] **Step 4: Calibrate drift overrides if needed**

If a frame (likely the strike) still reads smaller/larger: find the bad **canonical slot** in the capture (e.g. `attack_2`), then use the installer's printed **`slot <- master` mapping** (Task 5) to get its source master (e.g. `attack/master_003`), and set a **per-frame** override in `scale_masters.gd` `SCALE_NORM` for that master (e.g. `"attack/master_003": 1.2` — *not* `"attack"`, which would also scale windup/recover). Re-run Tasks 3→4→5 then re-import, re-capture. Iterate until consistent. If the capsule misaligns, hand-tune `chestAnchor`/`weaponTip` in **`tools/hu_capsule_overrides.json`** (`{ "<pose>": {"chestAnchor": [x,y], "weaponTip": [x,y]} }`) — the installer applies it over the heuristic, so it **survives reinstalls**; do **not** edit the generated manifest directly (it's overwritten each install). **After each re-install, confirm `hu.manifest.json` `renderScale` is still 2.0** (the installer writes 2.0, so it shouldn't revert — but verify, since a stale 1.625 would desync collision from rendering).

- [ ] **Step 5: Re-derive reach if the capsule changed**

Any change to `SCALE_NORM` (it scales the strike → blade), `chestAnchor`, or `weaponTip` changes the authored capsule, so `hu_light`/`hu_heavy` `range_units` are now stale. Re-run the derived-reach probe (Task 6 Step 2) and update `attack_catalog.gd` `range_units = derived_reach − 22`. Re-run `./run.sh --test` (reach-consistency asserts) before committing. Skip this step only if no capsule-affecting value changed.

- [ ] **Step 6: Commit calibration (incl. re-derived reach)**

```bash
git add WUGodot/tools/scale_masters.gd \
        WUGodot/tools/hu_capsule_overrides.json \
        WUGodot/assets/sprites/characters/hu/ \
        WUGodot/assets/animation_manifests/hu.manifest.json \
        WUGodot/scripts/attack_catalog.gd
git commit -m "fix(pipeline): calibrate Hu drift scaleNorm + capsule overrides + re-derived reach"
```

---

## Task 8: Register tests + final validation

**Files:** `WUGodot/tests/run_tests.gd`

- [ ] **Step 1: Register**

Add `"res://tests/test_master_normalizer.gd",` to `_TEST_MODULES` (if Task 2 didn't).

- [ ] **Step 2: Full suite + sanity**

Run: `./run.sh --test` → `failed: 0`. `./run.sh --import` → clean. `./run.sh --anchor-sanity` → OK (sidecar foot anchors should pass; if it cross-checks measured-vs-stored, allowlist the sidecar-sourced Hu poses or relax it for this character).

- [ ] **Step 3: Commit**

```bash
git add WUGodot/tests/run_tests.gd
git commit -m "test(pipeline): register master-normalizer module"
```

---

## Self-Review Notes (coverage map / findings addressed)

- **Finding #1 (actions list)** → Task 1 `--actions` full canonical set.
- **Finding #2 (no silhouette-height normalization)** → `MasterNormalizer` uses an **idle reference base scale × manual per-pose `scaleNorm`**, never each frame's own bbox (Tasks 2, 3, 7). Decision: manual overrides.
- **Finding #3 (canonical slots / all states)** → install into canonical slots, all ten actions, zero fallback offsets, integer scale only after all states migrated (Tasks 1, 5, 6). Decision: all actions + 2×.
- **Finding #4 (single pixelize out-size)** → pad all to a common F-divisible canvas → one `--out-size` (Tasks 3, 4).
- **Finding #5 (scale-mismatch commit)** → profile `scale` + manifest `renderScale` flipped together in Task 6.

**Round-2 review fixes:**
- **Invalid bare action names** → Task 1 lists real actions via `aiexp sprite-extractor actions`; single `attack` action fills `attack_0..3`; custom `name:count:loop:hint` specs allowed (bare split names are not).
- **Task 4 bbox≈145 check contradicted the decision** → now verifies **uniform image dimensions / density** and judges character scale **visually** (Task 7); silhouette heights are *expected* to differ.
- **Non-atomic scale flip** → Task 5 commits only the tool; sprites/manifest/`character_hu.json` + profile/manifest scale + reach are one **atomic** commit in Task 6.
- **Common-canvas clipping asymmetric poses** → Task 3 sizes from **directional foot-relative extents** (`max_left/right/up/down`), foot placed at `(PAD+max_left, PAD+max_up)`.
- **Installer dropped end poses** → `_sample_indices` (even, keeps the end pose) instead of first-N.
- **Capture missed states** → Task 7 first **extends the hook to force all Hu states** (heavy/block/hit/stun/dash/jump/fall/land/recover) before the visual gate.

**Round-3 review fixes:**
- **`walk` invalid** → `walk-cycle` everywhere (gen command, slot map, installer `SLOTS`, comment).
- **Reinstall clobbered `renderScale`** → installer writes `RENDER_SCALE = 2.0` (no Task-6-flip hack); Task 7 verifies it stays 2.0 after every re-install.
- **`yOffset` coordinate-space bug** → computed in **pixelized** space (`(pixel_canvas_h − pixel_foot_row) × 2`) and printed by the installer; Task 6 uses that value (not the smooth canvas height).
- **`SCALE_NORM` action-keyed** → now **per-frame** (`"<action>/<master_basename>"`) so a strike fix doesn't scale windup/recover of the single `attack` action.

**Round-4 review fixes:**
- **Off-center foot vs bottom-center fallback** → `scale_masters` now **centers the foot horizontally** (canvas half-width = max(left,right)+PAD), so FighterVisual fallback states don't shift sideways; vertical stays bottom-anchored via yOffset.
- **Stale intermediate-state note** → Task 5 now states the real dirty state (profile `scale` 1.625 / manifest `renderScale` 2.0), acceptable only because uncommitted + not playtested until Task 6.
- **Master↔slot bridge for calibration** → installer prints `slot <- action/master`, and Task 7 keys `SCALE_NORM` off the mapped source master.

**Round-5 review fixes (reinstall safety):**
- **Compounding scale on rerun** → `scale_masters` snapshots pristine masters (`masters_pristine/`) and restores them each run, so re-calibration scales the originals (idempotent).
- **Bridge printed pixel names** → installer prints the **master** key (`pixel_NNN`→`master_NNN`) matching `SCALE_NORM`.
- **Hand-tuned capsule clobbered on reinstall** → `chestAnchor`/`weaponTip` overrides live in `tools/hu_capsule_overrides.json`, applied over the heuristic on every install; the generated manifest is never hand-edited.

**Remaining manual / risk items:**
- **Drift `scaleNorm` values** are hand-calibrated via capture (Task 7) — start at 1.0, set outliers; the strike is the likely one.
- **`chestAnchor`/`weaponTip`** still heuristic → capsule check + hand-tune (Task 7).
- **Tool-interface assumptions** (sidecar keys, `--actions` flag, pixelize input dir) — verify in Task 1.
- **`anchor_sanity`** may cross-check measured-vs-stored → allowlist/relax for sidecar-sourced Hu (Task 8).

**Out of scope:** the 6 enemies (same recipe, per-character T); composable layers for "gains affect appearance"; chunkier R=3 art-direction option (change T/R constants if desired).
