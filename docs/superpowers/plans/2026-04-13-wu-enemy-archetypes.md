# WU Enemy Archetypes + Iron Bear Boss — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 5 enemy archetypes with unique attack pattern tables and AI behaviors, plus the Xiong Tie (Iron Bear) 2-phase boss fight, replacing the current single generic AI with archetype-driven combat that teaches the player different responses (parry, dodge, space, commit).

**Architecture:** Each enemy archetype is a JSON data file defining stats, a `pattern_table` array of attack IDs, and AI tuning parameters (aggression, block chance, preferred range). A new `AiBrain` RefCounted class reads the pattern table and selects attacks based on range, cooldowns, and weighted randomness. The existing `CombatSystem.update_ai()` delegates to `AiBrain.decide()` instead of hardcoding attack selection. Xiong Tie extends this with a `BossController` that tracks phase (1→2 at 50% HP), adjusts recovery timing, and gates signature moves (Bear Crush, Mountain-Breaker Stance) to once-per-phase. `AttackCatalog` gains ~20 new static factory methods for archetype and boss attacks.

**Tech Stack:** Godot 4.6.2 (GDScript), RefCounted data classes, JSON data under `WUGodot/data/Enemies/`. Headless test harness (`godot --headless --script res://tests/run_tests.gd`).

**Spec reference:** `docs/superpowers/specs/2026-04-10-wu-mvp-design.md` — this plan implements **Section D (Enemy archetypes + Boss)**.

**Plan sequence (5 plans total for the WU MVP):**

1. **Plan 1 — Combat Foundation Refactor.** Implemented at commit `72e34bc`.
2. **Plan 2 — Technique System + 20-Technique MVP Pool.** Implemented at commit `2ecf4a2`.
3. **Plan 3 (this document) — Enemy Archetypes + Iron Bear Boss.** 5 archetypes with pattern tables, Xiong Tie 2-phase boss.
4. **Plan 4 — Run Structure Expansion.** 8 node types, procedural map-gen, Event system, Shop system.
5. **Plan 5 — Run Flow & Chapter 1 Polish.** Main menu, Victory scroll, Defeat screen, SFX/music, balance pass.

Each plan produces working, testable software. Plan 3 validates through headless tests (new test modules) and a manual playtest checklist.

---

## File Structure

**New files:**

- `WUGodot/scripts/ai_brain.gd` — Per-fighter AI decision maker. Holds a pattern table (array of attack IDs), AI tuning params (aggression, block_chance, preferred_range, retreat_chance), and a `decide()` method that returns an action dictionary (`{type: "attack", attack_id: "..."}`, `{type: "block"}`, `{type: "move", direction: ...}`, `{type: "dash"}`, `{type: "idle"}`). Replaces the hardcoded attack selection in `CombatSystem.update_ai()`. ~120 lines.
- `WUGodot/scripts/boss_controller.gd` — Xiong Tie-specific phase manager. Tracks current phase (1 or 2), handles phase transition at 50% HP (roar feedback, recovery speed adjustment), gates Mountain-Breaker Stance to once-per-phase, tracks Bear Crush cooldown. Exposes `check_phase_transition()` and `get_phase_attack_table()`. ~90 lines.
- `WUGodot/data/Enemies/BanditSwordsman.json` — Replaces `BasicEnemy.json`. Stats + pattern table for the Bandit Swordsman archetype.
- `WUGodot/data/Enemies/BanditSpearman.json` — Spearman archetype: long reach, 2-attack pattern.
- `WUGodot/data/Enemies/WanderingRonin.json` — Ronin archetype: medium difficulty, 4-attack pattern with 1 perilous.
- `WUGodot/data/Enemies/SectDisciple.json` — Elite mirror-match: 5-attack pattern including parry-counter and jump-attack.
- `WUGodot/data/Enemies/MaskedAssassin.json` — Elite teleport gimmick: 4-attack pattern with perilous grab.
- `WUGodot/data/Enemies/IronBear.json` — Xiong Tie boss: large frame, high HP, 2-phase attack tables.
- `WUGodot/tests/test_ai_brain.gd` — Tests for pattern table loading, attack selection, range-based filtering.
- `WUGodot/tests/test_boss_controller.gd` — Tests for phase transition, once-per-phase gating, attack table switching.

**Modified files:**

- `WUGodot/scripts/attack_catalog.gd` — Add ~20 new static factory methods: 3 bandit swordsman attacks (slash, thrust, overhead), 2 spearman attacks (long_thrust, wide_swing), 4 ronin attacks (ronin_slash, ronin_thrust, ronin_sweep, ronin_perilous_thrust), 5 sect disciple attacks (disciple_slash, disciple_thrust, disciple_sweep, disciple_counter, disciple_jump_attack), 4 assassin attacks (smoke_thrust, flicker_slash, backstab, assassin_perilous_grab), 6 boss attacks (bear_swipe, bear_overhead, bear_stomp, bear_crush_grab, mountain_breaker, bear_roar_aoe).
- `WUGodot/scripts/combat_system.gd` — Replace hardcoded `update_ai()` body with `AiBrain`-delegated logic; boss attack selection uses `BossController.get_phase_attack_table()` instead of AiBrain's fixed pattern (swaps to phase 2 table with `bear_roar_aoe` after transition). Phase 2 recovery shortening scales only the recovery portion (`duration = active_end + (duration - active_end) * 0.8`), preserving windup/active timing. `is_blocking` cleared at the top of every AI action to prevent latch-through. Add grab resolution in `resolve_hits()` for Bear Crush. Gate `update_player()` movement behind `is_grabbed`.
- `WUGodot/scripts/fighter.gd` — Add `ai_brain: Variant = null` field, `boss_controller: Variant = null` field, `archetype_id: String = ""` field. Add `is_grabbed: bool = false` and `_grab_timer: float = 0.0` for Bear Crush. Update `reset_for_combat()` and `update_timers()`. Gate `can_attack()`, `can_jump()`, `can_dash()` behind `not is_grabbed` so grab immobilizes the fighter for 0.6s.
- `WUGodot/scripts/enemy_factory.gd` — Replace 3-type lookup with archetype-based creation. Add `_pick_archetype_for_node()` to select archetype by node type (BATTLE → random easy, ELITE → random hard, BOSS → IronBear). Load pattern tables from JSON and assign `AiBrain` to enemy fighters.
- `WUGodot/scripts/attack_definition.gd` — Add `is_grab: bool = false` field for Bear Crush. Add `forward_lunge: float = 0.0` field for attacks that move the attacker forward (Mountain-Breaker charge, Sect Disciple jump-attack).
- `WUGodot/scripts/combat_scene.gd` — Add boss phase transition visual (screen flash, feedback message, slow-mo). Add grab visual indicator (shake + red tint on grabbed fighter).
- `WUGodot/scripts/data_manager.gd` — Update `_load_enemies()` to key by archetype ID (e.g., `"bandit_swordsman"`) instead of generic type. Add `get_enemy_archetypes_for_difficulty(difficulty: String)` helper.
- `WUGodot/tests/run_tests.gd` — Add `test_ai_brain.gd` and `test_boss_controller.gd` to `_TEST_MODULES`.

**Deleted files:**

- `WUGodot/data/Enemies/BasicEnemy.json` — Replaced by `BanditSwordsman.json`.
- `WUGodot/data/Enemies/EliteEnemy.json` — Replaced by `SectDisciple.json` and `MaskedAssassin.json`.
- `WUGodot/data/Enemies/BossEnemy.json` — Replaced by `IronBear.json`.

---

## Testing Strategy

**Headless tests** (automated, run via `godot --headless --script res://tests/run_tests.gd`):

- `test_ai_brain.gd` — Pattern table construction, attack selection respects range, block decision probability, empty pattern fallback, cooldown tracking.
- `test_boss_controller.gd` — Phase starts at 1, transitions to 2 at 50% HP, Mountain-Breaker once-per-phase gating, attack table switches on phase change, phase transition only fires once.

**Manual playtest checklist** (Task 12):

