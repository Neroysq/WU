# WU Collision Geometry — Track B Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Hu's attacks connect on **authored capsule geometry that matches the animation** instead of a scalar range, resolved by deterministic shape math (not Godot physics), with `range_units` kept as a non-regressive fallback for every fighter that has no authored hitbox.

**Architecture:** Combat truth stays in `Fighter`/`AttackDefinition`/`AttackState`/`CombatSystem`. A new headless-testable shape layer (`CollisionShapeMath`, `HitboxTemplate`, `PresentationCollision`) computes a world-space attack capsule (from the attacker's manifest anchors + weapon class) and a defender hurtbox (manifest rect, else the existing body rect), and answers a single boolean overlap query. `CombatSystem.resolve_hits` calls that query **only when the attacker has an authored hitbox**; otherwise it uses today's scalar gate unchanged. No `Area2D` — overlap is exact segment/rect math so it is frame-exact and headless-testable (synthesis §3.4).

**Tech Stack:** Godot 4.6.2, GDScript (typed), JSON data, headless test runner (`./run.sh --test`).

**Scope:** Hu **as attacker** (light + heavy) on capsule geometry vs the defender's hurtbox (manifest rect for Hu, body-rect fallback for enemies). **Out of scope (explicit follow-ups):** enemy-attacker authored hitboxes (spear/sword/grab pilots — needs enemy manifests), parry/block *zones* as geometry, per-pose hurtbox authoring beyond Hu, and real per-pose anchor measurement (the placeholder anchors from Track A still apply — see the Anchor Dependency note). References: `docs/superpowers/specs/2026-06-08-wu-animation-system-revamp-synthesis.md` (§3.4 deterministic query, §3.6 templates) and `...-revamp.md` (§6.5, §9).

**Anchor dependency (read first):** Track A shipped with placeholder `footAnchor`/`chestAnchor`/`weaponTip` constants, so capsules will be *positioned* wherever those constants say until real per-pose anchors are measured. This plan's logic and unit tests are anchor-independent (they use fixtures); only the in-game *visual* alignment of the capsule depends on real anchors. The Task 7 playtest will look correct only after anchors are real — call that out at execution time.

> **Revision 2** — incorporates a plan-review pass. Fixes: (1) **attack-id allowlist** so only `hu_light`/`hu_heavy` use geometry — technique overrides (`drunken_*`/`tiger_*`) and enemy attacks fall back to scalar (Task 4); (2) **coarse visual-height fallback hurtbox** so Hu's chest/weapon-height capsule doesn't miss the short gameplay body rect of unregistered enemies (Task 4) — fixtures verified against the real anchor numbers; (3) **shape debug overlay moved out of the presenter-visible branch** so the heavy capsule is inspectable (Task 7); (4) **`derived_reach()` removed** rather than shipping a wrong value — deferred to the validation follow-up (Task 4). See the per-task "Rev 2" notes.

> **Post-implementation review stopgap** — a reach probe against the placeholder Track A anchors showed live Hu geometry would roughly double old scalar reach. `CombatScene.ENABLE_AUTHORED_PLAYER_HITBOXES` is therefore `false` by default: Track B remains built, registered with `CombatSystem`, and covered by tests, but Hu is not registered into live geometry until measured per-pose anchors land.

---

## File Structure

**New (headless-testable `RefCounted` logic):**
- `WUGodot/scripts/visual/collision_shape_math.gd` — pure geometry: point/segment/rect helpers and `capsule_intersects_rect`.
- `WUGodot/scripts/visual/hitbox_template.gd` — derive a capsule (a, b, radius in source px) from `chestAnchor`→`weaponTip` + weapon class + heavy/grab flags (synthesis §3.6).
- `WUGodot/scripts/visual/presentation_collision.gd` — registry mapping a `Fighter` to its manifest/scale/weapon-class; builds the world-space attack capsule and defender hurtbox; exposes `has_authored_hitbox(fighter)` and `query_hit(attacker, defender)`. `derived_reach()` is intentionally deferred to the validation follow-up.

**New (tests):**
- `WUGodot/tests/test_collision_shape_math.gd`
- `WUGodot/tests/test_hitbox_template.gd`
- `WUGodot/tests/test_presentation_collision.gd`

**Modified:**
- `WUGodot/scripts/visual/animation_manifest.gd` — parse top-level `weaponClass` and optional per-pose `hurtbox` rect.
- `WUGodot/assets/animation_manifests/hu.manifest.json` — add `weaponClass` + a `hurtbox` on the body poses.
- `WUGodot/scripts/combat_system.gd` — optional `hit_geometry` provider; geometry gate in `resolve_hits` (`:267-272`).
- `WUGodot/scripts/combat_scene.gd` — build the provider and keep live Hu registration behind `ENABLE_AUTHORED_PLAYER_HITBOXES`; extend the debug overlay to draw the active capsule + hurtbox when registration is enabled.
- `WUGodot/scripts/visual/animation_debug_overlay.gd` — add a `draw_shapes` helper.
- `WUGodot/tests/run_tests.gd` — register the three new modules.

---

## Task 1: CollisionShapeMath (capsule-vs-rect)

The geometry is the most bug-prone piece, so it is fully TDD with explicit fixtures, including the "segment passes through a thin rect without an endpoint inside" case that a naive endpoint/corner-only distance misses.

**Files:**
- Create: `WUGodot/scripts/visual/collision_shape_math.gd`
- Test: `WUGodot/tests/test_collision_shape_math.gd`

- [ ] **Step 1: Write the failing test**

Create `WUGodot/tests/test_collision_shape_math.gd`:

```gdscript
extends RefCounted

const M = preload("res://scripts/visual/collision_shape_math.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var rect := Rect2(0, 0, 100, 40)

	# 1. Capsule clearly inside overlaps.
	if M.capsule_intersects_rect(Vector2(10, 10), Vector2(30, 10), 5.0, rect):
		passed += 1
	else:
		failed += 1; failures.append("capsule inside rect should intersect")

	# 2. Capsule far away does not.
	if not M.capsule_intersects_rect(Vector2(500, 500), Vector2(520, 500), 5.0, rect):
		passed += 1
	else:
		failed += 1; failures.append("far capsule should not intersect")

	# 3. Endpoints outside but radius bridges the gap.
	if M.capsule_intersects_rect(Vector2(-9, 20), Vector2(-9, 25), 10.0, rect):
		passed += 1
	else:
		failed += 1; failures.append("radius should bridge a small gap to the left edge")

	# 4. Just-too-far by radius misses.
	if not M.capsule_intersects_rect(Vector2(-12, 20), Vector2(-12, 25), 10.0, rect):
		passed += 1
	else:
		failed += 1; failures.append("gap larger than radius should miss")

	# 5. THE crossing case: a thin segment passes straight through the rect with
	#    both endpoints outside and no corner nearby. Must intersect (radius 0).
	if M.capsule_intersects_rect(Vector2(-20, 20), Vector2(120, 20), 0.0, rect):
		passed += 1
	else:
		failed += 1; failures.append("segment crossing the rect interior must intersect")

	# 6. Same line but above the rect: no intersection.
	if not M.capsule_intersects_rect(Vector2(-20, -20), Vector2(120, -20), 0.0, rect):
		passed += 1
	else:
		failed += 1; failures.append("segment above the rect should miss")

	# 7. point_in_rect basics.
	if M.point_in_rect(Vector2(50, 20), rect) and not M.point_in_rect(Vector2(50, 60), rect):
		passed += 1
	else:
		failed += 1; failures.append("point_in_rect basic check")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./run.sh --test` (register the module per Task 8, or temporarily).
Expected: FAIL — preload of missing `collision_shape_math.gd`.

- [ ] **Step 3: Write minimal implementation**

Create `WUGodot/scripts/visual/collision_shape_math.gd`:

```gdscript
class_name CollisionShapeMath
extends RefCounted

# Capsule = segment (a,b) inflated by radius. Overlap with an axis-aligned Rect2
# iff the minimum distance from the segment to the rect is <= radius.
static func capsule_intersects_rect(a: Vector2, b: Vector2, radius: float, rect: Rect2) -> bool:
	return segment_rect_distance(a, b, rect) <= maxf(radius, 0.0)

static func point_in_rect(p: Vector2, rect: Rect2) -> bool:
	return p.x >= rect.position.x and p.x <= rect.position.x + rect.size.x \
		and p.y >= rect.position.y and p.y <= rect.position.y + rect.size.y

static func segment_rect_distance(a: Vector2, b: Vector2, rect: Rect2) -> float:
	if point_in_rect(a, rect) or point_in_rect(b, rect):
		return 0.0

	var tl := rect.position
	var tr := Vector2(rect.position.x + rect.size.x, rect.position.y)
	var br := rect.position + rect.size
	var bl := Vector2(rect.position.x, rect.position.y + rect.size.y)

	# Crossing any edge means overlap (distance 0).
	if _segments_intersect(a, b, tl, tr) or _segments_intersect(a, b, tr, br) \
		or _segments_intersect(a, b, br, bl) or _segments_intersect(a, b, bl, tl):
		return 0.0

	# Otherwise the closest features are endpoint-to-rect or corner-to-segment.
	var d: float = minf(_point_rect_distance(a, rect), _point_rect_distance(b, rect))
	for corner in [tl, tr, br, bl]:
		d = minf(d, _point_segment_distance(corner, a, b))
	return d

static func _point_rect_distance(p: Vector2, rect: Rect2) -> float:
	var dx: float = maxf(maxf(rect.position.x - p.x, p.x - (rect.position.x + rect.size.x)), 0.0)
	var dy: float = maxf(maxf(rect.position.y - p.y, p.y - (rect.position.y + rect.size.y)), 0.0)
	return Vector2(dx, dy).length()

static func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.000001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func _segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d1: float = _orient(p3, p4, p1)
	var d2: float = _orient(p3, p4, p2)
	var d3: float = _orient(p1, p2, p3)
	var d4: float = _orient(p1, p2, p4)
	if ((d1 > 0.0 and d2 < 0.0) or (d1 < 0.0 and d2 > 0.0)) \
		and ((d3 > 0.0 and d4 < 0.0) or (d3 < 0.0 and d4 > 0.0)):
		return true
	return false

static func _orient(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./run.sh --test`
Expected: PASS — `test_collision_shape_math.gd` contributes 7 passed.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/visual/collision_shape_math.gd WUGodot/tests/test_collision_shape_math.gd WUGodot/tests/run_tests.gd
git commit -m "feat(collision): add capsule-vs-rect shape math"
```

---

## Task 2: HitboxTemplate (capsule from anchors + weapon class)

Derives the active-window capsule from pose geometry so reach comes from where the weapon *is*, not from `range_units` (synthesis §3.6).

**Files:**
- Create: `WUGodot/scripts/visual/hitbox_template.gd`
- Test: `WUGodot/tests/test_hitbox_template.gd`

- [ ] **Step 1: Write the failing test**

Create `WUGodot/tests/test_hitbox_template.gd`:

```gdscript
extends RefCounted

const T = preload("res://scripts/visual/hitbox_template.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var chest := Vector2(128, 150)
	var tip := Vector2(218, 134)

	# Spear: thin capsule spanning chest -> tip.
	var spear: Dictionary = T.build("spear", chest, tip, false, false)
	if (spear["a"] as Vector2) == chest and (spear["b"] as Vector2) == tip and float(spear["radius"]) <= 14.0:
		passed += 1
	else:
		failed += 1; failures.append("spear should span chest->tip with a thin radius")

	# Sword: fatter, biased toward the tip half.
	var sword: Dictionary = T.build("sword", chest, tip, false, false)
	if float(sword["radius"]) >= float(spear["radius"]) and (sword["b"] as Vector2) == tip:
		passed += 1
	else:
		failed += 1; failures.append("sword should be fatter than spear and reach the tip")

	# Heavy widens the radius.
	var sword_heavy: Dictionary = T.build("sword", chest, tip, true, false)
	if float(sword_heavy["radius"]) > float(sword["radius"]):
		passed += 1
	else:
		failed += 1; failures.append("heavy should widen the radius")

	# Grab: a disc at the tip (a == b), large radius.
	var grab: Dictionary = T.build("sword", chest, tip, false, true)
	if (grab["a"] as Vector2) == (grab["b"] as Vector2) and float(grab["radius"]) >= 24.0:
		passed += 1
	else:
		failed += 1; failures.append("grab should be a large disc at the tip")

	# Unknown class falls back to sword behavior (non-empty capsule).
	var unknown: Dictionary = T.build("bogus", chest, tip, false, false)
	if float(unknown["radius"]) > 0.0:
		passed += 1
	else:
		failed += 1; failures.append("unknown weapon class should still yield a capsule")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — preload of missing `hitbox_template.gd`.

- [ ] **Step 3: Write minimal implementation**

Create `WUGodot/scripts/visual/hitbox_template.gd`:

```gdscript
class_name HitboxTemplate
extends RefCounted

# Returns a capsule {a, b, radius} in SOURCE pixels for an active-window strike.
# Reach is derived from chest->tip geometry; range_units is never an input here.
static func build(weapon_class: String, chest: Vector2, tip: Vector2, is_heavy: bool, is_grab: bool) -> Dictionary:
	if is_grab:
		var grab_r: float = 28.0 + (6.0 if is_heavy else 0.0)
		return {"a": tip, "b": tip, "radius": grab_r}

	var heavy_bonus: float = 6.0 if is_heavy else 0.0
	match weapon_class:
		"spear", "staff":
			return {"a": chest, "b": tip, "radius": 10.0 + heavy_bonus}
		"fan":
			return {"a": chest.lerp(tip, 0.5), "b": tip, "radius": 16.0 + heavy_bonus}
		"unarmed":
			return {"a": chest.lerp(tip, 0.4), "b": tip, "radius": 14.0 + heavy_bonus}
		_:  # sword and any unknown class
			return {"a": chest.lerp(tip, 0.35), "b": tip, "radius": 20.0 + heavy_bonus}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./run.sh --test`
Expected: PASS — `test_hitbox_template.gd` contributes 5 passed.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/visual/hitbox_template.gd WUGodot/tests/test_hitbox_template.gd
git commit -m "feat(collision): add weapon-class hitbox templates"
```

---

## Task 3: Manifest weaponClass + per-pose hurtbox

**Files:**
- Modify: `WUGodot/scripts/visual/animation_manifest.gd`
- Modify: `WUGodot/assets/animation_manifests/hu.manifest.json`
- Modify: `WUGodot/tests/test_animation_manifest.gd`

- [ ] **Step 1: Add weaponClass + hurtbox to the Hu manifest**

In `hu.manifest.json`, add `"weaponClass": "sword"` next to `renderScale`, and add a `hurtbox` rect (source px `[x, y, w, h]`) to the body poses. Add this to `guard`, `breath`, `walk_0..3`, `windup`, `strike_extended`, `recover` (same body box is fine for the pilot):

```json
"hurtbox": [92, 60, 72, 178]
```

So e.g. `guard` becomes:

```json
"guard": {
  "path": "res://assets/sprites/characters/hu/idle_0.png",
  "footAnchor": [128, 238],
  "chestAnchor": [128, 150],
  "weaponTip": [150, 150],
  "hurtbox": [92, 60, 72, 178]
}
```

And the top of the file:

```json
{
  "id": "hu",
  "sourceCanvas": [256, 256],
  "renderScale": 1.625,
  "weaponClass": "sword",
  "poses": { ... }
}
```

- [ ] **Step 2: Write the failing test additions**

In `test_animation_manifest.gd`, add inside `run_all()` before the final `return`:

```gdscript
	if manifest.weapon_class == "sword":
		passed += 1
	else:
		failed += 1
		failures.append("manifest should expose weaponClass")

	var hb: Variant = manifest.get_hurtbox("guard")
	if hb != null and (hb as Rect2) == Rect2(92, 60, 72, 178):
		passed += 1
	else:
		failed += 1
		failures.append("guard should expose its hurtbox rect")

	if manifest.get_hurtbox("nonexistent_pose") == null:
		passed += 1
	else:
		failed += 1
		failures.append("missing pose hurtbox should be null")
```

- [ ] **Step 3: Run test to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — `weapon_class` / `get_hurtbox` not defined on `AnimationManifest`.

- [ ] **Step 4: Extend the manifest loader**

In `animation_manifest.gd`, add the field near the top:

```gdscript
var weapon_class: String = "sword"
```

In `load_from_file`, after `manifest.render_scale = ...`:

```gdscript
	manifest.weapon_class = str(root.get("weaponClass", "sword"))
```

In the pose loop, capture the hurtbox (store `null` when absent so callers can fall back):

```gdscript
		var hurtbox_variant: Variant = entry.get("hurtbox", null)
		manifest.poses[str(pose_name)] = {
			"path": str(entry.get("path", "")),
			"footAnchor": _vec2(entry.get("footAnchor", null), Vector2.ZERO),
			"chestAnchor": _vec2(entry.get("chestAnchor", null), Vector2.ZERO),
			"weaponTip": _vec2(entry.get("weaponTip", null), Vector2.ZERO),
			"hurtbox": _rect(hurtbox_variant),
			"_has": entry.keys(),
		}
```

Add the accessor and the rect parser:

```gdscript
func get_hurtbox(pose_name: String) -> Variant:
	if not poses.has(pose_name):
		return null
	return (poses[pose_name] as Dictionary).get("hurtbox", null)

static func _rect(raw: Variant) -> Variant:
	if typeof(raw) == TYPE_ARRAY:
		var list: Array = raw as Array
		if list.size() >= 4:
			return Rect2(float(list[0]), float(list[1]), float(list[2]), float(list[3]))
	return null
```

- [ ] **Step 5: Run test to verify it passes**

Run: `./run.sh --test`
Expected: PASS — `test_animation_manifest.gd` now contributes 3 additional asserts (7 total).

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/visual/animation_manifest.gd WUGodot/assets/animation_manifests/hu.manifest.json WUGodot/tests/test_animation_manifest.gd
git commit -m "feat(collision): manifest weaponClass and per-pose hurtbox"
```

---

## Task 4: PresentationCollision (world shapes + overlap query)

Registry + world-space shape builder + the single boolean the combat resolver calls. Uses `AnchorMath` for the same foot-anchored, facing-mirrored transform the sprite uses, so the capsule lines up with the rendered weapon.

**Files:**
- Create: `WUGodot/scripts/visual/presentation_collision.gd`
- Test: `WUGodot/tests/test_presentation_collision.gd`

- [ ] **Step 1: Write the failing test**

Create `WUGodot/tests/test_presentation_collision.gd`:

```gdscript
extends RefCounted

const PresentationCollisionScript = preload("res://scripts/visual/presentation_collision.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var pc: Variant = PresentationCollisionScript.new()
	pc.register_from_manifest_file(_make_attacker_key(), "res://assets/animation_manifests/hu.manifest.json")

	var attacker: Variant = FighterScript.new()
	attacker.position = Vector2(400, 900)
	attacker.facing = 1
	attacker._attack_state.start(AttackCatalogScript.hu_light())
	# Advance into the active window so is_hit_active() is true.
	attacker._attack_state.advance(AttackCatalogScript.hu_light().windup_end + 0.01)
	pc.register_fighter(attacker, _make_attacker_key())

	if pc.has_authored_hitbox(attacker):
		passed += 1
	else:
		failed += 1; failures.append("registered attacker mid-active should have an authored hitbox")

	# Defender right in front, within reach -> hit.
	var near: Variant = FighterScript.new()
	near.position = Vector2(470, 900)
	near.facing = -1
	if pc.query_hit(attacker, near):
		passed += 1
	else:
		failed += 1; failures.append("defender within capsule reach should be hit")

	# Defender far away -> miss.
	var far: Variant = FighterScript.new()
	far.position = Vector2(900, 900)
	far.facing = -1
	if not pc.query_hit(attacker, far):
		passed += 1
	else:
		failed += 1; failures.append("defender out of reach should not be hit")

	# Defender BEHIND the attacker (capsule extends forward only) -> miss.
	var behind: Variant = FighterScript.new()
	behind.position = Vector2(330, 900)
	behind.facing = 1
	if not pc.query_hit(attacker, behind):
		passed += 1
	else:
		failed += 1; failures.append("defender behind the attacker should not be hit")

	# Unregistered attacker has no authored hitbox (falls back to scalar in combat).
	var stranger: Variant = FighterScript.new()
	if not pc.has_authored_hitbox(stranger):
		passed += 1
	else:
		failed += 1; failures.append("unregistered fighter must not report an authored hitbox")

	# A technique override (tiger_light) is NOT authored -> scalar fallback, even
	# though it is a registered Hu attack mid-active window.
	var tech: Variant = FighterScript.new()
	tech.position = Vector2(400, 900)
	tech.facing = 1
	tech._attack_state.start(AttackCatalogScript.tiger_light())
	tech._attack_state.advance(AttackCatalogScript.tiger_light().windup_end + 0.01)
	pc.register_fighter(tech, "hu")
	if not pc.has_authored_hitbox(tech):
		passed += 1
	else:
		failed += 1; failures.append("technique-override attack must fall back to scalar (not authored)")

	return {"passed": passed, "failed": failed, "failures": failures}

func _make_attacker_key() -> String:
	return "hu"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — preload of missing `presentation_collision.gd`.

- [ ] **Step 3: Write minimal implementation**

Create `WUGodot/scripts/visual/presentation_collision.gd`:

```gdscript
class_name PresentationCollision
extends RefCounted

const AnimationManifestScript = preload("res://scripts/visual/animation_manifest.gd")
const HitboxTemplateScript = preload("res://scripts/visual/hitbox_template.gd")
const ShapeMathScript = preload("res://scripts/visual/collision_shape_math.gd")

# Pose whose chest/tip anchors define the strike capsule for the pilot.
const STRIKE_POSE: String = "strike_extended"

# Only these attack ids have authored capsules. Technique overrides
# (drunken_*, tiger_*) and all enemy attacks fall back to scalar combat.
const _AUTHORED_IDS := {"hu_light": true, "hu_heavy": true}

# Coarse visual-body height for unregistered defenders (see _defender_hurtbox).
const VISUAL_BODY_HEIGHT: float = 260.0

var _manifests: Dictionary = {}        # key -> AnimationManifest
var _fighter_keys: Dictionary = {}     # Fighter instance id -> key

func register_from_manifest_file(key: String, manifest_path: String) -> void:
	_manifests[key] = AnimationManifestScript.load_from_file(manifest_path)

func register_fighter(fighter: Variant, key: String) -> void:
	_fighter_keys[fighter.get_instance_id()] = key

func _manifest_for(fighter: Variant) -> Variant:
	var fid: int = fighter.get_instance_id()
	if not _fighter_keys.has(fid):
		return null
	return _manifests.get(_fighter_keys[fid], null)

# An attacker has an authored hitbox only while its attack is in the active
# window, it has a registered manifest, AND its attack id is authored. Technique
# overrides and enemy attacks fall through to the scalar gate.
func has_authored_hitbox(fighter: Variant) -> bool:
	if not fighter.is_hit_active():
		return false
	if _manifest_for(fighter) == null:
		return false
	var def: Variant = fighter._attack_state.def
	return def != null and _AUTHORED_IDS.has(def.id)

# NOTE: derived_reach() (range_units cross-check) is intentionally NOT implemented
# here. A correct value must come from the actual world capsule extent + radius,
# not abs(tip.x - chest.x); it is deferred to the validation follow-up so we do
# not ship a misleading number.

func query_hit(attacker: Variant, defender: Variant) -> bool:
	var manifest: Variant = _manifest_for(attacker)
	if manifest == null:
		return false

	var pose: Dictionary = manifest.get_pose(STRIKE_POSE)
	var foot: Vector2 = pose.get("footAnchor", Vector2.ZERO) as Vector2
	var chest: Vector2 = pose.get("chestAnchor", Vector2.ZERO) as Vector2
	var tip: Vector2 = pose.get("weaponTip", Vector2.ZERO) as Vector2
	var scale: float = manifest.render_scale

	var def: Variant = attacker._attack_state.def
	var is_heavy: bool = def != null and def.is_heavy
	var is_grab: bool = def != null and def.is_grab
	var cap: Dictionary = HitboxTemplateScript.build(manifest.weapon_class, chest, tip, is_heavy, is_grab)

	# Capsule endpoints to world space via the same foot-anchored, mirrored map as the sprite.
	var a: Vector2 = _to_world(cap["a"], foot, attacker.position, scale, attacker.facing)
	var b: Vector2 = _to_world(cap["b"], foot, attacker.position, scale, attacker.facing)
	var radius: float = float(cap["radius"]) * scale

	var hurt: Rect2 = _defender_hurtbox(defender)
	return ShapeMathScript.capsule_intersects_rect(a, b, radius, hurt)

func _defender_hurtbox(defender: Variant) -> Rect2:
	# Prefer an authored hurtbox; otherwise fall back to the existing body rect.
	var manifest: Variant = _manifest_for(defender)
	if manifest != null:
		var hb: Variant = manifest.get_hurtbox(STRIKE_POSE)
		if hb == null:
			hb = manifest.get_hurtbox("guard")
		if hb != null:
			var foot: Vector2 = (manifest.get_pose("guard") as Dictionary).get("footAnchor", Vector2.ZERO) as Vector2
			var r: Rect2 = hb as Rect2
			# Transform rect corners; rebuild as an AABB (facing flips X).
			var p0: Vector2 = _to_world(r.position, foot, defender.position, manifest.render_scale, defender.facing)
			var p1: Vector2 = _to_world(r.position + r.size, foot, defender.position, manifest.render_scale, defender.facing)
			return Rect2(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)), (p1 - p0).abs())
	# Coarse visual-height fallback for unregistered fighters (enemies). The
	# gameplay body (fighter.height ~88) is far shorter than the rendered sprite,
	# and the attack capsule sits at chest/weapon height, so a body-rect-only
	# fallback would make Hu's capsule miss vertically. Cover the visible
	# silhouette instead. Replaced by per-enemy authored hurtboxes in the
	# enemy-manifest follow-up.
	var pad: float = 16.0
	return Rect2(
		defender.position.x - defender.half_width - pad,
		defender.position.y - VISUAL_BODY_HEIGHT,
		defender.half_width * 2.0 + pad * 2.0,
		VISUAL_BODY_HEIGHT)

