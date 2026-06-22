# Boon Move-Skin System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A boon infusing a move slot makes that move render a distinct, school-specific animation clip (Venom slice: light/heavy/dash), with a base-clip + school-recolor fallback for un-arted slots, all on the player only.

**Architecture:** The player renders through `FighterPresenter` (manifest → poses, graph → state→clip, timeline clips). We insert a pure `MoveSkinResolver` into the presenter's clip selection: state → slot → infusing 流 → variant clip if registered, else base clip + recolor flag. The loadout supplies the static slot→school map at combat setup and the per-frame active-stance school; gameplay timing is untouched (already flows through the technique engine; attack variant clips use `duration:"fromAttackDef"`).

**Tech Stack:** Godot 4.6.2, GDScript. Tests are RefCounted classes exposing `run_all() -> {passed, failed, failures}`, registered in `WUGodot/tests/run_tests.gd`, run via `./run.sh --test` (expect `failed: 0`). Asset/import changes need `./run.sh --import`.

**Spec:** `docs/superpowers/specs/2026-06-22-wu-boon-move-skin-design.md`

---

## File Structure

**Create:**
- `WUGodot/scripts/visual/move_skin_resolver.gd` — pure state→slot map + clip/recolor resolution (no engine deps; fully unit-testable).
- `WUGodot/assets/animation_clips/skins/venom/venom_hu_attack_light.timeline.json`, `…/venom_hu_attack_heavy.timeline.json`, `…/venom_held_dash.timeline.json` — Venom variant clips (placeholder frames in Phase A; real art in Phase B via the gate).
- `WUGodot/tests/test_move_skin_resolver.gd` — resolver unit tests.
- `WUGodot/tests/test_move_skin_presenter.gd` — presenter skin-routing + tint tests.

**Modify:**
- `WUGodot/scripts/boons/boon_loadout.gd` — add `move_slot_schools()` and `school_for_effect_id()`.
- `WUGodot/scripts/visual/shaders/fighter_presenter.gdshader` — add `skin_tint` + `skin_tint_weight` uniforms (under `flash`).
- `WUGodot/scripts/visual/fighter_presenter.gd` — skin registration, resolver-based clip selection, recolor/stance tint.
- `WUGodot/scripts/combat_scene.gd` — `setup_combat` loadout param, store it, `set_move_skins` at setup, per-frame `set_active_stance_school`.
- `WUGodot/scripts/main.gd` — pass `run_state.boon_loadout` into `setup_combat`.
- `WUGodot/tests/run_tests.gd` — register the two new test files.
- `WUGodot/tests/test_boon_loadout.gd` — add cases for the two new loadout methods.

---

## Task 1: Loadout — slot→school map + effect-id→school lookup

**Files:**
- Modify: `WUGodot/scripts/boons/boon_loadout.gd`
- Test: `WUGodot/tests/test_boon_loadout.gd`

Reviewer note this implements: `TechniqueEngine.active_stance()` returns an effect id (`boon_id#index`), **not** a school. Map it to a school through the loadout record, never by string-parsing the id.

- [ ] **Step 1: Write the failing test** — append to `test_boon_loadout.gd`'s `run_all()` (before the final `return`), reusing its existing `passed/failed/failures` counters:

```gdscript
	# --- move-skin support: slot->school map ---
	var skin_loadout: Variant = BoonLoadoutScript.new()
	skin_loadout.add_boon("venom_light", "common")
	skin_loadout.add_boon("venom_dash", "common")
	var slot_schools: Dictionary = skin_loadout.move_slot_schools()
	if str(slot_schools.get("light", "")) == "venom" and str(slot_schools.get("dash", "")) == "venom" and not slot_schools.has("heavy"):
		passed += 1
	else:
		failed += 1
		failures.append("move_slot_schools should map only infused slots to their school")

	# --- move-skin support: effect-id -> school ---
	# Bind an engine so records install real effects (each has an .id of boon_id#index).
	var skin_engine: Variant = TechniqueEngineScript.new()
	var skin_fighter: Variant = FighterScript.new()
	var bound_loadout: Variant = BoonLoadoutScript.new(skin_engine, skin_fighter)
	bound_loadout.add_boon("venom_light", "common")
	var first_effect_id: String = ""
	for record in bound_loadout._all_records():
		for effect in record.get("effects", []) as Array:
			first_effect_id = str(effect.id)
			break
	if not first_effect_id.is_empty() and bound_loadout.school_for_effect_id(first_effect_id) == "venom" and bound_loadout.school_for_effect_id("nope#9") == "":
		passed += 1
	else:
		failed += 1
		failures.append("school_for_effect_id should resolve installed effect ids to their boon school")
```

Add these preloads at the top of `test_boon_loadout.gd` if absent (check the existing `const` block first):

