# Fix Master-Scale Squeeze (un-thin Hu) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the horizontal squeeze in `tools/scale_masters.gd` (all installed Hu frames are compressed to ~⅔ width), re-run the pipeline from the surviving pristine masters — **no art regeneration needed** — and re-sync collision/balance to the corrected (wider) art.

**Root cause (diagnosed, confirmed by pixels):** the generator's master sidecars carry a **wrong `native_size`** (`[1024, 1024]` while the PNG is `1536×1024`). `scale_masters.gd:140` trusts the sidecar, `MasterNormalizer.plan` builds the resize box from it, and `:71` resizes the *actual* PNG into that box → X compressed by 1024/1536 = 0.667 (measured: idle aspect 0.495→0.331 ratio 0.669; attack 2.115→1.327 ratio 0.628). Every frame, every action.

**Architecture of the fix:** never trust sidecar geometry blindly. A new pure, testable `MasterGeometry` helper resolves each master's geometry: `native_size` always from the **actual image**; if the sidecar's `native_size` disagrees with the image (or its bbox falls outside the image), **remeasure bbox/foot from pixels**. `scale_masters` consumes the helper and adds a **uniformity gate** (scaled content aspect must match source content aspect ±2%, else hard-fail) so this bug class can never pass silently again. Then rerun scale → pixelize → install from `masters_pristine`, and re-derive reach/balance (the un-squeezed blade is ~1.5× longer in X — this is real, art-faithful reach per the standing "match the blade" decision).

**Tech Stack:** Godot 4.6.2 (GDScript, `Image` pixel access), aiexp pixelize (external), headless runner (`./run.sh --test`).

**Prerequisite / at-risk asset:** `/tmp/wu-smooth-hu-run2` (88 MB) holds the only pristine masters. **Task 0 archives it before anything else** — a reboot deletes it.

---

## File Structure

**New:**
- `WUGodot/scripts/visual/master_geometry.gd` — pure: resolve trusted geometry for one master (image dims + sidecar + pixel fallback).
- `WUGodot/tests/test_master_geometry.gd` — lying-sidecar cases.

**Modified:**
- `WUGodot/tools/scale_masters.gd` — consume `MasterGeometry`; pixel-measured uniformity gate; reference derived from resolved frames.
- `WUGodot/assets/sprites/characters/hu/*.png`, `hu.manifest.json`, `character_hu.json`, `DefaultProfiles.json` (yOffset) — regenerated/re-synced outputs (committed together).
- `WUGodot/data/Attacks/Attacks.json` (Hu + enemy `range_units`) + `WUGodot/data/Enemies/*.json` (`preferredRange`) — balance re-sync, **data-only thanks to A1** (no `attack_catalog.gd` changes — that would violate the A1 boundary).
- `WUGodot/tests/test_attack_data.gd` — A1 golden values updated as deliberate balance edits.
- `WUGodot/tools/anchor_sanity.gd` — clear the Hu pose allowlist so the drift gate is live again.
- `WUGodot/tools/hu_capsule_overrides.json` — stale (tuned against squeezed art): clear, re-tune only if the capture shows misalignment.
- `WUGodot/tests/run_tests.gd` — register the new module.

---

## Task 0: Archive the pristine masters (do FIRST)

- [ ] **Step 1: Copy out of /tmp**

```bash
mkdir -p ~/WU-art-masters
rsync -a /tmp/wu-smooth-hu-run2/ ~/WU-art-masters/wu-smooth-hu-run2/
du -sh ~/WU-art-masters/wu-smooth-hu-run2   # expect ~88M
```

- [ ] **Step 2: Record the location**

Add one line to `docs/ART_DESIGN_DOC.md` (or a new `docs/ART_SOURCES.md`): smooth-master archive lives at `~/WU-art-masters/` (not in git — 88 MB); regenerate installs from there. Commit the doc line.

```bash
git add docs/ && git commit -m "docs: record smooth-master archive location"
```

---

## Task 1: MasterGeometry helper (TDD)