static func _to_world(px: Vector2, foot: Vector2, root: Vector2, scale: float, facing: int) -> Vector2:
	var local: Vector2 = (px - foot) * scale
	if facing < 0:
		local.x = -local.x
	return root + local
```

Note: `_to_world` duplicates `AnchorMath.pose_to_world` intentionally to keep this module's query self-contained and identical to the presenter's transform; if you prefer, call `AnchorMath.pose_to_world` instead (same formula).

- [ ] **Step 4: Run test to verify it passes**

Run: `./run.sh --test`
Expected: PASS — `test_presentation_collision.gd` contributes 6 passed.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/visual/presentation_collision.gd WUGodot/tests/test_presentation_collision.gd
git commit -m "feat(collision): presentation collision provider with world capsule query"
```

---

## Task 5: Wire the geometry gate into CombatSystem (non-regressive)

**Files:**
- Modify: `WUGodot/scripts/combat_system.gd` (field + `resolve_hits` gate at `:267-272`)
- Test: extend `WUGodot/tests/test_presentation_collision.gd` with a resolve-hits fixture

- [ ] **Step 1: Write the failing test (combat fixture)**

Append to `run_all()` in `test_presentation_collision.gd`, before the final `return`. This proves the gate routes to geometry when authored and to scalar otherwise:

