extends RefCounted

const TimelineScript = preload("res://scripts/visual/animation_clip_timeline.gd")
const ManifestScript = preload("res://scripts/visual/animation_manifest.gd")
const CollisionScript = preload("res://scripts/visual/presentation_collision.gd")
const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

const CASES := [
	{"id": "hu_light", "clip": "res://assets/animation_clips/hu_attack_light.timeline.json"},
	{"id": "hu_heavy", "clip": "res://assets/animation_clips/hu_attack_heavy.timeline.json"},
]

func _max_extension_active_pose(clip: Variant, def: Variant, manifest: Variant) -> String:
	var t_start: float = clip.event_time("attack_active_start", def)
	var t_end: float = clip.event_time("attack_active_end", def)
	var best_pose: String = ""
	var best_dist: float = -1.0
	for kp in clip.keyposes:
		var t: float = clip._resolve_t(kp["t"], def)
		if t < t_start - 0.0001 or t > t_end + 0.0001:
			continue
		var pose: Dictionary = manifest.get_pose(str(kp["pose"]))
		if pose.is_empty():
			continue
		var foot: Vector2 = pose["footAnchor"]
		var tip: Vector2 = pose["weaponTip"]
		var dist: float = absf(tip.x - foot.x)
		if dist > best_dist:
			best_dist = dist
			best_pose = str(kp["pose"])
	return best_pose

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	if CASES.is_empty():
		passed += 1
		return {"passed": passed, "failed": failed, "failures": failures}

	var manifest: Variant = ManifestScript.load_from_file("res://assets/animation_manifests/hu.manifest.json")
	for case in CASES:
		var clip: Variant = TimelineScript.load_from_file(str(case["clip"]))
		var def: Variant = AttackCatalogScript.hu_light() if str(case["id"]) == "hu_light" else AttackCatalogScript.hu_heavy()
		var expected: String = _max_extension_active_pose(clip, def, manifest)
		var mapped: String = str(CollisionScript.STRIKE_POSE_BY_ID.get(str(case["id"]), ""))
		if not expected.is_empty() and mapped == expected:
			passed += 1
		else:
			failed += 1
			failures.append("%s: STRIKE_POSE_BY_ID maps '%s' but max-extension active pose is '%s'" % [case["id"], mapped, expected])

	return {"passed": passed, "failed": failed, "failures": failures}
