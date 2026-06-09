extends RefCounted

const AnimationManifestScript = preload("res://scripts/visual/animation_manifest.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var manifest: Variant = AnimationManifestScript.load_from_file("res://assets/animation_manifests/hu.manifest.json")
	if manifest != null and manifest.id == "hu" and is_equal_approx(manifest.render_scale, 2.0):
		passed += 1
	else:
		failed += 1
		failures.append("hu manifest should load id and renderScale")

	var pose: Dictionary = manifest.get_pose("strike_extended")
	var foot: Vector2 = pose.get("footAnchor", Vector2.ZERO) as Vector2
	var tip: Vector2 = pose.get("weaponTip", Vector2.ZERO) as Vector2
	if foot.x > 0 and foot.x < 256 and foot.y > 100 and foot.y < 256 and tip.x > foot.x and not (foot == Vector2(128, 238)):
		passed += 1
	else:
		failed += 1
		failures.append("strike_extended anchors should be measured, not placeholder (got foot %s tip %s)" % [str(foot), str(tip)])

	var errors: Array[String] = manifest.validation_errors(["guard", "windup", "strike_extended", "recover"])
	if errors.is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("complete hu manifest should have no validation errors, got: %s" % str(errors))

	var missing: Array[String] = manifest.validation_errors(["nonexistent_pose"])
	if missing.size() == 1:
		passed += 1
	else:
		failed += 1
		failures.append("requesting an undefined pose should yield one validation error")

	if manifest.weapon_class == "sword":
		passed += 1
	else:
		failed += 1
		failures.append("manifest should expose weaponClass")

	var hb: Variant = manifest.get_hurtbox("guard")
	if hb != null and (hb as Rect2).size.x >= 8.0 and (hb as Rect2).size.y >= 30.0:
		passed += 1
	else:
		failed += 1
		failures.append("guard hurtbox should be a sane body rect")

	if manifest.get_hurtbox("nonexistent_pose") == null:
		passed += 1
	else:
		failed += 1
		failures.append("missing pose hurtbox should be null")

	return {"passed": passed, "failed": failed, "failures": failures}