```gdscript
	# CombatSystem uses geometry when the attacker is registered, scalar otherwise.
	var CombatSystemScript: Script = load("res://scripts/combat_system.gd")
	var cs: Variant = CombatSystemScript.new()
	cs.hit_geometry = pc

	# Authored attacker (registered) vs a defender just inside capsule reach: connects.
	var atk2: Variant = FighterScript.new()
	atk2.position = Vector2(400, 900)
	atk2.facing = 1
	atk2._attack_state.start(AttackCatalogScript.hu_light())
	atk2._attack_state.advance(AttackCatalogScript.hu_light().windup_end + 0.01)
	pc.register_fighter(atk2, "hu")
	var def2: Variant = FighterScript.new()
	def2.position = Vector2(470, 900)
	def2.facing = -1
	var hp_before: float = def2.health_current
	cs.resolve_hits(atk2, def2)
	if def2.health_current < hp_before:
		passed += 1
	else:
		failed += 1; failures.append("authored hitbox should deal damage to an in-reach defender")

	# Unregistered attacker (no geometry) still works via scalar path: place in scalar range.
	var atk3: Variant = FighterScript.new()
	atk3.position = Vector2(400, 900)
	atk3.facing = 1
	atk3._attack_state.start(AttackCatalogScript.bandit_slash())
	atk3._attack_state.advance(AttackCatalogScript.bandit_slash().windup_end + 0.01)
	var def3: Variant = FighterScript.new()
	def3.position = Vector2(400 + 60, 900)  # within bandit_slash range_units (68) + half_width
	def3.facing = -1
	var hp3_before: float = def3.health_current
	cs.resolve_hits(atk3, def3)
	if def3.health_current < hp3_before:
		passed += 1
	else:
		failed += 1; failures.append("unregistered attacker should still hit via scalar fallback")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./run.sh --test`
