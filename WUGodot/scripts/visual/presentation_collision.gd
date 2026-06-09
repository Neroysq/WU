class_name PresentationCollision
extends RefCounted

const AnimationManifestScript = preload("res://scripts/visual/animation_manifest.gd")
const HitboxTemplateScript = preload("res://scripts/visual/hitbox_template.gd")
const ShapeMathScript = preload("res://scripts/visual/collision_shape_math.gd")

const STRIKE_POSE: String = "strike_extended"
const VISUAL_BODY_HEIGHT: float = 260.0
const STRIKE_POSE_BY_ID: Dictionary = {
	"hu_light": "strike_extended",
	"hu_heavy": "heavy_strike",
}

const _AUTHORED_IDS: Dictionary = {
	"hu_light": true,
	"hu_heavy": true,
}

var _manifests: Dictionary = {}
var _fighter_keys: Dictionary = {}

func register_from_manifest_file(key: String, manifest_path: String) -> void:
	_manifests[key] = AnimationManifestScript.load_from_file(manifest_path)

func register_fighter(fighter: Variant, key: String) -> void:
	_fighter_keys[fighter.get_instance_id()] = key

func has_authored_hitbox(fighter: Variant) -> bool:
	if not fighter.is_hit_active():
		return false
	if _manifest_for(fighter) == null:
		return false
	var def: Variant = fighter._attack_state.def
	return def != null and _AUTHORED_IDS.has(str(def.id))

func query_hit(attacker: Variant, defender: Variant) -> bool:
	if not has_authored_hitbox(attacker):
		return false

	var cap: Dictionary = attack_capsule_world(attacker)
	if cap.is_empty():
		return false

	var hurt: Rect2 = debug_hurtbox_world(defender)
	return ShapeMathScript.capsule_intersects_rect(cap["a"] as Vector2, cap["b"] as Vector2, float(cap["r"]), hurt)

func attack_capsule_world(fighter: Variant) -> Dictionary:
	var manifest: Variant = _manifest_for(fighter)
	if manifest == null or fighter._attack_state.def == null:
		return {}

	var pose: Dictionary = manifest.get_pose(_strike_pose_for(fighter))
	if pose.is_empty():
		return {}

	var foot: Vector2 = pose.get("footAnchor", Vector2.ZERO) as Vector2
	var chest: Vector2 = pose.get("chestAnchor", Vector2.ZERO) as Vector2
	var tip: Vector2 = pose.get("weaponTip", Vector2.ZERO) as Vector2
	var def: Variant = fighter._attack_state.def
	var cap: Dictionary = HitboxTemplateScript.build(manifest.weapon_class, chest, tip, bool(def.is_heavy), bool(def.is_grab))
	return {
		"a": _to_world(cap["a"] as Vector2, foot, fighter.position, manifest.render_scale, fighter.facing),
		"b": _to_world(cap["b"] as Vector2, foot, fighter.position, manifest.render_scale, fighter.facing),
		"r": float(cap["radius"]) * manifest.render_scale,
	}

func derived_reach(fighter: Variant) -> float:
	var cap: Dictionary = attack_capsule_world(fighter)
	if cap.is_empty():
		return 0.0
	var a: Vector2 = cap["a"] as Vector2
	var b: Vector2 = cap["b"] as Vector2
	var forward: float = maxf(a.x, b.x) - fighter.position.x
	var back: float = fighter.position.x - minf(a.x, b.x)
	return maxf(forward, back) + float(cap["r"])

func debug_capsule_world(fighter: Variant) -> Dictionary:
	if not has_authored_hitbox(fighter):
		return {}
	return attack_capsule_world(fighter)

func _strike_pose_for(fighter: Variant) -> String:
	var def: Variant = fighter._attack_state.def
	if def != null and STRIKE_POSE_BY_ID.has(str(def.id)):
		return str(STRIKE_POSE_BY_ID[str(def.id)])
	return STRIKE_POSE

func debug_hurtbox_world(fighter: Variant) -> Rect2:
	return _defender_hurtbox(fighter)

func _manifest_for(fighter: Variant) -> Variant:
	var fid: int = fighter.get_instance_id()
	if not _fighter_keys.has(fid):
		return null
	return _manifests.get(_fighter_keys[fid], null)

func _defender_hurtbox(defender: Variant) -> Rect2:
	var manifest: Variant = _manifest_for(defender)
	if manifest != null:
		var hb: Variant = manifest.get_hurtbox(STRIKE_POSE)
		if hb == null:
			hb = manifest.get_hurtbox("guard")
		if hb != null:
			var guard: Dictionary = manifest.get_pose("guard")
			var foot: Vector2 = guard.get("footAnchor", Vector2.ZERO) as Vector2
			var r: Rect2 = hb as Rect2
			var p0: Vector2 = _to_world(r.position, foot, defender.position, manifest.render_scale, defender.facing)
			var p1: Vector2 = _to_world(r.position + r.size, foot, defender.position, manifest.render_scale, defender.facing)
			return Rect2(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)), (p1 - p0).abs())

	var pad: float = 16.0
	return Rect2(
		defender.position.x - defender.half_width - pad,
		defender.position.y - VISUAL_BODY_HEIGHT,
		defender.half_width * 2.0 + pad * 2.0,
		VISUAL_BODY_HEIGHT
	)

static func _to_world(px: Vector2, foot: Vector2, root: Vector2, scale: float, facing: int) -> Vector2:
	var local: Vector2 = (px - foot) * scale
	if facing < 0:
		local.x = -local.x
	return root + local