- Each archetype's silhouette and behavior feels distinct.
- Bandit Swordsman: predictable, parry-friendly.
- Bandit Spearman: long reach forces spacing.
- Wandering Ronin: varied patterns, one perilous attack.
- Sect Disciple: aggressive mirror-match, can parry-counter.
- Masked Assassin: teleport repositioning, perilous grab.
- Xiong Tie phase 1 → phase 2 transition fires at 50% HP with visual feedback.
- Bear Crush grab connects and deals 25% max HP.
- Mountain-Breaker Stance charges across screen, must be dashed.
- Boss fight lasts 3-5 minutes.

---

### Task 1: Attack Definitions for All Archetypes

**Files:**
- Modify: `WUGodot/scripts/attack_definition.gd`
- Modify: `WUGodot/scripts/attack_catalog.gd`

- [ ] **Step 1: Add new fields to AttackDefinition**

In `WUGodot/scripts/attack_definition.gd`, add after `ignores_block` (line 22):

```gdscript
var is_grab: bool = false
var forward_lunge: float = 0.0
```

- [ ] **Step 2: Add Bandit Swordsman attacks to AttackCatalog**

In `WUGodot/scripts/attack_catalog.gd`, add after the `tiger_heavy()` function (after line 125):

```gdscript
# --- Bandit Swordsman (Easy) ---

static func bandit_overhead():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "bandit_overhead"
	def.duration = 0.95
	def.windup_end = 0.50
	def.active_end = 0.65
	def.damage = 14.0
	def.posture_damage = 30.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 72.0
	def.knockback_units = 380.0
	return def
```

Note: `bandit_slash()` and `bandit_thrust_perilous()` already exist in the catalog. The overhead completes the Bandit Swordsman's 3-attack pattern.

- [ ] **Step 3: Add Bandit Spearman attacks**

```gdscript
# --- Bandit Spearman (Easy, reach) ---

static func spear_long_thrust():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "spear_long_thrust"
	def.duration = 0.90
	def.windup_end = 0.50
	def.active_end = 0.62
	def.damage = 11.0
	def.posture_damage = 20.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 110.0
	def.knockback_units = 280.0
	return def

static func spear_wide_swing():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "spear_wide_swing"
	def.duration = 1.05
	def.windup_end = 0.55
	def.active_end = 0.72
	def.damage = 13.0
	def.posture_damage = 28.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 120.0
	def.knockback_units = 400.0
	return def
```

- [ ] **Step 4: Add Wandering Ronin attacks**

```gdscript
# --- Wandering Ronin (Medium) ---

static func ronin_slash():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "ronin_slash"
	def.duration = 0.65
	def.windup_end = 0.30
	def.active_end = 0.42
	def.damage = 12.0
	def.posture_damage = 26.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 76.0
	def.knockback_units = 300.0
	return def

static func ronin_thrust():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "ronin_thrust"
	def.duration = 0.70
	def.windup_end = 0.35
	def.active_end = 0.48
	def.damage = 14.0
	def.posture_damage = 22.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 88.0
	def.knockback_units = 320.0
	return def

static func ronin_sweep():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "ronin_sweep"
	def.duration = 0.85
	def.windup_end = 0.40
	def.active_end = 0.58
	def.damage = 16.0
	def.posture_damage = 32.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 80.0
	def.knockback_units = 420.0
	return def

static func ronin_perilous_thrust():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "ronin_perilous_thrust"
	def.duration = 0.90
	def.windup_end = 0.50
	def.active_end = 0.65
	def.damage = 18.0
	def.posture_damage = 24.0
	def.is_heavy = false
	def.is_perilous = true
	def.is_parryable = false
	def.range_units = 92.0
	def.knockback_units = 360.0
	return def
```

- [ ] **Step 5: Add Sect Disciple attacks**

```gdscript
# --- Sect Disciple (Hard, elite mirror-match) ---

static func disciple_slash():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "disciple_slash"
	def.duration = 0.55
	def.windup_end = 0.22
	def.active_end = 0.34
	def.damage = 13.0
	def.posture_damage = 26.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 74.0
	def.knockback_units = 300.0
	return def

static func disciple_thrust():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "disciple_thrust"
	def.duration = 0.60
	def.windup_end = 0.28
	def.active_end = 0.40
	def.damage = 14.0
	def.posture_damage = 24.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 82.0
	def.knockback_units = 320.0
	return def

static func disciple_sweep():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "disciple_sweep"
	def.duration = 0.75
	def.windup_end = 0.35
	def.active_end = 0.50
	def.damage = 16.0
	def.posture_damage = 34.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 78.0
	def.knockback_units = 400.0
	return def

static func disciple_counter():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "disciple_counter"
	def.duration = 0.45
	def.windup_end = 0.12
	def.active_end = 0.28
	def.damage = 15.0
	def.posture_damage = 36.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 70.0
	def.knockback_units = 360.0
	return def

static func disciple_jump_attack():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "disciple_jump_attack"
	def.duration = 0.80
	def.windup_end = 0.35
	def.active_end = 0.52
	def.damage = 18.0
	def.posture_damage = 30.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 90.0
	def.knockback_units = 440.0
	def.forward_lunge = 200.0
	return def
```

- [ ] **Step 6: Add Masked Assassin attacks**

```gdscript
# --- Masked Assassin (Hard, elite teleport gimmick) ---

static func smoke_thrust():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "smoke_thrust"
	def.duration = 0.50
	def.windup_end = 0.18
	def.active_end = 0.30
	def.damage = 12.0
	def.posture_damage = 20.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 68.0
	def.knockback_units = 260.0
	return def

static func flicker_slash():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "flicker_slash"
	def.duration = 0.40
	def.windup_end = 0.12
	def.active_end = 0.24
	def.damage = 10.0
	def.posture_damage = 18.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 72.0
	def.knockback_units = 240.0
	return def

static func assassin_backstab():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "assassin_backstab"
	def.duration = 0.55
	def.windup_end = 0.20
	def.active_end = 0.35
	def.damage = 20.0
	def.posture_damage = 16.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 64.0
	def.knockback_units = 300.0
	return def

static func assassin_perilous_grab():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "assassin_perilous_grab"
	def.duration = 0.85
	def.windup_end = 0.45
	def.active_end = 0.60
	def.damage = 22.0
	def.posture_damage = 10.0
	def.is_heavy = false
	def.is_perilous = true
	def.is_parryable = false
	def.is_grab = true
	def.range_units = 60.0
	def.knockback_units = 200.0
	return def
```

- [ ] **Step 7: Add Xiong Tie (Iron Bear) boss attacks**

```gdscript
# --- Xiong Tie / Iron Bear (Boss) ---

static func bear_swipe():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "bear_swipe"
	def.duration = 0.80
	def.windup_end = 0.40
	def.active_end = 0.55
	def.damage = 16.0
	def.posture_damage = 32.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 90.0
	def.knockback_units = 380.0
	return def

static func bear_overhead():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "bear_overhead"
	def.duration = 1.10
	def.windup_end = 0.55
	def.active_end = 0.72
	def.damage = 22.0
	def.posture_damage = 44.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 85.0
	def.knockback_units = 500.0
	return def

static func bear_stomp():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "bear_stomp"
	def.duration = 0.95
	def.windup_end = 0.50
	def.active_end = 0.65
	def.damage = 14.0
	def.posture_damage = 38.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 70.0
	def.knockback_units = 350.0
	return def

static func bear_crush_grab():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "bear_crush_grab"
	def.duration = 1.20
	def.windup_end = 0.60
	def.active_end = 0.80
	def.damage = 0.0
	def.posture_damage = 0.0
	def.is_heavy = false
	def.is_perilous = true
	def.is_parryable = false
	def.is_grab = true
	def.range_units = 95.0
	def.knockback_units = 0.0
	def.forward_lunge = 150.0
	return def

static func mountain_breaker():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "mountain_breaker"
	def.duration = 1.40
	def.windup_end = 0.70
	def.active_end = 0.95
	def.damage = 28.0
	def.posture_damage = 50.0
	def.is_heavy = true
	def.is_perilous = true
	def.is_parryable = false
	def.range_units = 100.0
	def.knockback_units = 600.0
	def.forward_lunge = 600.0
	return def

static func bear_roar_aoe():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "bear_roar_aoe"
	def.duration = 0.90
	def.windup_end = 0.45
	def.active_end = 0.65
	def.damage = 8.0
	def.posture_damage = 20.0
	def.is_heavy = false
	def.is_perilous = true
	def.is_parryable = false
	def.range_units = 140.0
	def.knockback_units = 450.0
	return def
```