Expected: FAIL — `hit_geometry` not defined on `CombatSystem` / gate still scalar-only.

- [ ] **Step 3: Add the provider field and geometry gate**

In `combat_system.gd`, add the field near `_rng` (top of the class):

```gdscript
var hit_geometry: Variant = null  # PresentationCollision, or null for pure scalar combat
```

In `resolve_hits`, replace the scalar gate block (`:267-272`) — keep the variables, change the decision:

```gdscript
	var in_range: bool = absf(defender.position.x - attacker.position.x) <= attack_range + defender.half_width
	var vertical_range: bool = absf(defender.position.y - attacker.position.y) <= defender.height + 20.0
	var facing_correct: bool = (-1 if defender.position.x - attacker.position.x < 0.0 else 1) == attacker.facing

	var connects: bool
	if hit_geometry != null and hit_geometry.has_authored_hitbox(attacker):
		# Authored capsule already encodes reach + facing; scalar checks are bypassed.
		connects = hit_geometry.query_hit(attacker, defender)
	else:
		connects = in_range and vertical_range and facing_correct

	if connects and not attacker.was_hit_this_swing:
		attacker.was_hit_this_swing = true
```

Everything after `attacker.was_hit_this_swing = true` (grab/parry/block/damage/posture/knockback) is unchanged.

