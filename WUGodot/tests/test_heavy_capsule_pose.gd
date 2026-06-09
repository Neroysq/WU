extends RefCounted

const PresentationCollisionScript = preload("res://scripts/visual/presentation_collision.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var pc: Variant = PresentationCollisionScript.new()
	pc.register_from_manifest_file("hu", "res://assets/animation_manifests/hu.manifest.json")
	var manifest: Variant = pc._manifests["hu"]
	var heavy_pose: Dictionary = manifest.get_pose("heavy_strike")
	var light_pose: Dictionary = manifest.get_pose("strike_extended")

	if heavy_pose.is_empty():
		failed += 1
		failures.append("manifest should include heavy_strike pose")
		return {"passed": passed, "failed": failed, "failures": failures}

	var heavy: Variant = _mid_active(AttackCatalogScript.hu_heavy())
	pc.register_fighter(heavy, "hu")
	var capsule: Dictionary = pc.attack_capsule_world(heavy)
	var endpoint: Vector2 = capsule.get("b", Vector2.INF) as Vector2
	var heavy_tip: Vector2 = _world_tip(heavy_pose, heavy.position, manifest.render_scale)

	if endpoint.distance_to(heavy_tip) <= 1.0:
		passed += 1
	else:
		failed += 1
		failures.append("heavy capsule endpoint should match heavy_strike tip (got %s expected %s)" % [str(endpoint), str(heavy_tip)])

	var light_tip_source: Vector2 = light_pose.get("weaponTip", Vector2.ZERO) as Vector2
	var heavy_tip_source: Vector2 = heavy_pose.get("weaponTip", Vector2.ZERO) as Vector2
	if not heavy_tip_source.is_equal_approx(light_tip_source):
		var light_tip: Vector2 = _world_tip(light_pose, heavy.position, manifest.render_scale)
		if endpoint.distance_to(light_tip) > 1.0:
			passed += 1
		else:
			failed += 1
			failures.append("heavy capsule must not use the light strike pose")
	else:
		passed += 1

	return {"passed": passed, "failed": failed, "failures": failures}

func _mid_active(attack_def: Variant) -> Variant:
	var fighter: Variant = FighterScript.new()
	fighter.position = Vector2(400.0, 900.0)
	fighter.facing = 1
	fighter._attack_state.start(attack_def)
	fighter._attack_state.advance(attack_def.windup_end + 0.01)
	return fighter

func _world_tip(pose: Dictionary, root: Vector2, scale: float) -> Vector2:
	var foot: Vector2 = pose.get("footAnchor", Vector2.ZERO) as Vector2
	var tip: Vector2 = pose.get("weaponTip", Vector2.ZERO) as Vector2
	return root + (tip - foot) * scale