- [ ] **Step 8: Commit**

```bash
git add WUGodot/scripts/attack_definition.gd WUGodot/scripts/attack_catalog.gd
git commit -m "feat: add attack definitions for 5 archetypes and Iron Bear boss"
```

---

### Task 2: AiBrain — Pattern Table and Decision Logic

**Files:**
- Create: `WUGodot/scripts/ai_brain.gd`
- Create: `WUGodot/tests/test_ai_brain.gd`

- [ ] **Step 1: Write the failing tests**

Create `WUGodot/tests/test_ai_brain.gd`:

```gdscript
extends RefCounted

const AiBrainScript = preload("res://scripts/ai_brain.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

func _make_fighter() -> Variant:
	var f: Variant = FighterScript.new()
	f.health_max = 100.0
	f.health_current = 100.0
	f.posture_max = 100.0
	f.posture_current = 100.0
	f.move_speed = 300.0
	f.attack_range = 68.0
	f.position = Vector2(800.0, 940.0)
	f.facing = -1
	f.is_ai = true
	return f

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	# Test 1: empty brain returns idle
	var brain: Variant = AiBrainScript.new()
	var ai: Variant = _make_fighter()
	var target: Variant = _make_fighter()
	target.position = Vector2(400.0, 940.0)
	var action: Dictionary = brain.decide(ai, target)
	if str(action.get("type", "")) == "idle":
		passed += 1
	else:
		failed += 1
		failures.append("empty brain should return idle (got %s)" % str(action.get("type", "")))

	# Test 2: brain with pattern table returns attack when in range
	brain = AiBrainScript.new()
	brain.pattern_table = ["bandit_slash", "bandit_thrust_perilous"]
	brain.aggression = 1.0
	brain.preferred_range = 70.0
	ai.position = Vector2(470.0, 940.0)
	target.position = Vector2(400.0, 940.0)
	ai._attack_cooldown = 0.0
	ai._ai_decision_timer = 0.0
	var got_attack: bool = false
	for i in range(20):
		action = brain.decide(ai, target)
		if str(action.get("type", "")) == "attack":
			got_attack = true
			break
	if got_attack:
		passed += 1
	else:
		failed += 1
		failures.append("brain with pattern table should return attack when in range")

	# Test 3: attack_id from decision is in pattern table
	if got_attack:
		var aid: String = str(action.get("attack_id", ""))
		if brain.pattern_table.has(aid):
			passed += 1
		else:
			failed += 1
			failures.append("attack_id '%s' not in pattern table" % aid)
	else:
		passed += 1

	# Test 4: brain respects decision cooldown
	brain._decision_cooldown = 5.0
	action = brain.decide(ai, target)
	if str(action.get("type", "")) != "attack":
		passed += 1
	else:
		failed += 1
		failures.append("brain should not attack during decision cooldown")
	brain._decision_cooldown = 0.0

	# Test 5: out of range → move toward target
	ai.position = Vector2(900.0, 940.0)
	target.position = Vector2(400.0, 940.0)
	action = brain.decide(ai, target)
	if str(action.get("type", "")) == "move":
		passed += 1
	else:
		failed += 1
		failures.append("should move toward target when out of range (got %s)" % str(action.get("type", "")))

	# Test 6: block decision when target has started an attack (windup phase)
	ai.position = Vector2(470.0, 940.0)
	target.position = Vector2(400.0, 940.0)
	brain.block_chance = 1.0
	target.start_light_attack()  # is_active() is true immediately; is_hit_active() is false until windup_end
	action = brain.decide(ai, target)
	if str(action.get("type", "")) == "block":
		passed += 1
	else:
		failed += 1
		failures.append("should block when target attacking and block_chance=1.0 (got %s)" % str(action.get("type", "")))
	brain.block_chance = 0.0

	# Test 7: update_cooldowns decrements timer
	brain._decision_cooldown = 1.0
	brain.update_cooldowns(0.5)
	if absf(brain._decision_cooldown - 0.5) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("update_cooldowns should decrement (got %.2f)" % brain._decision_cooldown)

	# Test 8: get_attack_def returns valid definition
	brain.pattern_table = ["bandit_slash"]
	var atk_def: Variant = brain.get_attack_def("bandit_slash")
	if atk_def != null and atk_def.id == "bandit_slash":
		passed += 1
	else:
		failed += 1
		failures.append("get_attack_def should return valid attack definition")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: FAIL because `ai_brain.gd` does not exist yet. (Tests won't run until registered in Task 6.)

- [ ] **Step 3: Implement AiBrain**

Create `WUGodot/scripts/ai_brain.gd`:

```gdscript
class_name AiBrain
extends RefCounted

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

var pattern_table: Array[String] = []
var aggression: float = 0.5
var block_chance: float = 0.25
var preferred_range: float = 70.0
var retreat_chance: float = 0.02
var dash_chance: float = 0.05
var teleport_chance: float = 0.0
var _decision_cooldown: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func update_cooldowns(dt: float) -> void:
	if _decision_cooldown > 0.0:
		_decision_cooldown -= dt

func decide(ai: Fighter, target: Fighter) -> Dictionary:
	if ai.is_stunned or ai.is_in_recovery():
		return {"type": "idle"}

	if _decision_cooldown > 0.0:
		return {"type": "idle"}

	var distance: float = target.position.x - ai.position.x
	var abs_distance: float = absf(distance)
	var direction: float = signf(distance)

	# Block if target has started an attack (react to windup, not just active frames)
	if target._attack_state.is_active() and abs_distance < preferred_range * 1.5:
		if _rng.randf() < block_chance:
			_decision_cooldown = 0.15
			return {"type": "block"}

	# In attack range
	if abs_distance <= preferred_range + ai.half_width + target.half_width:
		if pattern_table.is_empty():
			return {"type": "idle"}

		# Occasionally retreat
		if _rng.randf() < retreat_chance:
			_decision_cooldown = 0.3
			return {"type": "move", "direction": -direction}

		# Attack
		if ai.can_attack() and _rng.randf() < aggression:
			var attack_id: String = _pick_attack(abs_distance)
			_decision_cooldown = 0.25
			return {"type": "attack", "attack_id": attack_id}

		return {"type": "idle"}

	# Out of range — approach
	if abs_distance > preferred_range * 2.5 and _rng.randf() < dash_chance and ai.can_dash():
		_decision_cooldown = 0.2
		return {"type": "dash", "direction": direction}

	return {"type": "move", "direction": direction}

func _pick_attack(distance: float) -> String:
	if pattern_table.is_empty():
		return ""
	# Filter to attacks whose range can reach the target
	var candidates: Array[String] = []
	for atk_id in pattern_table:
		var atk: Variant = get_attack_def(atk_id)
		if atk != null and atk.range_units + 30.0 >= distance:
			candidates.append(atk_id)
	if candidates.is_empty():
		candidates = pattern_table.duplicate()
	return candidates[_rng.randi_range(0, candidates.size() - 1)]

func get_attack_def(attack_id: String) -> Variant:
	if not AttackCatalogScript.has_method(attack_id):
		return null
	return AttackCatalogScript.call(attack_id)