- [ ] **Step 4: Run test to verify it passes**

Run: `./run.sh --test`
Expected: PASS — both new asserts green; the full suite (including all combat/technique tests that call `resolve_hits` with `hit_geometry == null`) stays green, proving non-regression.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/combat_system.gd WUGodot/tests/test_presentation_collision.gd
git commit -m "feat(collision): geometry hit gate in resolve_hits with scalar fallback"
```

---

## Task 6: Register the provider for Hu in combat_scene

**Files:**
- Modify: `WUGodot/scripts/combat_scene.gd` (`_ready`, `setup_combat`)

- [ ] **Step 1: Create and attach the provider**

In `combat_scene.gd`, add a const near the others:

```gdscript
const PresentationCollisionScript = preload("res://scripts/visual/presentation_collision.gd")
```

and a field near `_player_presenter`:

```gdscript
var _hit_geometry: Variant = null
```

In `_ready` after `_combat_system = CombatSystem.new()`:

```gdscript
	_hit_geometry = PresentationCollisionScript.new()
	_hit_geometry.register_from_manifest_file("hu", "res://assets/animation_manifests/hu.manifest.json")
	_combat_system.hit_geometry = _hit_geometry
```

- [ ] **Step 2: Register the player fighter each combat**

In `setup_combat`, after `_player.reset_for_combat()` (and after `_player` is assigned), add:

```gdscript
	if _hit_geometry != null:
		_hit_geometry.register_fighter(_player, "hu")
