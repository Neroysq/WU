# A1 — Attack Definitions to JSON Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all 30 attack definitions from code (`attack_catalog.gd`, 472 lines of static constructors) into `data/Attacks/Attacks.json` loaded by `DataManager`, so attack balance is F5-hot-reloadable and AI attack lookup becomes data-driven — with zero behavior change (golden values preserved, full 239-test suite as the characterization net).

**Architecture:** A one-off dump tool generates the JSON **from the live catalog** (exact values, no hand-transcription). `DataManager` gains `_attacks` + `get_attack_def(id)` that returns a **fresh `AttackDefinition` per call** (boss phase 2 mutates fetched defs — shared instances would corrupt data). `attack_catalog.gd` shrinks to `by_id()` + one-line named wrappers, so the ~10 named call sites in `fighter.gd`/`technique_engine.gd`/`combat_system.gd` and 7 test modules need **no changes**. `ai_brain.gd` switches from `has_method`/`call` reflection to the data lookup — new attacks then need only JSON, no method.

**Tech Stack:** Godot 4.6.2 (GDScript, static `DataManager` pattern already in place), JSON, headless runner (`./run.sh --test`).

**Hard boundary (per the overall proposal §6 rule):** This plan must **not** touch technique resolution — `technique_engine.gd` logic is off-limits (its catalog calls keep working through the wrappers). The A2 effect-registry plan is a separate file and starts only after this plan is committed with the suite green.

---

## File Structure

**New:**
- `WUGodot/data/Attacks/Attacks.json` — all 30 definitions, keyed by id (generated, then source of truth).
- `WUGodot/tools/dump_attacks.gd` — one-shot generator (created Task 1, **deleted Task 3** once constructors are gone; survives in git history).
- `WUGodot/tests/test_attack_data.gd` — golden values, fresh-instance + lazy-load safety, required-field/timing validation, id-coverage.

**Modified:**
- `WUGodot/scripts/data_manager.gd` — `_attacks` store, `_load_attacks()`, `get_attack_def(id)`.
- `WUGodot/scripts/attack_catalog.gd` — constructors deleted; `by_id()` + thin wrappers remain.
- `WUGodot/scripts/ai_brain.gd:80-85` — reflection lookup → `DataManager.get_attack_def`.
- `WUGodot/tests/run_tests.gd` — register the new module.

**Explicitly untouched:** `technique_engine.gd`, `combat_system.gd` resolution logic, all existing tests.

---

## Task 1: Dump tool → generate Attacks.json from the live catalog

**Files:**
- Create: `WUGodot/tools/dump_attacks.gd`
- Create (generated): `WUGodot/data/Attacks/Attacks.json`

- [ ] **Step 1: Record the plan's base commit (for the Task 5 boundary check)**

```bash
git rev-parse HEAD   # record this SHA as A1_BASE (note it in the worklog/PR description)
```

- [ ] **Step 2: Write the dump tool**

Create `WUGodot/tools/dump_attacks.gd`. **Header must state it is one-shot**: it dumps the *legacy constructors*, so it is only meaningful **before Task 3** deletes them (the tool itself is deleted in Task 3; it lives on in git history).