static func from_enemy_data(data: Dictionary) -> AiBrain:
	var brain: AiBrain = AiBrain.new()
	var raw_table: Variant = data.get("pattern_table", [])
	if typeof(raw_table) == TYPE_ARRAY:
		for entry in (raw_table as Array):
			brain.pattern_table.append(str(entry))
	brain.aggression = float(data.get("aggression", 0.5))
	brain.block_chance = float(data.get("blockChance", 0.25))
	brain.preferred_range = float(data.get("preferredRange", 70.0))
	brain.retreat_chance = float(data.get("retreatChance", 0.02))
	brain.dash_chance = float(data.get("dashChance", 0.05))
	brain.teleport_chance = float(data.get("teleport_chance", 0.0))
	return brain
```

- [ ] **Step 4: Commit**

```bash
git add WUGodot/scripts/ai_brain.gd WUGodot/tests/test_ai_brain.gd
git commit -m "feat: add AiBrain pattern table and decision logic"
```

---

### Task 3: BossController — Phase Management for Xiong Tie

**Files:**
- Create: `WUGodot/scripts/boss_controller.gd`
- Create: `WUGodot/tests/test_boss_controller.gd`

- [ ] **Step 1: Write the failing tests**

Create `WUGodot/tests/test_boss_controller.gd`:

```gdscript
extends RefCounted

const BossControllerScript = preload("res://scripts/boss_controller.gd")
const FighterScript = preload("res://scripts/fighter.gd")

func _make_boss() -> Variant:
	var f: Variant = FighterScript.new()
	f.health_max = 300.0
	f.health_current = 300.0
	f.posture_max = 160.0
	f.posture_current = 160.0
	f.move_speed = 280.0
	f.is_ai = true
	return f

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var boss: Variant = _make_boss()
	var ctrl: Variant = BossControllerScript.new()

	# Test 1: starts in phase 1
	if ctrl.current_phase == 1:
		passed += 1
	else:
		failed += 1
		failures.append("should start in phase 1 (got %d)" % ctrl.current_phase)

	# Test 2: no transition above 50% HP
	boss.health_current = 200.0
	var transitioned: bool = ctrl.check_phase_transition(boss)
	if not transitioned and ctrl.current_phase == 1:
		passed += 1
	else:
		failed += 1
		failures.append("should not transition above 50%% HP")

	# Test 3: transition at 50% HP
	boss.health_current = 150.0
	transitioned = ctrl.check_phase_transition(boss)
	if transitioned and ctrl.current_phase == 2:
		passed += 1
	else:
		failed += 1
		failures.append("should transition at 50%% HP (phase=%d)" % ctrl.current_phase)

	# Test 4: transition only fires once
	boss.health_current = 100.0
	transitioned = ctrl.check_phase_transition(boss)
	if not transitioned:
		passed += 1
	else:
		failed += 1
		failures.append("phase transition should not fire twice")

	# Test 5: phase 1 attack table
	ctrl = BossControllerScript.new()
	var p1_table: Array[String] = ctrl.get_phase_attack_table()
	if p1_table.has("bear_swipe") and p1_table.has("bear_overhead") and not p1_table.has("bear_roar_aoe"):
		passed += 1
	else:
		failed += 1
		failures.append("phase 1 table should have swipe/overhead but not roar_aoe")

	# Test 6: phase 2 attack table differs
	boss = _make_boss()
	boss.health_current = 140.0
	ctrl.check_phase_transition(boss)
	var p2_table: Array[String] = ctrl.get_phase_attack_table()
	if p2_table.has("bear_roar_aoe") and p2_table.has("bear_swipe"):
		passed += 1
	else:
		failed += 1
		failures.append("phase 2 table should have roar_aoe and swipe")

	# Test 7: Mountain-Breaker once per phase
	ctrl = BossControllerScript.new()
	if ctrl.can_use_mountain_breaker():
		passed += 1
	else:
		failed += 1
		failures.append("should allow mountain_breaker in phase 1")
	ctrl.consume_mountain_breaker()
	if not ctrl.can_use_mountain_breaker():
		passed += 1
	else:
		failed += 1
		failures.append("should not allow mountain_breaker twice in phase 1")

	# Test 8: phase transition resets Mountain-Breaker
	boss = _make_boss()
	boss.health_current = 140.0
	ctrl.check_phase_transition(boss)
	if ctrl.can_use_mountain_breaker():
		passed += 1
	else:
		failed += 1
		failures.append("phase transition should reset mountain_breaker availability")

	# Test 9: Bear Crush cooldown
	ctrl = BossControllerScript.new()
	if ctrl.can_use_bear_crush():
		passed += 1
	else:
		failed += 1
		failures.append("should allow bear_crush initially")
	ctrl.consume_bear_crush()
	if not ctrl.can_use_bear_crush():
		passed += 1
	else:
		failed += 1
		failures.append("should not allow bear_crush on cooldown")
	ctrl.update_cooldowns(10.0)
	if ctrl.can_use_bear_crush():
		passed += 1
	else:
		failed += 1
		failures.append("bear_crush should be available after cooldown expires")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Implement BossController**

Create `WUGodot/scripts/boss_controller.gd`:

```gdscript
class_name BossController
extends RefCounted

var current_phase: int = 1
var _phase_transitioned: bool = false
var _mountain_breaker_used: bool = false
var _bear_crush_cooldown: float = 0.0

const BEAR_CRUSH_COOLDOWN: float = 8.0

const PHASE_1_TABLE: Array[String] = [
	"bear_swipe",
	"bear_swipe",
	"bear_overhead",
	"bear_stomp",
	"bear_crush_grab",
]

const PHASE_2_TABLE: Array[String] = [
	"bear_swipe",
	"bear_overhead",
	"bear_stomp",
	"bear_crush_grab",
	"bear_roar_aoe",
]

func check_phase_transition(boss: Fighter) -> bool:
	if _phase_transitioned:
		return false
	if boss.health_current <= boss.health_max * 0.5:
		current_phase = 2
		_phase_transitioned = true
		_mountain_breaker_used = false
		return true
	return false

func get_phase_attack_table() -> Array[String]:
	if current_phase == 2:
		return PHASE_2_TABLE.duplicate()
	return PHASE_1_TABLE.duplicate()

func can_use_mountain_breaker() -> bool:
	return not _mountain_breaker_used

func consume_mountain_breaker() -> void:
	_mountain_breaker_used = true

func can_use_bear_crush() -> bool:
	return _bear_crush_cooldown <= 0.0

func consume_bear_crush() -> void:
	_bear_crush_cooldown = BEAR_CRUSH_COOLDOWN

func update_cooldowns(dt: float) -> void:
	if _bear_crush_cooldown > 0.0:
		_bear_crush_cooldown -= dt
```

- [ ] **Step 3: Commit**

```bash
git add WUGodot/scripts/boss_controller.gd WUGodot/tests/test_boss_controller.gd
git commit -m "feat: add BossController for Xiong Tie phase management"
```

---

### Task 4: Enemy Archetype JSON Data Files

**Files:**
- Create: `WUGodot/data/Enemies/BanditSwordsman.json`
- Create: `WUGodot/data/Enemies/BanditSpearman.json`
- Create: `WUGodot/data/Enemies/WanderingRonin.json`
- Create: `WUGodot/data/Enemies/SectDisciple.json`
- Create: `WUGodot/data/Enemies/MaskedAssassin.json`
- Create: `WUGodot/data/Enemies/IronBear.json`
- Delete: `WUGodot/data/Enemies/BasicEnemy.json`
- Delete: `WUGodot/data/Enemies/EliteEnemy.json`
- Delete: `WUGodot/data/Enemies/BossEnemy.json`

- [ ] **Step 1: Create BanditSwordsman.json**

```json
{
  "archetype": "bandit_swordsman",
  "name": "Bandit Swordsman",
  "name_cn": "匪劍",
  "difficulty": "easy",
  "visualProfile": "enemy_humanoid_basic",

  "moveSpeed": 200.0,
  "jumpForce": 700.0,
  "gravity": 2800.0,
  "healthMax": 90.0,
  "postureMax": 100.0,
  "postureRecoveryRate": 10.0,
  "attackRange": 72.0,
  "halfWidth": 22.0,
  "height": 88.0,
  "colorBody": "#FF7878",
  "colorAccent": "#D23C3C",

  "pattern_table": ["bandit_slash", "bandit_thrust_perilous", "bandit_overhead"],
  "aggression": 0.5,
  "blockChance": 0.25,
  "preferredRange": 72.0,
  "retreatChance": 0.02,
  "dashChance": 0.03
}
```