```

Enemies are never registered, so they keep the scalar path — non-regressive.

- [ ] **Step 3: Verify tests + import**

Run: `./run.sh --test`
Expected: PASS — `failed: 0`.
Run: `./run.sh --import`
Expected: no script errors.

- [ ] **Step 4: Commit**

```bash
git add WUGodot/scripts/combat_scene.gd
git commit -m "feat(collision): register Hu hit geometry in combat scene"
```

---

## Task 7: Debug overlay for shapes + playtest

**Files:**
- Modify: `WUGodot/scripts/visual/animation_debug_overlay.gd`
- Modify: `WUGodot/scripts/combat_scene.gd` (`_draw_fighter`)

- [ ] **Step 1: Add a shape-drawing helper**

In `animation_debug_overlay.gd`, add:

```gdscript
static func draw_shapes(canvas: CanvasItem, hurt: Rect2, cap_a: Vector2, cap_b: Vector2, cap_r: float, camera_offset: Vector2, active: bool) -> void:
	var off: Vector2 = camera_offset
	# Hurtbox in cyan.
	canvas.draw_rect(Rect2(hurt.position + off, hurt.size), Color(0.2, 0.8, 1.0, 0.5), false, 2.0)
	# Attack capsule in red when active.
	var col := Color(1.0, 0.25, 0.2, 0.9) if active else Color(1.0, 0.5, 0.2, 0.4)
	canvas.draw_line(cap_a + off, cap_b + off, col, 2.0)
	canvas.draw_circle(cap_a + off, cap_r, Color(col.r, col.g, col.b, 0.15))
	canvas.draw_circle(cap_b + off, cap_r, Color(col.r, col.g, col.b, 0.15))