**Files:**
- Create: `WUGodot/scripts/visual/master_geometry.gd`
- Test: `WUGodot/tests/test_master_geometry.gd`

- [ ] **Step 1: Write the failing test + register**

Create `WUGodot/tests/test_master_geometry.gd`. Synthetic image: 120×80 canvas, opaque block at x 30..59, y 10..69 (bbox 30,10,30,60; foot = bottom-center (45, 69)).

```gdscript
extends RefCounted

const MG = preload("res://scripts/visual/master_geometry.gd")

func _img() -> Image:
	var img := Image.create(120, 80, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(10, 70):
		for x in range(30, 60):
			img.set_pixel(x, y, Color(1, 1, 1, 1))
	return img

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []
	var img := _img()

	# 1) Honest sidecar: native matches image -> sidecar bbox/foot are trusted as-is.
	var honest := {"native_size": [120, 80], "bbox": [30, 10, 30, 60], "foot_anchor": [45, 69]}
	var g: Dictionary = MG.resolve(img, honest)
	if (g["native"] as Vector2) == Vector2(120, 80) and (g["bbox"] as Rect2) == Rect2(30, 10, 30, 60) and not bool(g["remeasured"]):
		passed += 1
	else:
		failed += 1; failures.append("honest sidecar should be trusted (got %s)" % str(g))

	# 2) LYING native_size (the Hu bug: claims 80x80 for a 120x80 image):
	#    native must come from the IMAGE and bbox/foot must be REMEASURED from pixels.
	var lying := {"native_size": [80, 80], "bbox": [30, 10, 30, 60], "foot_anchor": [45, 69]}
	var g2: Dictionary = MG.resolve(img, lying)
	var b2: Rect2 = g2["bbox"] as Rect2
	if (g2["native"] as Vector2) == Vector2(120, 80) and bool(g2["remeasured"]) \
		and absf(b2.position.x - 30.0) <= 1.0 and absf(b2.size.x - 30.0) <= 2.0 and absf(b2.size.y - 60.0) <= 2.0:
		passed += 1
	else:
		failed += 1; failures.append("lying native must force image-dims + pixel remeasure (got %s)" % str(g2))

	# 3) Remeasured foot = bottom-center of silhouette.
	var f2: Vector2 = g2["foot"] as Vector2
	if absf(f2.x - 44.5) <= 1.5 and absf(f2.y - 69.0) <= 1.5:
		passed += 1
	else:
		failed += 1; failures.append("remeasured foot should be silhouette bottom-center (got %s)" % str(f2))

	# 4) Sidecar bbox outside the image also forces remeasure.
	var oob := {"native_size": [120, 80], "bbox": [100, 10, 50, 60], "foot_anchor": [45, 69]}
	var g3: Dictionary = MG.resolve(img, oob)
	if bool(g3["remeasured"]):
		passed += 1
	else:
		failed += 1; failures.append("out-of-bounds sidecar bbox should force remeasure")

	return {"passed": passed, "failed": failed, "failures": failures}
```

Register in `run_tests.gd`: `"res://tests/test_master_geometry.gd",`

- [ ] **Step 2: Run to verify it fails** — `./run.sh --test`, FAIL on missing script.

- [ ] **Step 3: Implement**

Create `WUGodot/scripts/visual/master_geometry.gd`:

```gdscript
class_name MasterGeometry
extends RefCounted

const ALPHA := 0.5

# Resolve trusted geometry for one smooth master.
# native ALWAYS comes from the actual image (the Hu squeeze came from trusting a
# sidecar native_size of 1024x1024 against a 1536x1024 PNG). bbox/foot come from
# the sidecar only when it is consistent with the image; otherwise pixel-remeasure.
static func resolve(img: Image, sidecar: Dictionary) -> Dictionary:
	var native := Vector2(img.get_width(), img.get_height())
	var side_native := _vec(sidecar.get("native_size"))
	var bbox := _rect(sidecar.get("bbox"))
	var foot := _vec(sidecar.get("foot_anchor"))

	var native_lies: bool = side_native.distance_to(native) > 1.0
	var bbox_oob: bool = bbox.size.x <= 0.0 or bbox.size.y <= 0.0 \
		or bbox.position.x < -1.0 or bbox.position.y < -1.0 \
		or bbox.position.x + bbox.size.x > native.x + 1.0 \
		or bbox.position.y + bbox.size.y > native.y + 1.0

	if not native_lies and not bbox_oob:
		return {"native": native, "bbox": bbox, "foot": foot, "remeasured": false}

	# Pixel truth: alpha bbox + foot = bottom-center of the silhouette.
	var w := img.get_width()
	var h := img.get_height()
	var l := w; var r := -1; var t := h; var b := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > ALPHA:
				l = mini(l, x); r = maxi(r, x); t = mini(t, y); b = maxi(b, y)
	if r < 0:
		return {"native": native, "bbox": Rect2(0, 0, native.x, native.y), "foot": native * Vector2(0.5, 1.0), "remeasured": true}
	# Foot x: center of the bottom-most opaque row span.
	var fl := w; var fr := -1
	for x in range(w):
		if img.get_pixel(x, b).a > ALPHA:
			fl = mini(fl, x); fr = maxi(fr, x)
	return {
		"native": native,
		"bbox": Rect2(l, t, r - l + 1, b - t + 1),
		"foot": Vector2(float(fl + fr) * 0.5, float(b)),
		"remeasured": true,
	}

static func _vec(raw: Variant) -> Vector2:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO

static func _rect(raw: Variant) -> Rect2:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 4:
		return Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
	return Rect2()
```

(Full-resolution pixel scan on a 1536×1024 master is a few seconds per remeasured frame in GDScript — acceptable for a 25-frame batch tool.)

- [ ] **Step 4: Run to verify it passes** — `./run.sh --test`, 4 new asserts green.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/visual/master_geometry.gd WUGodot/tests/test_master_geometry.gd WUGodot/tests/run_tests.gd
git commit -m "feat(pipeline): MasterGeometry trusted-geometry resolver"
```

---

## Task 2: Patch scale_masters + uniformity gate

**Files:**
- Modify: `WUGodot/tools/scale_masters.gd`

- [ ] **Step 1: Load the image during collection and resolve geometry through the helper**

In `_collect` (`scale_masters.gd:112-144`), load each master image and replace the sidecar-trusting fields:

```gdscript
				var meta: Dictionary = _read_dict(sidecar)
				var img: Image = Image.new()
				if img.load(png) != OK:
					printerr("failed to load %s" % png)
					quit(1)
					return []
				var geo: Dictionary = MasterGeometryScript.resolve(img, meta)
				if bool(geo["remeasured"]):
					print("NOTE %s/%s: sidecar geometry untrusted (native/bbox mismatch) -> pixel-remeasured" % [action, file_name])
				out.append({
					"png": png,
					"side": sidecar,
					"action": action,
					"img": img,                      # keep the loaded image; do not reload later
					"native": geo["native"] as Vector2,
					"bbox": geo["bbox"] as Rect2,
					"foot": geo["foot"] as Vector2,
				})
```

Add the preload at the top: `const MasterGeometryScript = preload("res://scripts/visual/master_geometry.gd")`. In the main loop, delete the second `img.load` (`:64-69`) and use `frame_dict["img"]`.

**Also restructure the reference derivation** — `_idle_reference()` (`:99-110`) currently reads `_rect(meta.get("bbox")).size.y` straight from the raw sidecar *before* `_collect` runs, so the base scale itself would still be computed from untrusted geometry. Reorder `_init()`: **collect (resolved) frames first, then derive the reference from the resolved idle frame**:

```gdscript
	var frames: Array = _collect(run_dir)          # resolved via MasterGeometry
	var ref_px: float = 0.0
	for frame in frames:                            # first sorted idle frame's TRUSTED bbox height
		var fd: Dictionary = frame as Dictionary
		if str(fd["action"]) == "idle":
			ref_px = (fd["bbox"] as Rect2).size.y
			break
	if ref_px <= 0.0:
		printerr("no resolvable idle master in %s" % run_dir)
		quit(1)
		return
	var base: float = MasterNormalizerScript.base_scale(ref_px, TARGET_TEXELS, DENSITY)