- [ ] **Step 2: Create BanditSpearman.json**

```json
{
  "archetype": "bandit_spearman",
  "name": "Bandit Spearman",
  "name_cn": "匪槍",
  "difficulty": "easy",
  "visualProfile": "enemy_humanoid_basic",

  "moveSpeed": 180.0,
  "jumpForce": 650.0,
  "gravity": 2800.0,
  "healthMax": 80.0,
  "postureMax": 90.0,
  "postureRecoveryRate": 9.0,
  "attackRange": 110.0,
  "halfWidth": 22.0,
  "height": 90.0,
  "colorBody": "#C89664",
  "colorAccent": "#966432",

  "pattern_table": ["spear_long_thrust", "spear_wide_swing"],
  "aggression": 0.4,
  "blockChance": 0.15,
  "preferredRange": 110.0,
  "retreatChance": 0.04,
  "dashChance": 0.02
}
```

- [ ] **Step 3: Create WanderingRonin.json**

```json
{
  "archetype": "wandering_ronin",
  "name": "Wandering Ronin",
  "name_cn": "浪人",
  "difficulty": "medium",
  "visualProfile": "enemy_humanoid_elite",

  "moveSpeed": 300.0,
  "jumpForce": 750.0,
  "gravity": 2800.0,
  "healthMax": 120.0,
  "postureMax": 110.0,
  "postureRecoveryRate": 12.0,
  "attackRange": 80.0,
  "halfWidth": 22.0,
  "height": 90.0,
  "colorBody": "#8888CC",
  "colorAccent": "#5555AA",

  "pattern_table": ["ronin_slash", "ronin_thrust", "ronin_sweep", "ronin_perilous_thrust"],
  "aggression": 0.6,
  "blockChance": 0.35,
  "preferredRange": 80.0,
  "retreatChance": 0.03,
  "dashChance": 0.06
}
```

- [ ] **Step 4: Create SectDisciple.json**

```json
{
  "archetype": "sect_disciple",
  "name": "Sect Disciple",
  "name_cn": "門徒",
  "difficulty": "hard",
  "visualProfile": "enemy_humanoid_elite",

  "moveSpeed": 380.0,
  "jumpForce": 780.0,
  "gravity": 2800.0,
  "healthMax": 140.0,
  "postureMax": 130.0,
  "postureRecoveryRate": 14.0,
  "attackRange": 78.0,
  "halfWidth": 24.0,
  "height": 92.0,
  "colorBody": "#FFAA6E",
  "colorAccent": "#E65C00",

  "pattern_table": ["disciple_slash", "disciple_thrust", "disciple_sweep", "disciple_counter", "disciple_jump_attack"],
  "aggression": 0.7,
  "blockChance": 0.45,
  "preferredRange": 78.0,
  "retreatChance": 0.03,
  "dashChance": 0.08
}
```

- [ ] **Step 5: Create MaskedAssassin.json**

```json
{
  "archetype": "masked_assassin",
  "name": "Masked Assassin",
  "name_cn": "面刺客",
  "difficulty": "hard",
  "visualProfile": "enemy_humanoid_elite",

  "moveSpeed": 420.0,
  "jumpForce": 800.0,
  "gravity": 2800.0,
  "healthMax": 100.0,
  "postureMax": 90.0,
  "postureRecoveryRate": 11.0,
  "attackRange": 68.0,
  "halfWidth": 20.0,
  "height": 86.0,
  "colorBody": "#444466",
  "colorAccent": "#222244",

  "pattern_table": ["smoke_thrust", "flicker_slash", "assassin_backstab", "assassin_perilous_grab"],
  "aggression": 0.65,
  "blockChance": 0.2,
  "preferredRange": 68.0,
  "retreatChance": 0.06,
  "dashChance": 0.12,
  "teleport_chance": 0.08
}
```

- [ ] **Step 6: Create IronBear.json**

```json
{
  "archetype": "iron_bear",
  "name": "Xiong Tie",
  "name_cn": "熊鐵",
  "difficulty": "boss",
  "visualProfile": "enemy_humanoid_boss",

  "moveSpeed": 240.0,
  "jumpForce": 600.0,
  "gravity": 2800.0,
  "healthMax": 300.0,
  "postureMax": 180.0,
  "postureRecoveryRate": 16.0,
  "attackRange": 90.0,
  "halfWidth": 30.0,
  "height": 104.0,
  "colorBody": "#CC6644",
  "colorAccent": "#884422",

  "pattern_table": ["bear_swipe", "bear_overhead", "bear_stomp", "bear_crush_grab"],
  "aggression": 0.55,
  "blockChance": 0.15,
  "preferredRange": 90.0,
  "retreatChance": 0.01,
  "dashChance": 0.03
}
```

- [ ] **Step 7: Delete old generic enemy files**

```bash
git rm WUGodot/data/Enemies/BasicEnemy.json WUGodot/data/Enemies/EliteEnemy.json WUGodot/data/Enemies/BossEnemy.json
```

- [ ] **Step 8: Commit**

```bash
git add WUGodot/data/Enemies/
git commit -m "feat: add 5 archetype + boss JSON data, remove generic enemy files"
```

---

### Task 5: Fighter Fields for Archetype and Grab

**Files:**
- Modify: `WUGodot/scripts/fighter.gd`

- [ ] **Step 1: Add new fields to Fighter**

In `WUGodot/scripts/fighter.gd`, after `technique_engine` (line 96):

```gdscript
var ai_brain: Variant = null
var boss_controller: Variant = null
var archetype_id: String = ""
```

After `bleed_dps` (line 113):

```gdscript
var is_grabbed: bool = false
var _grab_timer: float = 0.0
```

- [ ] **Step 2: Update reset_for_combat**

In `reset_for_combat()`, add after `_phoenix_invuln_timer = 0.0` (line 162):

```gdscript
	is_grabbed = false
	_grab_timer = 0.0
```

- [ ] **Step 3: Update update_timers for grab**

In `update_timers()`, add after the `_phoenix_invuln_timer` block (after line 184):

```gdscript
	if _grab_timer > 0.0:
		_grab_timer -= dt
		if _grab_timer <= 0.0:
			is_grabbed = false
```

- [ ] **Step 4: Gate actions behind is_grabbed**

In `WUGodot/scripts/fighter.gd`, update `can_attack()` (line 295):

```gdscript
func can_attack() -> bool:
	return not _attack_state.is_active() and _attack_cooldown <= 0.0 and _dash_timer <= 0.0 and not is_stunned and _landing_recovery <= 0.0 and not is_grabbed
```

Update `can_jump()` (line 298):

```gdscript
func can_jump() -> bool:
	return (is_grounded or has_double_jump) and _jump_cooldown <= 0.0 and not is_stunned and not is_grabbed
```

Update `can_dash()` (line 353):

```gdscript
func can_dash() -> bool:
	return _dash_timer <= 0.0 and _dash_cooldown <= 0.0 and not _attack_state.is_active() and not is_stunned and not is_grabbed
```

- [ ] **Step 5: Gate movement in update_player behind is_grabbed**

In `WUGodot/scripts/combat_system.gd`, update the `can_move` check in `update_player()` (line 29):