```

- [ ] **Step 2: Draw shapes when debug is on**

The provider builds shapes internally; expose two helpers on `PresentationCollision` so the overlay can read them (add to `presentation_collision.gd`):

```gdscript
func debug_capsule_world(fighter: Variant) -> Dictionary:
	# Only return geometry combat actually uses (authored ids, active window).
	if not has_authored_hitbox(fighter):
		return {}
	var manifest: Variant = _manifest_for(fighter)
	var pose: Dictionary = manifest.get_pose(STRIKE_POSE)
	var foot: Vector2 = pose.get("footAnchor", Vector2.ZERO) as Vector2
	var chest: Vector2 = pose.get("chestAnchor", Vector2.ZERO) as Vector2
	var tip: Vector2 = pose.get("weaponTip", Vector2.ZERO) as Vector2
	var def: Variant = fighter._attack_state.def
	var cap: Dictionary = HitboxTemplateScript.build(manifest.weapon_class, chest, tip, def.is_heavy, def.is_grab)
	return {
		"a": _to_world(cap["a"], foot, fighter.position, manifest.render_scale, fighter.facing),
		"b": _to_world(cap["b"], foot, fighter.position, manifest.render_scale, fighter.facing),
		"r": float(cap["radius"]) * manifest.render_scale,
	}

func debug_hurtbox_world(fighter: Variant) -> Rect2:
	return _defender_hurtbox(fighter)