```gdscript
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")
const FighterScript = preload("res://scripts/fighter.gd")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — `test_boon_loadout` reports failures like "Invalid call. Nonexistent function 'move_slot_schools'".

- [ ] **Step 3: Implement** — add to `boon_loadout.gd` (place after `school_boon_count`, before `serialize`):

```gdscript
func move_slot_schools() -> Dictionary:
	var out: Dictionary = {}
	for slot in slots.keys():
		var boon: Dictionary = (slots[slot] as Dictionary).get("boon", {}) as Dictionary
		out[str(slot)] = str(boon.get("school", ""))
	return out

func school_for_effect_id(effect_id: String) -> String:
	if effect_id.is_empty():
		return ""
	for record in _all_records():
		for effect in record.get("effects", []) as Array:
			if effect != null and str(effect.id) == effect_id:
				return str((record.get("boon", {}) as Dictionary).get("school", ""))
	return ""
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `./run.sh --test`
Expected: PASS — `failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/boons/boon_loadout.gd WUGodot/tests/test_boon_loadout.gd
git commit -m "feat(boons): loadout move_slot_schools + school_for_effect_id"
```

---

## Task 2: MoveSkinResolver (pure resolution)

**Files:**
- Create: `WUGodot/scripts/visual/move_skin_resolver.gd`
- Create: `WUGodot/tests/test_move_skin_resolver.gd`
- Modify: `WUGodot/tests/run_tests.gd`

- [ ] **Step 1: Write the failing test** — create `WUGodot/tests/test_move_skin_resolver.gd`:

```gdscript
extends RefCounted

const ResolverScript = preload("res://scripts/visual/move_skin_resolver.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	# state -> slot mapping (only move slots map; non-move states return "")
	var slot_cases: Dictionary = {
		"ATTACKING_LIGHT": "light", "ATTACKING_HEAVY": "heavy", "DASHING": "dash",
		"BLOCKING": "block", "JUMPING": "jump", "FALLING": "jump",
		"IDLE": "", "WALKING": "", "HIT_REACTION": "", "STUNNED": "", "LANDING": "", "COMBAT_ENTRY": "",
	}
	var slots_ok: bool = true
	for state_name in slot_cases.keys():
		if ResolverScript.slot_for_state(str(state_name)) != str(slot_cases[state_name]):
			slots_ok = false
	if slots_ok:
		passed += 1
	else:
		failed += 1
		failures.append("slot_for_state must map move states to slots and non-move states to ''")

	var slot_school_map: Dictionary = {"light": "venom", "block": "venom"}
	var variant_ids: Dictionary = {"venom:ATTACKING_LIGHT": "venom_hu_attack_light"}

	# infused + variant exists -> variant clip, no recolor
	var r1: Dictionary = ResolverScript.resolve("ATTACKING_LIGHT", "hu_attack_light", slot_school_map, variant_ids)
	if str(r1["clip_id"]) == "venom_hu_attack_light" and str(r1["recolor_school"]) == "":
		passed += 1
	else:
		failed += 1
		failures.append("resolve: infused slot with a variant clip should pick the variant, no recolor")

	# infused + no variant -> base clip + recolor with school
	var r2: Dictionary = ResolverScript.resolve("BLOCKING", "held_block", slot_school_map, variant_ids)
	if str(r2["clip_id"]) == "held_block" and str(r2["recolor_school"]) == "venom":
		passed += 1
	else:
		failed += 1
		failures.append("resolve: infused slot without a variant should keep base clip and flag recolor")

	# not infused -> base clip, no recolor
	var r3: Dictionary = ResolverScript.resolve("ATTACKING_HEAVY", "hu_attack_heavy", slot_school_map, variant_ids)
	if str(r3["clip_id"]) == "hu_attack_heavy" and str(r3["recolor_school"]) == "":
		passed += 1
	else:
		failed += 1
		failures.append("resolve: uninfused slot should keep base clip, no recolor")

	# non-move state is never skinned even if some loadout exists
	var r4: Dictionary = ResolverScript.resolve("IDLE", "idle", slot_school_map, variant_ids)
	if str(r4["clip_id"]) == "idle" and str(r4["recolor_school"]) == "":
		passed += 1
	else:
		failed += 1
		failures.append("resolve: non-move states must never be skinned or recolored")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Register the test** — in `WUGodot/tests/run_tests.gd`, add to the test path array (next to the other `test_animation_*` entries):

```gdscript
	"res://tests/test_move_skin_resolver.gd",
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — cannot load `move_skin_resolver.gd` (file does not exist yet).

- [ ] **Step 4: Implement** — create `WUGodot/scripts/visual/move_skin_resolver.gd`:

```gdscript
class_name MoveSkinResolver
extends RefCounted

# The only animation states that map to a boon move slot (and are therefore skinnable).
# Jump owns JUMPING + FALLING; LANDING and all non-move states are never skinned.
const STATE_SLOT: Dictionary = {
	"ATTACKING_LIGHT": "light",
	"ATTACKING_HEAVY": "heavy",
	"DASHING": "dash",
	"BLOCKING": "block",
	"JUMPING": "jump",
	"FALLING": "jump",
}

static func slot_for_state(state_name: String) -> String:
	return str(STATE_SLOT.get(state_name, ""))

static func variant_key(school: String, state_name: String) -> String:
	return "%s:%s" % [school, state_name]

# Returns {clip_id, recolor_school}. recolor_school is "" unless the slot is infused
# by a school that has no registered variant clip for this state.
static func resolve(state_name: String, base_clip_id: String, slot_school_map: Dictionary, variant_ids: Dictionary) -> Dictionary:
	var slot: String = slot_for_state(state_name)
	if slot.is_empty() or not slot_school_map.has(slot):
		return {"clip_id": base_clip_id, "recolor_school": ""}
	var school: String = str(slot_school_map[slot])
	if school.is_empty():
		return {"clip_id": base_clip_id, "recolor_school": ""}
	var key: String = variant_key(school, state_name)
	if variant_ids.has(key):
		return {"clip_id": str(variant_ids[key]), "recolor_school": ""}
	return {"clip_id": base_clip_id, "recolor_school": school}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `./run.sh --test`
Expected: PASS — `failed: 0`.

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/visual/move_skin_resolver.gd WUGodot/tests/test_move_skin_resolver.gd WUGodot/tests/run_tests.gd
git commit -m "feat(visual): MoveSkinResolver pure clip/recolor resolution"
```

---

## Task 3: Shader — skin_tint uniforms (flash keeps priority)

**Files:**
- Modify: `WUGodot/scripts/visual/shaders/fighter_presenter.gdshader`

- [ ] **Step 1: Add the uniforms** — after the existing `dissolve` uniform line, add:

```glsl
uniform vec4 skin_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float skin_tint_weight : hint_range(0.0, 1.0) = 0.0;
```

- [ ] **Step 2: Apply the tint UNDER flash** — in `fragment()`, replace the single flash line:

```glsl
	col.rgb = mix(col.rgb, vec3(1.0), flash);
```

with (tint first, then flash, so the teaching flash always wins):

```glsl
	col.rgb = mix(col.rgb, skin_tint.rgb, skin_tint_weight);
	col.rgb = mix(col.rgb, vec3(1.0), flash);
```

- [ ] **Step 3: Verify the shader compiles**

Run: `./run.sh --import`
Expected: Completes with no shader compile errors in output.

- [ ] **Step 4: Commit**

```bash
git add WUGodot/scripts/visual/shaders/fighter_presenter.gdshader
git commit -m "feat(visual): add skin_tint uniforms to presenter shader (under flash)"
```

---

## Task 4: Venom placeholder variant clips

**Files:**
- Create: `WUGodot/assets/animation_clips/skins/venom/venom_hu_attack_light.timeline.json`
- Create: `WUGodot/assets/animation_clips/skins/venom/venom_hu_attack_heavy.timeline.json`
- Create: `WUGodot/assets/animation_clips/skins/venom/venom_held_dash.timeline.json`

These are **placeholders** so the routing system is live and testable now; Phase B replaces their frames with real Venom art through the animation gate. The fastest safe placeholder is a copy of each base clip with a new `id`, so every referenced pose already exists in the base manifest (renders non-blank, valid timing).

- [ ] **Step 1: Create the light variant** — copy the base clip and rename its id:

```bash
mkdir -p WUGodot/assets/animation_clips/skins/venom
```

Then create `venom_hu_attack_light.timeline.json` as an exact copy of `WUGodot/assets/animation_clips/hu_attack_light.timeline.json` with **only** the top-level `"id"` changed to `"venom_hu_attack_light"`. (Read the base file, copy its full contents, change the id.)

- [ ] **Step 2: Create the heavy variant** — copy `hu_attack_heavy.timeline.json`, set `"id": "venom_hu_attack_heavy"`.

- [ ] **Step 3: Create the dash variant** — copy `held_dash.timeline.json`, set `"id": "venom_held_dash"`.

- [ ] **Step 4: Import the new assets**

Run: `./run.sh --import`
Expected: Completes; the three new `.timeline.json` files are picked up (they are JSON data, loaded at runtime via `AnimationClipTimeline.load_from_file`, so no `.import` sidecar is required — confirm no errors).

- [ ] **Step 5: Commit**

```bash
git add WUGodot/assets/animation_clips/skins/venom/
git commit -m "feat(visual): venom placeholder variant clips (light/heavy/dash)"
```

---

## Task 5: Presenter — skin registration, clip routing, tint