```gdscript
	var can_move: bool = fighter.current_animation != Fighter.AnimationState.DASHING and fighter.current_animation != Fighter.AnimationState.ATTACKING and fighter.current_animation != Fighter.AnimationState.STUNNED and not fighter.is_grabbed
```

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/fighter.gd
git commit -m "feat: add archetype_id, ai_brain, boss_controller, and grab fields to Fighter"
```

---

### Task 6: DataManager and EnemyFactory Archetype Wiring

**Files:**
- Modify: `WUGodot/scripts/data_manager.gd`
- Modify: `WUGodot/scripts/enemy_factory.gd`
- Modify: `WUGodot/tests/run_tests.gd`

- [ ] **Step 1: Update DataManager to key enemies by archetype**

In `WUGodot/scripts/data_manager.gd`, replace `_load_enemies()` (lines 200-223):

```gdscript
static func _load_enemies() -> void:
	var dir: DirAccess = DirAccess.open("res://data/Enemies")
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if file_name.get_extension().to_lower() != "json":
			continue
		var enemy_data: Dictionary = _load_json_file("res://data/Enemies/%s" % file_name)
		var archetype: String = str(enemy_data.get("archetype", enemy_data.get("type", "")))
		if archetype.is_empty():
			continue
		var normalized: Dictionary = _default_enemy_data()
		for key in enemy_data.keys():
			normalized[key] = enemy_data[key]
		normalized["colorBody"] = _parse_color(normalized.get("colorBody", "#FF7878"), Color8(255, 120, 120))
		normalized["colorAccent"] = _parse_color(normalized.get("colorAccent", "#D23C3C"), Color8(210, 60, 60))
		_enemies[archetype] = normalized
	dir.list_dir_end()
```

Add after `get_all_techniques()` (line 62):

```gdscript
static func get_enemy_archetypes_for_difficulty(difficulty: String) -> Array[String]:
	var result: Array[String] = []
	for key in _enemies.keys():
		var data: Dictionary = _enemies[key] as Dictionary
		if str(data.get("difficulty", "")) == difficulty:
			result.append(str(key))
	return result
```

- [ ] **Step 2: Rewrite EnemyFactory for archetype creation**

Replace the entire content of `WUGodot/scripts/enemy_factory.gd`:

```gdscript
class_name EnemyFactory
extends RefCounted

const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")
const AiBrainScript = preload("res://scripts/ai_brain.gd")
const BossControllerScript = preload("res://scripts/boss_controller.gd")

static func create_enemy_for_node(node: MapNode) -> Fighter:
	var archetype: String = _pick_archetype_for_node(node)
	return create_enemy_by_archetype(archetype)

static func create_enemy_by_archetype(archetype: String) -> Fighter:
	var enemy_data: Dictionary = DataManager.get_enemy(archetype)
	if enemy_data.is_empty():
		enemy_data = DataManager.get_enemy("bandit_swordsman")
	var settings: Dictionary = DataManager.get_game_settings()

	var enemy: Fighter = Fighter.new()
	enemy.name = str(enemy_data.get("name", "Enemy"))
	enemy.archetype_id = str(enemy_data.get("archetype", archetype))
	enemy.visual_profile_id = str(enemy_data.get("visualProfile", "enemy_humanoid_basic"))
	enemy.position = Vector2(float(settings.get("viewWidth", 1920)) - 360.0, float(settings.get("groundY", 940.0)))
	enemy.facing = -1
	enemy.color_body = enemy_data.get("colorBody", Color8(255, 120, 120)) as Color
	enemy.color_accent = enemy_data.get("colorAccent", Color8(210, 60, 60)) as Color
	enemy.is_ai = true
	enemy.health_max = float(enemy_data.get("healthMax", 90.0))
	enemy.health_current = enemy.health_max
	enemy.posture_max = float(enemy_data.get("postureMax", 100.0))
	enemy.posture_current = enemy.posture_max
	enemy.posture_recovery_rate = float(enemy_data.get("postureRecoveryRate", settings.get("defaultPostureRecoveryRate", 12.0)))
	enemy.attack_damage = float(enemy_data.get("attackDamage", 10.0))
	enemy.attack_posture_damage = float(enemy_data.get("attackPostureDamage", 24.0))
	enemy.attack_range = float(enemy_data.get("attackRange", 68.0))
	enemy.move_speed = float(enemy_data.get("moveSpeed", 380.0))
	enemy.jump_force = float(enemy_data.get("jumpForce", 700.0))
	enemy.gravity = float(enemy_data.get("gravity", 2800.0))
	enemy.half_width = float(enemy_data.get("halfWidth", 22.0))
	enemy.height = float(enemy_data.get("height", 88.0))
	enemy.parry_window = float(settings.get("parryWindow", 0.12))
	enemy.stun_duration = float(settings.get("stunDuration", 0.7))
	enemy.controls = Fighter.none_controls()

	enemy.ai_brain = AiBrainScript.from_enemy_data(enemy_data)

	if str(enemy_data.get("difficulty", "")) == "boss":
		enemy.boss_controller = BossControllerScript.new()

	return enemy

static func _pick_archetype_for_node(node: MapNode) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	match node.node_type:
		MapNode.NodeType.BATTLE:
			var pool: Array[String] = DataManager.get_enemy_archetypes_for_difficulty("easy")
			var medium: Array[String] = DataManager.get_enemy_archetypes_for_difficulty("medium")
			pool.append_array(medium)
			if pool.is_empty():
				return "bandit_swordsman"
			return pool[rng.randi_range(0, pool.size() - 1)]
		MapNode.NodeType.ELITE:
			var pool: Array[String] = DataManager.get_enemy_archetypes_for_difficulty("hard")
			if pool.is_empty():
				return "sect_disciple"
			return pool[rng.randi_range(0, pool.size() - 1)]
		MapNode.NodeType.BOSS:
			return "iron_bear"
		_:
			return "bandit_swordsman"

static func create_player(character_name: String = "") -> Fighter:
	var settings: Dictionary = DataManager.get_game_settings()
	var selected_character: String = character_name
	if selected_character.is_empty():
		selected_character = str(settings.get("selectedCharacter", "Hu"))
	var character_data: Dictionary = DataManager.get_character(selected_character)

	var player: Fighter = Fighter.new()
	player.name = str(character_data.get("name", selected_character))
	player.visual_profile_id = str(character_data.get("visualProfile", "player_humanoid"))
	player.position = Vector2(360.0, float(settings.get("groundY", 940.0)))
	player.facing = 1
	player.color_body = character_data.get("colorBody", Color8(110, 185, 255)) as Color
	player.color_accent = character_data.get("colorAccent", Color8(60, 120, 210)) as Color
	player.controls = Fighter.player_controls()
	player.is_ai = false

	player.health_max = float(character_data.get("healthMax", 100.0))
	player.health_current = player.health_max
	player.posture_max = float(character_data.get("postureMax", 100.0))
	player.posture_current = player.posture_max
	player.rage_max = float(character_data.get("rageMax", 100.0))
	player.rage_current = 0.0
	player.posture_recovery_rate = float(character_data.get("postureRecoveryRate", settings.get("defaultPostureRecoveryRate", 12.0)))

	player.attack_damage = float(character_data.get("attackDamage", 12.0))
	player.attack_posture_damage = float(character_data.get("attackPostureDamage", 22.0))
	player.attack_range = float(character_data.get("attackRange", 72.0))
	player.move_speed = float(character_data.get("moveSpeed", 420.0))
	player.jump_force = float(character_data.get("jumpForce", 750.0))
	player.gravity = float(character_data.get("gravity", 2800.0))
	player.half_width = float(character_data.get("halfWidth", 22.0))
	player.height = float(character_data.get("height", 88.0))
	player.dash_duration = float(character_data.get("dashDuration", 0.22))
	player.dash_cooldown = float(character_data.get("dashCooldown", 0.80))
	player.dash_speed = float(character_data.get("dashSpeed", 1100.0))
	player.air_dash_speed = float(character_data.get("airDashSpeed", 950.0))
	player.parry_window = float(character_data.get("parryWindow", 0.15))
	player.stun_duration = float(character_data.get("stunDuration", 0.7))
	player.combo_window_duration = float(character_data.get("comboWindow", 0.5))
	player.technique_engine = TechniqueEngineScript.new()
	return player
```

- [ ] **Step 3: Register test modules**

In `WUGodot/tests/run_tests.gd`, add to `_TEST_MODULES` (after line 8):

```gdscript
	"res://tests/test_ai_brain.gd",
	"res://tests/test_boss_controller.gd",