```

Delete `_idle_reference()` entirely (its only caller is gone).

- [ ] **Step 2: Add the uniformity gate — measured from PIXELS after the blit**

**Do NOT compare against `p["scaled_bbox"]`** — `MasterNormalizer.plan` computes it as `bbox * scale`, so its aspect equals the source's *by construction* (a tautology that would have passed the original bug). The gate must remeasure the **actual rendered content** on the canvas after `blit_rect` and compare that to the source geometry:

```gdscript
			# After canvas.blit_rect(...), before save:
			var measured: Rect2 = _alpha_bbox(canvas)   # stride-2 alpha scan of the real pixels
			var src_bbox: Rect2 = frame_dict["bbox"] as Rect2
			var src_aspect: float = src_bbox.size.x / maxf(src_bbox.size.y, 1.0)
			var got_aspect: float = measured.size.x / maxf(measured.size.y, 1.0)
			if absf(got_aspect / maxf(src_aspect, 0.0001) - 1.0) > 0.02:
				printerr("UNIFORMITY VIOLATION %s: source content aspect %.3f, rendered %.3f" % [str(frame_dict["png"]), src_aspect, got_aspect])
				quit(1)
				return
```

with the helper added to the tool:

```gdscript
func _alpha_bbox(img: Image) -> Rect2:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var l: int = w; var r: int = -1; var t: int = h; var b: int = -1
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			if img.get_pixel(x, y).a > 0.5:
				l = mini(l, x); r = maxi(r, x); t = mini(t, y); b = maxi(b, y)
	return Rect2(l, t, maxi(r - l + 2, 1), maxi(b - t + 2, 1))