```gdscript
# ONE-SHOT migration tool: dumps the legacy attack_catalog.gd constructors to JSON.
# Only valid BEFORE Task 3 of the A1 plan replaces those constructors with JSON-backed
# wrappers (after which this would merely round-trip the JSON). Deleted in Task 3.
extends SceneTree

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")
const OUT_PATH := "res://data/Attacks/Attacks.json"

# All 30 catalog constructors (grep "def.id = " attack_catalog.gd to verify count).
const IDS: Array[String] = [
	"hu_light", "hu_heavy",
	"bandit_slash", "bandit_thrust_perilous", "bandit_overhead",
	"drunken_light", "drunken_heavy", "tiger_light", "tiger_heavy",
	"spear_long_thrust", "spear_wide_swing",
	"ronin_slash", "ronin_thrust", "ronin_sweep", "ronin_perilous_thrust",
	"disciple_slash", "disciple_thrust", "disciple_sweep", "disciple_counter", "disciple_jump_attack",
	"smoke_thrust", "flicker_slash", "assassin_backstab", "assassin_perilous_grab",
	"bear_swipe", "bear_overhead", "bear_stomp", "bear_crush_grab", "mountain_breaker", "bear_roar_aoe",
]

func _init() -> void:
	var catalog: Variant = AttackCatalogScript.new()
	var attacks := {}
	for id in IDS:
		if not catalog.has_method(id):
			printerr("missing constructor: %s" % id); quit(1); return
		var def: Variant = catalog.call(id)
		attacks[id] = {
			"duration": def.duration,
			"windup_end": def.windup_end,
			"active_end": def.active_end,
			"damage": def.damage,
			"posture_damage": def.posture_damage,
			"is_heavy": def.is_heavy,
			"is_perilous": def.is_perilous,
			"is_parryable": def.is_parryable,
			"range_units": def.range_units,
			"knockback_units": def.knockback_units,
			"ignores_block": def.ignores_block,
			"is_grab": def.is_grab,
			"forward_lunge": def.forward_lunge,
		}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/Attacks"))
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"attacks": attacks}, "  "))
	f.close()
	print("dumped %d attacks -> %s" % [attacks.size(), OUT_PATH])
	quit()
```

- [ ] **Step 3: Run it**

Run: `export HOME="${WU_GODOT_HOME:-/tmp/godot-home}"; godot --path WUGodot --headless --script res://tools/dump_attacks.gd` (or add a temporary invocation; one-off, no `run.sh` case needed).
Expected: `dumped 30 attacks -> res://data/Attacks/Attacks.json`.

- [ ] **Step 4: Spot-check the JSON**

Open `WUGodot/data/Attacks/Attacks.json`; verify `hu_light.range_units == 210.0`, `hu_heavy.range_units == 234.0`, `bear_crush_grab.is_grab == true`, `bandit_thrust_perilous.is_parryable == false`. These are the live balance values — any mismatch means the dump ran against stale code.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/tools/dump_attacks.gd WUGodot/data/Attacks/Attacks.json
git commit -m "feat(data): dump attack catalog to Attacks.json"
```

---

## Task 2: DataManager loads attacks (TDD)

**Files:**
- Modify: `WUGodot/scripts/data_manager.gd`
- Test: `WUGodot/tests/test_attack_data.gd`

- [ ] **Step 1: Write the failing test + register it**

Create `WUGodot/tests/test_attack_data.gd`:

```gdscript
extends RefCounted