```

- [ ] **Step 4: Run tests**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass (75 existing + ~20 new).

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/data_manager.gd WUGodot/scripts/enemy_factory.gd WUGodot/tests/run_tests.gd
git commit -m "feat: wire archetype-based enemy creation through DataManager and EnemyFactory"
```

---

### Task 7: Rewrite CombatSystem.update_ai with AiBrain Delegation

**Files:**
- Modify: `WUGodot/scripts/combat_system.gd`

- [ ] **Step 1: Replace update_ai with AiBrain-delegated logic**

Replace `update_ai()` (lines 137-193) in `WUGodot/scripts/combat_system.gd`:

```gdscript
func update_ai(ai: Fighter, target: Fighter, dt: float) -> void:
	if not ai.is_ai:
		return

	ai.update_timers(dt)

	var distance: float = target.position.x - ai.position.x
	var abs_distance: float = absf(distance)
	var direction: float = signf(distance)

	# Boss phase check
	if ai.boss_controller != null:
		ai.boss_controller.update_cooldowns(dt)
		if ai.boss_controller.check_phase_transition(ai):
			emit_signal("camera_shake", 20.0)
			emit_signal("slow_motion", 0.4, 0.6)
			emit_signal("show_feedback", "「還在呼吸。好。我剛熱身。」", 1.2)
			emit_signal("spawn_particles", ai.position + Vector2(0.0, -ai.height * 0.5), 30, Color8(255, 140, 40))

	# AiBrain decision
	if ai.ai_brain != null:
		ai.ai_brain.update_cooldowns(dt)
		var action: Dictionary = ai.ai_brain.decide(ai, target)
		_execute_ai_action(ai, target, action, dt, direction)
	else:
		_execute_legacy_ai(ai, target, dt, direction, abs_distance)

	# Assassin teleport
	if ai.archetype_id == "masked_assassin" and not ai.is_stunned and not ai._attack_state.is_active():
		var tp_chance: float = ai.ai_brain.teleport_chance if ai.ai_brain != null else 0.08
		if abs_distance > 200.0 and ai.ai_brain != null and ai.ai_brain._rng.randf() < tp_chance:
			var behind_offset: float = -direction * 120.0
			var teleport_x: float = target.position.x + behind_offset
			teleport_x = clampf(teleport_x, GameConstants.WORLD_BOUNDS_LEFT + 40.0, GameConstants.WORLD_BOUNDS_RIGHT - 40.0)
			ai.position.x = teleport_x
			emit_signal("spawn_particles", ai.position + Vector2(0.0, -ai.height * 0.5), 12, Color8(80, 60, 120))
			emit_signal("show_feedback", "!", 0.3)

	# Forward lunge during active attack
	if ai._attack_state.is_active() and ai._attack_state.def != null:
		var lunge: float = ai._attack_state.def.forward_lunge
		if lunge > 0.0 and ai._attack_state.phase() == AttackDefinitionScript.Phase.WINDUP:
			var lunge_speed: float = lunge / maxf(ai._attack_state.def.windup_end, 0.01)
			ai.velocity.x = float(ai.facing) * lunge_speed

	if not ai.is_grounded:
		ai.velocity.y += ai.gravity * dt

	ai.position += ai.velocity * dt

	if ai.position.y >= GameConstants.GROUND_Y:
		if (not ai.is_grounded) and ai.velocity.y > 100.0:
			ai.land()
		ai.position.y = GameConstants.GROUND_Y
		ai.velocity.y = 0.0
		ai.is_grounded = true
	else:
		ai.is_grounded = false
```

- [ ] **Step 2: Add _execute_ai_action helper**

Add after `update_ai()`:

```gdscript
func _execute_ai_action(ai: Fighter, target: Fighter, action: Dictionary, dt: float, direction: float) -> void:
	# Clear blocking at the start of every decision so it doesn't latch across actions
	ai.is_blocking = false

	var action_type: String = str(action.get("type", "idle"))
	match action_type:
		"attack":
			if ai.can_attack():
				var attack_id: String = str(action.get("attack_id", ""))
				# Boss: pick from phase-specific table with range filtering
				if ai.boss_controller != null and ai.ai_brain != null:
					var phase_table: Array[String] = ai.boss_controller.get_phase_attack_table()
					var abs_dist: float = absf(target.position.x - ai.position.x)
					var candidates: Array[String] = []
					for pid in phase_table:
						var pdef: Variant = ai.ai_brain.get_attack_def(pid)
						if pdef != null and pdef.range_units + 30.0 >= abs_dist:
							candidates.append(pid)
					if candidates.is_empty():
						candidates = phase_table.duplicate()
					attack_id = candidates[ai.ai_brain._rng.randi_range(0, candidates.size() - 1)]
					# Bear Crush cooldown gate
					if attack_id == "bear_crush_grab" and not ai.boss_controller.can_use_bear_crush():
						attack_id = "bear_swipe"
					elif attack_id == "bear_crush_grab":
						ai.boss_controller.consume_bear_crush()
					# Chance to use Mountain-Breaker (overrides the picked attack)
					if ai.boss_controller.can_use_mountain_breaker() and ai.ai_brain != null and ai.ai_brain._rng.randf() < 0.15:
						attack_id = "mountain_breaker"
						ai.boss_controller.consume_mountain_breaker()
				var atk_def: Variant = ai.ai_brain.get_attack_def(attack_id) if ai.ai_brain != null else null
				if atk_def != null:
					# Phase 2: shorten recovery only (preserve windup + active timing)
					if ai.boss_controller != null and ai.boss_controller.current_phase == 2:
						var recovery: float = atk_def.duration - atk_def.active_end
						atk_def.duration = atk_def.active_end + recovery * 0.8
					ai._start_attack_with(atk_def)
					ai._ai_decision_timer = 0.2
					var attack_pos: Vector2 = ai.position + Vector2(float(ai.facing) * ai.half_width, -ai.height * 0.4)
					emit_signal("spawn_particles", attack_pos, 6, Color8(255, 120, 100))
		"block":
			ai.is_blocking = true
			ai.trigger_parry_window()
		"move":
			var move_dir: float = float(action.get("direction", direction))
			ai.velocity.x = lerp(ai.velocity.x, move_dir * ai.move_speed, 0.3)
		"dash":
			if ai.can_dash():
				var dash_dir: int = int(signf(float(action.get("direction", direction))))
				ai.start_dash(dash_dir)
				emit_signal("spawn_particles", ai.position, 8, Color8(255, 100, 100))
		_:
			ai.velocity.x = lerp(ai.velocity.x, 0.0, 0.2)
```

- [ ] **Step 3: Add _execute_legacy_ai fallback**

Add after `_execute_ai_action()`:

```gdscript
func _execute_legacy_ai(ai: Fighter, target: Fighter, dt: float, direction: float, abs_distance: float) -> void:
	var aggression_multiplier: float = 1.2 + (1.0 - ai.health_current / maxf(ai.health_max, 0.001)) * 0.5
	if ai.is_in_recovery() or ai.is_stunned:
		var retreat_speed: float = 0.0 if ai.is_stunned else -direction * ai.move_speed * 0.4
		ai.velocity.x = lerp(ai.velocity.x, retreat_speed, 0.2)
	else:
		if abs_distance > ai.attack_range * 0.9:
			ai.velocity.x = lerp(ai.velocity.x, direction * ai.move_speed * aggression_multiplier, 0.3)
		else:
			ai.velocity.x = lerp(ai.velocity.x, 0.0, 0.3)
			if ai.can_attack() and ai._ai_decision_timer <= 0.0 and _rng.randf() < 0.25 * aggression_multiplier:
				var next_attack: Variant = AttackCatalogScript.bandit_thrust_perilous() if _rng.randf() < 0.30 else AttackCatalogScript.bandit_slash()
				ai._start_attack_with(next_attack)
				ai._ai_decision_timer = 0.25
			if target.is_hit_active() and _rng.randf() < 0.4:
				ai.is_blocking = true
				ai.trigger_parry_window()
			else:
				ai.is_blocking = false
```