```

This catches the original bug class (resize box from bad inputs) AND any future one (e.g. a wrong resize call), because it checks what actually landed on the canvas. (Stride-2 scan of a ~1.2k×0.7k canvas ×25 frames is seconds — fine for a batch tool.)

- [ ] **Step 3: Sanity-run on the archived masters**

```bash
./run.sh --scale-masters ~/WU-art-masters/wu-smooth-hu-run2    # work on the ARCHIVE COPY? No —
```

**Work on a scratch copy** so the archive stays pristine:

```bash
rsync -a ~/WU-art-masters/wu-smooth-hu-run2/ /tmp/wu-hu-rescale/
./run.sh --scale-masters /tmp/wu-hu-rescale
```

Expected: `NOTE …pixel-remeasured` lines (the lying sidecars), **no uniformity violations**, a **wider** common canvas than 828×720 (X un-squeezes by ~1.5), and the printed `out-size for pixelize: W:H`. Spot-check one scaled master visually: the idle should look like the pristine (normal width), not the old narrow one.

- [ ] **Step 4: Commit the tool fix**

```bash
git add WUGodot/tools/scale_masters.gd
git commit -m "fix(pipeline): scale_masters trusts image dims, remeasures lying sidecars, gates uniformity"
```

---

## Task 3: Rerun pixelize + install (corrected art)

**Files (regenerated outputs; commit in Task 4 together with reach):**
- `WUGodot/assets/sprites/characters/hu/*.png`, `hu.manifest.json`, `character_hu.json` offsets, `DefaultProfiles.json` yOffset, `tools/hu_capsule_overrides.json`

- [ ] **Step 1: Pixelize at the printed out-size**

```bash
aiexp sprite-extractor pixelize /tmp/wu-hu-rescale --out-size <W>:<H> --palette vinik24 --fit-mode pad
```

- [ ] **Step 2: Clear stale capsule overrides**

`tools/hu_capsule_overrides.json` was tuned against squeezed geometry — reset it to `{}` (re-tune in Task 5 only if the capture shows misalignment).

- [ ] **Step 3: Install + gates**

```bash
./run.sh --install-pixelized /tmp/wu-hu-rescale
./run.sh --import
./run.sh --anchor-sanity
```

**Make the sanity gate real first:** `anchor_sanity.gd` currently **allowlists all Hu poses** (`OVERRIDE_ALLOWLIST`, sidecar-sourced era), so its stored-vs-measured drift check is skipped for exactly the frames we're correcting — as-is it's only a coarse bounds check. **Clear the Hu entries from the allowlist** in this task; with the corrected pipeline the stored (sidecar) anchors and AnchorMeasure's pixel measurements should now agree. Re-add a specific pose only if a legitimate, documented mismatch remains.

Note the installer's printed `yOffset` and set it in `DefaultProfiles.json` if changed. Expected: installed idle silhouette aspect ≈ **0.50** (was 0.32) — verify:
the quickest check is the existing measurement pattern (AnchorMeasure on `idle_0.png`); also confirm character texel height stayed ≈ the previous install (~same on-screen height; only width changes). **If the height changed too**, the pixelize fit semantics shifted with the wider canvas — stop and reconcile out-size before proceeding (this is the open T=145→178 mapping question; height parity with enemies must be preserved).

- [ ] **Step 4: Full suite**

`./run.sh --test` → reach-consistency asserts will likely FAIL now (reach grew with the un-squeezed blade) — that's expected; fix in Task 4, do not paper over.

---

## Task 4: Re-derive reach + balance re-sync (data-only, thanks to A1)

**Files:**
- Modify: `WUGodot/data/Attacks/Attacks.json` (`hu_light`/`hu_heavy` `range_units`; enemy attack ranges), `WUGodot/data/Enemies/*.json` (`preferredRange`)
- Modify: `WUGodot/tests/test_attack_data.gd` — **the A1 goldens pin the old values** (`hu_light.range_units == 210.0` in two places; `bear_crush_grab == 170.0`); update them to the new numbers as **deliberate balance edits** in the same commit, or the suite fails on purpose-changed data.

- [ ] **Step 1: Re-derive Hu reach**

Run the derived-reach probe (register Hu, advance into active, `pc.derived_reach`) for light + heavy; set `range_units = derived_reach − 22` in **Attacks.json** (data edit now, not code). Expect roughly **~1.4–1.5×** the current 210/234 (the X-axis un-squeeze) — record the actual numbers.

- [ ] **Step 2: Re-sync the enemy band (attack ranges scale; preferredRange is DERIVED, not scaled)**

Keep the established fairness band: enemies connect at **70–85%** of Hu's new c2c reach (spearman top, basic bandit bottom, assassin exempt). Mechanically:
1. Multiply each enemy **attack's `range_units`** (Attacks.json) by the factor Hu's reach grew; round sensibly.
2. **Recompute** each enemy's `preferredRange = (new shortest attack in its pattern_table).range_units − attacker.half_width` — do **not** multiply the old preferredRange by the factor. The two thresholds use different offsets (AI commits at `preferredRange + ai.half_width + target.half_width`; hits land at `range_units + defender.half_width`), so scaling both by the same factor breaks the commit⊆hit guarantee; deriving preserves it exactly (per-enemy half-widths: 22 normal, 24 disciple, 30 bear, as established).

This preserves the band ratios, so the prior balance playtest conclusions carry over; one confirmation fight per archetype in Task 5 instead of a full re-tune.

- [ ] **Step 3: Update the A1 goldens + tests green**

In `test_attack_data.gd`, update the pinned values (`hu_light` 210.0 → new, `bear_crush_grab` 170.0 → new, plus any other pinned enemy range that changed) — these tests exist to make balance changes *deliberate*, and this is one. Then `./run.sh --test` → reach-consistency (reads `range_units`+22 vs derived) and dormancy (range-relative) pass with the new values; full suite 0 failed.

- [ ] **Step 4: Commit art + reach + balance atomically**

```bash
git add WUGodot/assets/sprites/characters/hu/ WUGodot/assets/animation_manifests/hu.manifest.json \
        WUGodot/assets/animations/character_hu.json WUGodot/data/VisualProfiles/DefaultProfiles.json \
        WUGodot/data/Attacks/Attacks.json WUGodot/data/Enemies/ WUGodot/tools/hu_capsule_overrides.json \
        WUGodot/tools/anchor_sanity.gd WUGodot/tests/test_attack_data.gd
git commit -m "fix(art): un-squeeze Hu (corrected master scaling) + re-synced reach/balance/goldens"
```

---

## Task 5: Visual + balance acceptance

- [ ] **Step 1: Capture all states** — `./run.sh --shot-combat /tmp/wu-unsqueezed` (the hook forces all player states).

- [ ] **Step 2: Verify**
- **Width restored**: idle Hu reads like the pristine master (normal build) and no longer waif-like next to the ronin; measured idle aspect ≈ 0.50.
- **No height change**: Hu still ~same on-screen height as enemies (~350 px).
- **Feet planted, capsule on the blade** (overrides were cleared — re-tune via `hu_capsule_overrides.json` only if visibly off, then re-derive reach again if you touch `weaponTip`).
- **Tone note**: the block-frame color-tune drift is **not** fixed by this plan (generation-side; tracked separately) — don't chase it here.

- [ ] **Step 3: One confirmation fight per archetype** — trades should feel like the pre-fix balance (ratios preserved by construction). Adjust only obvious outliers.

- [ ] **Step 4: Final gates + commit any capture-driven tuning**

`./run.sh --test`, `--import`, `--anchor-sanity`, `git diff --check` — all clean.

---

## Self-Review Notes

- **Root cause, not symptom**: fixes the geometry-trust bug (image dims win; pixel-remeasure on mismatch) rather than rescaling the squeezed outputs; pristine masters make regeneration unnecessary.
- **Never again**: the uniformity gate hard-fails the tool on any content-aspect change; the lying-sidecar case is unit-tested (Task 1 case 2 mirrors the real 1024-vs-1536 bug).
- **Balance preserved by construction**: enemy band re-synced by the same growth factor, keeping the playtested ratios; only confirmation fights needed.
- **Archive first** (Task 0): the fix is only possible while the pristine masters exist; they currently live in volatile `/tmp`.
- **Known open items deliberately out of scope**: block-frame tone drift (generation-side; aiexp reference-conditioning request), the pixelize T=145→178 fit-semantics question (guarded by Task 3 Step 3's height check; full reconciliation before the enemy rollout), enemy-roster pipeline rollout.
- **Honest uncertainty**: the sidecar `bbox`/`foot` space (PNG vs claimed-native) is inferred, not documented — the helper sidesteps it by remeasuring whenever `native_size` disagrees with the image, which covers both interpretations.

**Review fixes folded in:**
- **Gate tautology** — the uniformity gate now remeasures the **actual alpha bbox on the blitted canvas** (`_alpha_bbox`), not `p["scaled_bbox"]` (which is `bbox*scale` and matches the source aspect by construction — it would have passed the original bug).
- **Reference path** — `_idle_reference()` deleted; the base scale derives from the **resolved** idle frame after `_collect`, so untrusted sidecar geometry can no longer set the global scale.
- **A1 goldens** — `test_attack_data.gd` added to Task 4 (pins `hu_light 210` / `bear_crush_grab 170`); updated as deliberate balance edits in the same atomic commit.
- **preferredRange rule** — attack ranges scale; `preferredRange` is **recomputed** (`shortest attack − attacker.half_width`), never multiplied, because the commit (+44) and hit (+22) thresholds use different offsets.
- **anchor-sanity claim** — the Hu allowlist is cleared in Task 3 so the drift gate is actually live for the corrected frames (previously skipped, making the gate coarse-only).
- **A1 boundary** — `attack_catalog.gd` removed from the inventory; all reach edits live in `Attacks.json` data.