```

In `combat_scene.gd` `_draw_fighter`, add the shape overlay as its **own block** for the player — **outside** the `_player_presenter.visible` branch. This is required because heavy attacks render via the FighterVisual fallback (presenter hidden), and we still want to inspect the heavy capsule. Place it after the existing player branch:

```gdscript
	if fighter == _player and _debug_enabled and _hit_geometry != null:
		var cap: Dictionary = _hit_geometry.debug_capsule_world(_player)
		if not cap.is_empty():
			var hb: Rect2 = _hit_geometry.debug_hurtbox_world(_enemy)
			AnimationDebugOverlayScript.draw_shapes(self, hb, cap["a"], cap["b"], float(cap["r"]), camera_offset, _player.is_hit_active())
```

`debug_capsule_world` returns `{}` unless the player is mid-active-window on an authored attack (`hu_light`/`hu_heavy`), so the overlay only appears when geometry is actually driving the hit — for both light (presenter visible) and heavy (presenter hidden).

- [ ] **Step 3: Verify tests + import**

Run: `./run.sh --test`
Expected: PASS — `failed: 0`.
Run: `./run.sh --import`
Expected: no script errors.

- [ ] **Step 4: Playtest (after real anchors exist — see Anchor Dependency)**

Run: `./run.sh`, enter combat, press `` ` `` to toggle debug.
Manual acceptance:
- The red capsule overlays Hu's blade during the active window and sits where the swing visually reaches.
- The cyan hurtbox sits on the enemy body.
- A hit registers iff the capsule overlaps the hurtbox (step in/out of range and watch hits start/stop at the capsule edge, not a wider/narrower invisible radius).
- Heavy reaches slightly further/fatter than light.
- Enemy attacks still connect exactly as before (scalar path untouched).
- With placeholder anchors, the capsule will be mis-positioned (it tracks the anchor constants); that is the known Anchor Dependency, not a Track B bug.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/visual/animation_debug_overlay.gd WUGodot/scripts/visual/presentation_collision.gd WUGodot/scripts/combat_scene.gd
git commit -m "feat(collision): debug overlay for capsule + hurtbox"
```

---

## Task 8: Register tests and final validation

**Files:**
- Modify: `WUGodot/tests/run_tests.gd`

- [ ] **Step 1: Register the three new modules**

Add to `_TEST_MODULES`:

```gdscript
	"res://tests/test_collision_shape_math.gd",
	"res://tests/test_hitbox_template.gd",
	"res://tests/test_presentation_collision.gd",
```

- [ ] **Step 2: Run the full suite**

Run: `./run.sh --test`
Expected: PASS — `failed: 0`. New modules contribute 7 + 5 + 8 = 20 asserts (plus the 3 added to `test_animation_manifest`), and the entire pre-existing suite stays green (the `hit_geometry == null` default proves non-regression).

- [ ] **Step 3: Commit**

```bash
git add WUGodot/tests/run_tests.gd
git commit -m "test(collision): register Track B test modules"
```

---

## Self-Review Notes (coverage map)

- **Synthesis §3.4 (deterministic shape-math query, not Area2D)** → `CollisionShapeMath` exact segment/rect overlap (Task 1); queried on the combat tick in `resolve_hits` (Task 5).
- **Synthesis §3.4 (facing/anchor/scale parity with the sprite)** → `_to_world` mirrors the presenter's `AnchorMath` transform (Task 4).
- **Synthesis §3.6 (reach from `chestAnchor`/`weaponTip`, not `range_units`)** → `HitboxTemplate` (Task 2); `range_units` retained only as the scalar fallback and is never an input to shape reach. `derived_reach()` (the range_units cross-check) is deferred — a correct value needs the real world-capsule extent + radius, so it is not stubbed here.
- **Attack-id scoping (Rev 2)** → `_AUTHORED_IDS` allowlist ensures only `hu_light`/`hu_heavy` use geometry; technique overrides (`drunken_*`, `tiger_*`) and enemy attacks keep the scalar path (Task 4).
- **Base spec §6.5/§9 (authored geometry, deterministic combat keeps damage/parry/block)** → gate swap leaves all post-hit logic intact (Task 5).
- **Non-regression** → enemies/legacy combat run with `hit_geometry == null` or unregistered fighters → scalar path unchanged; whole existing suite green (Tasks 5, 8).

**Deliberately deferred (next plans):**
- Enemy-attacker authored hitboxes (spear long-capsule, sword arc, Iron Bear grab) — needs enemy manifests; the base spec's full Phase 4 pilot.
- Parry/block zones as geometry; per-pose hurtbox variation; `range_units` ↔ `derived_reach` auto-validation as a hard test (kept informational here because Track A anchors are placeholder).
- Real per-pose anchor measurement (the **Anchor Dependency**): until anchors are measured, capsules are positioned by the placeholder constants, so the Task 7 *visual* acceptance is gated on that data landing. All Task 1–5/8 logic and tests are anchor-independent and pass today.

**Validation reality check:** unit tests prove the geometry, the template, the world transform, the provider query, and the combat gate (hit/miss/behind/fallback) headlessly. The only thing that needs eyes — and real anchors — is Task 7's in-game capsule alignment.