- [ ] **Step 4: Add AttackDefinition preload**

At the top of `combat_system.gd`, add after line 4:

```gdscript
const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")
```

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/combat_system.gd
git commit -m "feat: replace hardcoded AI with AiBrain-delegated archetype-aware combat"
```

---

### Task 8: Grab Mechanic — Bear Crush Resolution

**Files:**
- Modify: `WUGodot/scripts/combat_system.gd`

- [ ] **Step 1: Add grab resolution in resolve_hits**

In `resolve_hits()` in `WUGodot/scripts/combat_system.gd`, add after `attacker.was_hit_this_swing = true` (after line 212), before the parry check:

```gdscript
		# Grab attack — bypass parry/block, deal % max HP
		var attack_is_grab: bool = attack_def != null and attack_def.is_grab
		if attack_is_grab:
			var grab_damage: float = defender.health_max * 0.25
			defender.health_current -= grab_damage
			defender.health_current = maxf(defender.health_current, 0.0)
			defender.is_grabbed = true
			defender._grab_timer = 0.6
			defender.velocity = Vector2.ZERO
			emit_signal("damage_dealt", defender.position + Vector2(0.0, -defender.height - 20.0), grab_damage, true)
			emit_signal("camera_shake", 14.0)
			emit_signal("hitstop", 0.15)
			emit_signal("show_feedback", "CRUSH!", 0.7)
			emit_signal("spawn_particles", defender.position + Vector2(0.0, -defender.height * 0.5), 16, Color8(255, 100, 60))

			# B6 Phoenix check after grab damage
			if defender.health_current <= 0.0 and defender.technique_engine != null:
				if defender.technique_engine.check_lethal_save(defender):
					emit_signal("camera_shake", 16.0)
					emit_signal("slow_motion", 0.4, 0.5)
					emit_signal("show_feedback", "鳳凰起!", 0.8)
					emit_signal("spawn_particles", defender.position + Vector2(0.0, -defender.height * 0.5), 24, Color8(255, 120, 40))
			return
```

- [ ] **Step 2: Commit**

```bash
git add WUGodot/scripts/combat_system.gd
git commit -m "feat: add grab mechanic for Bear Crush and Assassin grab"
```

---

### Task 9: Boss HUD — Name Display and Phase Indicator

**Files:**
- Modify: `WUGodot/scripts/combat_scene.gd`

- [ ] **Step 1: Add boss name and phase display to HUD**

In `_draw_hud()` in `WUGodot/scripts/combat_scene.gd`, add after the enemy bar drawing (after the line that draws enemy bars):

Find the line `_draw_bars(_enemy, GameConstants.VIEW_WIDTH / 2 + 34, 36, true)` and add after it:

```gdscript
	# Enemy name
	var enemy_name: String = _enemy.name
	if not _enemy.archetype_id.is_empty():
		var enemy_data: Dictionary = DataManager.get_enemy(_enemy.archetype_id)
		var cn: String = str(enemy_data.get("name_cn", ""))
		if not cn.is_empty():
			enemy_name = "%s %s" % [cn, _enemy.name]
	_draw_text(enemy_name, GameConstants.VIEW_WIDTH / 2 + 34, 30, Color8(210, 200, 190), 14)

	# Boss phase indicator
	if _enemy.boss_controller != null:
		var phase_text: String = "Phase %d" % _enemy.boss_controller.current_phase
		var phase_color: Color = Color8(255, 180, 60) if _enemy.boss_controller.current_phase == 2 else Color8(200, 195, 190)
		_draw_text(phase_text, GameConstants.VIEW_WIDTH - 120, 30, phase_color, 14)
```

- [ ] **Step 2: Add grab visual indicator**

In `_draw_fighter()`, add after the bleed indicator block (after the `fighter.bleed_timer > 0.0` block):

```gdscript
	if fighter.is_grabbed:
		var grab_pulse: float = sin(fighter.animation_timer * 15.0) * 0.5 + 0.5
		var grab_rect: Rect2 = Rect2(
			body_rect.position.x - 4.0,
			body_rect.position.y - 4.0,
			body_rect.size.x + 8.0,
			body_rect.size.y + 8.0
		)
		draw_rect(grab_rect, Color8(255, 60, 40, int(120.0 * grab_pulse)), false, 3.0)
```

- [ ] **Step 3: Commit**

```bash
git add WUGodot/scripts/combat_scene.gd
git commit -m "feat: add boss name/phase HUD and grab visual indicator"
```

---

### Task 10: Run Tests and Full Verification

**Files:**
- No new files.

- [ ] **Step 1: Run all headless tests**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass (75 existing + ~20 new = ~95 total).

- [ ] **Step 2: Verify headless import**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --import`

Expected: Completes without errors.

- [ ] **Step 3: Verify headless startup**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --quit-after 1`

Expected: Starts and quits cleanly.

---

### Task 11: Manual Playtest Checklist

**Files:**
- No files modified.

- [ ] **Step 1: Manual playtest checklist**

Run the game: `HOME=/tmp/godot-home godot --path WUGodot`

Verify each item (pass/fail):

**Archetype variety:**
- [ ] Battle nodes spawn different enemy types (swordsman, spearman, or ronin)
- [ ] Elite nodes spawn sect disciple or masked assassin
- [ ] Boss node spawns Xiong Tie (Iron Bear)
- [ ] Each archetype has a visibly different color/size

**Archetype behaviors:**
- [ ] Bandit Swordsman: uses 3 attacks (slash, thrust, overhead), predictable pacing, parry-friendly
- [ ] Bandit Spearman: attacks from further away, 2 attacks (long thrust, wide swing), punishes close-range rushing
- [ ] Wandering Ronin: faster, varied 4-attack pattern, one perilous attack (red telegraph, must dodge)
- [ ] Sect Disciple: aggressive mirror-match, 5 attacks, blocks frequently, uses jump-attack with forward lunge
- [ ] Masked Assassin: teleports behind player, fast attacks, perilous grab

**Boss fight:**
- [ ] Xiong Tie has a large body (wider, taller than normal enemies)
- [ ] Phase 1: uses swipe, overhead, stomp, Bear Crush grab
- [ ] Bear Crush: red telegraph, unparryable grab, deals ~25% max HP damage, shows "CRUSH!"
- [ ] Phase transition at 50% HP: screen shake, slow-mo, dialog feedback
- [ ] Phase 2: recovery shortens (~20% faster), roar_aoe added to pattern
- [ ] Mountain-Breaker Stance: long windup (~0.7s), charges forward across screen, unblockable/unparryable, must dash
- [ ] Mountain-Breaker used once per phase (at most twice total)
- [ ] Boss fight lasts approximately 3-5 minutes
- [ ] Boss name displays in Chinese + English in HUD
- [ ] Phase indicator visible in HUD

**Integration with existing systems:**
- [ ] Player techniques work against all archetypes (parry echo, bleed, etc.)
- [ ] Rewards still appear after non-boss victories
- [ ] Boss victory ends the run (existing behavior preserved)

---

## Review Cycle Audit

After implementation, verify these cross-cutting concerns:

1. **Backward compatibility:** All existing 75 tests still pass. Reward screen, technique system, and combat foundation unchanged.
2. **JSON schema consistency:** All 6 new enemy JSON files share a common field set (archetype, name, name_cn, difficulty, pattern_table, aggression, blockChance, preferredRange, retreatChance, dashChance). MaskedAssassin.json adds `teleport_chance`; IronBear.json omits it. `AiBrain.from_enemy_data()` defaults `teleport_chance` to 0.0 when absent.
3. **AiBrain fallback:** If `ai_brain` is null (shouldn't happen after Task 6, but defensively), `_execute_legacy_ai` preserves the Plan 1 bandit behavior.
4. **Grab + Phoenix interaction:** Bear Crush grab checks B6 Phoenix Rising after applying damage.
5. **Boss phase transition:** Only fires once. Mountain-Breaker resets on phase change.
6. **Forward lunge timing:** Only applies during WINDUP phase, stops when attack transitions to ACTIVE.