const BossControllerScript = preload("res://scripts/boss_controller.gd")

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	DataManager.initialize()

	# Golden values (current live balance — change ONLY via deliberate balance edits).
	var light: Variant = DataManager.get_attack_def("hu_light")
	if light != null and light.id == "hu_light" and is_equal_approx(light.range_units, 210.0) \
		and is_equal_approx(light.duration, 0.5) and not light.is_heavy:
		passed += 1
	else:
		failed += 1; failures.append("hu_light golden values should load from JSON")

	var grab: Variant = DataManager.get_attack_def("bear_crush_grab")
	if grab != null and grab.is_grab and is_equal_approx(grab.range_units, 170.0):
		passed += 1
	else:
		failed += 1; failures.append("bear_crush_grab golden values should load from JSON")

	# Fresh instance per call: boss phase 2 mutates duration on fetched defs.
	var a: Variant = DataManager.get_attack_def("bear_swipe")
	a.duration = 999.0
	var b: Variant = DataManager.get_attack_def("bear_swipe")
	if b.duration < 100.0:
		passed += 1
	else:
		failed += 1; failures.append("get_attack_def must return a fresh instance per call")

	# Unknown id -> null (AiBrain already handles null).
	if DataManager.get_attack_def("nonexistent_attack") == null:
		passed += 1
	else:
		failed += 1; failures.append("unknown id should return null")

	# Lazy load: a cold DataManager (cleared store) must still serve wrappers — test
	# modules run in registration order and several call AttackCatalog before this one.
	DataManager._attacks.clear()
	var lazy: Variant = DataManager.get_attack_def("hu_light")
	if lazy != null and is_equal_approx(lazy.range_units, 210.0):
		passed += 1
	else:
		failed += 1; failures.append("get_attack_def must lazy-load when the store is empty")

	# Validation: shipped JSON must have all required fields and sane timing for EVERY attack.
	var validation_errors: Array[String] = DataManager.validate_attacks()
	if validation_errors.is_empty():
		passed += 1
	else:
		failed += 1; failures.append("attack data validation errors: %s" % str(validation_errors))

	# Validation catches a typoed field and bad timing ordering.
	DataManager._attacks["bad_attack"] = {"duration": 0.5, "windup_end": 0.4, "active_end": 0.2, "damage": 5.0, "posture_damage": 5.0, "range_unit": 80.0}  # typo: range_unit; active < windup
	var bad_errors: Array[String] = DataManager.validate_attacks()
	DataManager._attacks.erase("bad_attack")
	if bad_errors.size() >= 2:
		passed += 1
	else:
		failed += 1; failures.append("validation should flag missing required field AND timing ordering, got %s" % str(bad_errors))

	# Coverage: every enemy pattern_table id, boss-table id, and technique-override id resolves.
	var all_ids: Array[String] = []
	for enemy_file in ["BanditSwordsman", "BanditSpearman", "WanderingRonin", "SectDisciple", "MaskedAssassin", "IronBear"]:
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/Enemies/%s.json" % enemy_file)) as Dictionary
		for atk_id in parsed.get("pattern_table", []) as Array:
			all_ids.append(str(atk_id))
	var boss: Variant = BossControllerScript.new()
	for atk_id in boss.get_phase_attack_table():
		all_ids.append(str(atk_id))
	for override_id in ["drunken_light", "drunken_heavy", "tiger_light", "tiger_heavy", "mountain_breaker", "bear_roar_aoe"]:
		all_ids.append(override_id)
	var missing: Array[String] = []
	for atk_id in all_ids:
		if DataManager.get_attack_def(atk_id) == null:
			missing.append(atk_id)
	if missing.is_empty():
		passed += 1
	else:
		failed += 1; failures.append("ids referenced by enemies/boss/overrides missing from Attacks.json: %s" % str(missing))

	return {"passed": passed, "failed": failed, "failures": failures}
```

Register now — add to `_TEST_MODULES` in `WUGodot/tests/run_tests.gd`:

```gdscript
	"res://tests/test_attack_data.gd",
```

- [ ] **Step 2: Run to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — `get_attack_def` not defined on `DataManager`.

- [ ] **Step 3: Implement the loader**

In `data_manager.gd`, add the store near the other static vars:

```gdscript
static var _attacks: Dictionary = {}
```

Add `_load_attacks()` to `initialize()` **and** `reload_data()` (so F5 hot-reloads balance):

```gdscript
	_load_attacks()