**Files:**
- Modify: `WUGodot/scripts/visual/fighter_presenter.gd`
- Create: `WUGodot/tests/test_move_skin_presenter.gd`
- Modify: `WUGodot/tests/run_tests.gd`

The presenter gains: a static slot→school map (`set_move_skins`), a per-frame active-stance school (`set_active_stance_school`), resolver-based clip selection in `_maybe_change_state`, and per-frame `skin_tint` application in `update`. Variant clips are lazy-loaded by file-path convention `skins/<school>/<school>_<base_clip_id>.timeline.json`; a missing file simply means fallback. Overlay manifest poses (`skins/<school>.manifest.json`) are merged when present (Phase B adds Venom's).

- [ ] **Step 1: Write the failing test** — create `WUGodot/tests/test_move_skin_presenter.gd`:

```gdscript
extends RefCounted

const FighterPresenterScript = preload("res://scripts/visual/fighter_presenter.gd")
const AssetCatalogScript = preload("res://scripts/visual/asset_catalog.gd")

func _configured_presenter() -> Variant:
	var presenter: Variant = FighterPresenterScript.new(AssetCatalogScript.new())
	presenter.configure(
		"res://assets/animation_manifests/hu.manifest.json",
		"res://assets/animation_graphs/humanoid.graph.json",
		[
			"res://assets/animation_clips/hu_attack_light.timeline.json",
			"res://assets/animation_clips/hu_attack_heavy.timeline.json",
			"res://assets/animation_clips/held_dash.timeline.json",
			"res://assets/animation_clips/held_block.timeline.json",
			"res://assets/animation_clips/idle.timeline.json",
		],
		1.625
	)
	return presenter

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	# Venom infuses light + block. Light has a variant clip; block does not.
	var presenter: Variant = _configured_presenter()
	presenter.set_move_skins({"light": "venom", "block": "venom"})

	if presenter.resolve_state_clip_id("ATTACKING_LIGHT") == "venom_hu_attack_light":
		passed += 1
	else:
		failed += 1
		failures.append("infused light should resolve to the venom variant clip id")

	if presenter.resolve_state_clip_id("BLOCKING") == "held_block" and presenter.recolor_school_for("BLOCKING") == "venom":
		passed += 1
	else:
		failed += 1
		failures.append("infused block without a variant should keep base clip and recolor venom")

	if presenter.resolve_state_clip_id("ATTACKING_HEAVY") == "hu_attack_heavy" and presenter.recolor_school_for("ATTACKING_HEAVY") == "":
		passed += 1
	else:
		failed += 1
		failures.append("uninfused heavy should keep base clip, no recolor")

	if presenter.recolor_school_for("IDLE") == "" and presenter.resolve_state_clip_id("IDLE") == "idle":
		passed += 1
	else:
		failed += 1
		failures.append("non-move state IDLE must never be skinned or recolored")

	# Active-stance tint route: set school -> reported; clear -> empty.
	presenter.set_active_stance_school("thunder")
	if presenter.active_tint_school_for("IDLE") == "thunder":
		passed += 1
	else:
		failed += 1
		failures.append("active stance school should tint even on non-move states")
	presenter.set_active_stance_school("")
	if presenter.active_tint_school_for("IDLE") == "":
		passed += 1
	else:
		failed += 1
		failures.append("clearing active stance should remove the tint")

	# Per-move recolor takes precedence over stance tint on its own move state.
	presenter.set_active_stance_school("thunder")
	if presenter.active_tint_school_for("BLOCKING") == "venom":
		passed += 1
	else:
		failed += 1
		failures.append("an infused-unskinned move state should recolor with its own school over the stance tint")

	# handles_state stays true for skinnable states after set_move_skins (base clip always present).
	if presenter.handles_state("ATTACKING_LIGHT") and presenter.handles_state("DASHING"):
		passed += 1
	else:
		failed += 1
		failures.append("handles_state should remain true for skinnable states after skins are set")

	# Reconfigure (next combat) must reset all skin caches so stale skins/poses don't leak.
	# Skin with venom + an active stance, THEN reconfigure, and assert the cache dicts are
	# empty *directly* (calling set_move_skins({}) afterward would mask stale caches).
	var reconfigured: Variant = _configured_presenter()
	reconfigured.set_move_skins({"light": "venom"})
	reconfigured.set_active_stance_school("thunder")
	reconfigured.configure(  # simulate combat 2 starting fresh
		"res://assets/animation_manifests/hu.manifest.json",
		"res://assets/animation_graphs/humanoid.graph.json",
		["res://assets/animation_clips/hu_attack_light.timeline.json", "res://assets/animation_clips/idle.timeline.json"],
		1.625
	)
	if reconfigured._variant_ids.is_empty() and reconfigured._slot_school_map.is_empty() and reconfigured._loaded_skin_schools.is_empty() and reconfigured._active_stance_school == "" and reconfigured._recolor_school == "":
		passed += 1
	else:
		failed += 1
		failures.append("configure() must clear skin caches (variant_ids/slot_school_map/loaded_skin_schools/stance/recolor)")

	# And resolution after a clean reconfigure with no skins returns base, no recolor.
	if reconfigured.resolve_state_clip_id("ATTACKING_LIGHT") == "hu_attack_light" and reconfigured.recolor_school_for("ATTACKING_LIGHT") == "":
		passed += 1
	else:
		failed += 1
		failures.append("after reconfigure with no skins, light should resolve to the base clip")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Register the test** — in `WUGodot/tests/run_tests.gd` add:

```gdscript
	"res://tests/test_move_skin_presenter.gd",
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — "Nonexistent function 'set_move_skins'".

- [ ] **Step 4: Implement — members + preload** — in `fighter_presenter.gd`, add near the top consts:

```gdscript
const MoveSkinResolverScript = preload("res://scripts/visual/move_skin_resolver.gd")
const SKIN_TINT_WEIGHT: float = 0.35
```

and with the other `var` members:

```gdscript
var _slot_school_map: Dictionary = {}
var _variant_ids: Dictionary = {}
var _loaded_skin_schools: Dictionary = {}
var _active_stance_school: String = ""
var _recolor_school: String = ""
```

- [ ] **Step 5: Implement — skin registration API** — add these methods (e.g. after `handles_state`):

```gdscript
func set_move_skins(slot_school_map: Dictionary) -> void:
	_slot_school_map = slot_school_map.duplicate(true)
	for slot in _slot_school_map.keys():
		var school: String = str(_slot_school_map[slot])
		if school.is_empty():
			continue
		_load_skin_manifest(school)
		for state_name in MoveSkinResolverScript.STATE_SLOT.keys():
			if str(MoveSkinResolverScript.STATE_SLOT[state_name]) != str(slot):
				continue
			_load_variant_clip(school, str(state_name))

func set_active_stance_school(school: String) -> void:
	_active_stance_school = school

func resolve_state_clip_id(state_name: String) -> String:
	var base_clip_id: String = _graph.clip_for(state_name) if _graph != null else "idle"
	return str(MoveSkinResolverScript.resolve(state_name, base_clip_id, _slot_school_map, _variant_ids)["clip_id"])

func recolor_school_for(state_name: String) -> String:
	var base_clip_id: String = _graph.clip_for(state_name) if _graph != null else "idle"
	return str(MoveSkinResolverScript.resolve(state_name, base_clip_id, _slot_school_map, _variant_ids)["recolor_school"])

# Per-move recolor (infused-unskinned slot) wins over the held active-stance tint.
func active_tint_school_for(state_name: String) -> String:
	var recolor: String = recolor_school_for(state_name)
	return recolor if not recolor.is_empty() else _active_stance_school

func _load_variant_clip(school: String, state_name: String) -> void:
	if _graph == null:
		return
	var base_clip_id: String = _graph.clip_for(state_name)
	var path: String = "res://assets/animation_clips/skins/%s/%s_%s.timeline.json" % [school, school, base_clip_id]
	if not FileAccess.file_exists(path):
		return
	var clip: Variant = TimelineScript.load_from_file(path)
	_clips[clip.id] = clip
	_variant_ids[MoveSkinResolverScript.variant_key(school, state_name)] = clip.id

func _load_skin_manifest(school: String) -> void:
	if _loaded_skin_schools.has(school) or _manifest == null:
		return
	_loaded_skin_schools[school] = true
	var path: String = "res://assets/animation_manifests/skins/%s.manifest.json" % school
	if not FileAccess.file_exists(path):
		return
	var overlay: Variant = AnimationManifestScript.load_from_file(path)
	for pose_name in overlay.poses.keys():
		_manifest.poses[str(pose_name)] = overlay.poses[pose_name]
```

Note: `AnimationManifestScript` must be preloaded — confirm/add at top: `const AnimationManifestScript = preload("res://scripts/visual/animation_manifest.gd")`.

- [ ] **Step 6: Implement — reset skin caches in `configure()`** — `configure()` reloads a fresh base manifest and clears `_clips` every combat (`fighter_presenter.gd:35`). The skin caches must reset there too, or combat 2 will skip merging an overlay manifest (`_loaded_skin_schools` still set) while its poses are gone from the fresh `_manifest`. In `configure()`, alongside the existing resets (`_state = ""`, `_clip = null`, …), add:

```gdscript
	_slot_school_map.clear()
	_variant_ids.clear()
	_loaded_skin_schools.clear()
	_active_stance_school = ""
	_recolor_school = ""
```

- [ ] **Step 7: Implement — route clip selection through the resolver** — in `_maybe_change_state`, replace:

```gdscript
	_clip = _clips.get(_graph.clip_for(state_name), null) if _graph != null else null
```

with:

```gdscript
	_clip = _clips.get(resolve_state_clip_id(state_name), null) if _graph != null else null
	_recolor_school = recolor_school_for(state_name) if _graph != null else ""
```

- [ ] **Step 8: Implement — apply the tint each frame** — in `update`, in the shader-parameter block, after the `_mat_current.set_shader_parameter("flash", _flash)` line add:

```gdscript
	var tint_school: String = _recolor_school if not _recolor_school.is_empty() else _active_stance_school
	if tint_school.is_empty():
		_mat_current.set_shader_parameter("skin_tint_weight", 0.0)
		_mat_previous.set_shader_parameter("skin_tint_weight", 0.0)
	else:
		var skin_color: Color = Color.html(str(DataManager.get_school(tint_school).get("themeColor", "#ffffff")))
		_mat_current.set_shader_parameter("skin_tint", skin_color)
		_mat_current.set_shader_parameter("skin_tint_weight", SKIN_TINT_WEIGHT)
		# Mirror onto the outgoing dither sprite so a held tint doesn't flash untinted mid-transition.
		_mat_previous.set_shader_parameter("skin_tint", skin_color)
		_mat_previous.set_shader_parameter("skin_tint_weight", SKIN_TINT_WEIGHT)
```

- [ ] **Step 9: Run the test to verify it passes**

Run: `./run.sh --test`
Expected: PASS — `failed: 0` (including `test_move_skin_presenter` and the unchanged `test_presenter_bounds`/`test_presenter_offset`).

- [ ] **Step 10: Commit**

```bash
git add WUGodot/scripts/visual/fighter_presenter.gd WUGodot/tests/test_move_skin_presenter.gd WUGodot/tests/run_tests.gd
git commit -m "feat(visual): presenter move-skin routing + recolor/stance tint + configure reset"
```

---

## Task 6: Combat scene + main wiring

**Files:**
- Modify: `WUGodot/scripts/combat_scene.gd`
- Modify: `WUGodot/scripts/main.gd`

The loadout lives on `run_state.boon_loadout` but `setup_combat` does not receive `run_state`. Thread the loadout in (mirroring how `forced_archetype` was threaded for the difficulty curve), store it, push the static skin map at setup, and push the live stance school each frame.

- [ ] **Step 1: Add the loadout parameter + store it** — in `combat_scene.gd`, change the `setup_combat` signature:

```gdscript
func setup_combat(player: Fighter, node: MapNode, show_controls_legend: bool = false, forced_archetype: String = "", boon_loadout: Variant = null) -> void:
```

Add a member with the other `var`s near the top of the file:

```gdscript
var _boon_loadout: Variant = null
```

At the start of `setup_combat` body (right after `_player = player`), add:

```gdscript
	_boon_loadout = boon_loadout
```

- [ ] **Step 2: Push the static skin map after presenter.configure** — immediately after the `_player_presenter.configure(...)` call (and before/after the `timeline_event` connect), add:

```gdscript
	if _boon_loadout != null:
		_player_presenter.set_move_skins(_boon_loadout.move_slot_schools())
	else:
		_player_presenter.set_move_skins({})
```

- [ ] **Step 3: Push the live stance school each frame** — in `_update_player_presenter`, before the `if _player_presenter.handles_state(state_name):` block, add:

```gdscript
	var stance_school: String = ""
	if _boon_loadout != null and _player.technique_engine != null and _player.technique_engine.is_stance_active():
		stance_school = _boon_loadout.school_for_effect_id(_player.technique_engine.active_stance())
	_player_presenter.set_active_stance_school(stance_school)
```

- [ ] **Step 4: Update the live caller** — in `main.gd`, find the `_setup_combat_for_node` call to `_combat_scene.setup_combat(...)` (it currently passes `forced_archetype` from the encounter). Append the loadout argument:

```gdscript
	_combat_scene.setup_combat(_ctx.player, node, show_controls_legend, str(encounter.get("archetype", "")), _ctx.run_state.boon_loadout)
```

(Match the exact existing argument list at the call site; only add the trailing `_ctx.run_state.boon_loadout`.)

- [ ] **Step 5: Update the capture callers** — `_prepare_capture_matchup` and `_prepare_capture_character` in `main.gd` already call `_apply_capture_build(spec)` (which installs the spec's `build` boons onto `_ctx.run_state.boon_loadout`) **before** `setup_combat`, but they omit the loadout arg — so a `build` with `venom_light` would still render with no skins. In both functions, change:

```gdscript
	_combat_scene.setup_combat(_ctx.player, node, false, archetype)
```
(and the `_prepare_capture_character` variant `_combat_scene.setup_combat(_ctx.player, node, false, _capture_archetype(spec))`)

to pass the loadout. **In `_prepare_capture_matchup`** (it has a local `archetype`):

```gdscript
	_combat_scene.setup_combat(_ctx.player, node, false, archetype, _ctx.run_state.boon_loadout)
```

**In `_prepare_capture_character`** (no `archetype` local — it inlines `_capture_archetype(spec)`):

```gdscript
	_combat_scene.setup_combat(_ctx.player, node, false, _capture_archetype(spec), _ctx.run_state.boon_loadout)
```

- [ ] **Step 6: Find and check any other setup_combat callers**

Run: `grep -rn "setup_combat(" WUGodot/scripts WUGodot/tests`
Expected: confirm every caller still compiles. Callers that lack a loadout are safe — the param defaults to `null` (no skins). Only update a caller if it has a `run_state.boon_loadout` available and should show skins; otherwise leave it.

- [ ] **Step 7: Verify no regressions**

Run: `./run.sh --import && ./run.sh --test`
Expected: import clean; `failed: 0`.

- [ ] **Step 8: Commit**

```bash
git add WUGodot/scripts/combat_scene.gd WUGodot/scripts/main.gd
git commit -m "feat(combat): wire boon loadout -> presenter move-skins + stance tint"
```

---

## Task 7: Harness visual-capture smoke (end-to-end render proof)

**Files:**
- Modify: `WUGodot/scripts/combat_scene.gd` (add a capture-mode assertion print)
- Reference: capture infra — `./run.sh --capture spec.json [out]` → `main.gd:_run_dev_capture` (reads a JSON spec via `--capture-spec`), `tools/assert_nonblank.py`

**What this proves and doesn't:** the move-skin *clip swap* is already unit-proven in Task 5 (`resolve_state_clip_id("ATTACKING_LIGHT") == "venom_hu_attack_light"`). This task proves the **real renderer** runs the skinned path end-to-end: non-blank + deterministic, with an in-engine assertion that the player presenter actually selected the Venom variant during capture. With placeholder clips (exact base copies, Task 4), the PNG can look identical to base — so a **visual diff vs base is NOT asserted here**; that gate moves to Task 8 once real art lands. (The capture goes through the loadout because Task 6 Step 5 now passes the loadout into the capture callers, and `_apply_capture_build` installs the spec's `build` boons.)

- [ ] **Step 1: Add a capture-mode clip-swap assertion** — in `combat_scene.gd`, at the end of `dev_prepare_capture_state(state_name)`, after the player's state is set, print the resolved player clip id so the capture run self-verifies the skin path:

```gdscript
	if _player_presenter != null:
		var resolved_id: String = _player_presenter.resolve_state_clip_id(_resolve_player_state_name())
		print("CAPTURE CLIP: state=%s clip=%s" % [_resolve_player_state_name(), resolved_id])
```

- [ ] **Step 2: Write a capture spec with a Venom build** — create `/tmp/venom_light_spec.json`:

```json
{
  "kind": "matchup",
  "archetype": "bandit_swordsman",
  "state": "04_light_active",
  "build": [{"boon_id": "venom_light", "tier": "common"}]
}
```

(Confirm the `build` field shape against `_apply_capture_build` in `main.gd`; adjust to its expected keys if they differ — it is the same build format the existing matchup/character captures already accept.)

- [ ] **Step 3: Capture and assert non-blank + clip swap**

Run: `./run.sh --capture /tmp/venom_light_spec.json /tmp/venom_light.png`
Expected stdout includes `CAPTURE CLIP: state=ATTACKING_LIGHT clip=venom_hu_attack_light` (proves the renderer used the skin path).
Then: `python3 tools/assert_nonblank.py /tmp/venom_light.png`
Expected: reports the PNG is non-blank.

- [ ] **Step 4: Confirm determinism**

Run the capture twice to two files and compare:
`./run.sh --capture /tmp/venom_light_spec.json /tmp/a.png && ./run.sh --capture /tmp/venom_light_spec.json /tmp/b.png && cmp /tmp/a.png /tmp/b.png`
Expected: identical (no diff).

- [ ] **Step 5: Capture the recolor fallback (visible-tint proof)** — to prove the tint path renders visibly (since placeholder variants look like base), capture an **infused-but-unskinned** slot using a fixed boon: **`thunder_light`** (confirmed present in `data/Boons/Boons.json`, slot `light`, school `thunder`). It has no variant clip, so the resolver flags a Thunder recolor. Spec `/tmp/recolor_spec.json`:

```json
{
  "kind": "matchup",
  "archetype": "bandit_swordsman",
  "state": "04_light_active",
  "build": [{"boon_id": "thunder_light", "tier": "common"}]
}
```

Run: `./run.sh --capture /tmp/recolor_spec.json /tmp/recolor_light.png` then `cmp /tmp/recolor_light.png /tmp/base_light.png` (capture a no-build base light first). Expected: the recolored capture **differs** from base (tint is visible). `CAPTURE CLIP` line should show the **base** clip id (no variant), confirming this is the recolor path, not a variant swap.

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/combat_scene.gd
git commit -m "test(visual): capture-mode clip-swap assertion for move skins"
```

> **✋ STOP — report capture results to the user** (PNG paths, `CAPTURE CLIP` lines, assert/cmp output) before proceeding. First end-to-end visual proof; the user reviews it.

---

## Task 8: Venom slice art via the animation gate (content; user-gated)

**Files:**
- Replace placeholder frames in: `WUGodot/assets/animation_clips/skins/venom/venom_hu_attack_light.timeline.json` (then heavy, then dash)
- Create/extend: `WUGodot/assets/animation_manifests/skins/venom.manifest.json` (new Venom poses)
- Add new texture assets under `WUGodot/assets/` for the Venom poses

This task is the **art-generation workflow**, not autonomous coding. Each clip follows the gate (see [[review-keyframes-before-generating]], [[judge-art-size-overall-in-game]]) in order **light → heavy → dash**:

- [ ] **Step 1 (light):** Gate 1 — present Venom light-attack keyframe poses for user approval. **✋ STOP for approval.**
- [ ] **Step 2 (light):** Separate scale-vs-idle review of the approved poses. **✋ STOP for approval.**
- [ ] **Step 3 (light):** Generate frames; add textures; write the real poses into `skins/venom.manifest.json`; update `venom_hu_attack_light.timeline.json` keyposes/events to the Venom poses (keep `"duration": "fromAttackDef"`).
- [ ] **Step 4 (light):** `./run.sh --import`; capture via Task 7 and confirm the Venom light now **differs** from a base light capture (`cmp` shows a difference); in-game Gate 2 review. **✋ STOP for approval.**
- [ ] **Step 5 (light):** Commit: `git commit -m "feat(art): venom light attack move-skin"`.
- [ ] **Step 6:** Repeat Steps 1–5 for **heavy** (`venom_hu_attack_heavy`), then **dash** (`venom_held_dash`, `fixed_duration`, no `fromAttackDef`).
- [ ] **Step 7:** Record filled cells + remaining roadmap in the spec's §10 / a tracking note.

---

## Self-Review

**Spec coverage:**
- §3 state→slot map + never-skinned states → Task 2 (`STATE_SLOT`, resolver) + Task 5 test.
- §3 stance = active-mode recolor → Task 6 Step 3 (live route) + Task 5 tint precedence.
- §4 presenter render path, overlay clips/manifest, `set_move_skins`, lazy load → Task 5.
- §4 per-frame stance route via `is_stance_active()`/`active_stance()` mapped through loadout (not string parse) → Task 1 (`school_for_effect_id`) + Task 6.
- §4 shader `skin_tint`/`skin_tint_weight`, flash priority → Task 3.
- §4 timing via `duration:"fromAttackDef"` (no new system) → preserved; Venom attack variants keep the flag (Task 4 copy; Task 8 retains it).
- §5 Venom slice light/heavy/dash, order → Task 4 (placeholders) + Task 8 (art).
- §6 recolor fallback for un-arted infused slots → resolver `recolor_school` + Task 5/7.
- §7 structure tests → Tasks 1/2/5 (incl. reconfigure cache-reset + handles_state cases); harness capture (non-blank, deterministic, clip-swap assertion, recolor-tint diff) → Task 7; readability (flash over tint) → Task 3.
- Per-combat reconfigure safety (skin caches reset in `configure()`) → Task 5 Step 6 + reconfigure test.
- All `setup_combat` callers threaded (live + matchup + character capture) → Task 6 Steps 4–6.
- §8 out of scope (other schools, block/stance/jump Venom, duo/mastery, enemy skins, idle/walk) → not implemented; resolver naturally falls back.
- Player-only → enemies render via `FighterVisual`, never get `set_move_skins`; confirmed (only `_player_presenter` is skinned).

**Placeholder scan:** No "TBD"/"handle edge cases" steps; every code step shows code. Task 8 is intentionally a human art-gate workflow with explicit STOPs (content, not code).

**Type consistency:** `move_slot_schools()`/`school_for_effect_id()` (Task 1) used verbatim in Task 6. `set_move_skins`/`set_active_stance_school`/`resolve_state_clip_id`/`recolor_school_for`/`active_tint_school_for` defined in Task 5 and used by its test + Task 6. `MoveSkinResolver.STATE_SLOT`/`slot_for_state`/`variant_key`/`resolve` (Task 2) used by Task 5. Variant clip ids (`venom_hu_attack_light` etc.) consistent across Tasks 2/4/5. Shader uniform names (`skin_tint`, `skin_tint_weight`) consistent between Task 3 and Task 5 Step 7.
