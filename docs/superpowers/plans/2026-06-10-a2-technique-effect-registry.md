# A2 — Technique Effect Registry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the technique-ID coupling scattered across `combat_system.gd` (8 `.has("X")` checks), `technique_engine.gd` (dual apply/unapply matches, hardcoded stance/trigger logic), and `fighter.gd` (D2 auto-chain) with a **registry of self-contained effect objects** — so adding a technique becomes data + one effect class, with zero edits to combat resolution. Zero behavior change, pinned by characterization tests written **before** any logic moves.

**Architecture:** A `TechniqueEffect` base class defines the full lifecycle the current techniques actually need (not just stateless hooks): `on_add/on_remove` (symmetric stat deltas), `on_combat_start/on_combat_end` (reset vs deferred state), `update(dt)` (timers), ordered trigger hooks taking a mutable `HitContext`, stance support (`exclusive_group`, activate/deactivate, attack overrides), `once_per_run` state, and `state()/restore()` for future save-game persistence. `TechniqueEngine` becomes a thin host: it instantiates effects from a registry (params from `TechniquePool.json`), dispatches hooks in **fixed priority order** (preserving today's resolution order), and keeps its existing public API where it is already generic. `combat_system.gd` stops naming any technique ID.

**Tech Stack:** Godot 4.6.2 (GDScript), JSON (`TechniquePool.json` gains per-technique `effect` params), headless runner (`./run.sh --test`).

**Hard boundary (inverse of A1, per the proposal §6 rule):** This plan must **not** touch attack-data loading — `data/Attacks/Attacks.json`, `attack_catalog.gd`, and `DataManager.get_attack_def/_load_attacks/validate_attacks` are off-limits. (`technique_engine.gd` calling `AttackCatalog.drunken_light()` etc. through the existing wrappers is fine.) Record `A2_BASE` first; verify at the end.

---

## The effect lifecycle model (what the registry must support)

Derived from the actual current behaviors (`technique_engine.gd`, `combat_system.gd`):

| Capability | Today's examples | Registry mechanism |
|---|---|---|
| Symmetric stat deltas | A6–A9, A11, A12 (`technique_engine.gd:55-113`) | `on_add(fighter)` / `on_remove(fighter)`; one param-driven `StatDeltaEffect` |
| Per-combat reset vs deferred state | echo/sparrow reset; **`_gaze_earned` carries to next fight**; `_phoenix_used` persists all run (`:259-268, :12`) | `on_combat_start/on_combat_end`; effect-owned state; `once_per_run` flag |
| Timers | sparrow 0.6 s, gaze 3 s, D2 stance 15 s (`:115-133`) | `update(dt, fighter)` |
| Outgoing-hit modification, **ordered** | B5 ×1.25 → A4 ×1.30 (light, consume) → B1 echo (posture := defender+1) → B3 (heal 5) → … → A3 bleed → A10 twin (`combat_system.gd:318-421`) | `modify_outgoing_hit(ctx)` with integer `priority` mirroring today's sequence |
| Incoming-block modification | A5 chip ×0.5 (`:340`), D2 reflect 10% of *base* (`:342-347`) | `modify_block(ctx)` |
| Event triggers | B1 arm-on-parry (`:300-302`), B2 heal-on-break (`:235-237`), A1 dash-end stab (`:108-119`), B3 dash-through, B4 on-kill, A2 stagger roll, B6 lethal save | dedicated hooks (`on_parry_success`, `on_posture_break_dealt`, `on_dash_end(ctx)`, `on_dash_through`, `on_kill`, `roll_stagger`, `try_lethal_save`) |
| Stance exclusivity + machinery | `begins_with("D")` removal (`:34-37`); D1 dash mods + 20-dmg break; D2 timer + overrides + reflect; tiger auto-chain (`fighter.gd:221`); display names (`combat_system.gd:88-92`) | `exclusive_group = "stance"`; `on_stance_activate/deactivate(fighter)`; `attack_override(is_heavy)`; `should_auto_chain_light(def)`; `display_name` from JSON |
| Persisted state (Phase C save) | `_phoenix_used`, `_gaze_earned` | `state() -> Dictionary` / `restore(d)`; engine-level `save_state()/load_state()` |

**Ordering contract:** dispatch sorted by `(priority, id)` **within each of two phases**:
- **Pre-block `modify_outgoing_hit`**: B5=10, A4=20, B1-echo=30, B3-flow=40, A3=50 — runs before the block branch, matching `combat_system.gd:318-335`.
- **Block `modify_block`**: A5=10, D2-reflect=20.
- **Post-hit `post_hit`**: A10=10 — runs **after** block modifiers and primary damage application, because the twin prices off the *post-block* `hp_damage` (`combat_system.gd:421`); a single pre-block phase would make a blocked heavy spawn an unblocked-size twin.

Characterization tests assert the *combined* results so a future reorder fails loudly.

**Feedback-order contract:** technique messages (雀翼!/山谷回響!/流水!) currently emit **before** the generic HIT/BLOCKED feedback (`combat_system.gd:329-355`), and the feedback line shows the *last* emission — so the generic message wins today. The rewire must emit `ctx.messages` **before** the generic feedback to preserve visible behavior; a signal-order characterization in Task 1 pins this.

---

## File Structure

**New:**
- `WUGodot/scripts/techniques/technique_effect.gd` — base class + `HitContext`.
- `WUGodot/scripts/techniques/technique_registry.gd` — id → effect factory; reads `effect` params from `TechniquePool.json`.
- `WUGodot/scripts/techniques/effects/` — one small class per non-trivial technique (`stat_delta_effect.gd` covers six).
- `WUGodot/tests/test_technique_combat.gd` — **characterization tests for the combat_system-side behaviors** (the current gap; engine-side is already covered by `test_technique_engine.gd`).
- `WUGodot/tests/test_technique_registry.gd` — framework, ordering, state round-trip.

**Modified:**
- `WUGodot/data/Techniques/TechniquePool.json` — per-technique `effect` block (type + params + stance `display_name`).
- `WUGodot/scripts/technique_engine.gd` — becomes host/dispatcher (~100 lines).
- `WUGodot/scripts/combat_system.gd` — the 8 `.has()` checks + inline effect math replaced by ctx dispatch (`:86-95` stance names, `:108-119` A1, `:300-302`, `:318-360`, `:378-380`, `:399-406`, `:414-424`).
- `WUGodot/scripts/fighter.gd:221` — D2 auto-chain → `technique_engine.should_auto_chain_light(def)`.
- `WUGodot/tests/run_tests.gd` — register the two new modules.

**Explicitly untouched:** `data/Attacks/`, `attack_catalog.gd`, DataManager's attack functions.

---

## Task 1: Record A2_BASE + characterization tests (combat-side)

**Files:**
- Test: `WUGodot/tests/test_technique_combat.gd` (new)
- Modify: `WUGodot/tests/run_tests.gd`

- [ ] **Step 1: Record the base**

```bash
git rev-parse HEAD   # record as A2_BASE
```

- [ ] **Step 2: Write the characterization tests + register**

Create `WUGodot/tests/test_technique_combat.gd`. Pattern per case: build attacker/defender `Fighter`s, give the attacker/defender a `TechniqueEngine` with the technique under test, drive the attack into its active window, call `CombatSystem.resolve_hits`, assert the *numeric outcome*. These must **pass against current code** — they pin behavior, they are not TDD-fail tests. Cover, with exact expectations from today's code:

```gdscript
extends RefCounted

const CombatSystemScript = preload("res://scripts/combat_system.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")
const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

func _pair(attacker_tech: Array, defender_tech: Array) -> Array:
	var a: Variant = FighterScript.new()
	var d: Variant = FighterScript.new()
	a.position = Vector2(0, 900); a.facing = 1
	d.position = Vector2(60, 900); d.facing = -1
	a.technique_engine = TechniqueEngineScript.new()
	d.technique_engine = TechniqueEngineScript.new()
	for id in attacker_tech: a.technique_engine.add(id, a)
	for id in defender_tech: d.technique_engine.add(id, d)
	return [a, d]

func _strike(cs: Variant, a: Variant, d: Variant, attack: Variant) -> void:
	a._attack_state.start(attack)
	a._attack_state.advance(attack.windup_end + 0.01)
	cs.resolve_hits(a, d)

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []
	var cs: Variant = CombatSystemScript.new()

	# B5: at <=30% HP, hu_light damage x1.25 (base 12 -> 15 before combo bonus 1.0).
	var p := _pair(["B5"], [])
	p[0].health_current = p[0].health_max * 0.25
	var hp0: float = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp0 - p[1].health_current, 15.0):
		passed += 1
	else:
		failed += 1; failures.append("B5 low-HP light should deal 15 (got %.1f)" % (hp0 - p[1].health_current))

	# A4: sparrow window after dash-end -> light x1.30 (12 -> 15.6), consumed after one hit.
	p = _pair(["A4"], [])
	p[0].technique_engine.on_dash_end()
	hp0 = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp0 - p[1].health_current, 15.6) and not p[0].technique_engine.has_sparrow_bonus():
		passed += 1
	else:
		failed += 1; failures.append("A4 sparrow light should deal 15.6 and consume")

	# Feedback ORDER: technique message fires BEFORE generic HIT (the visible line is the
	# last emission, so generic wins today — the rewire must preserve this).
	p = _pair(["A4"], [])
	p[0].technique_engine.on_dash_end()
	var feedback_log: Array[String] = []
	cs.show_feedback.connect(func(msg: String, _d: float) -> void: feedback_log.append(msg))
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	var sparrow_idx: int = feedback_log.find("雀翼!")
	var hit_idx: int = feedback_log.find("HIT")
	if sparrow_idx != -1 and hit_idx != -1 and sparrow_idx < hit_idx:
		passed += 1
	else:
		failed += 1; failures.append("technique feedback must precede generic HIT (got %s)" % str(feedback_log))

	# B1 ordering: echo armed -> posture damage becomes defender.posture_current + 1 (guaranteed break).
	p = _pair(["B1"], [])
	p[0].technique_engine.set_echo()
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if p[1].is_stunned:
		passed += 1
	else:
		failed += 1; failures.append("armed echo should guarantee a posture break")

	# B3: flowing water heals attacker 5 on next hit.
	p = _pair(["B3"], [])
	p[0].health_current = 50.0
	p[0].technique_engine.on_dash_through()
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(p[0].health_current, 55.0):
		passed += 1
	else:
		failed += 1; failures.append("B3 should heal attacker 5 (got %.1f)" % p[0].health_current)

	# A3: heavy applies bleed (timer 3.0, dps 1.5); light does not.
	p = _pair(["A3"], [])
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_heavy())
	if is_equal_approx(p[1].bleed_timer, 3.0) and is_equal_approx(p[1].bleed_dps, 1.5):
		passed += 1
	else:
		failed += 1; failures.append("A3 heavy should bleed 3.0s @ 1.5dps")

	# A10: heavy adds a twin hit of 50% damage (22 + 11 = 33 total).
	p = _pair(["A10"], [])
	hp0 = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_heavy())
	if is_equal_approx(hp0 - p[1].health_current, 33.0):
		passed += 1
	else:
		failed += 1; failures.append("A10 heavy total should be 33 (got %.1f)" % (hp0 - p[1].health_current))

	# A5: blocking defender takes half chip: 12 * 0.2 * 0.5 = 1.2.
	p = _pair([], ["A5"])
	p[1].is_blocking = true
	hp0 = p[1].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp0 - p[1].health_current, 1.2):
		passed += 1
	else:
		failed += 1; failures.append("A5 blocked light chip should be 1.2 (got %.2f)" % (hp0 - p[1].health_current))

	# D2 reflect: blocking in tiger stance reflects 10% of BASE damage to the attacker.
	p = _pair([], ["D2"])
	p[1].rage_current = p[1].rage_max
	p[1].technique_engine.activate_stance(p[1])
	p[1].is_blocking = true
	hp0 = p[0].health_current
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(hp0 - p[0].health_current, 1.2):
		passed += 1
	else:
		failed += 1; failures.append("D2 block should reflect 1.2 (got %.2f)" % (hp0 - p[0].health_current))

	# B2: posture break heals the breaker 15.
	p = _pair(["B2"], [])
	p[0].health_current = 50.0
	p[1].posture_current = 1.0
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_light())
	if is_equal_approx(p[0].health_current, 65.0):
		passed += 1
	else:
		failed += 1; failures.append("B2 should heal 15 on posture break (got %.1f)" % p[0].health_current)

	# A2: stagger roll is has(A2) AND rng < 0.2 — seed the engine rng for determinism.
	p = _pair(["A2"], [])
	p[0].technique_engine._rng.seed = 1
	var rolled_any := false
	for i in range(50):
		if p[0].technique_engine.roll_stagger(): rolled_any = true
	if rolled_any:
		passed += 1
	else:
		failed += 1; failures.append("A2 seeded stagger should fire within 50 rolls")

	# B6 via resolve_hits: lethal hit leaves defender at 20% max HP, once per run.
	p = _pair([], ["B6"])
	p[1].health_current = 1.0
	_strike(cs, p[0], p[1], AttackCatalogScript.hu_heavy())
	if is_equal_approx(p[1].health_current, p[1].health_max * 0.2):
		passed += 1
	else:
		failed += 1; failures.append("B6 lethal save should leave 20%% HP (got %.1f)" % p[1].health_current)

	# A1: dash ending in range stabs the enemy for 8 (via update_player dash-end path).
	p = _pair(["A1"], [])
	p[0]._dash_timer = 0.01
	hp0 = p[1].health_current
	cs.update_player(p[0], {"move": 0.0}, 0.02, p[1])
	if is_equal_approx(hp0 - p[1].health_current, 8.0):
		passed += 1
	else:
		failed += 1; failures.append("A1 dash-end stab should deal 8 (got %.1f)" % (hp0 - p[1].health_current))

	return {"passed": passed, "failed": failed, "failures": failures}
```

Register in `run_tests.gd`:

```gdscript
	"res://tests/test_technique_combat.gd",
```

- [ ] **Step 3: Run — expected PASS against current code**

Run: `./run.sh --test`
Expected: PASS (13 new asserts, incl. the feedback-order pin). Any failure means the expectation, not the code, is wrong — fix the test to match observed behavior (these pin the status quo). Tip: `DataManager` settings affect block math (`blockHealthMultiplier 0.2`); the numbers above use shipped settings.

- [ ] **Step 4: Commit**

```bash
git add WUGodot/tests/test_technique_combat.gd WUGodot/tests/run_tests.gd
git commit -m "test(techniques): characterize combat-side technique behavior"
```

---

## Task 2: Effect framework (no behavior change)

**Files:**
- Create: `WUGodot/scripts/techniques/technique_effect.gd`
- Create: `WUGodot/scripts/techniques/technique_registry.gd`
- Test: `WUGodot/tests/test_technique_registry.gd`

- [ ] **Step 1: Write the framework test + register**

Create `WUGodot/tests/test_technique_registry.gd` with a dummy effect proving: registration, ordered dispatch (two dummies with priorities mutate `ctx.hp_damage` in priority order), `exclusive_group` replacement, `once_per_run` survival across `on_combat_start`, and `state()/restore()` round-trip:

```gdscript
extends RefCounted

const TechniqueEffectScript = preload("res://scripts/techniques/technique_effect.gd")
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")
const FighterScript = preload("res://scripts/fighter.gd")

class AddTwo extends "res://scripts/techniques/technique_effect.gd":
	func _init() -> void: id = "T_ADD"; priority = 10
	func modify_outgoing_hit(ctx: Variant) -> void: ctx.hp_damage += 2.0

class DoubleIt extends "res://scripts/techniques/technique_effect.gd":
	func _init() -> void: id = "T_DBL"; priority = 20
	func modify_outgoing_hit(ctx: Variant) -> void: ctx.hp_damage *= 2.0

class StanceA extends "res://scripts/techniques/technique_effect.gd":
	func _init() -> void: id = "T_STANCE_A"; exclusive_group = "stance"

class StanceB extends "res://scripts/techniques/technique_effect.gd":
	func _init() -> void: id = "T_STANCE_B"; exclusive_group = "stance"

class Counter extends "res://scripts/techniques/technique_effect.gd":
	var count: int = 0
	var combat_starts: int = 0
	func _init() -> void: id = "T_CTR"; once_per_run = true
	func on_combat_start(_f: Variant) -> void: combat_starts += 1
	func state() -> Dictionary: return {"count": count}
	func restore(d: Dictionary) -> void: count = int(d.get("count", 0))

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	var engine: Variant = TechniqueEngineScript.new()
	var fighter: Variant = FighterScript.new()
	engine._install_effect(AddTwo.new(), fighter)
	engine._install_effect(DoubleIt.new(), fighter)

	var ctx: Variant = TechniqueEffectScript.HitContext.new()
	ctx.hp_damage = 10.0
	engine.dispatch_outgoing_hit(ctx)
	# priority 10 then 20: (10+2)*2 = 24, NOT 10*2+2 = 22.
	if is_equal_approx(ctx.hp_damage, 24.0):
		passed += 1
	else:
		failed += 1; failures.append("dispatch must run in priority order (got %.1f)" % ctx.hp_damage)

	# exclusive_group: installing a second "stance" effect removes the first.
	engine._install_effect(StanceA.new(), fighter)
	engine._install_effect(StanceB.new(), fighter)
	if not engine.has_effect("T_STANCE_A") and engine.has_effect("T_STANCE_B"):
		passed += 1
	else:
		failed += 1; failures.append("exclusive_group install must replace the prior group member")

	# state survives combat reset (once-per-run semantics) and round-trips by VALUE.
	var ctr := Counter.new()
	ctr.count = 3
	engine._install_effect(ctr, fighter)
	engine.on_combat_start(fighter)
	if ctr.count == 3 and ctr.combat_starts == 1:
		passed += 1
	else:
		failed += 1; failures.append("effect state must survive on_combat_start (count=%d)" % ctr.count)

	var saved: Dictionary = engine.save_state()
	var engine2: Variant = TechniqueEngineScript.new()
	var ctr2 := Counter.new()
	engine2._install_effect(ctr2, fighter)
	engine2.load_state(saved, fighter)
	if ctr2.count == 3:
		passed += 1
	else:
		failed += 1; failures.append("load_state must restore concrete effect state fields (count=%d)" % ctr2.count)

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Run to verify it fails** — `./run.sh --test`, FAIL on missing scripts.

- [ ] **Step 3: Implement the base + context + registry + engine hosting**

`WUGodot/scripts/techniques/technique_effect.gd`:

```gdscript
class_name TechniqueEffect
extends RefCounted

# Mutable hit context passed through ordered outgoing/block dispatch.
class HitContext extends RefCounted:
	var attacker: Variant = null
	var defender: Variant = null
	var attack_def: Variant = null
	var hp_damage: float = 0.0
	var posture_damage: float = 0.0
	var base_hp_damage: float = 0.0        # pre-modifier (D2 reflect uses this)
	var heal_attacker: float = 0.0
	var bleed_timer: float = 0.0
	var bleed_dps: float = 0.0
	var extra_hits: Array = []             # [{damage, offset: Vector2, critical: bool}]
	var reflect_to_attacker: float = 0.0
	var messages: Array[String] = []       # show_feedback strings, in order

var id: String = ""
var priority: int = 100
var exclusive_group: String = ""           # "stance" for D-types
var once_per_run: bool = false
var params: Dictionary = {}                # from TechniquePool.json "effect" block
var display_name: String = ""              # stance activation banner

# Lifecycle (all optional overrides).
func on_add(_fighter: Variant) -> void: pass
func on_remove(_fighter: Variant) -> void: pass
func on_combat_start(_fighter: Variant) -> void: pass
func on_combat_end(_fighter: Variant) -> void: pass
func update(_dt: float, _fighter: Variant) -> void: pass
# Triggers. NOTE: ctx params are typed Variant, not HitContext — effects extend this
# class by path, and GDScript's parser is unreliable resolving a parent's inner class
# in child signatures (repo style is defensive Variant anyway).
# TWO PHASES: modify_outgoing_hit runs PRE-block (B5/A4/echo/flow/bleed);
# post_hit runs AFTER block modifiers + primary damage application (A10 twin prices
# off the post-block hp_damage — see combat_system.gd:421).
func modify_outgoing_hit(_ctx: Variant) -> void: pass
func post_hit(_ctx: Variant) -> void: pass
func modify_block(_ctx: Variant) -> void: pass
func on_parry_success(_fighter: Variant) -> void: pass
func on_posture_break_dealt(_fighter: Variant) -> void: pass
func on_dash_end(_fighter: Variant, _enemy: Variant) -> Dictionary: return {}
func on_dash_through(_fighter: Variant) -> void: pass
func on_kill(_fighter: Variant) -> void: pass
func roll_stagger(_rng: RandomNumberGenerator) -> bool: return false
func try_lethal_save(_fighter: Variant) -> bool: return false
# Stances.
func on_stance_activate(_fighter: Variant) -> void: pass
func on_stance_deactivate(_fighter: Variant) -> void: pass
func attack_override(_is_heavy: bool) -> Variant: return null
func should_auto_chain_light(_def: Variant) -> bool: return false
func on_stance_damage(_amount: float, _fighter: Variant) -> bool: return false
# Persistence.
func state() -> Dictionary: return {}
func restore(_d: Dictionary) -> void: pass
```

`WUGodot/scripts/techniques/technique_registry.gd` maps id → factory, pulling `params`/`display_name` from `DataManager` technique data (`effect` block). Engine additions: `_effects: Array` (sorted by `(priority, id)` on install), `_install_effect(effect, fighter)` (enforces `exclusive_group` replacement), `has_effect(id)`, `dispatch_outgoing_hit(ctx)`, `dispatch_block(ctx)`, `dispatch_post_hit(ctx)`, `on_combat_start(fighter)`/`on_combat_end(fighter)` (dispatch to effects; effect state is **not** cleared — effects own their reset), `save_state()`/`load_state(d, fighter)` (technique ids + per-effect `state()` + active stance id), and `add()` consults the registry **when it has the id**, else falls back to today's legacy paths (so behavior is unchanged until Tasks 3–5 migrate ids).

- [ ] **Step 4: Run** — `./run.sh --test`, all green (framework live, nothing migrated).

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/techniques/ WUGodot/tests/test_technique_registry.gd WUGodot/tests/run_tests.gd
git commit -m "feat(techniques): effect framework (lifecycle, ordered dispatch, state)"
```

---

## Task 3: Migrate the six stat passives (one param-driven class)

**Files:**
- Create: `WUGodot/scripts/techniques/effects/stat_delta_effect.gd`
- Modify: `WUGodot/data/Techniques/TechniquePool.json`, `technique_engine.gd`, `technique_registry.gd`

- [ ] **Step 1: Add `effect` blocks to TechniquePool.json**

For A6/A7/A8/A9/A11/A12, e.g.:

```json
{ "id": "A6", ..., "effect": { "type": "stat_delta", "flat": { "posture_max": 15.0, "posture_current": 15.0 } } }
{ "id": "A7", ..., "effect": { "type": "stat_delta", "scaled": { "move_speed": 0.15 } } }
{ "id": "A11", ..., "effect": { "type": "stat_delta", "scaled": { "dash_speed": 0.25, "air_dash_speed": 0.25 }, "dash_cooldown_floor": 0.1, "dash_cooldown_reduction": 0.15 } }
```

(A8 `scaled posture_recovery_rate 0.25`; A9 `flat parry_window 0.03`; A12 `flat health_max/health_current 20`. A11's cooldown rule replicates `-min(0.15, cooldown - 0.1)` from `technique_engine.gd:76`.)

- [ ] **Step 2: Implement `StatDeltaEffect`**

`on_add`: compute deltas (flat as-is; scaled as `fighter.<field> * factor`; A11 cooldown special-cased via its params), apply, remember in effect state. `on_remove`: subtract remembered deltas, clamp `*_current` to `*_max` exactly as `technique_engine.gd:96-112` does. `state()/restore()` carries the remembered deltas.

- [ ] **Step 3: Register A6–A12 ids; delete their branches from the engine's `_apply_on_add`/`_unapply` matches.**

- [ ] **Step 4: Gate** — `./run.sh --test`: the existing stat-delta characterizations in `test_technique_engine.gd` (A6 115 posture, A7 speed, A9 0.18 window, A11 1375/0.65, A8 15.0, A12 120) must pass **unchanged**.

- [ ] **Step 5: Commit** — `git add -A WUGodot/scripts/techniques WUGodot/data/Techniques WUGodot/scripts/technique_engine.gd && git commit -m "feat(techniques): stat passives via param-driven effect"`

---

## Task 4: Migrate hit-pipeline effects + rewire combat_system

The riskiest task: `combat_system.gd:318-360` (outgoing + block math) and `:300-302` (B1 arming) stop naming IDs. Gate: Task 1's characterization suite.

**Files:**
- Create: `effects/low_hp_boost_effect.gd` (B5), `effects/sparrow_effect.gd` (A4), `effects/echo_effect.gd` (B1), `effects/flowing_water_effect.gd` (B3), `effects/bleed_on_heavy_effect.gd` (A3), `effects/twin_strike_effect.gd` (A10), `effects/block_chip_effect.gd` (A5)
- Modify: `combat_system.gd`, `technique_engine.gd`, `technique_registry.gd`, `TechniquePool.json` (params: thresholds/multipliers per the table)

- [ ] **Step 1: Implement the seven effects** (exemplar — B5; the rest follow the same shape with the table below):

```gdscript
extends "res://scripts/techniques/technique_effect.gd"
# B5 — Scar of the Past: +25% hp/posture damage while at or below 30% HP.
func _init() -> void:
	id = "B5"; priority = 10
func modify_outgoing_hit(ctx: Variant) -> void:  # Variant, not HitContext (inner-class typing across path-extends is parser-fragile)
	var threshold: float = float(params.get("hp_threshold", 0.3))
	var mult: float = float(params.get("multiplier", 1.25))
	if ctx.attacker.health_current <= ctx.attacker.health_max * threshold:
		ctx.hp_damage *= mult
		ctx.posture_damage *= mult
```

| effect | priority | behavior to replicate (source) |
|---|---|---|
| A4 sparrow | 20 | light only + `has_sparrow_bonus()` window → hp ×1.30, consume, message "雀翼!" (`combat_system.gd:325-329`; window/consume state moves into the effect, `on_dash_end` sets the 0.6 s timer, `update` ticks it) |
| B1 echo | 30 | `on_parry_success` arms; armed → `ctx.posture_damage = defender.posture_current + 1.0`, disarm, message "山谷回響!" (`:300-302, :330-332`); arm state resets `on_combat_start` |
| B3 flowing water | 40 | `on_dash_through` arms; armed → `ctx.heal_attacker = 5.0`, disarm, message "流水!" (`:333-335`) |
| A3 bleed | 50 | heavy only → `ctx.bleed_timer = 3.0`, `ctx.bleed_dps = 1.5` (`:358-360`) |
| A10 twin | **post_hit 10** | heavy only → in `post_hit(ctx)` (NOT `modify_outgoing_hit`): `ctx.extra_hits.append({damage: ctx.hp_damage * 0.5, ...})` where `ctx.hp_damage` is the **post-block** primary (`:421` computes the twin *after* block/chip — a pre-block twin on a blocked heavy would be an unblocked-size regression) |
| A5 chip | block 10 | blocked, not perilous/ignores-block → `ctx.hp_damage *= 0.5` (`:339-340`) |

- [ ] **Step 2: Rewire `resolve_hits`**

Replace the ID-checks with this exact sequence (mirroring today's order):
1. Build `HitContext`; set `base_hp_damage` after the combo multiplier, before effects.
2. `attacker.technique_engine.dispatch_outgoing_hit(ctx)` (pre-block phase).
3. **Emit `ctx.messages` now** — before the generic HIT/BLOCKED feedback, preserving today's visible behavior (generic message wins the feedback line; Task 1's order pin enforces this).
4. Block branch: `defender.technique_engine.dispatch_block(ctx)`; emit generic BLOCKED/HIT as today.
5. Apply primary results: hp/posture, `heal_attacker`, bleed fields, `reflect_to_attacker` (with damage number).
6. `attacker.technique_engine.dispatch_post_hit(ctx)` — A10 prices its twin off the now-post-block `ctx.hp_damage`; apply `ctx.extra_hits` (damage_dealt/particles) and any post-hit messages.

The parry branch calls `defender.technique_engine.dispatch_parry_success()` instead of `has("B1")`/`set_echo()`. Keep all non-technique logic (parry/grab/knockback/rage/stagger plumbing) byte-equivalent.

- [ ] **Step 3: Gate** — `./run.sh --test`: **Task 1's 12 characterizations must pass unchanged** (this is the entire point). Then grep: `grep -n '\.has("' WUGodot/scripts/combat_system.gd` → only non-technique uses remain (Dictionary `.has` on input/action dicts is fine; no `has("A...")/("B...")/("D...")`).

- [ ] **Step 4: Commit** — `git add -A WUGodot/scripts && git commit -m "feat(techniques): hit-pipeline effects via ordered ctx dispatch"`

---

## Task 5: Migrate stances + remaining triggers; engine becomes pure host

**Files:**
- Create: `effects/stance_drunken_effect.gd` (D1), `effects/stance_tiger_effect.gd` (D2), `effects/dash_stab_effect.gd` (A1), `effects/stagger_effect.gd` (A2), `effects/break_heal_effect.gd` (B2), `effects/gaze_effect.gd` (B4), `effects/phoenix_effect.gd` (B6)
- Modify: `technique_engine.gd` (delete all remaining ID matches; add `active_stance_display_name()`), `combat_system.gd:86-95` (stance banner from `active_stance_display_name()`), `combat_system.gd:108-119` (A1 via `dispatch_dash_end`), **`combat_scene.gd:713-714`** (HUD stance text also maps `"D1"/"D2"` today — rewire to `active_stance_display_name()` or the ID-literal gate in Step 3 fails), `fighter.gd:221` (auto-chain query), `TechniquePool.json` (stance `display_name`, params: D1 break threshold 20, dash 0.30/0.26; D2 timer 15, reflect 0.10; B2 heal 15; B6 heal 0.2/invuln 2.0; B4 gaze 3 s/+50%; A1 range 60/damage 8; A2 chance 0.2)

- [ ] **Step 1: Stance effects** — `exclusive_group = "stance"` (engine's `add()` removes same-group effects, replacing the `begins_with("D")` check); D1: `on_stance_activate/deactivate` swap dash fields (state-carried pre-values), `on_stance_damage` accumulates to the 20-dmg break; D2: 15 s timer in `update`, `attack_override` returns tiger attacks via the existing catalog wrappers, `modify_block` carries the 10% reflect (moves here from Task 4's table if simpler — either home is fine, one only), `should_auto_chain_light(def)` returns `def.id == "tiger_light" + combo guard`; banner text from `display_name` ("醉拳 DRUNKEN FORM" / "虎形 TIGER STANCE").
- [ ] **Step 2: Trigger effects** — B2 (`on_posture_break_dealt` heal 15), B6 (`try_lethal_save`, `once_per_run`, state `{used}`), B4 (`on_kill` defer + `update` apply/expire + `on_combat_end` cleanup, state `{earned}` persists across combats — exactly `technique_engine.gd:115-129, 225-233, 259-267`), A1 (`on_dash_end(fighter, enemy)` returns `{damage: 8, message: "落葉!"}` when in range 60 + facing — `combat_system.gd:108-119` consumes the dict), A2 (`roll_stagger(rng)` < 0.2).
- [ ] **Step 3: Engine cleanup + ID-literal gate** — `technique_engine.gd` keeps only: id list, effect host/dispatch, stance activate/deactivate orchestration (rage gate stays — it's fighter-resource logic), `active_stance_display_name()` (reads the active stance effect's `display_name`), `save_state/load_state`, and the public methods `combat_system`/`fighter`/`combat_scene` call (now pure dispatchers). **No technique ID literals remain** outside `effects/` and JSON — this includes `combat_scene.gd:713-714`'s HUD mapping: `grep -rn '"A[0-9]\|"B[0-9]\|"D[0-9]' WUGodot/scripts --include="*.gd" | grep -v techniques/ | grep -v tests/` → empty.
- [ ] **Step 4: Gate** — `./run.sh --test`: full suite incl. all of `test_technique_engine.gd` (stance exclusivity, gaze deferral, phoenix once-per-run…) and Task 1's combat characterizations, unchanged.
- [ ] **Step 5: Commit** — `git commit -m "feat(techniques): stances + triggers as effects; engine is a pure host"`

---

## Task 6: Persistence round-trip + boundary + final gates

- [ ] **Step 1: End-to-end state test** (append to `test_technique_registry.gd`): build an engine with B4+B6+**D1**, consume the phoenix, earn gaze, activate the stance (full rage), tick partway, `save_state()` → fresh engine + fresh fighter + `load_state()`. Assert **precisely**:
  - phoenix still used → a lethal hit is NOT saved a second time;
  - gaze still pending → first `update` after restore applies the speed buff;
  - **stance restore is exact**: stance is active **without consuming the new fighter's rage** (restore bypasses the rage gate — it re-applies state, it does not re-trigger activation), `on_stance_activate`'s stat mutations are re-applied (D1: `dash_duration == 0.30`, `dash_iframe_end == 0.26`, with the *new* fighter's pre-stance values captured for later deactivate), and accumulated stance state survives (D1 `stance_damage_taken`; for D2: remaining `stance_timer`, not a fresh 15 s).

  This is the Phase-C save hook, proven now — restore must go through a dedicated `load_state` path on the stance effect, not through `activate_stance()`.
- [ ] **Step 2: Boundary check** (A2 inverse rule):

```bash
git diff --name-only <A2_BASE>...HEAD | grep -E "attack_catalog\.gd|data/Attacks/" && echo "BOUNDARY VIOLATED" || echo "boundary OK"
git diff <A2_BASE>...HEAD -- WUGodot/scripts/data_manager.gd | grep -E "get_attack_def|_load_attacks|_REQUIRED_ATTACK" && echo "ATTACK LOADING TOUCHED" || echo "attack loading untouched"
```

- [ ] **Step 3: Final gates** — `./run.sh --test` → 0 failed; `./run.sh --import` → clean; `git diff --check` → clean; quick playtest: acquire B5 + a stance in a run, verify banner, stance behavior, and damage feel unchanged.
- [ ] **Step 4: Commit** — `git commit -m "feat(techniques): effect state persistence + A2 boundary verification"`

---

## Self-Review Notes

- **Characterization-first**: Task 1 pins the 12 combat-side behaviors (the gap — engine-side was already covered) *before* anything moves; Tasks 4–5 use it as their gate. Numbers in the tests are derived from current code paths (`hu_light` 12 dmg, combo ×1.0 first hit, `blockHealthMultiplier` 0.2).
- **Ordering preserved**: priorities pin today's B5→A4→echo→flow→bleed→twin sequence; the framework test proves dispatch order is deterministic.
- **Lifecycle completeness** (per the proposal's Rev-2 requirement): timers (`update`), deferred cross-combat state (B4 `state()` persists, `on_combat_end` semantics match `reset_combat_state`'s deliberate gaze carry-over at `technique_engine.gd:267`), once-per-run (B6), stance exclusivity (`exclusive_group`), persisted state (`save_state/load_state`, Task 6 round-trip).
- **A2 boundary**: attack data untouched; verified mechanically against `A2_BASE` (file-level for catalog/JSON, content-level for DataManager's attack functions since DataManager legitimately changes for technique `effect` params).
- **Deliberate non-goals**: no new techniques; no JSON-scripted effect *logic* (params in JSON, behavior in small GDScript classes — full expression interpreters are YAGNI); rage gating and combo bookkeeping stay in fighter/combat (resource logic, not technique logic).
- **Known risks**: (1) `resolve_hits` rewiring is the big diff — keep non-technique lines byte-identical and lean on the characterization suite; (2) test count for Task 1 may need ±: if any pinned number disagrees with observed behavior, trust the *code*, adjust the test, and note it; (3) D2 reflect can live in Task 4 (block table) or Task 5 (stance class) — pick ONE home, delete the other reference.

**Review fixes folded in:**
- **A10 phase bug** — twin prices off the **post-block** primary (`combat_system.gd:421`); added a third dispatch phase (`post_hit`, after block + primary application) so a blocked heavy can't spawn an unblocked-size twin.
- **Feedback ordering** — contract stated (technique messages emit *before* generic HIT/BLOCKED; last emission wins the line) + a signal-order characterization in Task 1 (13 asserts).
- **combat_scene stance HUD** — `combat_scene.gd:713-714` maps `"D1"/"D2"` too; included in Task 5 via `active_stance_display_name()` so the ID-literal gate can actually pass.
- **Framework test strengthened** — explicit dummies for `exclusive_group` replacement and state-survival across `on_combat_start`, and the round-trip asserts a concrete restored field, not a dictionary hash.
- **Stance restore semantics specified** — bypasses the rage gate, re-applies stance stat mutations on the new fighter, restores accumulated timers/damage; dedicated `load_state` path, not `activate_stance()`.
- **`Variant` ctx typing** — inner-class (`HitContext`) annotations across path-`extends` child scripts are parser-fragile; all effect hook signatures use `Variant` per repo style.