```

Add (following the file's existing `_load_*` style):

```gdscript
static func _load_attacks() -> void:
	_attacks.clear()
	var path := "res://data/Attacks/Attacks.json"
	if not FileAccess.file_exists(path):
		push_error("DataManager: missing %s" % path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DataManager: %s did not parse" % path)
		return
	_attacks = (parsed as Dictionary).get("attacks", {}) as Dictionary
	for err in validate_attacks():
		push_error("DataManager: %s" % err)

# Required numeric fields: a typo (e.g. "range_unit") must fail loudly, not silently
# fall back to an AttackDefinition default. Flags stay optional (genuine defaults).
const _REQUIRED_ATTACK_FIELDS: Array[String] = [
	"duration", "windup_end", "active_end", "damage", "posture_damage", "range_units", "knockback_units",
]

static func validate_attacks() -> Array[String]:
	var errors: Array[String] = []
	for attack_id in _attacks.keys():
		var raw: Dictionary = _attacks[attack_id] as Dictionary
		for field in _REQUIRED_ATTACK_FIELDS:
			if not raw.has(field):
				errors.append("%s: missing required field '%s'" % [attack_id, field])
		var wu: float = float(raw.get("windup_end", 0.0))
		var ae: float = float(raw.get("active_end", 0.0))
		var du: float = float(raw.get("duration", 0.0))
		if not (wu >= 0.0 and ae >= wu and du >= ae):
			errors.append("%s: timing must satisfy 0 <= windup_end <= active_end <= duration (got %s/%s/%s)" % [attack_id, wu, ae, du])
	return errors

# Fresh AttackDefinition per call: callers (boss phase 2) mutate fetched defs.
# Lazy-loads when the store is cold: in headless tests, several modules call
# AttackCatalog wrappers BEFORE anything runs DataManager.initialize(), and module
# registration order must not decide whether the suite passes. (REQUIRED, not optional.)
static func get_attack_def(attack_id: String) -> Variant:
	if _attacks.is_empty():
		_load_attacks()
	if not _attacks.has(attack_id):
		return null
	var raw: Dictionary = _attacks[attack_id] as Dictionary
	var def: Variant = load("res://scripts/attack_definition.gd").new()
	def.id = attack_id
	def.duration = float(raw.get("duration", def.duration))
	def.windup_end = float(raw.get("windup_end", def.windup_end))
	def.active_end = float(raw.get("active_end", def.active_end))
	def.damage = float(raw.get("damage", def.damage))
	def.posture_damage = float(raw.get("posture_damage", def.posture_damage))
	def.is_heavy = bool(raw.get("is_heavy", def.is_heavy))
	def.is_perilous = bool(raw.get("is_perilous", def.is_perilous))
	def.is_parryable = bool(raw.get("is_parryable", def.is_parryable))
	def.range_units = float(raw.get("range_units", def.range_units))
	def.knockback_units = float(raw.get("knockback_units", def.knockback_units))
	def.ignores_block = bool(raw.get("ignores_block", def.ignores_block))
	def.is_grab = bool(raw.get("is_grab", def.is_grab))
	def.forward_lunge = float(raw.get("forward_lunge", def.forward_lunge))
	return def
```

- [ ] **Step 4: Run to verify it passes**

Run: `./run.sh --test`
Expected: PASS — `test_attack_data` contributes 8 (goldens ×2, fresh instance, unknown→null, lazy load, shipped-data validation, bad-data validation); whole suite still green (catalog untouched so far).

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/data_manager.gd WUGodot/tests/test_attack_data.gd WUGodot/tests/run_tests.gd
git commit -m "feat(data): DataManager loads attack definitions from JSON"
```

---

## Task 3: Shrink attack_catalog.gd to thin accessors

The 239-test suite (7 modules call named constructors; reach-consistency asserts pin `hu_light`/`hu_heavy` values) is the characterization net for this swap.

**Files:**
- Modify: `WUGodot/scripts/attack_catalog.gd` (472 lines → ~45)

- [ ] **Step 1: Replace the file body**

Replace `attack_catalog.gd`'s contents with `by_id` + one wrapper per attack (same names, so `fighter.gd:343,349`, `technique_engine.gd:183-193`, `combat_system.gd:248`, and all test call sites compile unchanged):

```gdscript
class_name AttackCatalog
extends RefCounted

# Attack data lives in res://data/Attacks/Attacks.json (see tools/dump_attacks.gd).
# These wrappers preserve the legacy named API; new attacks need ONLY a JSON entry
# (AiBrain resolves ids straight from data and does not need a wrapper).

static func by_id(attack_id: String) -> Variant:
	return DataManager.get_attack_def(attack_id)

static func hu_light() -> Variant: return by_id("hu_light")
static func hu_heavy() -> Variant: return by_id("hu_heavy")
static func bandit_slash() -> Variant: return by_id("bandit_slash")
static func bandit_thrust_perilous() -> Variant: return by_id("bandit_thrust_perilous")
static func bandit_overhead() -> Variant: return by_id("bandit_overhead")
static func drunken_light() -> Variant: return by_id("drunken_light")
static func drunken_heavy() -> Variant: return by_id("drunken_heavy")
static func tiger_light() -> Variant: return by_id("tiger_light")
static func tiger_heavy() -> Variant: return by_id("tiger_heavy")
static func spear_long_thrust() -> Variant: return by_id("spear_long_thrust")
static func spear_wide_swing() -> Variant: return by_id("spear_wide_swing")
static func ronin_slash() -> Variant: return by_id("ronin_slash")
static func ronin_thrust() -> Variant: return by_id("ronin_thrust")
static func ronin_sweep() -> Variant: return by_id("ronin_sweep")
static func ronin_perilous_thrust() -> Variant: return by_id("ronin_perilous_thrust")
static func disciple_slash() -> Variant: return by_id("disciple_slash")
static func disciple_thrust() -> Variant: return by_id("disciple_thrust")
static func disciple_sweep() -> Variant: return by_id("disciple_sweep")
static func disciple_counter() -> Variant: return by_id("disciple_counter")
static func disciple_jump_attack() -> Variant: return by_id("disciple_jump_attack")
static func smoke_thrust() -> Variant: return by_id("smoke_thrust")
static func flicker_slash() -> Variant: return by_id("flicker_slash")
static func assassin_backstab() -> Variant: return by_id("assassin_backstab")
static func assassin_perilous_grab() -> Variant: return by_id("assassin_perilous_grab")
static func bear_swipe() -> Variant: return by_id("bear_swipe")
static func bear_overhead() -> Variant: return by_id("bear_overhead")
static func bear_stomp() -> Variant: return by_id("bear_stomp")
static func bear_crush_grab() -> Variant: return by_id("bear_crush_grab")
static func mountain_breaker() -> Variant: return by_id("mountain_breaker")
static func bear_roar_aoe() -> Variant: return by_id("bear_roar_aoe")
```

(No initialization caveat needed: `get_attack_def` lazy-loads on a cold store — built into Task 2 precisely because five earlier-registered test modules call these wrappers before anything initializes DataManager.)

- [ ] **Step 2: Delete the one-shot dump tool**

`dump_attacks.gd` dumped the legacy constructors; with the constructors gone it would merely round-trip the JSON and could mislead someone into "regenerating" data from data. Delete it (it lives in git history):

```bash
git rm WUGodot/tools/dump_attacks.gd
```

- [ ] **Step 3: Full suite (the characterization gate)**

Run: `./run.sh --test`
Expected: **PASS, 244+/0** — identical behavior from JSON values. Any failure here means a JSON value diverges from the old constructor: diff against `git show HEAD~1:WUGodot/scripts/attack_catalog.gd`, fix the JSON (not the test).

- [ ] **Step 4: Import + sanity**

Run: `./run.sh --import` → clean. `./run.sh --anchor-sanity` → OK (reach untouched: `hu_light` 210 / `hu_heavy` 234 now come from JSON).

- [ ] **Step 5: Commit**

```bash
# (the dump-tool deletion from Step 2 is already staged by `git rm`)
git add WUGodot/scripts/attack_catalog.gd
git commit -m "refactor(data): attack_catalog becomes thin JSON accessor; drop one-shot dump tool"
```

---

## Task 4: AiBrain looks up attacks from data (TDD)

**Files:**
- Modify: `WUGodot/scripts/ai_brain.gd:80-85`
- Test: extend `WUGodot/tests/test_attack_data.gd`

- [ ] **Step 1: Write the failing assertion**

Append to `run_all()` in `test_attack_data.gd` before the final `return` — an id that exists **only in data** (no catalog method) must resolve through AiBrain, proving the reflection path is gone:

```gdscript
	# Data-driven AI lookup: an id with NO catalog method must resolve via AiBrain.
	DataManager._attacks["test_only_attack"] = {"duration": 0.4, "windup_end": 0.1, "active_end": 0.2, "damage": 5.0, "range_units": 80.0}
	var AiBrainScript: Script = load("res://scripts/ai_brain.gd")
	var brain: Variant = AiBrainScript.new()
	var test_def: Variant = brain.get_attack_def("test_only_attack")
	DataManager._attacks.erase("test_only_attack")
	if test_def != null and is_equal_approx(test_def.range_units, 80.0):
		passed += 1
	else:
		failed += 1; failures.append("AiBrain should resolve attacks from data, not catalog methods")
```

- [ ] **Step 2: Run to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — `has_method("test_only_attack")` is false, so the reflection path returns null.

- [ ] **Step 3: Implement**

Replace `ai_brain.gd:80-85` (and delete the now-unused `_attack_catalog` static var at `:6` and its `AttackCatalogScript` preload at `:4`):

```gdscript
func get_attack_def(attack_id: String) -> Variant:
	return DataManager.get_attack_def(attack_id)
```

- [ ] **Step 4: Run to verify it passes**

Run: `./run.sh --test`
Expected: PASS — full suite green (test_ai_brain/test_boss_controller exercise the new path with real ids).

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/ai_brain.gd WUGodot/tests/test_attack_data.gd
git commit -m "feat(ai): attack lookup from data, not catalog reflection"
```

---

## Task 5: F5 hot-reload verification + final validation

**Files:** none (verification).

- [ ] **Step 1: Confirm reload wiring**

Verify `reload_data()` in `data_manager.gd` includes `_load_attacks()` (added in Task 2). `main.gd`'s F5 handler already calls `DataManager.reload_data()`.

- [ ] **Step 2: Manual hot-reload check**

Run: `./run.sh`, enter combat, note light-attack damage. Edit `Attacks.json` `hu_light.damage` 12 → 50, press `F5`, hit the enemy.
Expected: damage numbers show the new value without restart. Revert the edit afterward (`git checkout WUGodot/data/Attacks/Attacks.json` if needed).

- [ ] **Step 3: Final gates**

Run: `./run.sh --test` → `failed: 0`. `./run.sh --import` → clean. `git diff --check` → clean.
Confirm the A1/A2 boundary held, using the **A1_BASE SHA recorded in Task 1 Step 1** (don't count commits — `HEAD~N` breaks the moment a task adds an extra commit):

```bash
git diff --name-only <A1_BASE>...HEAD | grep -E "technique_engine\.gd|combat_system\.gd" && echo "BOUNDARY VIOLATED" || echo "boundary OK"
```

Expected: `boundary OK` (neither file appears — `combat_system.gd`'s catalog calls go through the unchanged wrappers).

- [ ] **Step 4: Commit (if anything from verification)**

```bash
git add -A && git commit -m "chore(data): A1 attacks-to-JSON verification"
```

---

## Self-Review Notes

- **Zero behavior change** is the contract: dump-from-live-code (no transcription), golden-value tests (`hu_light` 210 / `bear_crush_grab` 170), and the full 239-test suite as the characterization gate (Task 3 Step 2).
- **Fresh-instance semantics** preserved (boss phase-2 mutation, `combat_system.gd:216-218`) — explicitly tested.
- **The actual win**: F5 balance tuning (Task 5 proves it) + AI attacks are pure data (Task 4 proves it — a JSON-only id resolves), which is what Phase C's Demon Spirit/boss content will use.
- **A1/A2 boundary enforced**: `technique_engine.gd` untouched (wrappers preserve its call sites); Task 5 Step 3 verifies with `git diff --stat`. A2 (effect registry) is a separate plan file, gated on this plan being committed green.
- **Known residue (deliberate, for A2 or later)**: stance-override *selection* logic stays in `technique_engine.gd`; the legacy-AI fallback in `combat_system.gd:248` keeps its named wrapper calls.

**Review fixes folded in:**
- **Lazy-load guard is REQUIRED, not optional** (Task 2): five earlier-registered test modules call catalog wrappers before anything initializes DataManager; without the guard the suite's result depends on registration order. Built into `get_attack_def` + a dedicated cold-store test.
- **Field validation** (Task 2): `validate_attacks()` enforces required numeric fields (a typo like `range_unit` fails loudly instead of silently defaulting) and timing ordering `0 ≤ windup_end ≤ active_end ≤ duration`; runs at load (push_error) and in tests (shipped data must be clean; a deliberately bad entry must be flagged).
- **Dump tool lifecycle**: header marks it one-shot/pre-Task-3; **deleted in Task 3** (post-migration it would only round-trip JSON).
- **Boundary check** uses the recorded `A1_BASE` SHA + `git diff --name-only <base>...HEAD | grep`, not `HEAD~N` commit counting.
